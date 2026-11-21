import '../../../core/utils/formatters.dart';

class Category {
  Category({required this.id, required this.name, required this.slug, this.icon});
  final String id;
  final String name;
  final String slug;
  final String? icon;

  factory Category.fromJson(Map<String, dynamic> j) => Category(id: j['id'], name: j['name'], slug: j['slug'], icon: j['icon']);
}

class Store {
  Store({
    required this.id,
    required this.name,
    this.description,
    this.logoUrl,
    this.coverUrl,
    this.locationNote,
    this.phone,
    required this.openingTime,
    required this.closingTime,
    required this.isOpenNow,
    required this.rating,
    required this.ratingCount,
    this.buildingName,
    this.productsCount,
    this.isFavorite = false,
  });

  final String id;
  final String name;
  final String? description;
  final String? logoUrl;
  final String? coverUrl;
  final String? locationNote;
  final String? phone;
  final String openingTime;
  final String closingTime;
  final bool isOpenNow;
  final double rating;
  final int ratingCount;
  final String? buildingName;
  final int? productsCount;
  bool isFavorite;

  String get hours => '$openingTime – $closingTime';
  String get location => [buildingName, locationNote].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

  factory Store.fromJson(Map<String, dynamic> j) => Store(
        id: j['id'],
        name: j['name'] ?? '',
        description: j['description'],
        logoUrl: j['logo_url'],
        coverUrl: j['cover_url'],
        locationNote: j['location_note'],
        phone: j['phone'],
        openingTime: j['opening_time'] ?? '',
        closingTime: j['closing_time'] ?? '',
        isOpenNow: j['is_open_now'] == true,
        rating: toDouble(j['rating_avg']),
        ratingCount: toInt(j['rating_count']),
        buildingName: (j['building'] as Map?)?['name'],
        productsCount: j['products_count'],
        isFavorite: j['is_favorite'] == true,
      );
}

class Product {
  Product({
    required this.id,
    required this.storeId,
    required this.name,
    this.description,
    required this.price,
    this.imageUrl,
    this.stockQuantity,
    required this.isAvailable,
    required this.inStock,
    required this.rating,
    required this.soldCount,
    this.category,
    this.storeName,
    this.storeOpen = true,
  });

  final String id;
  final String storeId;
  final String name;
  final String? description;
  final double price;
  final String? imageUrl;
  final int? stockQuantity;
  final bool isAvailable;
  final bool inStock;
  final double rating;
  final int soldCount;
  final Category? category;
  final String? storeName;
  final bool storeOpen;

  bool get canOrder => isAvailable && inStock;
  bool get lowStock => stockQuantity != null && stockQuantity! > 0 && stockQuantity! <= 5;

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'],
        storeId: j['store_id'],
        name: j['name'] ?? '',
        description: j['description'],
        price: toDouble(j['price']),
        imageUrl: j['image_url'],
        stockQuantity: j['stock_quantity'],
        isAvailable: j['is_available'] == true,
        inStock: j['in_stock'] == true,
        rating: toDouble(j['rating_avg']),
        soldCount: toInt(j['sold_count']),
        category: j['category'] is Map ? Category.fromJson((j['category'] as Map).cast()) : null,
        storeName: (j['store'] as Map?)?['name'],
        storeOpen: (j['store'] as Map?)?['is_open_now'] ?? true,
      );
}

class Announcement {
  Announcement({required this.id, required this.title, required this.body, required this.type, this.imageUrl});
  final String id;
  final String title;
  final String body;
  final String type;
  final String? imageUrl;

  bool get isPromotion => type == 'promotion';

  factory Announcement.fromJson(Map<String, dynamic> j) =>
      Announcement(id: j['id'], title: j['title'] ?? '', body: j['body'] ?? '', type: j['type'] ?? 'announcement', imageUrl: j['image_url']);
}

class Review {
  Review({required this.rating, this.comment, this.userName, this.productName, this.createdAt});
  final int rating;
  final String? comment;
  final String? userName;
  final String? productName;
  final DateTime? createdAt;

  factory Review.fromJson(Map<String, dynamic> j) => Review(
        rating: toInt(j['rating']),
        comment: j['comment'],
        userName: j['user_name'],
        productName: j['product_name'],
        createdAt: parseDate(j['created_at']),
      );
}
