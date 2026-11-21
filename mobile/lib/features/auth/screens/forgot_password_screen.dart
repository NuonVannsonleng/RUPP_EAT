import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../data/auth_repository.dart';

/// Two steps: request a 6-digit code by email, then set a new password with it.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _codeSent = false;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String> Function() action, {VoidCallback? onDone}) async {
    setState(() => _loading = true);
    try {
      final msg = await action();
      if (!mounted) return;
      showSnack(context, msg);
      onDone?.call();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<AuthRepository>();

    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        Text(
          _codeSent ? 'Enter the 6-digit code we emailed to ${_email.text} and choose a new password.' : 'Enter your account email. We will send you a 6-digit reset code.',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _email,
          enabled: !_codeSent,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: 'Email', prefixIcon: Icon(Icons.alternate_email)),
        ),
        if (_codeSent) ...[
          const SizedBox(height: 14),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(hintText: '6-digit code', prefixIcon: Icon(Icons.pin_outlined), counterText: ''),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(hintText: 'New password (min 8, letters + numbers)', prefixIcon: Icon(Icons.lock_outline)),
          ),
        ],
        const SizedBox(height: 24),
        GradientButton(
          label: _codeSent ? 'Reset password' : 'Send code',
          loading: _loading,
          onPressed: () => _codeSent
              ? _run(() => repo.resetPassword(_email.text.trim(), _code.text.trim(), _password.text), onDone: () => Navigator.pop(context))
              : _run(() => repo.forgotPassword(_email.text.trim()), onDone: () => setState(() => _codeSent = true)),
        ),
        if (_codeSent)
          TextButton(onPressed: () => setState(() => _codeSent = false), child: const Text('Use a different email')),
      ]),
    );
  }
}
