import 'package:exanor/services/api_service.dart';
import 'package:exanor/models/gst_ledger_model.dart';
import 'package:exanor/models/gst_summary_model.dart';

class GstLedgerService {
  /// Fetch GST Ledger data
  /// POST /gst-ledger-operations/
  static Future<GstLedgerResponse> getGstLedger(
    GstLedgerRequest request,
  ) async {
    try {
      final response = await ApiService.post(
        '/gst-ledger-operations/',
        body: request.toJson(),
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        return GstLedgerResponse.fromJson(response['data']);
      }

      throw Exception('Failed to load GST ledger data');
    } catch (e) {
      throw Exception('Failed to fetch GST ledger: $e');
    }
  }

  /// Fetch GST Summary
  /// POST /gst-ledger-operations/
  static Future<GstSummaryResponse> getGstSummary(
    GstSummaryRequest request,
  ) async {
    try {
      final response = await ApiService.post(
        '/gst-ledger-operations/',
        body: request.toJson(),
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        return GstSummaryResponse.fromJson(response['data']);
      }

      throw Exception('Failed to load GST summary data');
    } catch (e) {
      throw Exception('Failed to fetch GST summary: $e');
    }
  }
}
