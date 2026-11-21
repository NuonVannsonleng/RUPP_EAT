import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';

final _money = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

String money(num? value) => _money.format(value ?? 0);

DateTime? parseDate(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

String formatDateTime(DateTime? d) => d == null ? '' : DateFormat('d MMM yyyy, h:mm a').format(d);

String formatTime(DateTime? d) => d == null ? '' : DateFormat('h:mm a').format(d);

String timeAgo(DateTime? d) {
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays < 7) return '${diff.inDays} d ago';
  return DateFormat('d MMM').format(d);
}

double toDouble(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

int toInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;

/// Colour + icon for each order status, shared by customer and driver screens.
class StatusStyle {
  const StatusStyle(this.color, this.icon);
  final Color color;
  final IconData icon;

  static StatusStyle of(String status) {
    switch (status) {
      case 'pending':
        return const StatusStyle(Color(0xFFB7791F), Icons.hourglass_top_rounded);
      case 'accepted':
        return const StatusStyle(AppColors.info, Icons.thumb_up_alt_rounded);
      case 'preparing':
        return const StatusStyle(Color(0xFF8E44AD), Icons.soup_kitchen_rounded);
      case 'ready':
        return const StatusStyle(AppColors.accent, Icons.inventory_2_rounded);
      case 'driver_assigned':
      case 'assigned':
        return const StatusStyle(AppColors.primary, Icons.two_wheeler_rounded);
      case 'on_the_way':
      case 'picked_up':
      case 'arriving':
        return const StatusStyle(AppColors.primary, Icons.delivery_dining_rounded);
      case 'delivered':
        return const StatusStyle(AppColors.success, Icons.check_circle_rounded);
      case 'searching':
        return const StatusStyle(AppColors.accent, Icons.search_rounded);
      case 'rejected':
      case 'cancelled':
        return const StatusStyle(AppColors.danger, Icons.cancel_rounded);
      default:
        return const StatusStyle(AppColors.textMuted, Icons.circle_outlined);
    }
  }
}

/// Maps the Material icon names stored on categories (server) to Flutter icons.
IconData categoryIcon(String? name) {
  const map = <String, IconData>{
    'rice_bowl': Icons.rice_bowl_rounded,
    'ramen_dining': Icons.ramen_dining_rounded,
    'lunch_dining': Icons.lunch_dining_rounded,
    'fastfood': Icons.fastfood_rounded,
    'local_cafe': Icons.local_cafe_rounded,
    'local_drink': Icons.local_drink_rounded,
    'icecream': Icons.icecream_rounded,
    'eco': Icons.eco_rounded,
    'egg_alt': Icons.egg_alt_rounded,
    'bakery_dining': Icons.bakery_dining_rounded,
    'local_pizza': Icons.local_pizza_rounded,
  };
  return map[name] ?? Icons.restaurant_rounded;
}
