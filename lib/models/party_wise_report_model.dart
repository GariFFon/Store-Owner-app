class PartyWiseReportRequest {
  final bool partyWise;
  final String storeId;
  final String startDate;
  final String endDate;
  final String gstType;

  PartyWiseReportRequest({
    required this.partyWise,
    required this.storeId,
    required this.startDate,
    required this.endDate,
    required this.gstType,
  });

  Map<String, dynamic> toJson() {
    return {
      'party_wise': partyWise,
      'store_id': storeId,
      'start_date': startDate,
      'end_date': endDate,
      'gst_type': gstType,
    };
  }
}

class PartyWiseReportResponse {
  final int status;
  final PartyWiseReportData response;

  PartyWiseReportResponse({
    required this.status,
    required this.response,
  });

  factory PartyWiseReportResponse.fromJson(Map<String, dynamic> json) {
    return PartyWiseReportResponse(
      status: json['status'] ?? 200,
      response: PartyWiseReportData.fromJson(json['response'] ?? {}),
    );
  }
}

class PartyWiseReportData {
  final PeriodData period;
  final String gstType;
  final int partyCount;
  final PartyTotals totals;
  final List<PartyItem> parties;

  PartyWiseReportData({
    required this.period,
    required this.gstType,
    required this.partyCount,
    required this.totals,
    required this.parties,
  });

  factory PartyWiseReportData.fromJson(Map<String, dynamic> json) {
    return PartyWiseReportData(
      period: PeriodData.fromJson(json['period'] ?? {}),
      gstType: json['gst_type'] ?? 'all',
      partyCount: json['party_count'] ?? 0,
      totals: PartyTotals.fromJson(json['totals'] ?? {}),
      parties: (json['parties'] as List<dynamic>?)
              ?.map((e) => PartyItem.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class PeriodData {
  final String startDate;
  final String endDate;

  PeriodData({
    required this.startDate,
    required this.endDate,
  });

  factory PeriodData.fromJson(Map<String, dynamic> json) {
    return PeriodData(
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
    );
  }
}

class PartyTotals {
  final String totalTaxable;
  final String totalCgst;
  final String totalSgst;
  final String totalIgst;
  final String totalCess;
  final String totalGst;

  PartyTotals({
    required this.totalTaxable,
    required this.totalCgst,
    required this.totalSgst,
    required this.totalIgst,
    required this.totalCess,
    required this.totalGst,
  });

  factory PartyTotals.fromJson(Map<String, dynamic> json) {
    return PartyTotals(
      totalTaxable: json['total_taxable'] ?? '0.00',
      totalCgst: json['total_cgst'] ?? '0.00',
      totalSgst: json['total_sgst'] ?? '0.00',
      totalIgst: json['total_igst'] ?? '0.00',
      totalCess: json['total_cess'] ?? '0.00',
      totalGst: json['total_gst'] ?? '0.00',
    );
  }

  double get totalTaxableDouble => double.tryParse(totalTaxable) ?? 0.0;
  double get totalCgstDouble => double.tryParse(totalCgst) ?? 0.0;
  double get totalSgstDouble => double.tryParse(totalSgst) ?? 0.0;
  double get totalIgstDouble => double.tryParse(totalIgst) ?? 0.0;
  double get totalCessDouble => double.tryParse(totalCess) ?? 0.0;
  double get totalGstDouble => double.tryParse(totalGst) ?? 0.0;
}

class PartyItem {
  final String partyId;
  final String partyName;
  final String gstin;
  final int transactionCount;
  final String taxableValue;
  final String cgst;
  final String sgst;
  final String igst;
  final String cess;
  final String totalGst;

  PartyItem({
    required this.partyId,
    required this.partyName,
    required this.gstin,
    required this.transactionCount,
    required this.taxableValue,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.cess,
    required this.totalGst,
  });

  factory PartyItem.fromJson(Map<String, dynamic> json) {
    return PartyItem(
      partyId: json['party_id'] ?? '',
      partyName: json['party_name'] ?? '',
      gstin: json['gstin'] ?? 'N/A',
      transactionCount: json['transaction_count'] ?? 0,
      taxableValue: json['taxable_value'] ?? '0.00',
      cgst: json['cgst'] ?? '0.00',
      sgst: json['sgst'] ?? '0.00',
      igst: json['igst'] ?? '0.00',
      cess: json['cess'] ?? '0.00',
      totalGst: json['total_gst'] ?? '0.00',
    );
  }

  double get taxableValueDouble => double.tryParse(taxableValue) ?? 0.0;
  double get cgstDouble => double.tryParse(cgst) ?? 0.0;
  double get sgstDouble => double.tryParse(sgst) ?? 0.0;
  double get igstDouble => double.tryParse(igst) ?? 0.0;
  double get cessDouble => double.tryParse(cess) ?? 0.0;
  double get totalGstDouble => double.tryParse(totalGst) ?? 0.0;
}
