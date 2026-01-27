import 'dart:io';
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

  /// Fetch purchase entries
  /// POST /view-purchase-entry/
  ///
  /// Example payload: {"store_id": "...", "store_access": true, "filters": {}, "sort_by": "date", "sort_order": "desc", "limit": 50, "offset": 0}
  static Future<Map<String, dynamic>> getPurchaseEntries(
    String storeId, {
    Map<String, dynamic>? filters,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await ApiService.post(
        '/view-purchase-entry/',
        body: {
          'store_id': storeId,
          'store_access': true,
          'filters': filters ?? {},
          'sort_by': 'date',
          'sort_order': 'desc',
          'limit': limit,
          'offset': offset,
        },
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];

        if (data['status'] == 200 && data['response'] != null) {
          return Map<String, dynamic>.from(data['response']);
        }
      }

      return {};
    } catch (e) {
      throw Exception('Failed to fetch purchase entries: $e');
    }
  }

  /// Fetch units
  /// POST /units/
  static Future<List<Map<String, dynamic>>> getUnits(String storeId) async {
    try {
      final response = await ApiService.post(
        '/units/',
        body: {
          'store_id': storeId,
          'store_access': true,
          'create': false,
          'limit': 100,
        },
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
      throw Exception('Failed to fetch units: $e');
    }
  }

  /// Fetch godowns
  /// POST /godowns/
  static Future<List<Map<String, dynamic>>> getGodowns(String storeId) async {
    try {
      final response = await ApiService.post(
        '/godowns/',
        body: {
          'store_id': storeId,
          'store_access': true,
          'create': false,
          'limit': 50,
        },
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
      throw Exception('Failed to fetch godowns: $e');
    }
  }

  /// Fetch racks
  /// POST /racks/
  static Future<List<Map<String, dynamic>>> getRacks(String storeId) async {
    try {
      final response = await ApiService.post(
        '/racks/',
        body: {
          'store_id': storeId,
          'store_access': true,
          'create': false,
          'limit': 100,
        },
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
      throw Exception('Failed to fetch racks: $e');
    }
  }

  /// Upload purchase invoice for AI analysis
  /// POST /purchase-entry-intelligence/
  /// Upload purchase invoice for AI analysis
  /// POST /purchase-entry-intelligence/
  static Future<Map<String, dynamic>> uploadPurchaseInvoice(
    String storeId,
    File file,
    double lat,
    double lng,
  ) async {
    try {
      final response = await ApiService.uploadImage(
        '/purchase-entry-intelligence/',
        imageFile: file,
        fieldName: 'file',
        additionalFields: {
          'store_id': storeId,
          'store_access': 'true',
          'lat': lat.toString(),
          'lng': lng.toString(),
        },
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        return Map<String, dynamic>.from(response['data']);
      }
      return {};
    } catch (e) {
      throw Exception('Failed to upload purchase invoice: $e');
    }
  }

  /// Search product combination templates
  /// POST /product-combinations-templates/
  static Future<Map<String, dynamic>> searchProductCombinationTemplates({
    required String query,
    required String storeId,
    int page = 1,
  }) async {
    try {
      final response = await ApiService.post(
        '/product-combinations-templates/',
        body: {
          'query': query,
          'store_id': storeId,
          'store_access': true,
          'page': page,
          'lat': 0,
          'lng': 0,
          'is_store': false,
          'customer_user_id': '',
        },
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        return Map<String, dynamic>.from(response['data']);
      }
      return {};
    } catch (e) {
      throw Exception('Failed to search products: $e');
    }
  }

  /// Register a new store (supplier)
  /// POST /store-registration-by-store/
  static Future<Map<String, dynamic>> registerStore({
    required String storeId,
    required String storeName,
    required String legalName,
    required String city,
    required String state,
    required int pin,
    required bool isGstEnabled,
    required String gstIn,
    required String gstRegisteredState,
    required String gstRegistrationType,
    String area = '',
  }) async {
    try {
      final response = await ApiService.post(
        '/store-registration-by-store/',
        body: {
          'store_id': storeId,
          'store_access': true,
          'store_name': storeName,
          'legal_name': legalName,
          'city': city,
          'area': area,
          'state': state,
          'pin': pin,
          'is_gst_enabled': isGstEnabled,
          'gst_in': gstIn,
          'gst_registered_state': gstRegisteredState,
          'gst_registration_type': gstRegistrationType,
        },
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        return Map<String, dynamic>.from(response['data']);
      }
      return {};
    } catch (e) {
      throw Exception('Failed to register store: $e');
    }
  }
}
