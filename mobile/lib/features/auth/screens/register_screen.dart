import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _id = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String _type = 'student';
  bool _loading = false;
  ApiException? _error;

  @override
  void dispose() {
    for (final c in [_name, _email, _id, _phone, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().register({
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'university_id': _id.text.trim(),
        'user_type': _type,
        'phone': _phone.text.trim(),
        'password': _password.text,
        'password_confirmation': _confirm.text,
      });
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on ApiException catch (e) {
      setState(() => _error = e);
      _form.currentState!.validate();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _server(String field) => _error?.fieldError(field);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 32), children: [
            const Text('Join RUPP Eat with your university details.', style: TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 20),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'student', label: Text('Student'), icon: Icon(Icons.school_outlined)),
                ButtonSegment(value: 'lecturer', label: Text('Lecturer')),
                ButtonSegment(value: 'staff', label: Text('Staff')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 18),
            _field(_name, 'Full name', Icons.person_outline, 'name', validator: (v) => v!.trim().length < 2 ? 'Enter your name' : null),
            _field(_email, 'University email', Icons.alternate_email, 'email',
                keyboard: TextInputType.emailAddress, validator: (v) => !RegExp(r'^\S+@\S+\.\S+$').hasMatch(v!.trim()) ? 'Enter a valid email' : null),
            _field(_id, _type == 'student' ? 'Student ID (e.g. e20230001)' : 'Staff ID', Icons.badge_outlined, 'university_id',
                validator: (v) => v!.trim().isEmpty ? 'Enter your ID' : null),
            _field(_phone, 'Phone number', Icons.phone_outlined, 'phone',
                keyboard: TextInputType.phone, validator: (v) => v!.replaceAll(' ', '').length < 8 ? 'Enter a valid phone number' : null),
            _field(_password, 'Password (min 8, letters + numbers)', Icons.lock_outline, 'password', obscure: true,
                validator: (v) => v!.length < 8 || !RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)
                    ? 'At least 8 characters with letters and numbers'
                    : null),
            _field(_confirm, 'Confirm password', Icons.lock_outline, 'password_confirmation', obscure: true,
                validator: (v) => v != _password.text ? 'Passwords do not match' : null),
            if (_error != null && _error!.errors == null)
              Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!.message, style: const TextStyle(color: AppColors.danger))),
            const SizedBox(height: 8),
            GradientButton(label: 'Create account', loading: _loading, onPressed: _submit),
          ]),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, IconData icon, String key,
      {bool obscure = false, TextInputType? keyboard, String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: c,
        obscureText: obscure,
        keyboardType: keyboard,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon)),
        validator: (v) => validator?.call(v) ?? _server(key),
        onChanged: (_) {
          if (_server(key) != null) setState(() => _error = null);
        },
      ),
    );
  }
}
