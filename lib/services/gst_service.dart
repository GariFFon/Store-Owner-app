import 'package:exanor/services/api_service.dart';
import 'package:exanor/models/gst_rate_model.dart';

class GstService {
  static Future<GstResponse> fetchGstRates({
    required String storeId,
    int limit = 50,
    int offset = 0,
    String? searchQuery,
  }) async {
    try {
      final Map<String, dynamic> query = {};

      // Add search query if provided
      if (searchQuery != null && searchQuery.isNotEmpty) {
        query['search'] = searchQuery;
      }

      final body = {
        "store_id": storeId,
        "store_access": true,
        "create": false,
        "query": query,
        "order_by": "hsn_code",
        "limit": limit,
        "offset": offset,
      };

      final response = await ApiService.post(
        '/gst-rate-operations/',
        body: body,
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];
        return GstResponse.fromJson(data);
      }
      throw Exception('Failed to load GST rates');
    } catch (e) {
      throw Exception('Error fetching GST rates: $e');
    }
  }
}
