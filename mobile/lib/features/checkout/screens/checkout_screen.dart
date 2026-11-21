import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../cart/providers/cart_provider.dart';
import '../../orders/data/order_repository.dart';
import '../../stores/data/catalog_repository.dart';
import '../models/campus.dart';
import 'order_placed_screen.dart';

/// 1. Delivery or pickup  2. Confirm order  3. Payment method  → Place order
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  // One key per checkout attempt: retries / double taps return the same order.
  final String _idempotencyKey = List.generate(16, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join();

  List<Faculty> _campus = [];
  PublicSettings? _settings;
  bool _loadingSetup = true;
  String? _setupError;

  String _method = 'delivery';
  Faculty? _faculty;
  Building? _building;
  Floor? _floor;
  Classroom? _classroom;
  final _instructions = TextEditingController();
  final _note = TextEditingController();
  bool _placing = false;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  @override
  void dispose() {
    _instructions.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _setup() async {
    setState(() {
      _loadingSetup = true;
      _setupError = null;
    });
    final repo = context.read<CatalogRepository>();
    try {
      final results = await Future.wait([repo.campus(), repo.settings()]);
      _campus = results[0] as List<Faculty>;
      _settings = results[1] as PublicSettings;
      if (!_settings!.deliveryEnabled) _method = 'pickup';
      if (mounted) await context.read<CartProvider>().setFulfillment(_method);
    } on ApiException catch (e) {
      _setupError = e.message;
    } finally {
      if (mounted) setState(() => _loadingSetup = false);
    }
  }

  Future<void> _setMethod(String m) async {
    setState(() => _method = m);
    await context.read<CartProvider>().setFulfillment(m);
  }

  Future<void> _placeOrder() async {
    if (_method == 'delivery' && _classroom == null) {
      showSnack(context, 'Please choose your faculty, building, floor and classroom.', error: true);
      return;
    }
    setState(() => _placing = true);
    try {
      final order = await context.read<OrderRepository>().place({
        'fulfillment_method': _method,
        'payment_method': _method == 'delivery' ? 'cash_on_delivery' : 'cash_on_pickup',
        'classroom_id': _classroom?.id,
        'delivery_instructions': _instructions.text.trim(),
        'customer_note': _note.text.trim(),
      }, _idempotencyKey);
      if (!mounted) return;
      context.read<CartProvider>().resetLocal();
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => OrderPlacedScreen(order: order)));
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
      if (mounted) context.read<CartProvider>().load().catchError((_) {});
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = context.watch<CartProvider>();
    final cart = cartProvider.cart;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: _loadingSetup
          ? const LoadingView()
          : _setupError != null
              ? ErrorView(message: _setupError!, onRetry: _setup)
              : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
                  StepCard(
                    step: 1,
                    title: 'Delivery or pickup',
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      SegmentedButton<String>(
                        segments: [
                          ButtonSegment(
                            value: 'delivery',
                            enabled: _settings?.deliveryEnabled ?? true,
                            icon: const Icon(Icons.meeting_room_outlined),
                            label: const Text('Classroom delivery'),
                          ),
                          const ButtonSegment(value: 'pickup', icon: Icon(Icons.storefront_outlined), label: Text('Self-pickup')),
                        ],
                        selected: {_method},
                        onSelectionChanged: (s) => _setMethod(s.first),
                      ),
                      const SizedBox(height: 14),
                      if (_method == 'delivery') ..._deliveryFields() else _pickupInfo(cart.store?.name, cart.store?.location),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  StepCard(
                    step: 2,
                    title: 'Confirm order',
                    child: Column(children: [
                      for (final i in cart.items)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(6)),
                              child: Text('${i.quantity}×', style: const TextStyle(fontWeight: FontWeight.w800)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(i.name)),
                            Text(money(i.lineTotal), style: const TextStyle(fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _note,
                        maxLength: 300,
                        decoration: const InputDecoration(hintText: 'Note for the store (e.g. less spicy)', prefixIcon: Icon(Icons.edit_note_rounded), counterText: ''),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  StepCard(
                    step: 3,
                    title: 'Payment method',
                    child: Wrap(spacing: 8, runSpacing: 8, children: [
                      ChoiceChip(
                        selected: true,
                        showCheckmark: false,
                        avatar: const Icon(Icons.payments_outlined, size: 18),
                        label: Text(_method == 'delivery' ? 'Cash on delivery' : 'Cash on pickup'),
                        onSelected: (_) {},
                      ),
                      ChoiceChip(
                        selected: false,
                        showCheckmark: false,
                        avatar: const Icon(Icons.qr_code_2_rounded, size: 18),
                        label: Text(_settings?.khqrEnabled == true ? 'Bakong KHQR' : 'Bakong KHQR · coming soon'),
                        onSelected: _settings?.khqrEnabled == true ? (_) => showSnack(context, 'KHQR payment is not available yet.') : null,
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(children: [
                        _row('Subtotal', money(cart.subtotal)),
                        _row(_method == 'delivery' ? 'Delivery fee' : 'Pickup', cart.deliveryFee == 0 ? 'Free' : money(cart.deliveryFee)),
                        const Divider(height: 22),
                        _row('Total', money(cart.total), total: true),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 20),
                  GradientButton(
                    label: 'Place order',
                    trailing: money(cart.total),
                    loading: _placing || cartProvider.loading,
                    onPressed: cart.isEmpty ? null : _placeOrder,
                  ),
                  const SizedBox(height: 8),
                  const Text('You pay in cash when you receive your food.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                ]),
    );
  }

  List<Widget> _deliveryFields() => [
        _dropdown<Faculty>('Faculty', _faculty, _campus, (f) => f.name, (f) => setState(() {
              _faculty = f;
              _building = f != null && f.buildings.length == 1 ? f.buildings.first : null;
              _floor = null;
              _classroom = null;
            })),
        _dropdown<Building>('Building', _building, _faculty?.buildings ?? [], (b) => b.name, (b) => setState(() {
              _building = b;
              _floor = null;
              _classroom = null;
            })),
        Row(children: [
          Expanded(
            child: _dropdown<Floor>('Floor', _floor, _building?.floors ?? [], (f) => f.label, (f) => setState(() {
                  _floor = f;
                  _classroom = null;
                })),
          ),
          const SizedBox(width: 10),
          Expanded(child: _dropdown<Classroom>('Classroom', _classroom, _floor?.classrooms ?? [], (c) => c.name, (c) => setState(() => _classroom = c))),
        ]),
        TextField(
          controller: _instructions,
          maxLength: 300,
          maxLines: 2,
          minLines: 1,
          decoration: const InputDecoration(hintText: 'Instructions (e.g. Please call me when you arrive)', prefixIcon: Icon(Icons.info_outline_rounded), counterText: ''),
        ),
      ];

  Widget _pickupInfo(String? store, String? location) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Pick up at ${store ?? 'the store'}', style: const TextStyle(fontWeight: FontWeight.w800)),
              if (location != null && location.isNotEmpty) Text(location, style: const TextStyle(color: AppColors.textMuted)),
              const SizedBox(height: 4),
              const Text("We'll notify you when it's ready. Show your pickup code at the counter.", style: TextStyle(fontSize: 12.5)),
            ]),
          ),
        ]),
      );

  Widget _dropdown<T>(String label, T? value, List<T> items, String Function(T) text, ValueChanged<T?> onChanged) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<T>(
          // New key whenever the parent selection changes, so the field resets.
          key: ValueKey(Object.hash(label, value, identityHashCode(items))),
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(text(i), overflow: TextOverflow.ellipsis))).toList(),
          onChanged: items.isEmpty ? null : onChanged,
        ),
      );

  Widget _row(String label, String value, {bool total = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(fontWeight: total ? FontWeight.w800 : FontWeight.w500, fontSize: total ? 17 : 14))),
          Text(value, style: TextStyle(fontWeight: total ? FontWeight.w900 : FontWeight.w600, fontSize: total ? 18 : 14, color: total ? AppColors.accent : AppColors.text)),
        ]),
      );
}
