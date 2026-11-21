import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../auth/providers/auth_provider.dart';
import '../../notifications/providers/notification_provider.dart';
import '../../notifications/screens/notifications_screen.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';
import 'favorites_screen.dart';
import 'support_screen.dart';

/// Shared by customers and drivers (drivers get a slightly different menu).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user!;
    final unread = context.watch<NotificationProvider>().unread;

    void open(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: AppColors.primary,
                backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                child: user.avatarUrl == null ? Text(user.initials, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)) : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user.name, style: Theme.of(context).textTheme.titleLarge),
                  Text(user.email, style: const TextStyle(color: AppColors.textMuted)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, children: [
                    _tag(user.typeLabel, AppColors.primary),
                    if (user.universityId != null) _tag(user.universityId!, AppColors.accent),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(children: [
            _item(Icons.person_outline_rounded, 'Edit profile', () => open(const EditProfileScreen())),
            _item(Icons.lock_outline_rounded, 'Change password', () => open(const ChangePasswordScreen())),
            _item(Icons.notifications_none_rounded, 'Notifications', () => open(const NotificationsScreen()),
                trailing: unread > 0 ? Badge(label: Text('$unread')) : null),
            if (user.isCustomer) _item(Icons.favorite_border_rounded, 'Favorite stores', () => open(const FavoritesScreen())),
            _item(Icons.support_agent_rounded, 'Contact support', () => open(const SupportScreen())),
          ]),
        ),
        const SizedBox(height: 16),
        Card(
          child: _item(Icons.logout_rounded, 'Log out', () async {
            if (await confirmDialog(context, title: 'Log out?', message: 'You will need to log in again to order.', confirm: 'Log out', danger: true)) {
              await auth.logout();
            }
          }, color: AppColors.danger),
        ),
        const SizedBox(height: 24),
        const Center(child: BrandLogo(size: 0.7)),
        const SizedBox(height: 6),
        const Center(child: Text('Royal University of Phnom Penh', style: TextStyle(color: AppColors.textMuted, fontSize: 12))),
      ]),
    );
  }

  Widget _tag(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
      );

  Widget _item(IconData icon, String label, VoidCallback onTap, {Widget? trailing, Color? color}) => ListTile(
        leading: Icon(icon, color: color ?? AppColors.primary),
        title: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
        trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      );
}
