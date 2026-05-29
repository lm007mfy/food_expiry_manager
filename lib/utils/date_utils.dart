import 'package:intl/intl.dart';

class DateUtils {
  static String formatDate(String? isoDate) {
    if (isoDate == null) return '—';
    final date = DateTime.tryParse(isoDate);
    if (date == null) return '—';
    return DateFormat('yyyy-MM-dd').format(date);
  }

  static String formatDateTime(String? isoDate) {
    if (isoDate == null) return '—';
    final date = DateTime.tryParse(isoDate);
    if (date == null) return '—';
    return DateFormat('yyyy-MM-dd HH:mm').format(date);
  }

  static String formatFullDateTime(DateTime dt) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
  }

  static String getWeekday(int weekday) {
    const days = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    return days[weekday - 1];
  }

  /// Calculate days between two dates
  static int daysBetween(DateTime from, DateTime to) {
    from = DateTime(from.year, from.month, from.day);
    to = DateTime(to.year, to.month, to.day);
    return to.difference(from).inDays;
  }

  /// Calculate remaining time as human-readable string from a target date
  static String remainingTimeText(DateTime target) {
    final now = DateTime.now();
    final diff = target.difference(now);

    if (diff.isNegative) {
      return '已过期 ${diff.inDays.abs()}天';
    }

    final days = diff.inDays;
    final years = days ~/ 365;
    final months = (days % 365) ~/ 30;
    final remainingDays = days - years * 365 - months * 30;

    if (years > 0) {
      return '$years年${months}个月${remainingDays}天';
    } else if (months > 0) {
      return '$months个月${remainingDays}天';
    } else {
      return '$days天';
    }
  }
}
