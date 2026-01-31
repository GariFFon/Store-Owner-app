import 'package:exanor/services/api_service.dart';
import 'package:exanor/models/sales_models.dart';

class SalesService {
  static Future<SalesResponse> fetchSales({
    required String storeId,
    int limit = 50,
    int offset = 0,
    String sortBy = 'date',
    String sortOrder = 'desc',
    String? searchQuery,
    String? voucherNumber,
  }) async {
    try {
      final Map<String, dynamic> filters = {"voucher_type": "SALES"};

      if (voucherNumber != null && voucherNumber.isNotEmpty) {
        // Assuming client side search or specific filter if API supports it
        // But the requirement says payload specific filter.
        // Let's stick to base payload.
      }

      final body = {
        "store_id": storeId,
        "store_access": true,
        "filters": filters,
        "sort_by": sortBy,
        "sort_order": sortOrder,
        "limit": limit,
        "offset": offset,
      };

      final response = await ApiService.post(
        '/view-sales-entry/',
        body: body,
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];
        if (data['status'] == 200 && data['body'] != null) {
          return SalesResponse.fromJson(data['body']);
        }
      }
      throw Exception('Failed to load sales: ${response['message']}');
    } catch (e) {
      throw Exception('Error fetching sales data: $e');
    }
  }
}
