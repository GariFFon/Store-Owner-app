class PaymentResponse {
  final int totalItems;
  final int totalPages;
  final int currentPage;
  final List<PaymentVoucher> vouchers;

  PaymentResponse({
    required this.totalItems,
    required this.totalPages,
    required this.currentPage,
    required this.vouchers,
  });

  factory PaymentResponse.fromJson(Map<String, dynamic> json) {
    var pagination = json['pagination'] ?? {};
    return PaymentResponse(
      totalItems: pagination['total_items'] ?? 0,
      totalPages: pagination['total_pages'] ?? 1,
      currentPage: pagination['current_page'] ?? 1,
      vouchers:
          (json['response'] as List<dynamic>?)
              ?.map((e) => PaymentVoucher.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class PaymentVoucher {
  final String voucherId;
  final String voucherNumber;
  final String date;
  final String partyName;
  final double amount;
  final String paymentAccount;
  final bool isPosted;
  final String? narration;
  // Fields implied by UI but not in sample response list, making optional
  final String? partyType;
  final String? financialYear;

  PaymentVoucher({
    required this.voucherId,
    required this.voucherNumber,
    required this.date,
    required this.partyName,
    required this.amount,
    required this.paymentAccount,
    required this.isPosted,
    this.narration,
    this.partyType,
    this.financialYear,
  });

  factory PaymentVoucher.fromJson(Map<String, dynamic> json) {
    return PaymentVoucher(
      voucherId: json['voucher_id'] ?? '',
      voucherNumber: json['voucher_number'] ?? '',
      date: json['date'] ?? '',
      partyName: json['party_name'] ?? 'Unknown',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentAccount: json['payment_account'] ?? '',
      isPosted: json['is_posted'] ?? false,
      narration: json['narration'],
      partyType: json['party_type'], // Might be null
      financialYear: json['financial_year'], // Might be null
    );
  }
}
