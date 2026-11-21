import '../../../core/network/api_client.dart';
import '../models/cart.dart';

class CartRepository {
  CartRepository(this._api);
  final ApiClient _api;

  Cart _cart(Map<String, dynamic> res) => Cart.fromJson((res['data'] as Map).cast());

  Future<Cart> get({String fulfillment = 'delivery'}) async => _cart(await _api.get('/cart', query: {'fulfillment_method': fulfillment}));

  Future<Cart> add(String productId, int quantity, {String? note, bool replace = false}) async =>
      _cart(await _api.post('/cart/items', data: {'product_id': productId, 'quantity': quantity, 'note': note, 'replace': replace}));

  Future<Cart> update(String itemId, int quantity, {String? note}) async =>
      _cart(await _api.patch('/cart/items/$itemId', data: {'quantity': quantity, 'note': ?note}));

  Future<Cart> remove(String itemId) async => _cart(await _api.delete('/cart/items/$itemId'));

  Future<Cart> clear() async => _cart(await _api.delete('/cart'));
}
