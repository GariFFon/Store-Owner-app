class GstSummaryRequest {
  final bool summary;
  final String storeId;
  final String startDate;
  final String endDate;

  GstSummaryRequest({
    required this.summary,
    required this.storeId,
    required this.startDate,
    required this.endDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'summary': summary,
      'store_id': storeId,
      'start_date': startDate,
      'end_date': endDate,
    };
  }
}

class GstSummaryResponse {
  final int status;
  final GstSummaryData response;

  GstSummaryResponse({
    required this.status,
    required this.response,
  });

  factory GstSummaryResponse.fromJson(Map<String, dynamic> json) {
    return GstSummaryResponse(
      status: json['status'] ?? 200,
      response: GstSummaryData.fromJson(json['response'] ?? {}),
    );
  }
}

class GstSummaryData {
  final PeriodData period;
  final TaxData inputGst;
  final TaxData outputGst;
  final NetLiabilityData netLiability;
  final List<HsnSummaryItem> hsnSummary;

  GstSummaryData({
    required this.period,
    required this.inputGst,
    required this.outputGst,
    required this.netLiability,
    required this.hsnSummary,
  });

  factory GstSummaryData.fromJson(Map<String, dynamic> json) {
    return GstSummaryData(
      period: PeriodData.fromJson(json['period'] ?? {}),
      inputGst: TaxData.fromJson(json['input_gst'] ?? {}),
      outputGst: TaxData.fromJson(json['output_gst'] ?? {}),
      netLiability: NetLiabilityData.fromJson(json['net_liability'] ?? {}),
      hsnSummary: (json['hsn_summary'] as List<dynamic>?)
              ?.map((e) => HsnSummaryItem.fromJson(e))
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

class TaxData {
  final String taxableValue;
  final String cgst;
  final String sgst;
  final String igst;
  final String cess;
  final String total;

  TaxData({
    required this.taxableValue,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.cess,
    required this.total,
  });

  factory TaxData.fromJson(Map<String, dynamic> json) {
    return TaxData(
      taxableValue: json['taxable_value'] ?? '0.00',
      cgst: json['cgst'] ?? '0.00',
      sgst: json['sgst'] ?? '0.00',
      igst: json['igst'] ?? '0.00',
      cess: json['cess'] ?? '0.00',
      total: json['total'] ?? '0.00',
    );
  }

  double get taxableValueDouble => double.tryParse(taxableValue) ?? 0.0;
  double get cgstDouble => double.tryParse(cgst) ?? 0.0;
  double get sgstDouble => double.tryParse(sgst) ?? 0.0;
  double get igstDouble => double.tryParse(igst) ?? 0.0;
  double get cessDouble => double.tryParse(cess) ?? 0.0;
  double get totalDouble => double.tryParse(total) ?? 0.0;
}

class NetLiabilityData {
  final String cgst;
  final String sgst;
  final String igst;
  final String cess;
  final String total;
  final String note;

  NetLiabilityData({
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.cess,
    required this.total,
    required this.note,
  });

  factory NetLiabilityData.fromJson(Map<String, dynamic> json) {
    return NetLiabilityData(
      cgst: json['cgst'] ?? '0.00',
      sgst: json['sgst'] ?? '0.00',
      igst: json['igst'] ?? '0.00',
      cess: json['cess'] ?? '0.00',
      total: json['total'] ?? '0.00',
      note: json['note'] ?? '',
    );
  }

  double get cgstDouble => double.tryParse(cgst) ?? 0.0;
  double get sgstDouble => double.tryParse(sgst) ?? 0.0;
  double get igstDouble => double.tryParse(igst) ?? 0.0;
  double get cessDouble => double.tryParse(cess) ?? 0.0;
  double get totalDouble => double.tryParse(total) ?? 0.0;
}

class HsnSummaryItem {
  final String hsnCode;
  final String taxableValue;
  final String cgst;
  final String sgst;
  final String igst;
  final String cess;
  final String totalGst;

  HsnSummaryItem({
    required this.hsnCode,
    required this.taxableValue,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.cess,
    required this.totalGst,
  });

  factory HsnSummaryItem.fromJson(Map<String, dynamic> json) {
    return HsnSummaryItem(
      hsnCode: json['hsn_code'] ?? '',
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
