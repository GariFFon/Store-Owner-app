import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/models/coupon.dart';
import 'package:exanor/services/store_owner_api_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EditCouponBottomSheet extends StatefulWidget {
  final Coupon coupon;

  const EditCouponBottomSheet({super.key, required this.coupon});

  @override
  State<EditCouponBottomSheet> createState() => _EditCouponBottomSheetState();
}

class _EditCouponBottomSheetState extends State<EditCouponBottomSheet> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late final TextEditingController _codeController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _expiryDateController;
  late final TextEditingController _discountAmountController;
  late final TextEditingController _minAmountController;
  late final TextEditingController _maxDiscountController;
  late final TextEditingController _maxAmountController;
  late final TextEditingController _usageLimitController;
  late final TextEditingController _userLimitController;
  late final TextEditingController _itemLimitController;

  // State
  String _discountType = 'fixed'; // 'fixed' or 'percentage'
  DateTime? _selectedExpiryDate;
  bool _individualUseOnly = false;
  bool _offerFreeShipping = false;
  bool _isUniversal = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    final coupon = widget.coupon;

    // Initialize controllers with existing coupon data
    _codeController = TextEditingController(text: coupon.couponCode);
    _descriptionController = TextEditingController(text: coupon.description);

    // Convert timestamp to DateTime
    _selectedExpiryDate = DateTime.fromMillisecondsSinceEpoch(
      coupon.expiryTimestamp * 1000,
    );
    _expiryDateController = TextEditingController(
      text: DateFormat('dd/MM/yyyy').format(_selectedExpiryDate!),
    );

    _discountAmountController = TextEditingController(
      text: coupon.amount.toStringAsFixed(2),
    );
    _minAmountController = TextEditingController(
      text: coupon.minimumAmount.toStringAsFixed(2),
    );
    _maxDiscountController = TextEditingController(
      text: coupon.maximumDiscountAmountLimit.toStringAsFixed(2),
    );
    // Max amount is not in the model, so we'll use a default
    _maxAmountController = TextEditingController(text: '5000');
    _usageLimitController = TextEditingController(text: '1000');
    _userLimitController = TextEditingController(text: '5');
    _itemLimitController = TextEditingController(text: '3');

    // Set state values
    _offerFreeShipping = coupon.freeShipping;
    _isUniversal = coupon.isUniversal;
  }

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
      initialDate:
          _selectedExpiryDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6366F1),
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

  Future<void> _updateCoupon() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedExpiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TranslatedText('Please select expiry date')),
      );
      return;
    }

    // Prepare data matching the required payload format
    final updateData = {
      "coupon_code": _codeController.text,
      "amount": double.tryParse(_discountAmountController.text) ?? 0,
      "description": _descriptionController.text,
      "expiry_timestamp": (_selectedExpiryDate!.millisecondsSinceEpoch / 1000)
          .round(),
      "minimum_amount": double.tryParse(_minAmountController.text) ?? 0,
      "maximum_discount_amount_limit":
          double.tryParse(_maxDiscountController.text) ?? 0,
      "free_shipping": _offerFreeShipping,
      "is_universal": _isUniversal,
    };

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final success = await StoreOwnerApiService.updateCoupon(
        couponId: widget.coupon.id,
        data: updateData,
      );

      // Hide loading
      if (mounted) Navigator.pop(context);

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: TranslatedText('Coupon Updated Successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true); // Return success
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: TranslatedText('Failed to update coupon'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Hide loading
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: TranslatedText('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TranslatedText(
                        'Edit Coupon',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Update coupon details',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
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
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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
                    LayoutBuilder(
                      builder: (context, constraints) {
                        // Use column layout for smaller screens
                        if (constraints.maxWidth < 400) {
                          return Column(
                            children: [
                              _buildTextField(
                                label: 'Min Amount (₹) *',
                                controller: _minAmountController,
                                hint: '500',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                label: 'Max Discount (₹) *',
                                controller: _maxDiscountController,
                                hint: '200',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                label: 'Max Amount (₹) *',
                                controller: _maxAmountController,
                                hint: '5000',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                label: 'Min Amount (₹) *',
                                controller: _minAmountController,
                                hint: '500',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                label: 'Max Discount (₹) *',
                                controller: _maxDiscountController,
                                hint: '200',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                label: 'Max Amount (₹) *',
                                controller: _maxAmountController,
                                hint: '5000',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 32),

                    // --- Usage Limits ---
                    _buildSectionHeader('Usage Limits'),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 400) {
                          return Column(
                            children: [
                              _buildTextField(
                                label: 'Total Usage Limit *',
                                controller: _usageLimitController,
                                hint: '1000',
                                keyboardType: TextInputType.number,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                label: 'Per User Limit *',
                                controller: _userLimitController,
                                hint: '5',
                                keyboardType: TextInputType.number,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                label: 'Item Limit *',
                                controller: _itemLimitController,
                                hint: '3',
                                keyboardType: TextInputType.number,
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                label: 'Total Usage Limit *',
                                controller: _usageLimitController,
                                hint: '1000',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                label: 'Per User Limit *',
                                controller: _userLimitController,
                                hint: '5',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                label: 'Item Limit *',
                                controller: _itemLimitController,
                                hint: '3',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        );
                      },
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

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Buttons
          Container(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 16,
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
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
            child: SafeArea(
              top: false,
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
                        onPressed: _updateCoupon,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const TranslatedText(
                          'Update Coupon',
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
