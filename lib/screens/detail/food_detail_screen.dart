import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/food.dart';
import '../../models/food_history.dart';
import '../../db/database_helper.dart';
import '../../providers/app_state.dart';
import 'package:provider/provider.dart';
import 'record_edit_screen.dart';

class FoodDetailScreen extends StatefulWidget {
  final Food food;
  final String? merchantFilter; // If set, only show records for this merchant
  const FoodDetailScreen({super.key, required this.food, this.merchantFilter});

  @override
  State<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends State<FoodDetailScreen> {
  late Food _currentFood;

  @override
  void initState() {
    super.initState();
    _currentFood = widget.food;
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.merchantFilter != null
        ? '${_currentFood.name} - ${widget.merchantFilter}'
        : _currentFood.name;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: _buildRecordsList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addRecord(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildRecordsList() {
    final db = DatabaseHelper();
    final Future<List<FoodHistory>> future;
    if (widget.merchantFilter != null) {
      future = db.getHistoryByFoodIdAndMerchant(_currentFood.id!, widget.merchantFilter!);
    } else {
      future = db.getHistoryByFoodId(_currentFood.id!);
    }

    return FutureBuilder<List<FoodHistory>>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final histories = snapshot.data!;
        if (histories.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  widget.merchantFilter != null
                      ? '暂无该商家的记录，点击右下角添加'
                      : '暂无记录，点击右下角添加',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: histories.length,
          itemBuilder: (context, index) {
            final h = histories[index];
            final isExpired = (h.realDaysRemaining ?? h.daysRemaining) != null && (h.realDaysRemaining ?? h.daysRemaining)! < 0;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '录入时间：${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(h.recordedAt))}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                        // Edit button (directly updates this record)
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20, color: Color(0xFF4CAF50)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: '编辑此记录',
                          onPressed: () => _editRecord(context, h),
                        ),
                        const SizedBox(width: 8),
                        // Delete button
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: '删除此记录',
                          onPressed: () => _confirmDeleteRecord(context, h),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (h.productionDate != null)
                      _infoRow('生产日期', h.productionDate!.substring(0, 10)),
                    if (h.shelfLifeDays != null && h.shelfLifeDays! > 0)
                      _infoRow('保质期', '${h.shelfLifeDays}天'),
                    if (h.merchantName != null && h.merchantName!.isNotEmpty)
                      _infoRow('商家', h.merchantName!),
                    _infoRow('数量', '${h.quantity}'),
                    const SizedBox(height: 4),
                    Text(
                      '距到期：${h.remainingText}',
                      style: TextStyle(
                        fontSize: 14,
                        color: isExpired ? const Color(0xFFF44336) : const Color(0xFF4CAF50),
                        fontWeight: FontWeight.w600,
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

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Text('$label：', style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  void _addRecord(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecordEditScreen(food: _currentFood),
      ),
    );
    if (result == true && mounted) {
      final updated = await DatabaseHelper().getFood(_currentFood.id!);
      if (updated != null && mounted) {
        setState(() => _currentFood = updated);
      }
    }
  }

  /// Edit directly updates the existing record
  void _editRecord(BuildContext context, FoodHistory record) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecordEditScreen(food: _currentFood, record: record),
      ),
    );
    if (result == true && mounted) {
      final updated = await DatabaseHelper().getFood(_currentFood.id!);
      if (updated != null && mounted) {
        setState(() => _currentFood = updated);
      }
    }
  }

  void _confirmDeleteRecord(BuildContext context, FoodHistory record) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定删除该记录吗？\n录入时间：${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(record.recordedAt))}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final appState = context.read<AppState>();
              await appState.deleteRecord(record.id!, _currentFood.id!);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已删除该记录')),
                );
                // Refresh food data
                final updated = await DatabaseHelper().getFood(_currentFood.id!);
                if (updated != null && mounted) {
                  setState(() => _currentFood = updated);
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
