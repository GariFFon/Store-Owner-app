import 'package:exanor/services/api_service.dart';
import 'package:exanor/models/payment_models.dart';

class PaymentService {
  static Future<PaymentResponse> fetchPayments({
    required String storeId,
    int page = 1,
    int pageSize = 50,
    String? fromDate,
    String? toDate,
    bool? isPosted,
    String? partyId,
    String? searchQuery,
  }) async {
    try {
      final Map<String, dynamic> body = {
        "store_id": storeId,
        "store_access": true,
        "page": page,
        "page_size": pageSize,
      };

      if (fromDate != null && fromDate.isNotEmpty) {
        body['from_date'] = fromDate;
      }
      if (toDate != null && toDate.isNotEmpty) {
        body['to_date'] = toDate;
      }
      if (isPosted != null) {
        body['is_posted'] = isPosted;
      }
      if (partyId != null && partyId.isNotEmpty) {
        body['party_id'] = partyId;
      }
      // Handling search if API supports it, implied by standard patterns
      if (searchQuery != null && searchQuery.isNotEmpty) {
        body['search_query'] = searchQuery;
      }

      final response = await ApiService.post(
        '/list-payments/',
        body: body,
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];
        if (data['status'] == 200) {
          return PaymentResponse.fromJson(data);
        }
      }
      throw Exception('Failed to load payments: ${response['message']}');
    } catch (e) {
      throw Exception('Error fetching payment data: $e');
    }
  }
}
