import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../../providers/app_state.dart';
import '../../db/database_helper.dart';
import '../../models/food_history.dart';
import '../../models/food.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<FoodHistory> _dismissedRecords = [];
  List<Food> _dismissedFoods = [];
  bool _loadingDismissed = true;
  int _lastDismissVersion = -1;

  @override
  void initState() {
    super.initState();
    _loadDismissed();
    // BUG-1: Listen to AppState changes to refresh dismissed data when switching tabs
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      appState.addListener(_onAppStateChanged);
      _lastDismissVersion = appState.dismissVersion;
    });
  }

  @override
  void dispose() {
    // Safe removeListener - read AppState without listening
    try {
      final appState = context.read<AppState>();
      appState.removeListener(_onAppStateChanged);
    } catch (_) {}
    super.dispose();
  }

  void _onAppStateChanged() {
    final appState = context.read<AppState>();
    if (appState.dismissVersion != _lastDismissVersion) {
      _lastDismissVersion = appState.dismissVersion;
      _loadDismissed();
    }
  }

  Future<void> _loadDismissed() async {
    final records = await DatabaseHelper().getDismissedHistoryRecords();
    final foods = await DatabaseHelper().getDismissedFoods();
    if (mounted) {
      setState(() {
        _dismissedRecords = records;
        _dismissedFoods = foods;
        _loadingDismissed = false;
      });
    }
  }

  int get _totalDismissedCount => _dismissedRecords.length + _dismissedFoods.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('历史记录'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: '导出',
            onPressed: () => _showExportDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings_backup_restore),
            tooltip: '备份与恢复',
            onPressed: () => _showBackupDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildDismissedSection(),
          const Divider(height: 1),
          Expanded(child: _buildHistoryList()),
        ],
      ),
    );
  }

  Widget _buildDismissedSection() {
    if (_loadingDismissed) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final totalCount = _totalDismissedCount;

    return Container(
      color: Colors.orange[50],
      child: totalCount == 0
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.restore, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Text('暂无已关闭的提醒', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                ],
              ),
            )
          : ExpansionTile(
              initiallyExpanded: true,
              leading: const Icon(Icons.restore, color: Colors.orange),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      '已关闭的提醒（$totalCount）',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  // [全部恢复] button
                  TextButton(
                    onPressed: () => _restoreAll(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('全部恢复', style: TextStyle(fontSize: 13, color: Colors.orange)),
                  ),
                ],
              ),
              children: [
                // v2.4: history-based dismissed records
                ..._dismissedRecords.map((record) {
                  final days = record.realDaysRemaining ?? record.daysRemaining; // BUG-3
                  final isExpired = days != null && days < 0;
                  return ListTile(
                    contentPadding: const EdgeInsets.only(left: 56, right: 16),
                    title: Text(record.foodName),
                    subtitle: Text(
                      record.remainingText,
                      style: TextStyle(
                        fontSize: 12,
                        color: isExpired ? const Color(0xFFF44336) : Colors.grey[600],
                      ),
                    ),
                    trailing: ElevatedButton(
                      onPressed: () => _restoreHistoryRecord(record),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('恢复', style: TextStyle(fontSize: 13)),
                    ),
                  );
                }),
                // Legacy: food-level dismissed records (backward-compatible)
                ..._dismissedFoods.map((food) {
                  final days = food.daysRemaining;
                  final remainingText = food.remainingText;
                  return ListTile(
                    contentPadding: const EdgeInsets.only(left: 56, right: 16),
                    title: Text(food.name),
                    subtitle: days != null
                        ? Text(
                            '距到期：$remainingText',
                            style: TextStyle(
                              fontSize: 12,
                              color: days < 0 ? const Color(0xFFF44336) : Colors.grey[600],
                            ),
                          )
                        : null,
                    trailing: ElevatedButton(
                      onPressed: () => _restoreFoodAnnouncement(food),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('恢复', style: TextStyle(fontSize: 13)),
                    ),
                  );
                }),
              ],
            ),
    );
  }

  Future<void> _restoreHistoryRecord(FoodHistory record) async {
    final appState = context.read<AppState>();
    await appState.restoreAnnouncementByHistoryId(record.id!);
    await _loadDismissed();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已恢复「${record.foodName}」的提醒')),
      );
    }
  }

  Future<void> _restoreFoodAnnouncement(Food food) async {
    final appState = context.read<AppState>();
    await appState.restoreAnnouncement(food.id!);
    await _loadDismissed();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已恢复「${food.name}」的提醒')),
      );
    }
  }

  Future<void> _restoreAll(BuildContext context) async {
    final appState = context.read<AppState>();
    await appState.clearAllDismissals();
    await _loadDismissed();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已恢复所有提醒')),
      );
    }
  }

  Widget _buildHistoryList() {
    return FutureBuilder<List<FoodHistory>>(
      future: DatabaseHelper().getAllHistory(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final histories = snapshot.data!;
        if (histories.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('暂无历史记录', style: TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: histories.length,
          itemBuilder: (context, index) {
            final h = histories[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            h.foodName,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                        ),
                        Text(
                          DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(h.recordedAt)),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (h.merchantName != null && h.merchantName!.isNotEmpty) ...[
                          _infoChip('商家', h.merchantName!),
                          const SizedBox(width: 12),
                        ],
                        _infoChip('数量', '${h.quantity}'),
                        if (h.shelfLifeDays != null) ...[
                          const SizedBox(width: 12),
                          _infoChip('保质期', '${h.shelfLifeDays}天'),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '距到期：${h.remainingText}',
                      style: TextStyle(
                        fontSize: 13,
                        color: ((h.realDaysRemaining ?? h.daysRemaining) != null && (h.realDaysRemaining ?? h.daysRemaining)! < 0)
                            ? const Color(0xFFF44336)
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _infoChip(String label, String value) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$label：', style: const TextStyle(fontSize: 13, color: Colors.grey)),
          TextSpan(text: value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  // ========== Export Dialog ==========

  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('导出数据'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.all_inclusive, color: Color(0xFF4CAF50)),
                title: const Text('导出全部食品'),
                subtitle: const Text('导出所有食品信息'),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportExcel(context, 'all');
                },
              ),
              ListTile(
                leading: const Icon(Icons.shopping_bag, color: Color(0xFF2196F3)),
                title: const Text('导出在售商品'),
                subtitle: const Text('仅导出未删除的食品'),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportExcel(context, 'active');
                },
              ),
              ListTile(
                leading: const Icon(Icons.remove_shopping_cart, color: Colors.orange),
                title: const Text('导出已售罄商品'),
                subtitle: const Text('仅导出已删除的食品'),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportExcel(context, 'deleted');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportExcel(BuildContext context, String mode) async {
    try {
      final db = DatabaseHelper();
      List<Food> foods;

      switch (mode) {
        case 'active':
          foods = await db.getAllFoods(includeDeleted: false);
          break;
        case 'deleted':
          foods = await db.getDeletedFoods();
          break;
        default:
          foods = await db.getAllFoods(includeDeleted: true);
      }

      final excel = excel_lib.Excel.createExcel();
      final sheet = excel['食品保质期报表'];

      // Header
      sheet.appendRow([
        excel_lib.TextCellValue('食品名称'),
        excel_lib.TextCellValue('商家名称'),
        excel_lib.TextCellValue('生产日期'),
        excel_lib.TextCellValue('保质期（天）'),
        excel_lib.TextCellValue('到期日'),
        excel_lib.TextCellValue('距离到期天数'),
        excel_lib.TextCellValue('数量'),
        excel_lib.TextCellValue('状态'),
      ]);

      // Data
      for (final food in foods) {
        final days = food.daysRemaining;
        sheet.appendRow([
          excel_lib.TextCellValue(food.name),
          excel_lib.TextCellValue(food.merchantName ?? '—'),
          excel_lib.TextCellValue(food.productionDate?.substring(0, 10) ?? '—'),
          excel_lib.IntCellValue(food.shelfLifeDays ?? 0),
          excel_lib.TextCellValue(food.expiryDate?.substring(0, 10) ?? '—'),
          excel_lib.IntCellValue(days ?? 0),
          excel_lib.IntCellValue(food.quantity),
          excel_lib.TextCellValue(food.isDeleted == 1 ? '已售罄' : '在售'),
        ]);
      }

      // Remove default sheet
      excel.delete('Sheet1');

      final dir = await getApplicationDocumentsDirectory();
      final now = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final modeLabel = mode == 'active' ? '在售' : (mode == 'deleted' ? '已售罄' : '全部');
      final filePath = '${dir.path}/食品保质期报表_${modeLabel}_$now.xlsx';
      final file = File(filePath);
      final bytes = excel.save();
      if (bytes != null) {
        await file.writeAsBytes(bytes);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出成功：$filePath'), duration: const Duration(seconds: 3)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败：$e')),
        );
      }
    }
  }

  // ========== Backup & Restore ==========

  void _showBackupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('数据备份与恢复'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.backup, color: Color(0xFF4CAF50)),
                title: const Text('备份数据'),
                subtitle: const Text('导出全部数据为 JSON 文件'),
                onTap: () {
                  Navigator.pop(ctx);
                  _backupData(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.restore, color: Color(0xFF2196F3)),
                title: const Text('恢复数据'),
                subtitle: const Text('从 JSON 文件导入数据'),
                onTap: () {
                  Navigator.pop(ctx);
                  _restoreData(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _backupData(BuildContext context) async {
    try {
      final db = DatabaseHelper();
      final data = await db.exportAllData();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);

      final dir = await getApplicationDocumentsDirectory();
      final now = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${dir.path}/food_backup_$now.json';
      await File(filePath).writeAsString(jsonStr);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('备份成功：$filePath'), duration: const Duration(seconds: 3)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('备份失败：$e')),
        );
      }
    }
  }

  void _restoreData(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('恢复数据'),
        content: const Text('请将备份的 JSON 文件放置到应用文档目录中，然后在下方输入文件名进行恢复。\n\n示例：food_backup_20260529_120000.json'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _doRestore(context);
            },
            child: const Text('从默认目录恢复'),
          ),
        ],
      ),
    );
  }

  Future<void> _doRestore(BuildContext context) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final files = dir.listSync().where((f) => f.path.endsWith('.json') && f.path.contains('food_backup')).toList();

      if (files.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未找到备份文件')),
          );
        }
        return;
      }

      // Use the most recent backup
      files.sort((a, b) => b.path.compareTo(a.path));
      final file = File(files.first.path);
      final jsonStr = await file.readAsString();
      final data = const JsonDecoder().convert(jsonStr) as Map<String, dynamic>;

      final db = DatabaseHelper();
      await db.importAllData(data);

      if (context.mounted) {
        final appState = context.read<AppState>();
        await appState.refreshFoods();
        await appState.refreshCategories();
        await appState.refreshMerchants();
        await _loadDismissed();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('数据恢复成功')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('恢复失败：$e')),
        );
      }
    }
  }
}
