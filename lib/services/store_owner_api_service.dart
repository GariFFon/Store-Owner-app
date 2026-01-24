import 'package:exanor/services/api_service.dart';
import 'package:exanor/models/category_model.dart';

/// API Service for Store Owner operations
class StoreOwnerApiService {
  /// Fetch all available stores for the user
  /// POST /user-stores/
  static Future<List<Map<String, dynamic>>> getOwnerStores() async {
    try {
      final response = await ApiService.post(
        '/user-stores/',
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];

        if (data['status'] == 200 && data['response'] != null) {
          return List<Map<String, dynamic>>.from(data['response']);
        }
      }

      return [];
    } catch (e) {
      throw Exception('Failed to fetch owner stores: $e');
    }
  }

  /// Fetch product categories linked to a store
  /// POST /get-linked-product-categories/
  ///
  /// Example payload: { "store_id": "d95069ca-839d-4469-8037-a5796633deb1" }
  static Future<List<Category>> getLinkedProductCategories(
    String storeId,
  ) async {
    try {
      final response = await ApiService.post(
        '/get-linked-product-categories/',
        body: {'store_id': storeId},
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];

        if (data['status'] == 200 && data['response'] != null) {
          final List<dynamic> categoriesData = data['response'];
          return categoriesData.map((json) => Category.fromJson(json)).toList();
        }
      }

      return [];
    } catch (e) {
      throw Exception('Failed to fetch categories: $e');
    }
  }

  /// Fetch products by category
  /// POST /get-products-by-category/
  ///
  /// Example payload: { "store_id": "...", "category_id": "..." }
  static Future<List<Map<String, dynamic>>> getProductsByCategory(
    String storeId,
    String categoryId,
  ) async {
    try {
      final response = await ApiService.post(
        '/get-products-by-category/',
        body: {'store_id': storeId, 'category_id': categoryId},
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];

        if (data['status'] == 200 && data['response'] != null) {
          return List<Map<String, dynamic>>.from(data['response']);
        }
      }

      return [];
    } catch (e) {
      throw Exception('Failed to fetch products by category: $e');
    }
  }

  /// Search products in a store
  /// POST /search-products/
  ///
  /// Example payload: { "store_id": "...", "query": "..." }
  static Future<List<Map<String, dynamic>>> searchProducts(
    String storeId,
    String query,
  ) async {
    try {
      final response = await ApiService.post(
        '/search-products/',
        body: {'store_id': storeId, 'query': query},
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];

        if (data['status'] == 200 && data['response'] != null) {
          return List<Map<String, dynamic>>.from(data['response']);
        }
      }

      return [];
    } catch (e) {
      throw Exception('Failed to search products: $e');
    }
  }

  /// Search product by barcode/QR code
  /// POST /search-product-by-code/
  ///
  /// Example payload: { "store_id": "...", "code": "..." }
  static Future<Map<String, dynamic>?> searchProductByCode(
    String storeId,
    String code,
  ) async {
    try {
      final response = await ApiService.post(
        '/search-product-by-code/',
        body: {'store_id': storeId, 'code': code},
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];

        if (data['status'] == 200 && data['response'] != null) {
          return Map<String, dynamic>.from(data['response']);
        }
      }

      return null;
    } catch (e) {
      throw Exception('Failed to search product by code: $e');
    }
  }

  /// Get all products in a store
  /// POST /get-store-products/
  ///
  /// Example payload: { "store_id": "..." }
  static Future<List<Map<String, dynamic>>> getStoreProducts(
    String storeId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await ApiService.post(
        '/get-store-products/',
        body: {'store_id': storeId, 'page': page, 'limit': limit},
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];

        if (data['status'] == 200 && data['response'] != null) {
          return List<Map<String, dynamic>>.from(data['response']);
        }
      }

      return [];
    } catch (e) {
      throw Exception('Failed to fetch store products: $e');
    }
  }
}
