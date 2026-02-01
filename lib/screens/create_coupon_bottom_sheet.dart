import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/services/store_owner_api_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CreateCouponBottomSheet extends StatefulWidget {
  final String storeId;

  const CreateCouponBottomSheet({super.key, required this.storeId});

  @override
  State<CreateCouponBottomSheet> createState() =>
      _CreateCouponBottomSheetState();
}

class _CreateCouponBottomSheetState extends State<CreateCouponBottomSheet> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _expiryDateController = TextEditingController();
  final TextEditingController _discountAmountController =
      TextEditingController();
  final TextEditingController _minAmountController = TextEditingController();
  final TextEditingController _maxDiscountController = TextEditingController();
  final TextEditingController _maxAmountController = TextEditingController();
  final TextEditingController _usageLimitController = TextEditingController();
  final TextEditingController _userLimitController = TextEditingController();
  final TextEditingController _itemLimitController = TextEditingController();

  // State
  String _discountType = 'fixed'; // 'fixed' or 'percentage'
  DateTime? _selectedExpiryDate;
  bool _individualUseOnly = false;
  bool _offerFreeShipping = false;
  bool _isUniversal = false;

  @override
  void dispose() {
    _codeController.dispose();
    _descriptionController.dispose();
    _expiryDateController.dispose();
    _discountAmountController.dispose();
    _minAmountController.dispose();
    _maxDiscountController.dispose();
    _maxAmountController.dispose();
    _usageLimitController.dispose();
    _userLimitController.dispose();
    _itemLimitController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6366F1), // Indigo
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedExpiryDate) {
      setState(() {
        _selectedExpiryDate = picked;
        _expiryDateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 90% of screen height max, allowing scroll
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TranslatedText(
                      'Create New Coupon',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Fill in the details to create a new coupon',
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey[100],
                    foregroundColor: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: 24,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Basic Information ---
                    _buildSectionHeader('Basic Information'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            label: 'Coupon Code *',
                            controller: _codeController,
                            hint: 'WELCOME50',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            label: 'Expiry Date *',
                            controller: _expiryDateController,
                            hint: 'dd/mm/yyyy',
                            readOnly: true,
                            suffixIcon: Icons.calendar_today_outlined,
                            onTap: () => _selectDate(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Description *',
                      controller: _descriptionController,
                      hint: 'Get ₹50 off on your first order',
                      maxLines: 3,
                    ),

                    const SizedBox(height: 32),

                    // --- Discount Settings ---
                    _buildSectionHeader('Discount Settings'),
                    const SizedBox(height: 16),
                    const Text(
                      'Discount Type *',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          _buildToggleOption(
                            'Fixed Amount (₹)',
                            'fixed',
                            _discountType,
                          ),
                          _buildToggleOption(
                            'Percentage (%)',
                            'percentage',
                            _discountType,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Discount Amount *',
                      controller: _discountAmountController,
                      hint: '50',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // --- Amount Restrictions ---
                    _buildSectionHeader('Amount Restrictions'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            label: 'Min Amount (₹) *',
                            controller: _minAmountController,
                            hint: '500',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            label: 'Max Discount (₹) *',
                            controller: _maxDiscountController,
                            hint: '200',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            label: 'Max Amount (₹) *',
                            controller: _maxAmountController,
                            hint: '5000',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // --- Usage Limits ---
                    _buildSectionHeader('Usage Limits'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            label: 'Total Usage Limit *',
                            controller: _usageLimitController,
                            hint: '1000',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            label: 'Per User Limit *',
                            controller: _userLimitController,
                            hint: '5',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            label: 'Item Limit *',
                            controller: _itemLimitController,
                            hint: '3',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // --- Additional Options ---
                    _buildSectionHeader('Additional Options'),
                    const SizedBox(height: 16),
                    _buildCheckbox(
                      'Individual Use Only (cannot be combined with other coupons)',
                      _individualUseOnly,
                      (v) => setState(() => _individualUseOnly = v!),
                    ),
                    _buildCheckbox(
                      'Offer Free Shipping',
                      _offerFreeShipping,
                      (v) => setState(() => _offerFreeShipping = v!),
                    ),
                    _buildCheckbox(
                      'Universal Coupon (applies to all products)',
                      _isUniversal,
                      (v) => setState(() => _isUniversal = v!),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Buttons
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        foregroundColor: Colors.grey[700],
                        backgroundColor: const Color(0xFFF3F4F6),
                      ),
                      child: const TranslatedText(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          // Basic validation
                          if (_selectedExpiryDate == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: TranslatedText(
                                  'Please select expiry date',
                                ),
                              ),
                            );
                            return;
                          }

                          // Prepare data
                          final couponData = {
                            "coupon_code": _codeController.text,
                            "store_id": widget.storeId,
                            "img_url":
                                "https://res.cloudinary.com/anurupmillan/image/upload/v1766165284/coupon_o3tsoy.png", // Default image
                            "is_universal": _isUniversal,
                            "amount":
                                double.tryParse(
                                  _discountAmountController.text,
                                ) ??
                                0,
                            "is_percent_discount_type":
                                _discountType == 'percentage',
                            "is_amount_discount_type": _discountType == 'fixed',
                            "description": _descriptionController.text,
                            "expiry_timestamp":
                                (_selectedExpiryDate!.millisecondsSinceEpoch /
                                        1000)
                                    .round(),
                            "usage_count": 0,
                            "individual_use": _individualUseOnly,
                            "product_ids": [],
                            "excluded_product_ids": [],
                            "product_categories": [],
                            "excluded_product_categories": [],
                            "usage_limit":
                                int.tryParse(_usageLimitController.text) ?? 0,
                            "usage_limit_per_user":
                                int.tryParse(_userLimitController.text) ?? 0,
                            "limit_usage_to_x_items":
                                int.tryParse(_itemLimitController.text) ?? 0,
                            "free_shipping": _offerFreeShipping,
                            "minimum_amount":
                                double.tryParse(_minAmountController.text) ?? 0,
                            "maximum_discount_amount_limit":
                                double.tryParse(_maxDiscountController.text) ??
                                0,
                            "maximum_amount":
                                double.tryParse(_maxAmountController.text) ?? 0,
                          };

                          // Show loading indicator
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );

                          try {
                            final success =
                                await StoreOwnerApiService.createCoupon(
                                  couponData,
                                );

                            // Hide loading
                            Navigator.pop(context);

                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: TranslatedText(
                                    'Coupon Created Successfully',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              Navigator.pop(context, true); // Return success
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: TranslatedText(
                                    'Failed to create coupon',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } catch (e) {
                            // Hide loading
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: TranslatedText('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const TranslatedText(
                        'Create Coupon',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Color(0xFF111827),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    bool readOnly = false,
    IconData? suffixIcon,
    VoidCallback? onTap,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: IgnorePointer(
            ignoring: onTap != null,
            child: TextField(
              controller: controller,
              maxLines: maxLines,
              readOnly: readOnly,
              keyboardType: keyboardType,
              style: const TextStyle(fontSize: 15, color: Color(0xFF1F2937)),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF6366F1),
                    width: 1.5,
                  ),
                ),
                suffixIcon: suffixIcon != null
                    ? Icon(suffixIcon, color: Colors.grey[500], size: 20)
                    : null,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleOption(String title, String value, String currentValue) {
    final isSelected = value == currentValue;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _discountType = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[600],
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckbox(
    String label,
    bool value,
    ValueChanged<bool?> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 24,
            width: 24,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFF6366F1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
            ),
          ),
        ],
      ),
    );
  }
}
