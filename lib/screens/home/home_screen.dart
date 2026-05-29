import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/app_state.dart';
import '../../utils/date_utils.dart' as du;
import '../../models/food_history.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Timer _timer;
  // PERF-2: Use ValueNotifier so only the clock widget rebuilds each second
  final ValueNotifier<DateTime> _clockNotifier = ValueNotifier(DateTime.now());

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _clockNotifier.value = DateTime.now();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _clockNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('食品保质期助手')),
      body: Column(
        children: [
          _buildClockSection(),
          Expanded(child: _buildAnnouncementSection()),
        ],
      ),
    );
  }

  Widget _buildClockSection() {
    // PERF-2: Only rebuilds the clock container, not the whole page
    return ValueListenableBuilder<DateTime>(
      valueListenable: _clockNotifier,
      builder: (context, now, _) {
        final year = '${now.year}年';
        final date = '${now.month}月${now.day}日 ${du.DateUtils.getWeekday(now.weekday)}';
        final time = DateFormat('HH:mm:ss').format(now);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            children: [
              Text(year, style: const TextStyle(fontSize: 20, color: Colors.white70)),
              const SizedBox(height: 4),
              Text(date, style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Text(
                time,
                style: const TextStyle(fontSize: 48, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 4),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnnouncementSection() {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final records = appState.expiringRecords;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.notifications_active, color: Color(0xFFF44336)),
                  const SizedBox(width: 8),
                  const Text('临期提醒', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  _buildThresholdSelector(appState),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: records.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('暂无临期食品', style: TextStyle(fontSize: 16, color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: records.length,
                        itemBuilder: (context, index) {
                          final record = records[index];
                          return _buildRecordCard(context, appState, record);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecordCard(BuildContext context, AppState appState, FoodHistory record) {
    final days = record.realDaysRemaining ?? record.daysRemaining; // BUG-3: real-time
    final isExpired = days != null && days < 0;
    // DEFECT-4: 3-level color grading
    final Color dotColor;
    final Color textColor;
    if (isExpired) {
      dotColor = const Color(0xFF616161); // 过期：灰色
      textColor = const Color(0xFF616161);
    } else if (days != null && days <= 7) {
      dotColor = const Color(0xFFF44336); // 紧急（7天内）：红色
      textColor = const Color(0xFFF44336);
    } else if (days != null && days <= 30) {
      dotColor = const Color(0xFFFF9800); // 临期（30天内）：橙色
      textColor = const Color(0xFFFF9800);
    } else {
      dotColor = const Color(0xFF4CAF50); // 安全：绿色
      textColor = const Color(0xFF4CAF50);
    }
    final daysText = record.remainingText;

    // Build subtitle parts
    final subtitleParts = <String>[];
    if (record.merchantName != null && record.merchantName!.isNotEmpty) {
      subtitleParts.add(record.merchantName!);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: ListTile(
          leading: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          title: Text(
            record.foodName,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    daysText,
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                  if (record.quantity > 0) ...[
                    const SizedBox(width: 12),
                    Text('数量：${record.quantity}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                  if (subtitleParts.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Text(subtitleParts.join(' · '), style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                ],
              ),
              Text(
                '录入时间：${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(record.recordedAt))}',
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
            ],
          ),
          trailing: GestureDetector(
            onTap: () => _dismissWithConfirm(context, appState, record),
            child: const Icon(Icons.close, color: Colors.grey, size: 20),
          ),
        ),
      ),
    );
  }

  void _dismissWithConfirm(BuildContext context, AppState appState, FoodHistory record) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('关闭提醒'),
        content: Text('确定关闭「${record.foodName}」的这条提醒吗？\n可在历史记录页面恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              appState.dismissAnnouncement(record.foodId, historyId: record.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Widget _buildThresholdSelector(AppState appState) {
    return GestureDetector(
      onTap: () => _showThresholdDialog(appState),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${appState.thresholdMonths}个月',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(width: 2),
          const Icon(Icons.settings, size: 18, color: Colors.grey),
        ],
      ),
    );
  }

  void _showThresholdDialog(AppState appState) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('提醒阈值设置'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [1, 2, 3].map((months) {
              return RadioListTile<int>(
                title: Text('$months个月'),
                value: months,
                groupValue: appState.thresholdMonths,
                activeColor: const Color(0xFF4CAF50),
                onChanged: (value) {
                  if (value != null) {
                    appState.setThresholdMonths(value);
                    Navigator.pop(ctx);
                  }
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
