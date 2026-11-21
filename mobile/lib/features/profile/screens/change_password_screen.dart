import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/widgets/common.dart';
import '../../auth/data/auth_repository.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final msg = await context.read<AuthRepository>().changePassword(_current.text, _new.text);
      if (mounted) {
        showSnack(context, msg);
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.fieldError('current_password') ?? e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          TextFormField(controller: _current, obscureText: true, decoration: const InputDecoration(labelText: 'Current password', prefixIcon: Icon(Icons.lock_outline)),
              validator: (v) => v!.isEmpty ? 'Enter your current password' : null),
          const SizedBox(height: 14),
          TextFormField(controller: _new, obscureText: true, decoration: const InputDecoration(labelText: 'New password', prefixIcon: Icon(Icons.lock_reset_rounded)),
              validator: (v) => v!.length < 8 || !RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v) ? 'At least 8 characters with letters and numbers' : null),
          const SizedBox(height: 14),
          TextFormField(controller: _confirm, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm new password', prefixIcon: Icon(Icons.lock_reset_rounded)),
              validator: (v) => v != _new.text ? 'Passwords do not match' : null),
          const SizedBox(height: 8),
          const Text('Other devices will be signed out.', style: TextStyle(fontSize: 12.5)),
          const SizedBox(height: 24),
          GradientButton(label: 'Update password', loading: _saving, onPressed: _save),
        ]),
      ),
    );
  }
}
