import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../orders/data/order_repository.dart';
import '../../orders/models/order.dart';
import '../../stores/data/catalog_repository.dart';

/// Contact support: call / email, or send a ticket (optionally about an order).
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key, this.order});
  final Order? order;

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  PublicSettings? _settings;
  List<Map<String, dynamic>> _tickets = [];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    if (widget.order != null) _subject.text = 'Problem with order ${widget.order!.number}';
    _load();
  }

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([context.read<CatalogRepository>().settings(), context.read<OrderRepository>().supportTickets()]);
      if (mounted) {
        setState(() {
          _settings = results[0] as PublicSettings;
          _tickets = results[1] as List<Map<String, dynamic>>;
        });
      }
    } catch (_) {}
  }

  Future<void> _send() async {
    if (_subject.text.trim().isEmpty || _message.text.trim().length < 5) {
      showSnack(context, 'Please enter a subject and describe the problem.', error: true);
      return;
    }
    setState(() => _sending = true);
    try {
      final msg = await context.read<OrderRepository>().createSupportTicket(_subject.text.trim(), _message.text.trim(), orderId: widget.order?.id);
      if (!mounted) return;
      showSnack(context, msg);
      _message.clear();
      _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact support')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: Column(children: [
            if (_settings?.supportPhone != null)
              ListTile(
                leading: const Icon(Icons.call_rounded, color: AppColors.success),
                title: const Text('Call RUPP Eat support'),
                subtitle: Text(_settings!.supportPhone!),
                onTap: () => launchUrl(Uri(scheme: 'tel', path: _settings!.supportPhone!.replaceAll(' ', ''))),
              ),
            if (_settings?.supportEmail != null)
              ListTile(
                leading: const Icon(Icons.email_outlined, color: AppColors.primary),
                title: const Text('Email us'),
                subtitle: Text(_settings!.supportEmail!),
                onTap: () => launchUrl(Uri(scheme: 'mailto', path: _settings!.supportEmail!)),
              ),
          ]),
        ),
        const SizedBox(height: 16),
        Text('Send a message', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        TextField(controller: _subject, decoration: const InputDecoration(labelText: 'Subject')),
        const SizedBox(height: 12),
        TextField(controller: _message, maxLines: 5, maxLength: 2000, decoration: const InputDecoration(labelText: 'Describe the problem', alignLabelWithHint: true)),
        const SizedBox(height: 8),
        GradientButton(label: 'Send to support', loading: _sending, onPressed: _send),
        if (_tickets.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('My requests', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final t in _tickets)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(t['subject'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(t['resolution'] ?? t['message'] ?? '', maxLines: 3, overflow: TextOverflow.ellipsis),
                trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  StatusChip(status: t['status'] == 'resolved' ? 'delivered' : 'pending', label: t['status'] == 'resolved' ? 'Resolved' : 'Open', small: true),
                  Text(timeAgo(parseDate(t['created_at'])), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ]),
              ),
            ),
        ],
      ]),
    );
  }
}
