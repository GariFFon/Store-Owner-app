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
  final _categorySearchController = TextEditingController();

  // Images
  XFile? _storeLogo;
  XFile? _storeBanner;
  final ImagePicker _picker = ImagePicker();

  // GST
  bool _showGSTForm = false;
  final _gstNumberController = TextEditingController();
  final _gstRegisteredStateController =
      TextEditingController(); // Keep for compatibility if needed, but we'll use _selectedState
  String? _selectedState;
  final List<String> _states = [
    "Andhra Pradesh",
    "Arunachal Pradesh",
    "Assam",
    "Bihar",
    "Chhattisgarh",
    "Goa",
    "Gujarat",
    "Haryana",
    "Himachal Pradesh",
    "Jharkhand",
    "Karnataka",
    "Kerala",
    "Madhya Pradesh",
    "Maharashtra",
    "Manipur",
    "Meghalaya",
    "Mizoram",
    "Nagaland",
    "Odisha",
    "Punjab",
    "Rajasthan",
    "Sikkim",
    "Tamil Nadu",
    "Telangana",
    "Tripura",
    "Uttar Pradesh",
    "Uttarakhand",
    "West Bengal",
    "Andaman and Nicobar Islands",
    "Chandigarh",
    "Dadra and Nagar Haveli and Daman and Diu",
    "Delhi",
    "Jammu and Kashmir",
    "Ladakh",
    "Lakshadweep",
    "Puducherry",
  ];
  String _gstRegistrationType = 'Regular';
  bool _isTdsEnabled = false;
  String? _gstr1Periodicity = 'Monthly';

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
    _categorySearchController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: KeyedSubtree(
                key: ValueKey(_currentStep),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                  child: _buildCurrentStepContent(),
                ),
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF), // Light Blue like Order Screen
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF94A3B8).withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRect(
        child: Stack(
          children: [
            // Watermark
            Positioned(
              right: -30,
              top: -10,
              child: Transform.rotate(
                angle: -math.pi / 6,
                child: Icon(
                  Icons.storefront_rounded,
                  size: 180,
                  color: const Color(0xFFDBEAFE).withOpacity(0.6),
                ),
              ),
            ),

            // Content
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Row
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
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.blueGrey.withOpacity(0.5),
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 20,
                              color: Colors.blueGrey,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            "STEP ${_currentStep + 1}/${_stepTitles.length}",
                            style: const TextStyle(
                              color: Color(0xFF1565C0),
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _stepTitles[_currentStep],
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                        letterSpacing: -0.5,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Progress Bar
                    Stack(
                      children: [
                        Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 4,
                          width:
                              MediaQuery.of(context).size.width *
                              ((_currentStep + 1) / _stepTitles.length),
                          decoration: BoxDecoration(
                            color: _primaryColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
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
                  child: Text(
                    "Back",
                    style: TextStyle(
                      color: _slate500,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Container(
                height: 48, // More compact height
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primaryColor, const Color(0xFF1D4ED8)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryColor.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _onNextPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(
                    _currentStep == 4 ? "Create Store" : "Continue",
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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

    final filteredCategories = _categories.where((cat) {
      final name = (cat['category_name'] ?? '').toString().toLowerCase();
      final query = _categorySearchController.text.toLowerCase();
      return name.contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "What's your niche?",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: _slate900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Select the category that best fits your business.",
          style: TextStyle(fontSize: 14, color: _slate500),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _categorySearchController,
          onChanged: (value) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Search categories...',
            prefixIcon: Icon(Icons.search_rounded, color: _slate500),
            filled: true,
            fillColor: Colors.white,
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
              borderSide: BorderSide(color: _primaryColor, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
        const SizedBox(height: 12), // Reduced spacing from 24 to 12
        if (filteredCategories.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                "No categories found",
                style: TextStyle(color: _slate500),
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              // 3 cols on phone (Standard), 6 on tablet
              final crossAxisCount = constraints.maxWidth > 600 ? 6 : 3;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: 0.9, // Taller for cleaner look
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: filteredCategories.length,
                itemBuilder: (context, index) {
                  final cat = filteredCategories[index];
                  final isSel = _selectedCategoryId == cat['id'];

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      color: isSel ? _primaryColor : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSel ? _primaryColor : _slate200,
                        width: isSel ? 0 : 1.5, // Thicker border for unselected
                      ),
                      boxShadow: isSel
                          ? [
                              BoxShadow(
                                color: _primaryColor.withOpacity(0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 2,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: () =>
                            setState(() => _selectedCategoryId = cat['id']),
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          children: [
                            if (isSel)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.25),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Center(
                                      child: cat['category_icon'] != null
                                          ? Image.network(
                                              cat['category_icon'],
                                              fit: BoxFit.contain,
                                              height: 54, // Larger icon
                                              width: 54,
                                              // NO color filter here, keeping original colors
                                              errorBuilder: (_, __, ___) =>
                                                  Icon(
                                                    Icons.store_rounded,
                                                    color: isSel
                                                        ? Colors.white
                                                        : _slate500,
                                                    size: 40,
                                                  ),
                                            )
                                          : Icon(
                                              Icons.store_rounded,
                                              color: isSel
                                                  ? Colors.white
                                                  : _slate500,
                                              size: 40,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    flex: 2,
                                    child: Align(
                                      alignment: Alignment.center,
                                      child: Text(
                                        cat['category_name'] ?? 'General',
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isSel
                                              ? FontWeight.w700
                                              : FontWeight.w600,
                                          color: isSel
                                              ? Colors.white
                                              : _slate900,
                                          height: 1.1,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _slate200),
          ),
          child: Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: _primaryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Pro Tip: High-quality images increase customer trust significanty.",
                  style: TextStyle(
                    color: _slate500,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
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
          style: TextStyle(fontWeight: FontWeight.w600, color: _slate900),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(isCircle ? 100 : 12),
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: isCircle ? null : BorderRadius.circular(12),
              border: Border.all(
                color: _slate200,
                width: 1.5,
                style: BorderStyle.solid,
              ),
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
                        Icons.add_photo_alternate_rounded,
                        color: _primaryColor,
                        size: 28,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Upload",
                        style: TextStyle(
                          color: _primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : null,
          ),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(fontSize: 11, color: _slate500)),
      ],
    );
  }

  Widget _buildGSTStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Tax Information"),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _slate200),
          ),
          child: SwitchListTile(
            title: Text(
              "I have a GST Number",
              style: TextStyle(fontWeight: FontWeight.w600, color: _slate900),
            ),
            subtitle: Text(
              "Enable if your business is registered for GST",
              style: TextStyle(fontSize: 12, color: _slate500),
            ),
            value: _showGSTForm,
            activeColor: _primaryColor,
            onChanged: (val) => setState(() => _showGSTForm = val),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        if (_showGSTForm) ...[
          const SizedBox(height: 24),
          _buildTextField(
            label: "GST Number",
            controller: _gstNumberController,
          ),
          const SizedBox(height: 16),
          // State Dropdown
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Registered State",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _slate500,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _slate200),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedState,
                    hint: Text(
                      "Select State",
                      style: TextStyle(color: _slate500),
                    ),
                    isExpanded: true,
                    icon: Icon(Icons.arrow_drop_down_rounded, color: _slate500),
                    items: _states.map((String state) {
                      return DropdownMenuItem<String>(
                        value: state,
                        child: Text(state, style: TextStyle(color: _slate900)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedState = val;
                        _gstRegisteredStateController.text = val ?? '';
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Review Details"),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _slate200),
          ),
          child: Column(
            children: [
              _buildReviewRow("Store Name", _storeNameController.text),
              const Divider(),
              _buildReviewRow(
                "Category",
                _categories.firstWhere(
                  (c) => c['id'] == _selectedCategoryId,
                  orElse: () => {'category_name': 'Unknown'},
                )['category_name'],
              ),
              const Divider(),
              _buildReviewRow("Phone", _phoneController.text),
              const Divider(),
              _buildReviewRow("Email", _emailController.text),
              const Divider(),
              _buildReviewRow(
                "GST",
                _showGSTForm ? _gstNumberController.text : "Not Provided",
              ),
              if (_showGSTForm) ...[
                const Divider(),
                _buildReviewRow("State", _gstRegisteredStateController.text),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: _slate500, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: _slate900,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
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
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _slate500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: isNumber
              ? TextInputType.phone
              : (isEmail ? TextInputType.emailAddress : TextInputType.text),
          decoration: InputDecoration(
            hintText: "Enter $label",
            prefixIcon: icon != null
                ? Icon(icon, size: 20, color: _slate500)
                : null,
            filled: true,
            fillColor: Colors.white,
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
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  void _onNextPressed() async {
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

    if (_currentStep == 2) {
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
      _showSnack("Creating your store...");
      // Logic to submit
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
