import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/widgets/common.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/providers/auth_provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: context.read<AuthProvider>().user!.name);
  late final _email = TextEditingController(text: context.read<AuthProvider>().user!.email);
  late final _phone = TextEditingController(text: context.read<AuthProvider>().user!.phone ?? '');
  late final _plate = TextEditingController(text: context.read<AuthProvider>().user!.driverProfile?.plateNumber ?? '');
  late String _vehicle = context.read<AuthProvider>().user!.driverProfile?.vehicleType ?? 'motorbike';
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _plate.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    setState(() => _saving = true);
    try {
      final user = await context.read<AuthRepository>().updateProfile({
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        if (auth.user!.isDriver) ...{'vehicle_type': _vehicle, 'plate_number': _plate.text.trim()},
      });
      auth.setUser(user);
      if (mounted) {
        showSnack(context, 'Profile updated');
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user!;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)),
              validator: (v) => v!.trim().length < 2 ? 'Enter your name' : null),
          const SizedBox(height: 14),
          TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.alternate_email)),
              validator: (v) => !RegExp(r'^\S+@\S+\.\S+$').hasMatch(v!.trim()) ? 'Enter a valid email' : null),
          const SizedBox(height: 14),
          TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined)),
              validator: (v) => v!.replaceAll(' ', '').length < 8 ? 'Enter a valid phone number' : null),
          if (user.universityId != null) ...[
            const SizedBox(height: 14),
            TextFormField(initialValue: user.universityId, enabled: false, decoration: const InputDecoration(labelText: 'Student / staff ID', prefixIcon: Icon(Icons.badge_outlined))),
          ],
          if (user.isDriver) ...[
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _vehicle,
              decoration: const InputDecoration(labelText: 'Vehicle', prefixIcon: Icon(Icons.two_wheeler_outlined)),
              items: const [
                DropdownMenuItem(value: 'motorbike', child: Text('Motorbike')),
                DropdownMenuItem(value: 'bicycle', child: Text('Bicycle')),
                DropdownMenuItem(value: 'walking', child: Text('On foot')),
              ],
              onChanged: (v) => setState(() => _vehicle = v!),
            ),
            const SizedBox(height: 14),
            TextFormField(controller: _plate, decoration: const InputDecoration(labelText: 'Plate number (optional)', prefixIcon: Icon(Icons.pin_outlined))),
          ],
          const SizedBox(height: 28),
          GradientButton(label: 'Save changes', loading: _saving, onPressed: _save),
        ]),
      ),
    );
  }
}
