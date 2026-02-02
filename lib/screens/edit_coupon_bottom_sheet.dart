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

class _EditCouponBottomSheetState extends State<EditCouponBottomSheet>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;

  // Controllers
  late final TextEditingController _codeController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _expiryDateController;
  late final TextEditingController _discountAmountController;
  late final TextEditingController _minAmountController;
  late final TextEditingController _maxDiscountController;
  late final TextEditingController _usageLimitController;
  late final TextEditingController _userLimitController;

  // State
  String _discountType = 'fixed';
  DateTime? _selectedExpiryDate;
  bool _individualUseOnly = false;
  bool _offerFreeShipping = false;
  bool _isUniversal = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeControllers();

    _codeController.addListener(() => setState(() {}));
    _discountAmountController.addListener(() => setState(() {}));
    _minAmountController.addListener(() => setState(() {}));
  }

  void _initializeControllers() {
    final coupon = widget.coupon;
    _codeController = TextEditingController(text: coupon.couponCode);
    _descriptionController = TextEditingController(text: coupon.description);
    _selectedExpiryDate = DateTime.fromMillisecondsSinceEpoch(
      coupon.expiryTimestamp * 1000,
    );
    _expiryDateController = TextEditingController(
      text: DateFormat('dd MMM yyyy').format(_selectedExpiryDate!),
    );
    _discountAmountController = TextEditingController(
      text: coupon.amount.toStringAsFixed(0),
    );
    _minAmountController = TextEditingController(
      text: coupon.minimumAmount.toStringAsFixed(0),
    );
    _maxDiscountController = TextEditingController(
      text: coupon.maximumDiscountAmountLimit.toStringAsFixed(0),
    );
    _usageLimitController = TextEditingController(text: '1000');
    _userLimitController = TextEditingController(text: '5');
    _offerFreeShipping = coupon.freeShipping;
    _isUniversal = coupon.isUniversal;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codeController.dispose();
    _descriptionController.dispose();
    _expiryDateController.dispose();
    _discountAmountController.dispose();
    _minAmountController.dispose();
    _maxDiscountController.dispose();
    _usageLimitController.dispose();
    _userLimitController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedExpiryDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF3B82F6)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedExpiryDate = picked;
        _expiryDateController.text = DateFormat('dd MMM yyyy').format(picked);
      });
    }
  }

  Future<void> _updateCoupon() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedExpiryDate == null) return;

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
      if (mounted) {
        Navigator.pop(context);
        if (success) {
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: TranslatedText('Failed to update')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          _buildHeader(),

          const SizedBox(height: 12),

          // Coupon Preview Card
          _buildCouponPreview(),

          const SizedBox(height: 16),

          // Tab Bar
          _buildTabBar(),

          const SizedBox(height: 4),

          // Tab Content
          Expanded(
            child: Form(
              key: _formKey,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildGeneralTab(),
                  _buildRulesTab(),
                  _buildLimitsTab(),
                ],
              ),
            ),
          ),

          // Save Button
          _buildSaveButton(),
        ],
      ),
    );
  }

  // ============== HEADER ==============
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.edit_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),

          // Title & Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Edit Coupon',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Update your coupon details',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),

          // Close Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.close_rounded,
                  color: Colors.grey[600],
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============== COUPON PREVIEW ==============
  Widget _buildCouponPreview() {
    final isExpired = _selectedExpiryDate?.isBefore(DateTime.now()) ?? false;
    final code = _codeController.text.isEmpty ? 'CODE' : _codeController.text;
    final amount = _discountAmountController.text.isEmpty
        ? '0'
        : _discountAmountController.text;
    final minSpend = _minAmountController.text.isEmpty
        ? '0'
        : _minAmountController.text;
    final expiryText = _selectedExpiryDate != null
        ? DateFormat('dd MMM yyyy').format(_selectedExpiryDate!)
        : 'Not set';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Code + Status
          Row(
            children: [
              // Coupon Code
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.confirmation_number_rounded,
                        size: 18,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          code,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isExpired
                      ? const Color(0xFFFEE2E2)
                      : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isExpired
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF22C55E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isExpired ? 'Expired' : 'Active',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isExpired
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Discount Amount
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹$amount',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  'OFF',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Bottom Info Row
          Row(
            children: [
              // Min Spend
              _buildInfoChip(
                icon: Icons.shopping_cart_outlined,
                label: 'Min ₹$minSpend',
              ),
              const SizedBox(width: 10),

              // Expiry
              _buildInfoChip(
                icon: Icons.event_outlined,
                label: expiryText,
                isWarning: isExpired,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    bool isWarning = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isWarning ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isWarning
                ? const Color(0xFFD97706)
                : const Color(0xFF64748B),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isWarning
                  ? const Color(0xFFB45309)
                  : const Color(0xFF475569),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ============== TAB BAR ==============
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: const Color(0xFF0F172A),
        unselectedLabelColor: const Color(0xFF64748B),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        labelPadding: EdgeInsets.zero,
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.tune_rounded, size: 16),
                SizedBox(width: 6),
                Text('General'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.rule_rounded, size: 16),
                SizedBox(width: 6),
                Text('Rules'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.speed_rounded, size: 16),
                SizedBox(width: 6),
                Text('Limits'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============== GENERAL TAB ==============
  Widget _buildGeneralTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        // Section: Basic Details
        _buildSectionTitle('Basic Details'),
        const SizedBox(height: 12),

        _buildTextField(
          label: 'Coupon Code',
          controller: _codeController,
          icon: Icons.local_offer_rounded,
          hint: 'e.g. SAVE50',
        ),

        const SizedBox(height: 14),

        _buildTextField(
          label: 'Expiry Date',
          controller: _expiryDateController,
          icon: Icons.calendar_today_rounded,
          readOnly: true,
          onTap: () => _selectDate(context),
          suffixIcon: Icons.arrow_drop_down_rounded,
        ),

        const SizedBox(height: 14),

        _buildTextField(
          label: 'Description',
          controller: _descriptionController,
          icon: Icons.notes_rounded,
          hint: 'What does this coupon offer?',
          maxLines: 3,
        ),

        const SizedBox(height: 24),

        // Section: Options
        _buildSectionTitle('Options'),
        const SizedBox(height: 12),

        _buildToggleOption(
          icon: Icons.local_shipping_rounded,
          title: 'Free Shipping',
          subtitle: 'Waive delivery charges with this coupon',
          value: _offerFreeShipping,
          onChanged: (v) => setState(() => _offerFreeShipping = v),
        ),

        const SizedBox(height: 10),

        _buildToggleOption(
          icon: Icons.public_rounded,
          title: 'Universal Coupon',
          subtitle: 'Applies to all products in store',
          value: _isUniversal,
          onChanged: (v) => setState(() => _isUniversal = v),
        ),

        const SizedBox(height: 60),
      ],
    );
  }

  // ============== RULES TAB ==============
  Widget _buildRulesTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        // Section: Discount Type
        _buildSectionTitle('Discount Type'),
        const SizedBox(height: 12),

        // Segmented Control for discount type
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              _buildSegmentButton(
                icon: Icons.currency_rupee_rounded,
                label: 'Fixed Amount',
                value: 'fixed',
              ),
              const SizedBox(width: 4),
              _buildSegmentButton(
                icon: Icons.percent_rounded,
                label: 'Percentage',
                value: 'percentage',
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Section: Discount Value
        _buildSectionTitle('Discount Value'),
        const SizedBox(height: 12),

        _buildTextField(
          label: _discountType == 'fixed' ? 'Amount (₹)' : 'Percentage (%)',
          controller: _discountAmountController,
          icon: _discountType == 'fixed'
              ? Icons.currency_rupee_rounded
              : Icons.percent_rounded,
          hint: _discountType == 'fixed' ? 'e.g. 100' : 'e.g. 15',
          keyboardType: TextInputType.number,
        ),

        const SizedBox(height: 20),

        // Section: Spending Rules
        _buildSectionTitle('Spending Rules'),
        const SizedBox(height: 4),
        Text(
          'Set minimum order value and maximum discount cap',
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _buildCompactField(
                label: 'Min Order',
                controller: _minAmountController,
                prefix: '₹',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCompactField(
                label: 'Max Discount',
                controller: _maxDiscountController,
                prefix: '₹',
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Info Box
        _buildInfoBox(
          icon: Icons.lightbulb_outline_rounded,
          title: 'How it works',
          description:
              'Customer must spend at least the minimum amount to use this coupon. The discount will be capped at the maximum value.',
        ),

        const SizedBox(height: 60),
      ],
    );
  }

  // ============== LIMITS TAB ==============
  Widget _buildLimitsTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        // Section: Usage Limits
        _buildSectionTitle('Usage Limits'),
        const SizedBox(height: 4),
        Text(
          'Control how many times this coupon can be used',
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
        const SizedBox(height: 14),

        _buildTextField(
          label: 'Total Usage Limit',
          controller: _usageLimitController,
          icon: Icons.groups_rounded,
          hint: 'e.g. 1000',
          keyboardType: TextInputType.number,
          helperText: 'Maximum times this coupon can be redeemed overall',
        ),

        const SizedBox(height: 14),

        _buildTextField(
          label: 'Per User Limit',
          controller: _userLimitController,
          icon: Icons.person_rounded,
          hint: 'e.g. 1',
          keyboardType: TextInputType.number,
          helperText: 'How many times each customer can use this coupon',
        ),

        const SizedBox(height: 24),

        // Section: Restrictions
        _buildSectionTitle('Restrictions'),
        const SizedBox(height: 12),

        _buildToggleOption(
          icon: Icons.block_rounded,
          title: 'Individual Use Only',
          subtitle: 'Cannot be combined with other coupons',
          value: _individualUseOnly,
          onChanged: (v) => setState(() => _individualUseOnly = v),
        ),

        const SizedBox(height: 20),

        // Warning Box
        _buildInfoBox(
          icon: Icons.info_outline_rounded,
          title: 'Tip',
          description:
              'Setting strict limits prevents coupon abuse and protects your margins.',
          color: const Color(0xFFFEF3C7),
          iconColor: const Color(0xFFD97706),
        ),

        const SizedBox(height: 60),
      ],
    );
  }

  // ============== REUSABLE WIDGETS ==============

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Color(0xFF0F172A),
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? hint,
    bool readOnly = false,
    VoidCallback? onTap,
    int maxLines = 1,
    IconData? suffixIcon,
    TextInputType? keyboardType,
    String? helperText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label outside the container
        Row(
          children: [
            Icon(icon, size: 14, color: const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Input container
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: IgnorePointer(
              ignoring: onTap != null,
              child: TextFormField(
                controller: controller,
                readOnly: readOnly,
                maxLines: maxLines,
                keyboardType: keyboardType,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey[400],
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  suffixIcon: suffixIcon != null
                      ? Icon(suffixIcon, color: const Color(0xFF64748B))
                      : null,
                ),
                validator: (val) =>
                    val != null && val.isEmpty ? 'Required' : null,
              ),
            ),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              helperText,
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCompactField({
    required String label,
    required TextEditingController controller,
    String? prefix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label outside
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        // Input container
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              prefixText: prefix,
              prefixStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
            validator: (val) => val != null && val.isEmpty ? 'Required' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentButton({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final isSelected = _discountType == value;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _discountType = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? const Color(0xFF3B82F6)
                    : const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: value ? const Color(0xFFDBEAFE) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 20,
              color: value ? const Color(0xFF3B82F6) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFF3B82F6),
              activeTrackColor: const Color(0xFF93C5FD),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox({
    required IconData icon,
    required String title,
    required String description,
    Color color = const Color(0xFFEFF6FF),
    Color iconColor = const Color(0xFF3B82F6),
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: iconColor.withOpacity(0.8),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============== SAVE BUTTON ==============
  Widget _buildSaveButton() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: _updateCoupon,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B82F6).withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_rounded, color: Colors.white, size: 22),
              SizedBox(width: 10),
              Text(
                'Save Changes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
