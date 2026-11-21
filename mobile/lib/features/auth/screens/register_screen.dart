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
  final _plate = TextEditingController();
  final _nationalId = TextEditingController();
  String _role = 'customer'; // customer | driver
  String _type = 'student';
  String _vehicle = 'motorbike';
  bool _loading = false;
  ApiException? _error;

  @override
  void dispose() {
    for (final c in [_name, _email, _id, _phone, _password, _confirm, _plate, _nationalId]) {
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
      final auth = context.read<AuthProvider>();
      final common = {
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'password': _password.text,
        'password_confirmation': _confirm.text,
      };
      if (_role == 'driver') {
        await auth.registerDriver({
          ...common,
          'university_id': _id.text.trim().isEmpty ? null : _id.text.trim(),
          'vehicle_type': _vehicle,
          'plate_number': _plate.text.trim().isEmpty ? null : _plate.text.trim(),
          'national_id': _nationalId.text.trim(),
        });
      } else {
        await auth.register({...common, 'university_id': _id.text.trim(), 'user_type': _type});
      }
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
            const Text('I want to', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _roleCard('customer', Icons.restaurant_rounded, 'Order food', 'Student, lecturer or staff')),
              const SizedBox(width: 10),
              Expanded(child: _roleCard('driver', Icons.delivery_dining_rounded, 'Deliver food', 'Campus driver')),
            ]),
            const SizedBox(height: 18),
            if (_role == 'customer') ...[
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
            ] else
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(14)),
                child: const Row(children: [
                  Icon(Icons.verified_user_outlined, color: AppColors.primary),
                  SizedBox(width: 10),
                  Expanded(child: Text('The RUPP Eat admin checks your details before you can go online and accept deliveries.', style: TextStyle(fontSize: 13))),
                ]),
              ),
            _field(_name, 'Full name', Icons.person_outline, 'name', validator: (v) => v!.trim().length < 2 ? 'Enter your name' : null),
            _field(_email, 'University email', Icons.alternate_email, 'email',
                keyboard: TextInputType.emailAddress, validator: (v) => !RegExp(r'^\S+@\S+\.\S+$').hasMatch(v!.trim()) ? 'Enter a valid email' : null),
            _field(_id, _role == 'driver' ? 'Student / staff ID (optional)' : _type == 'student' ? 'Student ID (e.g. e20230001)' : 'Staff ID',
                Icons.badge_outlined, 'university_id',
                validator: (v) => _role == 'customer' && v!.trim().isEmpty ? 'Enter your ID' : null),
            _field(_phone, 'Phone number', Icons.phone_outlined, 'phone',
                keyboard: TextInputType.phone, validator: (v) => v!.replaceAll(' ', '').length < 8 ? 'Enter a valid phone number' : null),
            if (_role == 'driver') ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: DropdownButtonFormField<String>(
                  initialValue: _vehicle,
                  decoration: const InputDecoration(labelText: 'How do you deliver?', prefixIcon: Icon(Icons.two_wheeler_outlined)),
                  items: const [
                    DropdownMenuItem(value: 'motorbike', child: Text('Motorbike')),
                    DropdownMenuItem(value: 'bicycle', child: Text('Bicycle')),
                    DropdownMenuItem(value: 'walking', child: Text('On foot')),
                  ],
                  onChanged: (v) => setState(() => _vehicle = v!),
                ),
              ),
              if (_vehicle == 'motorbike')
                _field(_plate, 'Plate number (e.g. 1AB-2345)', Icons.pin_outlined, 'plate_number',
                    validator: (v) => v!.trim().isEmpty ? 'Enter your plate number' : null),
              _field(_nationalId, 'National ID or university card number', Icons.credit_card_outlined, 'national_id',
                  validator: (v) => v!.trim().isEmpty ? 'Needed for verification' : null),
            ],
            _field(_password, 'Password (min 8, letters + numbers)', Icons.lock_outline, 'password', obscure: true,
                validator: (v) => v!.length < 8 || !RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)
                    ? 'At least 8 characters with letters and numbers'
                    : null),
            _field(_confirm, 'Confirm password', Icons.lock_outline, 'password_confirmation', obscure: true,
                validator: (v) => v != _password.text ? 'Passwords do not match' : null),
            if (_error != null && _error!.errors == null)
              Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!.message, style: const TextStyle(color: AppColors.danger))),
            const SizedBox(height: 8),
            GradientButton(label: _role == 'driver' ? 'Apply as driver' : 'Create account', loading: _loading, onPressed: _submit),
          ]),
        ),
      ),
    );
  }

  Widget _roleCard(String value, IconData icon, String title, String subtitle) {
    final selected = _role == value;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() {
        _role = value;
        _error = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.cardGradient : null,
          color: selected ? null : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: selected ? AppColors.gold : AppColors.primary, size: 28),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: selected ? Colors.white : AppColors.text)),
          Text(subtitle, style: TextStyle(fontSize: 12, color: selected ? Colors.white70 : AppColors.textMuted)),
        ]),
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
