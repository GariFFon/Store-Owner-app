class SalesResponse {
  final int count;
  final int returned;
  final List<Voucher> vouchers;

  SalesResponse({
    required this.count,
    required this.returned,
    required this.vouchers,
  });

  factory SalesResponse.fromJson(Map<String, dynamic> json) {
    return SalesResponse(
      count: json['count'] ?? 0,
      returned: json['returned'] ?? 0,
      vouchers:
          (json['vouchers'] as List<dynamic>?)
              ?.map((e) => Voucher.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class Voucher {
  final String id;
  final String voucherNumber;
  final String voucherType;
  final String date;
  final Customer? customer;
  final double totalAmount;
  final TaxBreakdown? taxBreakdown;
  final double grandTotal;
  final bool isPosted;
  final String? narration;
  final List<SalesItem> items;
  final String createdAt;

  Voucher({
    required this.id,
    required this.voucherNumber,
    required this.voucherType,
    required this.date,
    this.customer,
    required this.totalAmount,
    this.taxBreakdown,
    required this.grandTotal,
    required this.isPosted,
    this.narration,
    required this.items,
    required this.createdAt,
  });

  factory Voucher.fromJson(Map<String, dynamic> json) {
    return Voucher(
      id: json['id'],
      voucherNumber: json['voucher_number'] ?? '',
      voucherType: json['voucher_type'] ?? '',
      date: json['date'] ?? '',
      customer: json['customer'] != null
          ? Customer.fromJson(json['customer'])
          : null,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      taxBreakdown: json['tax_breakdown'] != null
          ? TaxBreakdown.fromJson(json['tax_breakdown'])
          : null,
      grandTotal: (json['grand_total'] as num?)?.toDouble() ?? 0.0,
      isPosted: json['is_posted'] ?? false,
      narration: json['narration'],
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => SalesItem.fromJson(e))
              .toList() ??
          [],
      createdAt: json['created_at'] ?? '',
    );
  }
}

class Customer {
  final String id;
  final String name;
  final String partyType;

  Customer({required this.id, required this.name, required this.partyType});

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      partyType: json['party_type'] ?? '',
    );
  }
}

class TaxBreakdown {
  final double totalCgst;
  final double totalSgst;
  final double totalIgst;
  final double totalCess;
  final double totalTax;

  TaxBreakdown({
    required this.totalCgst,
    required this.totalSgst,
    required this.totalIgst,
    required this.totalCess,
    required this.totalTax,
  });

  factory TaxBreakdown.fromJson(Map<String, dynamic> json) {
    return TaxBreakdown(
      totalCgst: (json['total_cgst'] as num?)?.toDouble() ?? 0.0,
      totalSgst: (json['total_sgst'] as num?)?.toDouble() ?? 0.0,
      totalIgst: (json['total_igst'] as num?)?.toDouble() ?? 0.0,
      totalCess: (json['total_cess'] as num?)?.toDouble() ?? 0.0,
      totalTax: (json['total_tax'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class SalesItem {
  final double quantity;
  final String? unitName;
  final double rate;
  final double amount;
  final String? productName;
  final TaxDetails? taxDetails;
  final Inventory? inventory;

  SalesItem({
    required this.quantity,
    this.unitName,
    required this.rate,
    required this.amount,
    this.productName,
    this.taxDetails,
    this.inventory,
  });

  factory SalesItem.fromJson(Map<String, dynamic> json) {
    return SalesItem(
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unitName: json['unit']?['name'],
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      productName: json['product']?['name'],
      taxDetails: json['tax_details'] != null
          ? TaxDetails.fromJson(json['tax_details'])
          : null,
      inventory: json['inventory'] != null
          ? Inventory.fromJson(json['inventory'])
          : null,
    );
  }
}

class TaxDetails {
  final String hsnCode;
  final double taxableValue;
  final double cgstRate;
  final double cgstAmount;
  final double sgstRate;
  final double sgstAmount;
  final double igstRate;
  final double igstAmount;
  final double cessRate;
  final double cessAmount;

  TaxDetails({
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
  });

  factory TaxDetails.fromJson(Map<String, dynamic> json) {
    return TaxDetails(
      hsnCode: json['hsn_code'] ?? '',
      taxableValue: (json['taxable_value'] as num?)?.toDouble() ?? 0.0,
      cgstRate: (json['cgst_rate'] as num?)?.toDouble() ?? 0.0,
      cgstAmount: (json['cgst_amount'] as num?)?.toDouble() ?? 0.0,
      sgstRate: (json['sgst_rate'] as num?)?.toDouble() ?? 0.0,
      sgstAmount: (json['sgst_amount'] as num?)?.toDouble() ?? 0.0,
      igstRate: (json['igst_rate'] as num?)?.toDouble() ?? 0.0,
      igstAmount: (json['igst_amount'] as num?)?.toDouble() ?? 0.0,
      cessRate: (json['cess_rate'] as num?)?.toDouble() ?? 0.0,
      cessAmount: (json['cess_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class Inventory {
  final double mrp;
  final double sellingAmount;
  final String hsnCode;

  Inventory({
    required this.mrp,
    required this.sellingAmount,
    required this.hsnCode,
  });

  factory Inventory.fromJson(Map<String, dynamic> json) {
    return Inventory(
      mrp: (json['mrp'] as num?)?.toDouble() ?? 0.0,
      sellingAmount:
          (json['selling_amount_excluding_tax'] as num?)?.toDouble() ?? 0.0,
      hsnCode: json['hsn_code'] ?? '',
    );
  }
}
