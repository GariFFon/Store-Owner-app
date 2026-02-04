class GstLedgerRequest {
  final bool list;
  final String storeId;
  final String startDate;
  final String endDate;
  final String gstType;
  final String? voucherType;
  final String? partyId;
  final String? hsnCode;
  final String sortBy;
  final String sortOrder;
  final int page;

  GstLedgerRequest({
    required this.list,
    required this.storeId,
    required this.startDate,
    required this.endDate,
    required this.gstType,
    this.voucherType,
    this.partyId,
    this.hsnCode,
    required this.sortBy,
    required this.sortOrder,
    required this.page,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'list': list,
      'store_id': storeId,
      'start_date': startDate,
      'end_date': endDate,
      'gst_type': gstType,
      'sort_by': sortBy,
      'sort_order': sortOrder,
      'page': page,
    };
    if (voucherType != null) json['voucher_type'] = voucherType!;
    if (partyId != null) json['party_id'] = partyId!;
    if (hsnCode != null) json['hsn_code'] = hsnCode!;
    return json;
  }
}

class GstLedgerResponse {
  final int status;
  final GstLedgerData response;

  GstLedgerResponse({
    required this.status,
    required this.response,
  });

  factory GstLedgerResponse.fromJson(Map<String, dynamic> json) {
    return GstLedgerResponse(
      status: json['status'] ?? 200,
      response: GstLedgerData.fromJson(json['response'] ?? {}),
    );
  }
}

class GstLedgerData {
  final int count;
  final int page;
  final int pageSize;
  final int totalPages;
  final FiltersApplied filtersApplied;
  final GstTotals totals;
  final List<LedgerEntry> ledger;

  GstLedgerData({
    required this.count,
    required this.page,
    required this.pageSize,
    required this.totalPages,
    required this.filtersApplied,
    required this.totals,
    required this.ledger,
  });

  factory GstLedgerData.fromJson(Map<String, dynamic> json) {
    return GstLedgerData(
      count: json['count'] ?? 0,
      page: json['page'] ?? 1,
      pageSize: json['page_size'] ?? 50,
      totalPages: json['total_pages'] ?? 1,
      filtersApplied: FiltersApplied.fromJson(json['filters_applied'] ?? {}),
      totals: GstTotals.fromJson(json['totals'] ?? {}),
      ledger: (json['ledger'] as List<dynamic>?)
              ?.map((e) => LedgerEntry.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class FiltersApplied {
  final String startDate;
  final String endDate;
  final String gstType;
  final String? voucherType;
  final String? partyId;
  final String? hsnCode;
  final String sortBy;
  final String sortOrder;

  FiltersApplied({
    required this.startDate,
    required this.endDate,
    required this.gstType,
    this.voucherType,
    this.partyId,
    this.hsnCode,
    required this.sortBy,
    required this.sortOrder,
  });

  factory FiltersApplied.fromJson(Map<String, dynamic> json) {
    return FiltersApplied(
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
      gstType: json['gst_type'] ?? 'all',
      voucherType: json['voucher_type'],
      partyId: json['party_id'],
      hsnCode: json['hsn_code'],
      sortBy: json['sort_by'] ?? 'date',
      sortOrder: json['sort_order'] ?? 'desc',
    );
  }
}

class GstTotals {
  final String totalTaxable;
  final String totalCgst;
  final String totalSgst;
  final String totalIgst;
  final String totalCess;
  final String totalGst;

  GstTotals({
    required this.totalTaxable,
    required this.totalCgst,
    required this.totalSgst,
    required this.totalIgst,
    required this.totalCess,
    required this.totalGst,
  });

  factory GstTotals.fromJson(Map<String, dynamic> json) {
    return GstTotals(
      totalTaxable: json['total_taxable'] ?? '0.00',
      totalCgst: json['total_cgst'] ?? '0.00',
      totalSgst: json['total_sgst'] ?? '0.00',
      totalIgst: json['total_igst'] ?? '0.00',
      totalCess: json['total_cess'] ?? '0.00',
      totalGst: json['total_gst'] ?? '0.00',
    );
  }

  double get totalTaxableValue => double.tryParse(totalTaxable) ?? 0.0;
  double get totalCgstValue => double.tryParse(totalCgst) ?? 0.0;
  double get totalSgstValue => double.tryParse(totalSgst) ?? 0.0;
  double get totalIgstValue => double.tryParse(totalIgst) ?? 0.0;
  double get totalCessValue => double.tryParse(totalCess) ?? 0.0;
  double get totalGstValue => double.tryParse(totalGst) ?? 0.0;
}

class LedgerEntry {
  final String id;
  final String date;
  final String voucherId;
  final String voucherNumber;
  final String voucherType;
  final String partyName;
  final String partyId;
  final String itemName;
  final String hsnCode;
  final String taxableValue;
  final String cgstRate;
  final String cgstAmount;
  final String sgstRate;
  final String sgstAmount;
  final String igstRate;
  final String igstAmount;
  final String cessRate;
  final String cessAmount;
  final String totalGst;
  final String balanceCgst;
  final String balanceSgst;
  final String balanceIgst;
  final String balanceCess;

  LedgerEntry({
    required this.id,
    required this.date,
    required this.voucherId,
    required this.voucherNumber,
    required this.voucherType,
    required this.partyName,
    required this.partyId,
    required this.itemName,
    required this.hsnCode,
    required this.taxableValue,
    required this.cgstRate,
    required this.cgstAmount,
    required this.sgstRate,
    required this.sgstAmount,
    required this.igstRate,
    required this.igstAmount,
    required this.cessRate,
    required this.cessAmount,
    required this.totalGst,
    required this.balanceCgst,
    required this.balanceSgst,
    required this.balanceIgst,
    required this.balanceCess,
  });

  factory LedgerEntry.fromJson(Map<String, dynamic> json) {
    return LedgerEntry(
      id: json['id'] ?? '',
      date: json['date'] ?? '',
      voucherId: json['voucher_id'] ?? '',
      voucherNumber: json['voucher_number'] ?? '',
      voucherType: json['voucher_type'] ?? '',
      partyName: json['party_name'] ?? '',
      partyId: json['party_id'] ?? '',
      itemName: json['item_name'] ?? '',
      hsnCode: json['hsn_code'] ?? '',
      taxableValue: json['taxable_value']?.toString() ?? '0.00',
      cgstRate: json['cgst_rate']?.toString() ?? '0.00',
      cgstAmount: json['cgst_amount']?.toString() ?? '0.00',
      sgstRate: json['sgst_rate']?.toString() ?? '0.00',
      sgstAmount: json['sgst_amount']?.toString() ?? '0.00',
      igstRate: json['igst_rate']?.toString() ?? '0.00',
      igstAmount: json['igst_amount']?.toString() ?? '0.00',
      cessRate: json['cess_rate']?.toString() ?? '0.00',
      cessAmount: json['cess_amount']?.toString() ?? '0.00',
      totalGst: json['total_gst']?.toString() ?? '0.00',
      balanceCgst: json['balance_cgst']?.toString() ?? '0.00',
      balanceSgst: json['balance_sgst']?.toString() ?? '0.00',
      balanceIgst: json['balance_igst']?.toString() ?? '0.00',
      balanceCess: json['balance_cess']?.toString() ?? '0.00',
    );
  }

  double get taxableValueDouble => double.tryParse(taxableValue) ?? 0.0;
  double get cgstAmountDouble => double.tryParse(cgstAmount) ?? 0.0;
  double get sgstAmountDouble => double.tryParse(sgstAmount) ?? 0.0;
  double get igstAmountDouble => double.tryParse(igstAmount) ?? 0.0;
  double get totalGstDouble => double.tryParse(totalGst) ?? 0.0;
}
