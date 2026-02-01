class StoreBankDetails {
  final String id;
  final String storeId;
  final String accountTypeChoices;
  final String? bankName;
  final String accountNumberOrUpiId;
  final String? ifscCode;
  final String accountHolderName;
  final String accountHolderType;
  final String? accountHolderAddress;
  final String? accountHolderCity;
  final String? accountHolderState;
  final String? accountHolderCountry;
  final bool isDefault;
  final bool isActive;
  final bool isDeleted;
  final bool isVerified;
  final bool isBlocked;

  StoreBankDetails({
    required this.id,
    required this.storeId,
    required this.accountTypeChoices,
    this.bankName,
    required this.accountNumberOrUpiId,
    this.ifscCode,
    required this.accountHolderName,
    required this.accountHolderType,
    this.accountHolderAddress,
    this.accountHolderCity,
    this.accountHolderState,
    this.accountHolderCountry,
    required this.isDefault,
    required this.isActive,
    required this.isDeleted,
    required this.isVerified,
    required this.isBlocked,
  });

  factory StoreBankDetails.fromJson(Map<String, dynamic> json) {
    return StoreBankDetails(
      id: json['id'] ?? '',
      storeId: json['store_id'] ?? '',
      accountTypeChoices: json['account_type_choices'] ?? 'savings',
      bankName: json['bank_name'],
      accountNumberOrUpiId: json['account_number_or_upi_id'] ?? '',
      ifscCode: json['ifsc_code'],
      accountHolderName: json['account_holder_name'] ?? '',
      accountHolderType: json['account_holder_type'] ?? 'individual',
      accountHolderAddress: json['account_holder_address'],
      accountHolderCity: json['account_holder_city'],
      accountHolderState: json['account_holder_state'],
      accountHolderCountry: json['account_holder_country'],
      isDefault: json['is_default'] ?? false,
      isActive: json['is_active'] ?? true,
      isDeleted: json['is_deleted'] ?? false,
      isVerified: json['is_verified'] ?? false,
      isBlocked: json['is_blocked'] ?? false,
    );
  }
}
