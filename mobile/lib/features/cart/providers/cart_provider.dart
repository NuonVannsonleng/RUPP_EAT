import 'package:flutter/foundation.dart';

import '../data/cart_repository.dart';
import '../models/cart.dart';

/// Server-side cart mirrored locally. All prices/totals come from the API.
class CartProvider extends ChangeNotifier {
  CartProvider(this._repo);
  final CartRepository _repo;

  Cart cart = Cart.empty();
  bool loading = false;
  String fulfillment = 'delivery';
  final Set<String> _busy = {};

  bool isBusy(String productId) => _busy.contains(productId);
  int get count => cart.itemCount;

  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      cart = await _repo.get(fulfillment: fulfillment);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> setFulfillment(String method) async {
    if (method == fulfillment) return;
    fulfillment = method;
    await load();
  }

  /// Throws [ApiException] with statusCode 409 when the cart holds another store's items.
  Future<void> add(String productId, {int quantity = 1, String? note, bool replace = false}) =>
      _run(productId, () => _repo.add(productId, quantity, note: note, replace: replace));

  /// Set the absolute quantity of a product (0 removes it).
  Future<void> setQuantity(String productId, int quantity) async {
    final item = cart.itemFor(productId);
    if (item == null) {
      if (quantity > 0) await add(productId, quantity: quantity);
      return;
    }
    await _run(productId, () => quantity <= 0 ? _repo.remove(item.id) : _repo.update(item.id, quantity));
  }

  Future<void> remove(String itemId, String productId) => _run(productId, () => _repo.remove(itemId));

  Future<void> clear() async {
    cart = await _repo.clear();
    notifyListeners();
  }

  /// After an order is placed the server empties the cart.
  void resetLocal() {
    cart = Cart.empty();
    notifyListeners();
  }

  Future<void> _run(String productId, Future<Cart> Function() op) async {
    _busy.add(productId);
    notifyListeners();
    try {
      cart = await op();
      // Mutations return delivery pricing; re-read when the customer chose pickup.
      if (fulfillment == 'pickup') cart = await _repo.get(fulfillment: fulfillment);
    } finally {
      _busy.remove(productId);
      notifyListeners();
    }
  }
}
