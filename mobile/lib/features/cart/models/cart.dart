import '../../../core/utils/formatters.dart';
import '../../stores/models/catalog_models.dart';

class CartItem {
  CartItem({required this.id, required this.quantity, this.note, required this.lineTotal, required this.available, required this.productId, required this.name, required this.price, this.imageUrl, this.stock});

  final String id;
  final int quantity;
  final String? note;
  final double lineTotal;
  final bool available;
  final String productId;
  final String name;
  final double price;
  final String? imageUrl;
  final int? stock;

  factory CartItem.fromJson(Map<String, dynamic> j) {
    final p = (j['product'] as Map).cast<String, dynamic>();
    return CartItem(
      id: j['id'],
      quantity: toInt(j['quantity']),
      note: j['note'],
      lineTotal: toDouble(j['line_total']),
      available: j['available'] == true,
      productId: p['id'],
      name: p['name'] ?? '',
      price: toDouble(p['price']),
      imageUrl: p['image_url'],
      stock: p['stock_quantity'],
    );
  }
}

class Cart {
  Cart({this.store, required this.items, required this.itemCount, required this.subtotal, required this.deliveryFee, required this.total, required this.canCheckout, required this.storeOpen});

  final Store? store;
  final List<CartItem> items;
  final int itemCount;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final bool canCheckout;
  final bool storeOpen;

  bool get isEmpty => items.isEmpty;
  bool get hasUnavailable => items.any((i) => !i.available);

  int quantityOf(String productId) => items.where((i) => i.productId == productId).fold(0, (s, i) => s + i.quantity);

  CartItem? itemFor(String productId) {
    for (final i in items) {
      if (i.productId == productId) return i;
    }
    return null;
  }

  static Cart empty() => Cart(items: [], itemCount: 0, subtotal: 0, deliveryFee: 0, total: 0, canCheckout: false, storeOpen: false);

  factory Cart.fromJson(Map<String, dynamic> j) {
    final s = (j['summary'] as Map).cast<String, dynamic>();
    return Cart(
      store: j['store'] is Map ? Store.fromJson((j['store'] as Map).cast()) : null,
      items: (j['items'] as List).map((e) => CartItem.fromJson((e as Map).cast())).toList(),
      itemCount: toInt(s['item_count']),
      subtotal: toDouble(s['subtotal']),
      deliveryFee: toDouble(s['delivery_fee']),
      total: toDouble(s['total']),
      canCheckout: s['can_checkout'] == true,
      storeOpen: s['store_open'] == true,
    );
  }
}
