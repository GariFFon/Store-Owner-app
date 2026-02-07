import 'package:flutter/material.dart';
import 'package:exanor/services/api_service.dart';
import 'dart:ui';
import 'dart:io';
import 'dart:math' as math;
import 'package:image_picker/image_picker.dart';
import 'package:exanor/screens/location_selection_screen.dart';

class CreateStoreScreen extends StatefulWidget {
  const CreateStoreScreen({super.key});

  @override
  State<CreateStoreScreen> createState() => _CreateStoreScreenState();
}

class _CreateStoreScreenState extends State<CreateStoreScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<dynamic> _categories = [];
  String? _selectedCategoryId;
  String? _errorMessage;

  // Steps
  final List<String> _stepTitles = [
    "Choose Category",
    "Basic Details",
    "Branding",
    "GST / Tax",
    "Review",
  ];

  int _currentStep = 0;

  // Controllers
  final _storeNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  // Address
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _localityController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _districtController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _countryController = TextEditingController();

  // Images
  XFile? _storeLogo;
  XFile? _storeBanner;
  final ImagePicker _picker = ImagePicker();

  // GST
  bool _showGSTForm = false;
  final _gstNumberController = TextEditingController();
  final _gstRegisteredStateController = TextEditingController();
  String _gstRegistrationType = 'Regular';
  bool _isTdsEnabled = false;
  bool _isOtherTerritory = false;
  String _gstr1Periodicity = 'Monthly';

  // Animation
  late AnimationController _fadeController;

  // Design Tokens
  final Color _primaryColor = const Color(0xFF2563EB); // Exchange Blue
  final Color _slate900 = const Color(0xFF0F172A);
  final Color _slate500 = const Color(0xFF64748B);
  final Color _slate200 = const Color(0xFFE2E8F0);
  final Color _bgLight = const Color(0xFFEFF6FF); // Light Blue BG

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _localityController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _districtController.dispose();
    _pincodeController.dispose();
    _countryController.dispose();
    _gstNumberController.dispose();
    _gstRegisteredStateController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    // ... Existing logic retained ...
    try {
      if (mounted) setState(() => _isLoading = true);
      final response = await ApiService.post(
        '/store-categories/',
        body: {"query": {}},
        useBearerToken: true,
      );
      if (response['statusCode'] == 200 &&
          response['data'] != null &&
          response['data']['response'] != null) {
        if (mounted) {
          setState(() {
            _categories = response['data']['response'] is List
                ? response['data']['response']
                : [];
            _isLoading = false;
          });
        }
      } else {
        _handleError('Failed to fetch categories');
      }
    } catch (e) {
      _handleError(e.toString());
    }
  }

  void _handleError(String msg) {
    if (mounted) setState(() => _errorMessage = msg);
  }

  Future<void> _pickImage(bool isLogo) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        if (isLogo)
          _storeLogo = image;
        else
          _storeBanner = image;
      });
    }
  }

  void _updateAddressFromResult(Map<String, dynamic> result) {
    _addressLine1Controller.text = result['addressLine1'] ?? '';
    _addressLine2Controller.text = result['addressLine2'] ?? '';
    _localityController.text = result['locality'] ?? '';
    _cityController.text = result['city'] ?? '';
    _stateController.text = result['state'] ?? '';
    _districtController.text = result['district'] ?? '';
    _pincodeController.text = result['pincode'] ?? '';
    _countryController.text = result['country'] ?? 'India';
  }

  // --- UI CONSTRUCTION ---

  @override
  Widget build(BuildContext context) {
    // Full screen scaffold
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Content Body (Scrollable)
          Positioned.fill(
            child: Column(
              children: [
                // Spacer for fixed header
                const SizedBox(height: 180),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 100),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      switchInCurve: Curves.easeOutQuart,
                      switchOutCurve: Curves.easeInQuart,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.04, 0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey(_currentStep),
                        child: _buildCurrentStepContent(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Premium Header (Fixed)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 180,
            child: _buildHeader(),
          ),

          // 3. Floating Bottom Action Bar
          Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomBar()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: _bgLight,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Watermark Icon
          Positioned(
            right: -20,
            top: -40,
            child: Transform.rotate(
              angle: -math.pi / 6,
              child: Icon(
                Icons.storefront_rounded,
                size: 200,
                color: _primaryColor.withOpacity(0.05),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Back Button & Step Indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: () {
                          if (_currentStep > 0)
                            setState(() => _currentStep--);
                          else
                            Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: _slate900,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "Step ${_currentStep + 1} of ${_stepTitles.length}",
                          style: TextStyle(
                            color: _primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Title
                  Text(
                    _stepTitles[_currentStep],
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: _slate900,
                      letterSpacing: -0.5,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (_currentStep + 1) / _stepTitles.length,
                      backgroundColor: Colors.white,
                      valueColor: AlwaysStoppedAnimation(_primaryColor),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                flex: 1,
                child: TextButton(
                  onPressed: () => setState(() => _currentStep--),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    "Back",
                    style: TextStyle(
                      color: _slate500,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _onNextPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  shadowColor: _primaryColor.withOpacity(0.4),
                  elevation: 8,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  _currentStep == 4 ? "Create Store" : "Continue",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- CONTENT SCREEN BUILDERS ---

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildCategoryStep();
      case 1:
        return _buildDetailsStep();
      case 2:
        return _buildBrandingStep();
      case 3:
        return _buildGSTStep();
      case 4:
        return _buildReviewStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCategoryStep() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: _primaryColor));
    }
    if (_errorMessage != null) {
      return Center(
        child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "What kind of store is this?",
          style: TextStyle(
            fontSize: 18,
            color: _slate500,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final count = constraints.maxWidth > 600 ? 4 : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: count,
                childAspectRatio: 0.85,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSel = _selectedCategoryId == cat['id'];

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSel ? _bgLight : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSel ? _primaryColor : _slate200,
                      width: isSel ? 2 : 1,
                    ),
                    boxShadow: isSel
                        ? [
                            BoxShadow(
                              color: _primaryColor.withOpacity(0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: InkWell(
                    onTap: () =>
                        setState(() => _selectedCategoryId = cat['id']),
                    borderRadius: BorderRadius.circular(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: cat['category_icon'] != null
                              ? Image.network(
                                  cat['category_icon'],
                                  width: 40,
                                  height: 40,
                                  errorBuilder: (_, __, ___) =>
                                      Icon(Icons.store, color: _primaryColor),
                                )
                              : Icon(
                                  Icons.store,
                                  size: 40,
                                  color: _primaryColor,
                                ),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            cat['category_name'] ?? 'Unknown',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSel
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: isSel ? _primaryColor : _slate900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Contact Info"),
        _buildTextField(
          label: "Store Name",
          controller: _storeNameController,
          icon: Icons.store_rounded,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          label: "Phone Number",
          controller: _phoneController,
          icon: Icons.phone_rounded,
          isNumber: true,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          label: "Email Address",
          controller: _emailController,
          icon: Icons.email_rounded,
          isEmail: true,
        ),
      ],
    );
  }

  Widget _buildBrandingStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Store Identity"),
        const SizedBox(height: 12),
        // Logos Stack
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildImageUploadTile(
                title: "Logo",
                subtitle: "1:1 Ratio",
                image: _storeLogo,
                isCircle: true,
                onTap: () => _pickImage(true),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: _buildImageUploadTile(
                title: "Cover Banner",
                subtitle: "16:9 Ratio",
                image: _storeBanner,
                isCircle: false,
                onTap: () => _pickImage(false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blueGrey[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.tips_and_updates_rounded, color: Colors.blueGrey[700]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Pro Tip: High-quality images increase customer trust by 40%.",
                  style: TextStyle(color: Colors.blueGrey[900], fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageUploadTile({
    required String title,
    required String subtitle,
    required XFile? image,
    required bool isCircle,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold, color: _slate900),
        ),
        Text(subtitle, style: TextStyle(fontSize: 12, color: _slate500)),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(isCircle ? 100 : 16),
          child: Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: isCircle ? null : BorderRadius.circular(16),
              border: Border.all(color: _slate200, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
              image: image != null
                  ? DecorationImage(
                      image: FileImage(File(image.path)),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: image == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_upload_rounded,
                        color: _primaryColor,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Upload",
                        style: TextStyle(
                          color: _primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
                      borderRadius: isCircle ? null : BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Icon(Icons.edit, color: Colors.white, size: 28),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildGSTStep() {
    if (!_showGSTForm) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _slate200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long_rounded, size: 64, color: _primaryColor),
              const SizedBox(height: 24),
              Text(
                "Do you have a GST Number?",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _slate900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Enable GST to unlock tax invoices and reports.",
                textAlign: TextAlign.center,
                style: TextStyle(color: _slate500, height: 1.5),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => setState(() => _showGSTForm = true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Yes, Add GST Details",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => setState(() => _currentStep++),
                child: Text(
                  "No, Skip for Now",
                  style: TextStyle(color: _slate500),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _buildSectionHeader("GST Configuration")),
            TextButton(
              onPressed: () => setState(() => _showGSTForm = false),
              child: const Text("Cancel"),
            ),
          ],
        ),
        _buildTextField(label: "GST Number", controller: _gstNumberController),
        const SizedBox(height: 16),
        _buildTextField(
          label: "Registered State",
          controller: _gstRegisteredStateController,
        ),

        const SizedBox(height: 24),
        Text(
          "Registration Type",
          style: TextStyle(fontWeight: FontWeight.bold, color: _slate900),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: _slate200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              RadioListTile<String>(
                title: const Text("Regular"),
                value: "Regular",
                groupValue: _gstRegistrationType,
                onChanged: (v) => setState(() => _gstRegistrationType = v!),
              ),
              const Divider(height: 1),
              RadioListTile<String>(
                title: const Text("Composite"),
                value: "Composite",
                groupValue: _gstRegistrationType,
                onChanged: (v) => setState(() => _gstRegistrationType = v!),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            "TDS Enabled",
            style: TextStyle(fontWeight: FontWeight.bold, color: _slate900),
          ),
          value: _isTdsEnabled,
          onChanged: (v) => setState(() => _isTdsEnabled = v),
          activeColor: _primaryColor,
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    return Column(
      children: [
        Icon(Icons.verified_rounded, size: 80, color: Colors.green),
        const SizedBox(height: 24),
        Text(
          "You're almost done!",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _slate900,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "Review your details before creating the store.",
          textAlign: TextAlign.center,
          style: TextStyle(color: _slate500),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _bgLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _primaryColor.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              _buildReviewRow("Store Name", _storeNameController.text),
              const Divider(),
              _buildReviewRow(
                "Category",
                _categories.firstWhere(
                  (e) => e['id'] == _selectedCategoryId,
                  orElse: () => {'category_name': 'Unknown'},
                )['category_name'],
              ),
              const Divider(),
              _buildReviewRow("Phone", _phoneController.text),
              const Divider(),
              _buildReviewRow(
                "GST",
                _showGSTForm ? _gstNumberController.text : "Not Provided",
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: _slate500)),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: _slate900),
          ),
        ],
      ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: _slate900,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    IconData? icon,
    bool isNumber = false,
    bool isEmail = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _slate900,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: isNumber
              ? TextInputType.phone
              : isEmail
              ? TextInputType.emailAddress
              : TextInputType.text,
          style: TextStyle(color: _slate900, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            prefixIcon: icon != null
                ? Icon(icon, color: _slate500, size: 22)
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _slate200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _slate200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _primaryColor, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  void _onNextPressed() async {
    // 1. Validation
    if (_currentStep == 0 && _selectedCategoryId == null) {
      _showSnack("Please select a category first.");
      return;
    }
    if (_currentStep == 1) {
      if (_storeNameController.text.isEmpty || _phoneController.text.isEmpty) {
        _showSnack("Please fill required details.");
        return;
      }
    }

    // 2. Logic Jumping
    if (_currentStep == 2) {
      // Branding -> Map -> GST
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (c) =>
              const LocationSelectionScreen(isStoreCreationMode: true),
        ),
      );
      if (result != null && result is Map<String, dynamic>) {
        setState(() {
          _updateAddressFromResult(result);
          _currentStep++;
        });
      }
      return;
    }

    if (_currentStep == 4) {
      // Submit
      _showSnack("Creating your store...");
      // Add submission logic
    } else {
      if (_currentStep < _stepTitles.length - 1) {
        setState(() => _currentStep++);
      }
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _slate900,
      ),
    );
  }
}
