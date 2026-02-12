import 'package:flutter/material.dart';
import 'package:exanor/services/api_service.dart';
import 'dart:ui';
import 'dart:io';
import 'dart:math' as math;
import 'package:image_picker/image_picker.dart';
import 'package:exanor/screens/location_selection_screen.dart';
import 'package:google_fonts/google_fonts.dart';

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
    const lightBlueBg = Color(0xFFEFF6FF);
    const watermarkColor = Color(0xFFDBEAFE);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: lightBlueBg,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF94A3B8).withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRect(
        child: Stack(
          children: [
            // Watermark
            Positioned(
              right: -20,
              top: -10,
              child: Transform.rotate(
                angle: -math.pi / 6,
                child: Icon(
                  Icons.storefront_rounded,
                  size: 160,
                  color: watermarkColor.withOpacity(0.8),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Back Button
                        InkWell(
                          onTap: () {
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
                            child: const Center(
                              child: Padding(
                                padding: EdgeInsets.only(right: 2),
                                child: Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Colors.blueGrey,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Create Store",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1E293B),
                                  letterSpacing: -0.5,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF2563EB,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'STEP ${_currentStep + 1} OF ${_stepTitles.length}: ${_stepTitles[_currentStep].toUpperCase()}',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF2563EB),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Progress Line at bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LinearProgressIndicator(
                value: (_currentStep + 1) / _stepTitles.length,
                backgroundColor: Colors.transparent,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF2563EB),
                ),
                minHeight: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
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
            if (_currentStep > 0)
              TextButton(
                onPressed: () => setState(() => _currentStep--),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  "Back",
                  style: GoogleFonts.inter(
                    color: _slate500,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primaryColor, const Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: _onNextPressed,
                    borderRadius: BorderRadius.circular(12),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentStep == 4 ? "Complete Setup" : "Continue",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ],
                      ),
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _primaryColor, strokeWidth: 3),
            const SizedBox(height: 16),
            Text(
              "Loading Categories...",
              style: GoogleFonts.inter(
                color: _slate500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.red[300], size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: GoogleFonts.inter(color: Colors.red[700]),
            ),
          ],
        ),
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
          style: GoogleFonts.plusJakartaSans(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: _slate900,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Select the category that best represents your business to get started.",
          style: GoogleFonts.inter(fontSize: 15, color: _slate500, height: 1.5),
        ),
        const SizedBox(height: 24), // Reduced from 32 to 24
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF64748B).withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: _categorySearchController,
            onChanged: (value) => setState(() {}),
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: 'Search categories...',
              hintStyle: GoogleFonts.inter(color: _slate500.withOpacity(0.7)),
              prefixIcon: Icon(Icons.search_rounded, color: _slate500),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: _primaryColor.withOpacity(0.5),
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (filteredCategories.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Column(
                children: [
                  Icon(Icons.search_off_rounded, size: 48, color: _slate200),
                  const SizedBox(height: 16),
                  Text(
                    "No categories found",
                    style: GoogleFonts.inter(
                      color: _slate500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.1,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: filteredCategories.length,
            itemBuilder: (context, index) {
              final cat = filteredCategories[index];
              final isSel = _selectedCategoryId == cat['id'];

              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.fastOutSlowIn,
                decoration: BoxDecoration(
                  color: isSel ? _primaryColor : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSel ? _primaryColor : Colors.transparent,
                    width: isSel ? 0 : 0,
                  ),
                  boxShadow: isSel
                      ? [
                          BoxShadow(
                            color: _primaryColor.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: const Color(0xFF64748B).withOpacity(0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () =>
                        setState(() => _selectedCategoryId = cat['id']),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? Colors.white.withOpacity(0.2)
                                  : _bgLight,
                              shape: BoxShape.circle,
                            ),
                            child: cat['category_icon'] != null
                                ? Image.network(
                                    cat['category_icon'],
                                    width: 32,
                                    height: 32,
                                    errorBuilder: (_, __, ___) => Icon(
                                      Icons.store_rounded,
                                      color: isSel
                                          ? Colors.white
                                          : _primaryColor,
                                      size: 32,
                                    ),
                                  )
                                : Icon(
                                    Icons.store_rounded,
                                    color: isSel ? Colors.white : _primaryColor,
                                    size: 32,
                                  ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            cat['category_name'] ?? 'General',
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: isSel
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: isSel ? Colors.white : _slate900,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
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
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: _slate900,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(isCircle ? 100 : 16),
          child: CustomPaint(
            painter: _DashedBorderPainter(
              color: _primaryColor.withOpacity(0.5),
              strokeWidth: 2,
              radius: isCircle ? 100 : 16,
              shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
            ),
            child: Container(
              height: isCircle ? 100 : 120, // Reduced height for Logo (Circle)
              width: double.infinity,
              decoration: BoxDecoration(
                color: _bgLight.withOpacity(0.5),
                shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: isCircle ? null : BorderRadius.circular(16),
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
                        const SizedBox(height: 8),
                        Text(
                          "Click to Upload",
                          style: GoogleFonts.inter(
                            color: _primaryColor,
                            fontSize: isCircle ? 10 : 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: _slate500,
            fontWeight: FontWeight.w500,
          ),
        ),
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
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF64748B).withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedState,
                    hint: Text(
                      "Select State",
                      style: GoogleFonts.inter(
                        color: _slate500.withOpacity(0.6),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    isExpanded: true,
                    isDense: true,
                    menuMaxHeight: 300,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _slate500,
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: _slate900,
                    ),
                    items: _states.map((String state) {
                      return DropdownMenuItem<String>(
                        value: state,
                        child: Text(state),
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
      padding: const EdgeInsets.only(bottom: 20),
      child: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: _slate900,
          letterSpacing: -0.5,
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
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _slate900,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF64748B).withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: isNumber
                ? TextInputType.phone
                : (isEmail ? TextInputType.emailAddress : TextInputType.text),
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: _slate900,
            ),
            decoration: InputDecoration(
              hintText: "Enter $label",
              hintStyle: GoogleFonts.inter(
                color: _slate500.withOpacity(0.6),
                fontSize: 15,
              ),
              prefixIcon: icon != null
                  ? Icon(icon, size: 20, color: _slate500)
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: _primaryColor, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(18),
            ),
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
      if (_phoneController.text.length != 10) {
        _showSnack("Phone number must be exactly 10 digits.");
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

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;
  final BoxShape shape;

  _DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1,
    this.radius = 0,
    this.shape = BoxShape.rectangle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (strokeWidth <= 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    Path path;
    if (shape == BoxShape.circle) {
      path = Path()..addOval(Rect.fromLTWH(0, 0, size.width, size.height));
    } else {
      path = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 0, size.width, size.height),
            Radius.circular(radius),
          ),
        );
    }

    final dashPath = _dashPath(
      path,
      dashArray: CircularIntervalList<double>([8, 4]),
    );
    canvas.drawPath(dashPath, paint);
  }

  Path _dashPath(
    Path source, {
    required CircularIntervalList<double> dashArray,
  }) {
    final Path dest = Path();
    for (final PathMetric metric in source.computeMetrics()) {
      double distance = 0.0;
      bool draw = true;
      while (distance < metric.length) {
        final double len = dashArray.next;
        if (draw) {
          dest.addPath(
            metric.extractPath(distance, distance + len),
            Offset.zero,
          );
        }
        distance += len;
        draw = !draw;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.radius != radius ||
        oldDelegate.shape != shape;
  }
}

class CircularIntervalList<T> {
  final List<T> _values;
  int _index = 0;

  CircularIntervalList(this._values);

  T get next {
    if (_index >= _values.length) {
      _index = 0;
    }
    return _values[_index++];
  }
}
