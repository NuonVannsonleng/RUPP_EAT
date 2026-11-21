import '../../../core/utils/formatters.dart';
import '../../orders/models/order.dart';

/// What a driver sees for one delivery (request or assignment).
class Delivery {
  Delivery({
    required this.id,
    required this.status,
    required this.orderId,
    required this.orderNumber,
    required this.orderStatus,
    required this.orderStatusLabel,
    required this.paymentMethodLabel,
    required this.paymentMethod,
    required this.total,
    required this.deliveryFee,
    required this.itemCount,
    required this.items,
    this.location,
    this.instructions,
    required this.storeName,
    this.storeLogo,
    this.storePhone,
    this.storeLocation,
    this.storeLat,
    this.storeLng,
    this.customerName,
    this.customerPhone,
    this.requestedAt,
    this.assignedAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.cancelledAt,
  });

  final String id;
  final String status; // searching, assigned, picked_up, arriving, delivered, cancelled
  final String orderId;
  final String orderNumber;
  final String orderStatus;
  final String orderStatusLabel;
  final String paymentMethodLabel;
  final String paymentMethod;
  final double total;
  final double deliveryFee;
  final int itemCount;
  final List<({String name, int quantity, String? note})> items;
  final DeliveryLocation? location;
  final String? instructions;
  final String storeName;
  final String? storeLogo;
  final String? storePhone;
  final String? storeLocation;
  final double? storeLat;
  final double? storeLng;
  final String? customerName;
  final String? customerPhone;
  final DateTime? requestedAt;
  final DateTime? assignedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final DateTime? cancelledAt;

  bool get isRequest => status == 'searching';
  bool get isActive => ['assigned', 'picked_up', 'arriving'].contains(status);
  bool get foodReady => ['ready', 'driver_assigned'].contains(orderStatus);
  bool get collectCash => paymentMethod == 'cash_on_delivery';

  /// Where the driver is heading now: the store until pickup, then the customer's building.
  bool get headingToStore => status == 'assigned' || status == 'searching';

  String get statusLabel => switch (status) {
        'searching' => 'New request',
        'assigned' => 'Go to store',
        'picked_up' => 'On the way',
        'arriving' => 'Arriving',
        'delivered' => 'Delivered',
        'cancelled' => 'Cancelled',
        _ => status,
      };

  factory Delivery.fromJson(Map<String, dynamic> j) {
    final o = (j['order'] as Map).cast<String, dynamic>();
    final s = (j['store'] as Map).cast<String, dynamic>();
    final c = (j['customer'] as Map?)?.cast<String, dynamic>();
    return Delivery(
      id: j['id'],
      status: j['status'],
      orderId: o['id'],
      orderNumber: o['order_number'] ?? '',
      orderStatus: o['status'] ?? '',
      orderStatusLabel: o['status_label'] ?? '',
      paymentMethod: o['payment_method'] ?? '',
      paymentMethodLabel: o['payment_method_label'] ?? '',
      total: toDouble(o['total']),
      deliveryFee: toDouble(o['delivery_fee']),
      itemCount: toInt(o['item_count']),
      items: (o['items'] as List? ?? [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .map((e) => (name: e['name'] as String, quantity: toInt(e['quantity']), note: e['note'] as String?))
          .toList(),
      location: o['delivery_location'] is Map ? DeliveryLocation((o['delivery_location'] as Map).cast()) : null,
      instructions: o['delivery_instructions'],
      storeName: s['name'] ?? '',
      storeLogo: s['logo_url'],
      storePhone: s['phone'],
      storeLocation: [s['building'], s['location_note']].whereType<String>().join(' · '),
      storeLat: (s['latitude'] as num?)?.toDouble(),
      storeLng: (s['longitude'] as num?)?.toDouble(),
      customerName: c?['name'],
      customerPhone: c?['phone'],
      requestedAt: parseDate(j['requested_at']),
      assignedAt: parseDate(j['assigned_at']),
      pickedUpAt: parseDate(j['picked_up_at']),
      deliveredAt: parseDate(j['delivered_at']),
      cancelledAt: parseDate(j['cancelled_at']),
    );
  }
}
