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
      partyType: json['party_type'],
      financialYear: json['financial_year'],
    );
  }
}

class PaymentDetail {
  final String voucherId;
  final String voucherNumber;
  final String voucherType;
  final String date;
  final bool isPosted;
  final String? narration;
  final PartyInfo party;
  final double amount;
  final List<LedgerEntry> ledgerEntries;
  final double totalDebit;
  final double totalCredit;
  final bool isBalanced;
  final String financialYear;

  PaymentDetail({
    required this.voucherId,
    required this.voucherNumber,
    required this.voucherType,
    required this.date,
    required this.isPosted,
    this.narration,
    required this.party,
    required this.amount,
    required this.ledgerEntries,
    required this.totalDebit,
    required this.totalCredit,
    required this.isBalanced,
    required this.financialYear,
  });

  factory PaymentDetail.fromJson(Map<String, dynamic> json) {
    return PaymentDetail(
      voucherId: json['voucher_id'] ?? '',
      voucherNumber: json['voucher_number'] ?? '',
      voucherType: json['voucher_type'] ?? 'PAYMENT',
      date: json['date'] ?? '',
      isPosted: json['is_posted'] ?? false,
      narration: json['narration'],
      party: PartyInfo.fromJson(json['party'] ?? {}),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      ledgerEntries: (json['ledger_entries'] as List<dynamic>?)
              ?.map((e) => LedgerEntry.fromJson(e))
              .toList() ??
          [],
      totalDebit: (json['total_debit'] as num?)?.toDouble() ?? 0.0,
      totalCredit: (json['total_credit'] as num?)?.toDouble() ?? 0.0,
      isBalanced: json['is_balanced'] ?? false,
      financialYear: json['financial_year'] ?? '',
    );
  }
}

class PartyInfo {
  final String id;
  final String name;
  final String type;

  PartyInfo({
    required this.id,
    required this.name,
    required this.type,
  });

  factory PartyInfo.fromJson(Map<String, dynamic> json) {
    return PartyInfo(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown',
      type: json['type'] ?? 'Unknown',
    );
  }
}

class LedgerEntry {
  final String account;
  final double debit;
  final double credit;

  LedgerEntry({
    required this.account,
    required this.debit,
    required this.credit,
  });

  factory LedgerEntry.fromJson(Map<String, dynamic> json) {
    return LedgerEntry(
      account: json['account'] ?? '',
      debit: (json['debit'] as num?)?.toDouble() ?? 0.0,
      credit: (json['credit'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
