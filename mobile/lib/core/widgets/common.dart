import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Network image with rounded corners, loading shimmer and a branded fallback.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage(this.url, {super.key, this.width, this.height, this.radius = 14, this.icon = Icons.restaurant_rounded});

  final String? url;
  final double? width;
  final double? height;
  final double radius;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.primaryLight, AppColors.accentSoft], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Icon(icon, color: AppColors.primary.withValues(alpha: 0.45), size: 32),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: (url == null || url!.isEmpty)
          ? fallback
          : Image.network(
              url!,
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : Container(width: width, height: height, color: AppColors.border.withValues(alpha: 0.5)),
            ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(color: AppColors.accent),
          if (message != null) ...[const SizedBox(height: 12), Text(message!, style: const TextStyle(color: AppColors.textMuted))],
        ]),
      );
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off_rounded, size: 56, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
            ],
          ]),
        ),
      );
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.icon, required this.title, this.message, this.action});
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(color: AppColors.accentSoft, shape: BoxShape.circle),
              child: Icon(icon, size: 44, color: AppColors.accent),
            ),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(message!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
            ],
            if (action != null) ...[const SizedBox(height: 18), action!],
          ]),
        ),
      );
}

/// The orange gradient call-to-action used for "Log in", "Place Order", etc.
class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.label, this.onPressed, this.loading = false, this.icon, this.trailing});

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: 54,
          decoration: BoxDecoration(gradient: AppColors.ctaGradient, borderRadius: BorderRadius.circular(14)),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: enabled ? onPressed : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: loading
                  ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white)))
                  : Row(children: [
                      if (icon != null) ...[Icon(icon, color: Colors.white), const SizedBox(width: 8)],
                      Expanded(
                        child: Text(label,
                            textAlign: trailing == null && icon == null ? TextAlign.center : TextAlign.start,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                      ),
                      if (trailing != null)
                        Text(trailing!, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                    ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// − 2 + control, as in the menu design.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({super.key, required this.value, required this.onChanged, this.min = 0, this.max = 50, this.compact = false});

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 28.0 : 34.0;
    Widget btn(IconData icon, VoidCallback? onTap, {bool filled = false}) => InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: filled ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: filled ? AppColors.primary : AppColors.border),
            ),
            child: Icon(icon, size: compact ? 16 : 18, color: onTap == null ? AppColors.border : (filled ? Colors.white : AppColors.text)),
          ),
        );

    return Row(mainAxisSize: MainAxisSize.min, children: [
      btn(Icons.remove_rounded, value > min ? () => onChanged(value - 1) : null),
      SizedBox(
        width: compact ? 26 : 32,
        child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      ),
      btn(Icons.add_rounded, value < max ? () => onChanged(value + 1) : null, filled: true),
    ]);
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status, required this.label, this.small = false});
  final String status;
  final String label;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final style = StatusStyle.of(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 10, vertical: small ? 3 : 5),
      decoration: BoxDecoration(color: style.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(style.icon, size: small ? 13 : 15, color: style.color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: style.color, fontWeight: FontWeight.w700, fontSize: small ? 11 : 12)),
      ]),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 12, 10),
        child: Row(children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!, style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700))),
        ]),
      );
}

/// Small white card with a numbered step title, used on checkout.
class StepCard extends StatelessWidget {
  const StepCard({super.key, required this.step, required this.title, required this.child});
  final int step;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(radius: 13, backgroundColor: AppColors.primary, child: Text('$step', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800))),
              const SizedBox(width: 10),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ]),
            const SizedBox(height: 14),
            child,
          ]),
        ),
      );
}

void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.danger : AppColors.text,
    ));
}

Future<bool> confirmDialog(BuildContext context, {required String title, required String message, String confirm = 'Confirm', bool danger = false}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: danger ? AppColors.danger : AppColors.primary, minimumSize: const Size(90, 42)),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// The official RUPP seal in a white ring.
class RuppSeal extends StatelessWidget {
  const RuppSeal({super.key, this.size = 48});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.05),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Image.asset('assets/images/rupp_logo.png', fit: BoxFit.contain),
      );
}

/// RUPP seal + "RUPP Eat" wordmark. [light] for use on green backgrounds.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 1, this.light = false});
  final double size;
  final bool light;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        RuppSeal(size: 44 * size),
        SizedBox(width: 10 * size),
        RichText(
          text: TextSpan(style: TextStyle(fontSize: 24 * size, fontWeight: FontWeight.w900, letterSpacing: 0.3), children: [
            TextSpan(text: 'RUPP ', style: TextStyle(color: light ? Colors.white : AppColors.primary)),
            const TextSpan(text: 'Eat', style: TextStyle(color: AppColors.gold)),
          ]),
        ),
      ]);
}

/// Green campus header: RUPP building photo, green overlay, seal and the
/// university name in Khmer and English — same style as the RUPP Smart Campus app.
class CampusHeader extends StatelessWidget {
  const CampusHeader({super.key, this.trailing, this.bottom, this.height});
  final Widget? trailing;
  final Widget? bottom;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light, // white status-bar icons on the green header
      child: Container(
      height: height,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned.fill(
          child: Opacity(
            opacity: 0.55,
            child: Image.asset('assets/images/rupp_building.webp', fit: BoxFit.cover, alignment: Alignment.bottomCenter),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.primaryDark.withValues(alpha: 0.55), AppColors.primary.withValues(alpha: 0.92)],
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, top + 14, 12, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const RuppSeal(size: 50),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('សាកលវិទ្យាល័យភូមិន្ទភ្នំពេញ',
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700, height: 1.3)),
                  Text('Royal University of Phnom Penh', style: TextStyle(color: Colors.white70, fontSize: 13)),
                ]),
              ),
              ?trailing,
            ]),
            if (bottom != null) ...[const SizedBox(height: 18), bottom!],
          ]),
        ),
      ]),
      ),
    );
  }
}
