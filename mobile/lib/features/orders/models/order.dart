import '../../../core/utils/formatters.dart';

class OrderItem {
  OrderItem({required this.productId, required this.name, this.imageUrl, required this.unitPrice, required this.quantity, required this.lineTotal, this.note});
  final String? productId;
  final String name;
  final String? imageUrl;
  final double unitPrice;
  final int quantity;
  final double lineTotal;
  final String? note;

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
        productId: j['product_id'],
        name: j['product_name'] ?? '',
        imageUrl: j['image_url'],
        unitPrice: toDouble(j['unit_price']),
        quantity: toInt(j['quantity']),
        lineTotal: toDouble(j['line_total']),
        note: j['note'],
      );
}

class TimelineEntry {
  TimelineEntry(this.status, this.label, this.at, this.note);
  final String status;
  final String label;
  final DateTime? at;
  final String? note;
}

/// Campus destination snapshot stored on the order.
class DeliveryLocation {
  DeliveryLocation(this.raw);
  final Map<String, dynamic> raw;

  String? get faculty => raw['faculty'];
  String get building => raw['building'] ?? '';
  String get room => raw['room'] ?? '';
  String get floor => raw['floor_label'] ?? (raw['floor'] != null ? 'Floor ${raw['floor']}' : '');

  String get short => '$building · $room';
  double? get latitude => (raw['latitude'] as num?)?.toDouble();
  double? get longitude => (raw['longitude'] as num?)?.toDouble();
  String get full => [faculty, building, floor, room].whereType<String>().where((s) => s.isNotEmpty).join(' › ');
}

class Order {
  Order({
    required this.id,
    required this.number,
    required this.status,
    required this.statusLabel,
    required this.fulfillment,
    required this.paymentMethod,
    required this.paymentMethodLabel,
    required this.paymentStatus,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    this.location,
    this.instructions,
    this.pickupCode,
    this.cancelReason,
    required this.canCancel,
    required this.canReview,
    required this.isReviewed,
    required this.items,
    required this.timeline,
    this.storeId,
    this.storeName,
    this.storeLogo,
    this.storePhone,
    this.storeLocation,
    this.driverName,
    this.driverPhone,
    this.deliveryStatus,
    this.createdAt,
    required this.itemCount,
  });

  final String id;
  final String number;
  final String status;
  final String statusLabel;
  final String fulfillment;
  final String paymentMethod;
  final String paymentMethodLabel;
  final String paymentStatus;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final DeliveryLocation? location;
  final String? instructions;
  final String? pickupCode;
  final String? cancelReason;
  final bool canCancel;
  final bool canReview;
  final bool isReviewed;
  final List<OrderItem> items;
  final List<TimelineEntry> timeline;
  final String? storeId;
  final String? storeName;
  final String? storeLogo;
  final String? storePhone;
  final String? storeLocation;
  final String? driverName;
  final String? driverPhone;
  final String? deliveryStatus;
  final DateTime? createdAt;
  final int itemCount;

  bool get isDelivery => fulfillment == 'delivery';
  bool get isActive => !['delivered', 'picked_up', 'cancelled', 'rejected'].contains(status);
  bool get isCompleted => status == 'delivered' || status == 'picked_up';
  bool get isCancelled => status == 'cancelled' || status == 'rejected';

  DateTime? timeOf(String s) {
    for (final t in timeline) {
      if (t.status == s) return t.at;
    }
    return null;
  }

  factory Order.fromJson(Map<String, dynamic> j) {
    final store = (j['store'] as Map?)?.cast<String, dynamic>();
    final driver = (j['driver'] as Map?)?.cast<String, dynamic>();
    final items = (j['items'] as List? ?? []).map((e) => OrderItem.fromJson((e as Map).cast())).toList();
    return Order(
      id: j['id'],
      number: j['order_number'] ?? '',
      status: j['status'] ?? 'pending',
      statusLabel: j['status_label'] ?? '',
      fulfillment: j['fulfillment_method'] ?? 'pickup',
      paymentMethod: j['payment_method'] ?? '',
      paymentMethodLabel: j['payment_method_label'] ?? '',
      paymentStatus: j['payment_status'] ?? 'unpaid',
      subtotal: toDouble(j['subtotal']),
      deliveryFee: toDouble(j['delivery_fee']),
      total: toDouble(j['total']),
      location: j['delivery_location'] is Map ? DeliveryLocation((j['delivery_location'] as Map).cast()) : null,
      instructions: j['delivery_instructions'],
      pickupCode: j['pickup_code'],
      cancelReason: j['cancel_reason'],
      canCancel: j['can_cancel'] == true,
      canReview: j['can_review'] == true,
      isReviewed: j['is_reviewed'] == true,
      items: items,
      timeline: (j['timeline'] as List? ?? [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .map((e) => TimelineEntry(e['status'], e['label'] ?? e['status'], parseDate(e['at']), e['note']))
          .toList(),
      storeId: store?['id'],
      storeName: store?['name'],
      storeLogo: store?['logo_url'],
      storePhone: store?['phone'],
      storeLocation: [store?['building'], store?['location_note']].whereType<String>().join(' · '),
      driverName: driver?['name'],
      driverPhone: driver?['phone'],
      deliveryStatus: (j['delivery'] as Map?)?['status'],
      createdAt: parseDate(j['created_at']),
      itemCount: j['item_count'] != null ? toInt(j['item_count']) : items.fold(0, (s, i) => s + i.quantity),
    );
  }
}

class AppNotification {
  AppNotification({required this.id, required this.type, required this.title, required this.body, this.orderId, this.readAt, this.createdAt});
  final String id;
  final String type;
  final String title;
  final String body;
  final String? orderId;
  DateTime? readAt;
  final DateTime? createdAt;

  bool get isRead => readAt != null;

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'],
        type: j['type'] ?? '',
        title: j['title'] ?? '',
        body: j['body'] ?? '',
        orderId: (j['data'] as Map?)?['order_id'],
        readAt: parseDate(j['read_at']),
        createdAt: parseDate(j['created_at']),
      );
}
