import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' hide Category;
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
        body: {'store_id': storeId, 'store_access': true, 'query': query},
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
          'order_by': 'name',
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

  /// Create godown
  /// POST /godowns/
  static Future<Map<String, dynamic>> createGodown({
    required String storeId,
    required String name,
    required String description,
    required String address,
    required bool isActive,
    required bool isPrimary,
  }) async {
    try {
      final response = await ApiService.post(
        '/godowns/',
        body: {
          'store_id': storeId,
          'store_access': true,
          'create': true,
          'name': name,
          'description': description,
          'address': address,
          'is_active': isActive,
          'is_primary': isPrimary,
        },
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        return Map<String, dynamic>.from(response['data']);
      }
      return {};
    } catch (e) {
      throw Exception('Failed to create godown: $e');
    }
  }

  /// Update godown
  /// PUT /godowns/
  static Future<Map<String, dynamic>> updateGodown({
    required String storeId,
    required String godownId,
    required String name,
    required String description,
    required String address,
    required bool isActive,
    required bool isPrimary,
  }) async {
    try {
      final response = await ApiService.put(
        '/godowns/',
        body: {
          'store_id': storeId,
          'store_access': true,
          'godown_id': godownId,
          'name': name,
          'description': description,
          'address': address,
          'is_active': isActive,
          'is_primary': isPrimary,
        },
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        return Map<String, dynamic>.from(response['data']);
      }
      return {};
    } catch (e) {
      throw Exception('Failed to update godown: $e');
    }
  }

  /// Create rack
  /// POST /racks/
  static Future<Map<String, dynamic>> createRack({
    required String storeId,
    required String godownId,
    required String name,
    required int level,
    required String description,
    required bool isActive,
  }) async {
    try {
      final response = await ApiService.post(
        '/racks/',
        body: {
          'store_id': storeId,
          'store_access': true,
          'create': true,
          'godown': godownId,
          'name': name,
          'level': level,
          'description': description,
          'is_active': isActive,
        },
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        return Map<String, dynamic>.from(response['data']);
      }
      return {};
    } catch (e) {
      throw Exception('Failed to create rack: $e');
    }
  }

  /// Fetch product inventory
  /// POST /product-inventory/
  static Future<Map<String, dynamic>> getProductInventory(
    String storeId,
    String rackId,
    String godownId, {
    int page = 1,
    Map<String, dynamic>? filters,
    String? orderBy,
  }) async {
    try {
      final response = await ApiService.post(
        '/product-inventory/',
        body: {
          'store_id': storeId,
          'store_access': true,
          'query': {'rack_id': rackId, 'godown_id': godownId},
          'filters': filters ?? {},
          'order_by': orderBy ?? '-purchase_timestamp',
          'page': page,
          'limit': 25,
        },
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        return Map<String, dynamic>.from(response['data']);
      }
      return {};
    } catch (e) {
      throw Exception('Failed to fetch product inventory: $e');
    }
  }

  /// Search product inventory
  /// POST /product-inventory-search/
  static Future<Map<String, dynamic>> searchProductInventory(
    String storeId,
    String query, {
    int page = 1,
  }) async {
    try {
      final response = await ApiService.post(
        '/product-inventory-search/',
        body: {
          'store_id': storeId,
          'store_access': true,
          'query': query,
          'page': page,
        },
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        return Map<String, dynamic>.from(response['data']);
      }
      return {};
    } catch (e) {
      throw Exception('Failed to search product inventory: $e');
    }
  }

  /// Update product inventory
  /// PUT /product-inventory/
  static Future<Map<String, dynamic>> updateProductInventory({
    required String storeId,
    required String productInventoryId,
    required bool isAccessibleOnline,
    required bool isAccessiblePos,
  }) async {
    try {
      final response = await ApiService.put(
        '/product-inventory/',
        body: {
          'store_id': storeId,
          'store_access': true,
          'product_inventory_id': productInventoryId,
          'data': {
            'is_accessible_online': isAccessibleOnline,
            'is_accessible_pos': isAccessiblePos,
          },
        },
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        return Map<String, dynamic>.from(response['data']);
      }
      return {};
    } catch (e) {
      throw Exception('Failed to update product inventory: $e');
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
          'order_by': 'name',
          'limit': 1000,
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

  /// Fetch store bank details
  /// POST /store-bank-details/
  static Future<List<Map<String, dynamic>>> getStoreBankDetails(
    String storeId, {
    String? financialYearId,
  }) async {
    try {
      final body = {
        'store_id': storeId,
        'store_access': true,
        'create': false,
        'order_by': 'bank_name',
        'limit': 50,
      };

      if (financialYearId != null) {
        body['financial_year_id'] = financialYearId;
      }

      debugPrint('Fetching bank details with body: $body');

      final response = await ApiService.post(
        '/store-bank-details/',
        body: body,
        useBearerToken: true,
      );

      debugPrint('Bank Details Response: $response');

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];
        if (data['status'] == 200 && data['response'] != null) {
          final list = List<Map<String, dynamic>>.from(data['response']);
          debugPrint('Parsed Bank Details List: $list');
          return list;
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching bank details: $e');
      throw Exception('Failed to fetch store bank details: $e');
    }
  }

  /// Create store bank details
  /// POST /store-bank-details/
  static Future<bool> createStoreBankDetails({
    required String storeId,
    required String accountType,
    required String bankName,
    required String accountNumber,
    required String ifscCode,
    required String holderName,
    required String holderType,
    required String city,
    required String address,
    required String state,
    required String country,
    required bool isDefault,
    required bool isActive,
    String? financialYearId,
    double? openingBalance,
  }) async {
    try {
      final body = {
        'store_id': storeId,
        'store_access': true,
        'create': true,
        'account_type_choices': _mapAccountTypeToApi(accountType),
        'bank_name': bankName,
        'account_number_or_upi_id': accountNumber,
        'ifsc_code': ifscCode,
        'account_holder_name': holderName,
        'account_holder_type': holderType.toLowerCase(),
        'account_holder_address': address,
        'account_holder_city': city,
        'account_holder_state': state,
        'account_holder_country': country,
        'is_default': isDefault,
        'is_active': isActive,
      };

      if (financialYearId != null) {
        body['financial_year_id'] = financialYearId;
      }
      if (openingBalance != null) {
        body['opening_balance'] = openingBalance;
      }

      final response = await ApiService.post(
        '/store-bank-details/',
        body: body,
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 || response['statusCode'] == 201) {
        // Some APIs return 201 for create, some 200. Check both.
        // Assuming success if status code is OK.
        // Also check inner status if available
        final data = response['data'];
        if (data is Map<String, dynamic> && data.containsKey('status')) {
          return data['status'] == 200 || data['status'] == 201;
        }
        return true;
      }
      return false;
    } catch (e) {
      throw Exception('Failed to create store bank details: $e');
    }
  }

  /// Update store bank details
  /// PUT /store-bank-details/
  static Future<bool> updateStoreBankDetails({
    required String storeId,
    required String bankDetailsId,
    required String accountType,
    required String bankName,
    required String accountNumber,
    required String ifscCode,
    required String holderName,
    required String holderType,
    required String city,
    required String address,
    required String state,
    required String country,
    required bool isDefault,
    required bool isActive,
    String? financialYearId,
    double? openingBalance,
  }) async {
    try {
      final body = {
        'store_id': storeId,
        'store_access': true,
        'create': false,
        'view': false,
        'bank_details_id': bankDetailsId,
        'account_type_choices': _mapAccountTypeToApi(accountType),
        'bank_name': bankName,
        'account_number_or_upi_id': accountNumber,
        'ifsc_code': ifscCode,
        'account_holder_name': holderName,
        'account_holder_type': holderType.toLowerCase(),
        'account_holder_address': address,
        'account_holder_city': city,
        'account_holder_state': state,
        'account_holder_country': country,
        'is_default': isDefault,
        'is_active': isActive,
        'is_verified': false, // As per payload requirement
      };

      if (financialYearId != null) {
        body['financial_year_id'] = financialYearId;
      }
      if (openingBalance != null) {
        body['opening_balance'] = openingBalance;
      }

      final response = await ApiService.put(
        '/store-bank-details/',
        body: body,
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 || response['statusCode'] == 201) {
        final data = response['data'];
        if (data is Map<String, dynamic> && data.containsKey('status')) {
          return data['status'] == 200 || data['status'] == 201;
        }
        return true;
      }
      return false;
    } catch (e) {
      throw Exception('Failed to update store bank details: $e');
    }
  }

  /// ── Phase 1: Submit invoice for AI analysis (async) ────────────────
  /// POST /purchase-entry-intelligence/
  /// Returns { job_id, poll_url, status, message }
  static Future<Map<String, dynamic>> submitPurchaseInvoice(
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

      if (response['statusCode'] == 202 && response['data'] != null) {
        return Map<String, dynamic>.from(response['data']);
      }

      // Fallback: handle old synchronous API (200 response)
      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = Map<String, dynamic>.from(response['data']);
        _normalizeAiResponse(data);
        return {
          'status': 200,
          'job_status': 'done',
          'response': data['response'] ?? data,
        };
      }

      return {
        'status': response['statusCode'] ?? 500,
        'job_status': 'failed',
        'error': response['data']?['response'] ?? 'Upload failed',
      };
    } catch (e) {
      throw Exception('Failed to upload purchase invoice: $e');
    }
  }

  /// ── Phase 2: Poll for AI analysis result ─────────────────────────────
  /// GET /purchase-entry-intelligence/status/<job_id>/
  static Future<Map<String, dynamic>> pollPurchaseIntelligenceStatus(
    String jobId,
  ) async {
    try {
      final response = await ApiService.get(
        '/purchase-entry-intelligence/status/$jobId/',
        useBearerToken: true,
      );

      if ((response['statusCode'] == 200 || response['statusCode'] == 202) &&
          response['data'] != null) {
        final data = Map<String, dynamic>.from(response['data']);

        if (data['job_status'] == 'done' && data['response'] != null) {
          _normalizeAiResponse(data);
        }
        return data;
      }

      return {
        'status': response['statusCode'] ?? 500,
        'job_status': 'failed',
        'error':
            'Unexpected response from server (HTTP ${response['statusCode']})',
      };
    } catch (e) {
      return {
        'status': 500,
        'job_status': 'failed',
        'error': 'Network error: $e',
      };
    }
  }

  /// Normalize AI response (decode nested JSON strings)
  static void _normalizeAiResponse(Map<String, dynamic> data) {
    if (data['response'] is String) {
      try {
        data['response'] = jsonDecode(data['response'] as String);
      } catch (_) {}
    }
    if (data['response'] is Map) {
      final resp = data['response'] as Map;
      if (resp['product_data'] is String) {
        try {
          resp['product_data'] = jsonDecode(resp['product_data'] as String);
        } catch (_) {}
      }
      if (resp['supplier_details'] is String) {
        try {
          resp['supplier_details'] = jsonDecode(
            resp['supplier_details'] as String,
          );
        } catch (_) {}
      }
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
    String? phoneNumber,
    String? email,
    String? websiteUrl,
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
          if (phoneNumber != null) 'phone_number': phoneNumber,
          if (email != null) 'email': email,
          if (websiteUrl != null) 'website_url': websiteUrl,
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

  /// Search for stores by GST number or query
  /// POST /search-store/
  static Future<List<Map<String, dynamic>>> searchStore(String query) async {
    try {
      final response = await ApiService.post(
        '/search-store/',
        body: {'query': query},
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
      throw Exception('Failed to search store: $e');
    }
  }

  /// Create a purchase entry
  /// POST /create-purchase-entry/
  static Future<Map<String, dynamic>> createPurchaseEntry({
    required String storeId,
    required String purchasedFromStoreId,
    required String supplierInvoiceId,
    required String date,
    required List<Map<String, dynamic>> items,
    required String paymentStatus,
    required double amountPaid,
    String? paymentMethodStoreBankId,
    bool autoPost = true,
    String status = 'PENDING',
  }) async {
    try {
      final body = {
        'store_id': storeId,
        'store_access': true,
        'purchased_from_store_id': purchasedFromStoreId,
        'supplier_invoice_id': supplierInvoiceId,
        'date': date,
        'items': items,
        'auto_post': autoPost,
        'payment_status': paymentStatus,
        'amount_paid': amountPaid,
        'status': status,
      };

      // Add payment method if provided
      if (paymentMethodStoreBankId != null &&
          paymentMethodStoreBankId.isNotEmpty) {
        body['payment_method_store_bank_id'] = paymentMethodStoreBankId;
      }

      final response = await ApiService.post(
        '/create-purchase-entry/',
        body: body,
        useBearerToken: true,
      );

      if (response['data'] != null) {
        return Map<String, dynamic>.from(response['data']);
      }
      return {};
    } catch (e) {
      throw Exception('Failed to create purchase entry: $e');
    }
  }

  /// Fetch receipt entries
  /// POST /list-receipts/
  static Future<Map<String, dynamic>> getReceipts(
    String storeId, {
    int page = 1,
    String? searchQuery,
  }) async {
    try {
      final body = {'store_id': storeId, 'store_access': true, 'page': page};

      if (searchQuery != null && searchQuery.isNotEmpty) {
        body['search'] = searchQuery;
      }

      final response = await ApiService.post(
        '/list-receipts/',
        body: body,
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];
        if (data['status'] == 200) {
          return Map<String, dynamic>.from(data);
        }
      }
      return {};
    } catch (e) {
      throw Exception('Failed to fetch receipts: $e');
    }
  }

  /// Fetch party list (Suppliers, Customers, etc.)
  /// POST /party-list/
  static Future<Map<String, dynamic>> getParties(
    String storeId, {
    int page = 1,
    int pageSize = 25,
    String? filter = 'suppliers',
    String sortBy = 'name',
    String sortOrder = 'desc',
    String? searchQuery,
    bool includeAgingReport = false,
    bool includeLedgerReport = false,
    String? ledgerStartDate,
    String? ledgerEndDate,
    String? asOfDate,
  }) async {
    try {
      final body = {
        'store_id': storeId,
        'store_access': true,
        'page': page,
        'page_size': pageSize,
        'sort_by': sortBy,
        'sort_order': sortOrder,
      };

      if (filter != null) body['filter'] = filter;
      if (searchQuery != null && searchQuery.isNotEmpty)
        body['search'] = searchQuery;

      if (includeAgingReport) {
        body['include_aging_report'] = true;
        if (asOfDate != null) body['as_of_date'] = asOfDate;
      }

      if (includeLedgerReport) {
        body['include_ledger_report'] = true;
        if (ledgerStartDate != null)
          body['ledger_start_date'] = ledgerStartDate;
        if (ledgerEndDate != null) body['ledger_end_date'] = ledgerEndDate;
      }

      final response = await ApiService.post(
        '/party-list/',
        body: body,
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];
        if (data['status'] == 200) {
          return Map<String, dynamic>.from(data);
        }
      }
      return {};
    } catch (e) {
      throw Exception('Failed to fetch parties: $e');
    }
  }

  /// Fetch financial years
  /// POST /financial-year-operations/
  static Future<Map<String, dynamic>> getFinancialYears(
    String storeId, {
    int limit = 50,
    int offset = 0,
    Map<String, dynamic>? query,
  }) async {
    try {
      final response = await ApiService.post(
        '/financial-year-operations/',
        body: {
          'create': false,
          'store_id': storeId,
          'store_access': true,
          'query': query ?? {},
          'order_by': '-start_date',
          'limit': limit,
          'offset': offset,
        },
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];
        if (data['status'] == 200) {
          return Map<String, dynamic>.from(data);
        }
      }
      return {};
    } catch (e) {
      throw Exception('Failed to fetch financial years: $e');
    }
  }

  /// Create a new financial year
  /// POST /financial-year-operations/
  static Future<Map<String, dynamic>> createFinancialYear({
    required String storeId,
    required String startDate,
    required String endDate,
    required bool isActive,
    required bool isLocked,
  }) async {
    try {
      final response = await ApiService.post(
        '/financial-year-operations/',
        body: {
          'create': true,
          'store_id': storeId,
          'store_access': true,
          'start_date': startDate,
          'end_date': endDate,
          'is_active': isActive,
          'is_locked': isLocked,
        },
        useBearerToken: true,
      );

      // Return the full response data if status code is 200, or if it's a 400 error handled by API
      // The shared ApiService usually returns {statusCode: ..., data: ...}
      if (response['data'] != null) {
        return Map<String, dynamic>.from(response['data']);
      }
      return {};
    } catch (e) {
      throw Exception('Failed to create financial year: $e');
    }
  }

  /// View User Roles
  /// POST /view-user-roles/
  static Future<List<Map<String, dynamic>>> viewUserRoles(
    String storeId,
  ) async {
    try {
      final response = await ApiService.post(
        '/view-user-roles/',
        body: {'store_id': storeId},
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
      throw Exception('Failed to fetch user roles: $e');
    }
  }

  /// Get Store Staff
  /// POST /store-staff/
  static Future<List<Map<String, dynamic>>> getStoreStaff(
    String storeId,
  ) async {
    try {
      final response = await ApiService.post(
        '/store-staff/',
        body: {
          'store_id': storeId,
          'view': true,
          'create': false,
          'staff_data': {},
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
      throw Exception('Failed to fetch store staff: $e');
    }
  }

  /// Update Store Staff
  /// PUT /store-staff/
  static Future<bool> updateStoreStaff({
    required String storeId,
    required String staffId,
    required Map<String, dynamic> dataToBeUpdated,
  }) async {
    try {
      final response = await ApiService.put(
        '/store-staff/',
        body: {
          'data_to_be_updated': dataToBeUpdated,
          'staff_id': staffId,
          'store_id': storeId,
        },
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];
        if (data['status'] == 200) {
          return true;
        }
      }
      return false;
    } catch (e) {
      throw Exception('Failed to update store staff: $e');
    }
  }

  /// Create Store Staff
  /// POST /store-staff/
  /// Returns a map with 'success' (bool) and 'message' (String?)
  static Future<Map<String, dynamic>> createStoreStaff({
    required String storeId,
    required String phoneNumber,
    required String roleId,
  }) async {
    try {
      final response = await ApiService.post(
        '/store-staff/',
        body: {
          'store_id': storeId,
          'create': true,
          'view': false,
          'staff_data': {
            'phone_number': int.tryParse(phoneNumber) ?? phoneNumber,
            'role_id': roleId,
          },
        },
        useBearerToken: true,
      );

      if ((response['statusCode'] == 200 || response['statusCode'] == 201) &&
          response['data'] != null) {
        final data = response['data'];
        if (data['status'] == 201) {
          return {'success': true, 'message': 'Staff created'};
        }
        return {
          'success': false,
          'message': data['message']?.toString() ?? 'Failed to add staff',
        };
      }
      return {'success': false, 'message': 'Failed to add staff'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Generate GST Report
  /// POST /gst-report/
  static Future<Map<String, dynamic>> generateGstReport({
    required String storeId,
    required String reportType,
    required String startDate,
    required String endDate,
    required String fileType,
  }) async {
    try {
      final response = await ApiService.post(
        '/gst-report/',
        body: {
          'store_id': storeId,
          'store_access': true,
          'report_type': reportType,
          'start_date': startDate,
          'end_date': endDate,
          'file_type': fileType, // 'pdf', 'xlsx', 'csv', 'json'
        },
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];
        // The sample response has "status": 200 at the top level of 'data' usually,
        // but based on previous methods, ApiService.post returns a wrapper.
        // Previous methods check data['status'] == 200.
        // Sample response provided by user: { "status": 200, "report": ..., "file": ... }
        if (data['status'] == 200) {
          return Map<String, dynamic>.from(data);
        }
      }
      return {};
    } catch (e) {
      throw Exception('Failed to generate GST report: $e');
    }
  }

  /// Fetch Voucher Register (Day Book)
  /// POST /voucher-register/
  static Future<Map<String, dynamic>> getVoucherRegister({
    required String storeId,
    List<String>? voucherTypes,
    String? startDate,
    String? endDate,
    bool? isPosted,
    bool? isCancelled,
    String? sourceType,
    String? search,
    String? partyId,
    int page = 1,
    int pageSize = 25,
    bool includeLines = false,
  }) async {
    try {
      final Map<String, dynamic> body = {
        'store_id': storeId,
        'store_access': true,
        'page': page,
        'page_size': pageSize,
        'include_lines': includeLines,
      };

      if (voucherTypes != null && voucherTypes.isNotEmpty) {
        body['voucher_types'] = voucherTypes;
      }
      if (startDate != null) body['start_date'] = startDate;
      if (endDate != null) body['end_date'] = endDate;
      if (isPosted != null) body['is_posted'] = isPosted;
      if (isCancelled != null) body['is_cancelled'] = isCancelled;
      if (sourceType != null) body['source_type'] = sourceType;
      if (search != null && search.isNotEmpty) body['search'] = search;
      if (partyId != null) body['party_id'] = partyId;

      final response = await ApiService.post(
        '/voucher-register/',
        body: body,
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];
        if (data['status'] == 200) {
          return Map<String, dynamic>.from(data);
        }
      }
      return {};
    } catch (e) {
      throw Exception('Failed to fetch voucher register: $e');
    }
  }

  /// Fetch coupons
  /// POST /coupons/
  static Future<Map<String, dynamic>> getCoupons({
    required String storeId,
    int page = 1,
    String orderBy = '-expiry_timestamp',
    Map<String, dynamic> query = const {},
  }) async {
    try {
      final response = await ApiService.post(
        '/coupons/',
        body: {
          'store_id': storeId,
          // 'store_access': true,
          'query': query,
          'order_by': orderBy,
          'page': page,
        },
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];
        if (data['status'] == 200) {
          return Map<String, dynamic>.from(data);
        }
      }
      return {};
    } catch (e) {
      throw Exception('Failed to fetch coupons: $e');
    }
  }

  /// Create a new coupon
  /// POST /add-coupon/
  static Future<bool> createCoupon(Map<String, dynamic> couponData) async {
    try {
      // Add modified_on_timestamp if not present
      if (!couponData.containsKey('modified_on_timestamp')) {
        couponData['modified_on_timestamp'] =
            (DateTime.now().millisecondsSinceEpoch / 1000).round();
      }

      final response = await ApiService.post(
        '/add-coupon/',
        body: couponData,
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];
        if (data['status'] == 200) {
          return true;
        }
      }
      return false;
    } catch (e) {
      throw Exception('Failed to create coupon: $e');
    }
  }

  /// Update an existing coupon
  /// PUT /coupons/
  static Future<bool> updateCoupon({
    required String couponId,
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await ApiService.put(
        '/coupons/',
        body: {'coupon_id': couponId, 'data': data},
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final responseData = response['data'];
        if (responseData['status'] == 200) {
          return true;
        }
      }
      return false;
    } catch (e) {
      throw Exception('Failed to update coupon: $e');
    }
  }

  static String _mapAccountTypeToApi(String displayType) {
    final lower = displayType.toLowerCase();
    if (lower.contains('savings')) return 'savings';
    if (lower.contains('current')) return 'current';
    if (lower.contains('cash')) return 'cash';
    if (lower.contains('bhim')) return 'bhimupi';
    if (lower.contains('paytm')) return 'paytmupi';
    if (lower.contains('phonepe')) return 'phonepeupi';
    if (lower.contains('google')) return 'googlepayupi';
    if (lower.contains('amazon')) return 'amazonpayupi';
    if (lower.contains('other')) return 'other';
    return 'savings'; // Fallback
  }

  /// Register staff face
  /// POST /register-face/
  /// Payload: { "staff_id": "...", "video": FILE }
  static Future<bool> registerFace(String staffId, File videoFile) async {
    try {
      final response = await ApiService.postMultipart(
        endpoint: '/register-face/',
        files: {'video': videoFile},
        fields: {'staff_id': staffId},
        useBearerToken: true,
      );

      if (response['statusCode'] == 200) {
        final data = response['data'];
        if (data != null && data['status'] == 200) {
          return true;
        }
      }
      return false;
    } catch (e) {
      throw Exception('Failed to register face: $e');
    }
  }

  /// Create product template from AI
  /// POST /create-product-template-from-ai/
  static Future<Map<String, dynamic>> createProductTemplateFromAi({
    required String productString,
    required String storeId,
  }) async {
    try {
      final response = await ApiService.post(
        '/create-product-template-from-ai/',
        body: {
          'product_string': productString,
          'store_access': true,
          'store_id': storeId,
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
      throw Exception('Failed to generate product from AI: $e');
    }
  }

  /// Update product template
  /// PUT /update-product-template/
  static Future<Map<String, dynamic>> updateProductTemplate({
    required String productTemplateId,
    required String storeId,
    required List<Map<String, dynamic>> editables,
  }) async {
    try {
      final response = await ApiService.put(
        '/update-product-template/',
        body: {
          'product_template_id': productTemplateId,
          'store_access': true,
          'store_id': storeId,
          'editables': editables,
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
      throw Exception('Failed to update product template: $e');
    }
  }

  /// Fetch product reviews (paginated)
  /// POST /product-reviews/
  ///
  /// Sample payload:
  /// {"page":1,"query":{"product_id":"..."},"store_access":true,"store_id":"..."}
  static Future<Map<String, dynamic>> getProductReviews({
    required String storeId,
    required String productId,
    int page = 1,
  }) async {
    try {
      final response = await ApiService.post(
        '/product-reviews/',
        body: {
          'page': page,
          'query': {'product_id': productId},
          'store_access': true,
          'store_id': storeId,
        },
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        return Map<String, dynamic>.from(response['data']);
      }
      return {};
    } catch (e) {
      throw Exception('Failed to fetch product reviews: $e');
    }
  }

  /// Fetch all active order methods with their IDs.
  /// POST /order-method/
  static Future<List<Map<String, String>>> getOrderMethods(
    String storeId,
  ) async {
    try {
      final response = await ApiService.post(
        '/order-method/',
        body: {
          'customer_user_id': '',
          'store_access': true,
          'store_id': storeId,
          'query': {},
        },
        useBearerToken: true,
      );
      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];
        final raw = data['response'];
        if (raw is List) {
          return raw
              .whereType<Map>()
              .where((m) => m['id'] != null && m['order_method_name'] != null)
              .map(
                (m) => {
                  'id': m['id'].toString(),
                  'name': m['order_method_name'].toString(),
                },
              )
              .toList();
        }
      }
      return [];
    } catch (_) {
      return []; // non-fatal
    }
  }

  /// Fetch orders filtered by status (paginated)
  /// POST /orders/
  ///
  /// Sample payload:
  /// {"query":{"status":"order_placed"},"page":1,"store_id":"...","store_access":true}
  static Future<Map<String, dynamic>> getOrdersByStatus({
    required String storeId,
    String status = 'order_placed',
    int page = 1,
  }) async {
    try {
      final response = await ApiService.post(
        '/orders/',
        body: {
          'query': {'status': status},
          'page': page,
          'store_id': storeId,
          'store_access': true,
        },
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        return Map<String, dynamic>.from(response['data']);
      }
      return {};
    } catch (e) {
      throw Exception('Failed to fetch orders: $e');
    }
  }

  /// Fetch BOM operations for a product combination
  /// POST /bom-operations/
  ///
  /// Sample payload:
  /// {"list":true,"store_id":"...","is_active":true,"product_combination_id":"..."}
  static Future<Map<String, dynamic>> getBomOperations({
    required String storeId,
    required String productCombinationId,
    bool isActive = true,
  }) async {
    try {
      final response = await ApiService.post(
        '/bom-operations/',
        body: {
          'list': true,
          'store_id': storeId,
          'is_active': isActive,
          'product_combination_id': productCombinationId,
        },
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        return Map<String, dynamic>.from(response['data']);
      }
      return {};
    } catch (e) {
      throw Exception('Failed to fetch BOM operations: $e');
    }
  }

  /// Validate whether a BOM can be produced for a given quantity + godown.
  /// POST /validate-production-possibility/
  static Future<Map<String, dynamic>> validateProductionPossibility({
    required String storeId,
    required String bomId,
    required double quantityToProduce,
    String? godownId,
  }) async {
    try {
      final body = <String, dynamic>{
        'bom_id': bomId,
        'store_id': storeId,
        'quantity_to_produce': quantityToProduce,
      };
      if (godownId != null) body['godown_id'] = godownId;

      final response = await ApiService.post(
        '/validate-production-possibility/',
        body: body,
        useBearerToken: true,
      );
      if (response['statusCode'] == 200 && response['data'] != null) {
        return Map<String, dynamic>.from(response['data']);
      }
      return {};
    } catch (e) {
      throw Exception('Failed to validate production: $e');
    }
  }

  /// Fetch full BOM details (components list).
  /// POST /bom-operations/  { "view_details": true, "bom_id": "..." }
  static Future<Map<String, dynamic>> getBomDetails({
    required String bomId,
  }) async {
    try {
      final response = await ApiService.post(
        '/bom-operations/',
        body: {'view_details': true, 'bom_id': bomId},
        useBearerToken: true,
      );
      if (response['statusCode'] == 200 && response['data'] != null) {
        return Map<String, dynamic>.from(response['data']);
      }
      return {};
    } catch (e) {
      throw Exception('Failed to fetch BOM details: $e');
    }
  }

  /// Fetch racks filtered by a specific godown.
  /// POST /racks/  (with godown query filter)
  static Future<List<Map<String, dynamic>>> getRacksByGodown({
    required String storeId,
    required String godownId,
  }) async {
    try {
      final response = await ApiService.post(
        '/racks/',
        body: {
          'store_id': storeId,
          'store_access': true,
          'create': false,
          'query': {'godown': godownId, 'is_active': true},
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

  /// Execute production from a BOM.
  /// POST /bom-operations/  { "produce": true, ... }
  static Future<Map<String, dynamic>> produceFromBom({
    required String bomId,
    required String storeId,
    required String godownId,
    required int quantityMultiplier,
    required String date, // 'YYYY-MM-DD'
    String? rackId,
  }) async {
    try {
      final body = <String, dynamic>{
        'produce': true,
        'bom_id': bomId,
        'store_id': storeId,
        'godown_id': godownId,
        'quantity_multiplier': quantityMultiplier,
        'date': date,
      };
      if (rackId != null && rackId.isNotEmpty) body['rack_id'] = rackId;

      final response = await ApiService.post(
        '/bom-operations/',
        body: body,
        useBearerToken: true,
      );
      if (response['data'] != null) {
        return Map<String, dynamic>.from(response['data']);
      }
      return {};
    } catch (e) {
      throw Exception('Failed to execute production: $e');
    }
  }

  /// Search product combinations by query string.
  /// POST /search-product-combinations/
  static Future<Map<String, dynamic>> searchProductCombinations({
    required String storeId,
    required String query,
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final response = await ApiService.post(
        '/search-product-combinations/',
        body: {
          'query': query,
          'store_access': true,
          'store_id': storeId,
          'page': page,
          'page_size': pageSize,
        },
        useBearerToken: true,
      );
      if (response['data'] != null) {
        return Map<String, dynamic>.from(response['data']);
      }
      return {};
    } catch (e) {
      throw Exception('Failed to search combinations: $e');
    }
  }

  /// Create a new BOM.
  /// POST /bom-operations/  { "create": true, ... }
  static Future<Map<String, dynamic>> saveBom({
    required String storeId,
    required String finishedCombinationId,
    required double outputQuantity,
    required String outputUnitId,
    String? orderMethodId, // universal recipe: null = all methods
    required List<Map<String, dynamic>> components,
    // each: { raw_combination_id, quantity, unit_id (opt), scrap_percentage }
  }) async {
    try {
      final body = <String, dynamic>{
        'create': true,
        'store_id': storeId,
        'store_access': true,
        'finished_combination_id': finishedCombinationId,
        'output_quantity': outputQuantity,
        'output_unit_id': outputUnitId,
        'components': components,
      };
      if (orderMethodId != null) body['order_method_id'] = orderMethodId;

      final response = await ApiService.post(
        '/bom-operations/',
        body: body,
        useBearerToken: true,
      );
      if (response['data'] != null) {
        return Map<String, dynamic>.from(response['data']);
      }
      return {};
    } catch (e) {
      throw Exception('Failed to save BOM: $e');
    }
  }

  /// Create a product in the store from a global template
  /// POST /create-from-template/
  static Future<Map<String, dynamic>> createProductFromTemplate({
    required String storeId,
    required String productCombinationTemplateId,
    bool isInventoryManagementRequired = false,
  }) async {
    try {
      final response = await ApiService.post(
        '/create-from-template/',
        body: {
          'store_id': storeId,
          'store_access': true,
          'product_combination_template_id': productCombinationTemplateId,
          'is_inventory_management_required': isInventoryManagementRequired,
        },
        useBearerToken: true,
      );
      if (response['data'] != null) {
        return Map<String, dynamic>.from(response['data']);
      }
      return {};
    } catch (e) {
      throw Exception('Failed to create product from template: $e');
    }
  }
}
