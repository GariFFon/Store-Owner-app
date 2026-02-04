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

      // Attempting to filter by HSN code or description if search query is provided
      // Note: The exact query syntax depends on the backend.
      // Using a simple partial match assumption or skipping if unknown.
      // Since we don't know the exact query syntax (e.g. $regex), we will just rely on the API returning all and handle what we can,
      // or if the backend supports a "search" parameter we would add it.
      // For now, we strictly follow the payload structure provided.

      if (searchQuery != null && searchQuery.isNotEmpty) {
        // Assuming MongoDB-like query structure for backend
        query['\$or'] = [
          {
            "hsn_code": {"\$regex": searchQuery, "\$options": "i"},
          },
          {
            "hsn_description": {"\$regex": searchQuery, "\$options": "i"},
          },
        ];
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
        // The API returns the data directly or wrapped in 'data' depending on ApiService
        // ApiService post returns: {'statusCode': ..., 'data': jsonDecode(body)}
        // The endpoint response structure is: { "status": 200, "response": [...], ... }
        final data = response['data'];
        return GstResponse.fromJson(data);
      }
      throw Exception('Failed to load GST rates');
    } catch (e) {
      throw Exception('Error fetching GST rates: $e');
    }
  }
}
