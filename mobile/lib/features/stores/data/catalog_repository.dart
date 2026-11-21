import '../../../core/network/api_client.dart';
import '../../checkout/models/campus.dart';
import '../../orders/models/order.dart';
import '../models/catalog_models.dart';

class HomeData {
  HomeData({required this.categories, required this.featuredStores, required this.popularProducts, required this.recentProducts, required this.activeOrders, required this.announcements});
  final List<Category> categories;
  final List<Store> featuredStores;
  final List<Product> popularProducts;
  final List<Product> recentProducts;
  final List<Order> activeOrders;
  final List<Announcement> announcements;
}

class StoreDetail {
  StoreDetail(this.store, this.categories, this.pickupLocation);
  final Store store;
  final List<Category> categories;
  final String pickupLocation;
}

class PublicSettings {
  PublicSettings(this.raw);
  final Map<String, dynamic> raw;
  double get deliveryFee => (raw['delivery_fee'] as num?)?.toDouble() ?? 0;
  double get freeDeliveryThreshold => (raw['free_delivery_threshold'] as num?)?.toDouble() ?? 0;
  bool get deliveryEnabled => raw['delivery_enabled'] != false;
  bool get khqrEnabled => raw['khqr_enabled'] == true;
  String? get supportPhone => raw['support_phone'];
  String? get supportEmail => raw['support_email'];
}

class CatalogRepository {
  CatalogRepository(this._api);
  final ApiClient _api;

  List<T> _list<T>(dynamic data, T Function(Map<String, dynamic>) f) => (data as List? ?? []).map((e) => f((e as Map).cast())).toList();

  Future<HomeData> home() async {
    final d = ((await _api.get('/home'))['data'] as Map).cast<String, dynamic>();
    return HomeData(
      categories: _list(d['categories'], Category.fromJson),
      featuredStores: _list(d['featured_stores'], Store.fromJson),
      popularProducts: _list(d['popular_products'], Product.fromJson),
      recentProducts: _list(d['recent_products'], Product.fromJson),
      activeOrders: _list(d['active_orders'], Order.fromJson),
      announcements: _list(d['announcements'], Announcement.fromJson),
    );
  }

  Future<List<Category>> categories() async => _list((await _api.get('/categories'))['data'], Category.fromJson);

  Future<Paged<Store>> stores({String? search, String? category, bool favorites = false, String? sort, int page = 1}) =>
      _api.getPaged('/stores', Store.fromJson, query: {'search': search, 'category': category, 'favorites': favorites ? 1 : null, 'sort': sort, 'page': page});

  Future<StoreDetail> store(String id) async {
    final d = ((await _api.get('/stores/$id'))['data'] as Map).cast<String, dynamic>();
    return StoreDetail(Store.fromJson((d['store'] as Map).cast()), _list(d['categories'], Category.fromJson), d['pickup_location'] ?? '');
  }

  Future<List<Product>> storeProducts(String storeId) async =>
      (await _api.getPaged('/stores/$storeId/products', Product.fromJson, query: {'per_page': 100})).items;

  Future<Paged<Product>> products({String? search, String? category, String? sort, int page = 1}) =>
      _api.getPaged('/products', Product.fromJson, query: {'search': search, 'category': category, 'sort': sort, 'page': page});

  Future<List<Store>> favorites() async => _list((await _api.get('/favorites'))['data'], Store.fromJson);

  Future<bool> toggleFavorite(String storeId) async => ((await _api.post('/favorites/$storeId'))['data'] as Map)['is_favorite'] == true;

  Future<Paged<Review>> storeReviews(String storeId) => _api.getPaged('/stores/$storeId/reviews', Review.fromJson);

  Future<PublicSettings> settings() async => PublicSettings(((await _api.get('/settings/public'))['data'] as Map).cast());

  Future<List<Faculty>> campus() async => Faculty.listFromJson((await _api.get('/campus/locations'))['data'] as List);
}
