import 'dart:async';
import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/services/store_owner_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:exanor/components/otp_input_section.dart';

class CreateStaffBottomSheet extends StatefulWidget {
  final String storeId;
  final List<Map<String, dynamic>> roles;

  const CreateStaffBottomSheet({
    super.key,
    required this.storeId,
    required this.roles,
  });

  @override
  State<CreateStaffBottomSheet> createState() => _CreateStaffBottomSheetState();
}

class _CreateStaffBottomSheetState extends State<CreateStaffBottomSheet>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;

  // Controllers
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();

  // State
  String? _selectedRoleId;
  String? _selectedRoleName;
  bool _isSubmitting = false;

  // Flow steps:
  // 0 = normal phone+role entry
  // 1 = OTP verification
  // 2 = name & details collection
  int _registrationStep = 0;
  String _formattedPhoneNumber = '';
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  bool _isRegistering = false;
  String? _failureMessage; // store the first failure message to show
  String? _newUserToken; // access token of the NEWLY registered user

  // OTP Resend timer
  int _resendTimer = 0;
  Timer? _resendTimerRef;
  bool _canResend = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _phoneController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _resendTimerRef?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _resendTimer = 60;
      _canResend = false;
    });
    _resendTimerRef?.cancel();
    _resendTimerRef = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendTimer > 0) {
        setState(() => _resendTimer--);
      } else {
        setState(() => _canResend = true);
        timer.cancel();
      }
    });
  }

  // ============== MAIN SUBMIT (Step 0) ==============
  // Try to add staff directly first. If it fails, start the OTP registration flow.
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedRoleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TranslatedText('Please select a role')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final phoneNumber = _phoneController.text.trim();
    _formattedPhoneNumber =
        phoneNumber.length == 10 ? '91$phoneNumber' : phoneNumber;

    try {
      final result = await StoreOwnerApiService.createStoreStaff(
        storeId: widget.storeId,
        phoneNumber: _formattedPhoneNumber,
        roleId: _selectedRoleId!,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        // Staff added successfully — done!
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: TranslatedText('Staff Member Added Successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        // Staff creation failed — start OTP registration flow
        _failureMessage = result['message']?.toString();
        setState(() {
          _registrationStep = 1;
          _isSubmitting = false;
        });
        _sendOtp();
      }
    } catch (e) {
      if (!mounted) return;
      // Any error → start OTP registration flow
      _failureMessage = e.toString();
      setState(() {
        _registrationStep = 1;
        _isSubmitting = false;
      });
      _sendOtp();
    }
  }

  // ============== SEND OTP ==============
  Future<void> _sendOtp() async {
    setState(() => _isSendingOtp = true);

    try {
      final response = await ApiService.post(
        '/send-otp/',
        body: {'phone_number': _formattedPhoneNumber},
      );

      if (!mounted) return;
      setState(() => _isSendingOtp = false);

      if (response['data'] != null && response['data']['status'] == 200) {
        _startResendTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OTP sent to +$_formattedPhoneNumber'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send OTP. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSendingOtp = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending OTP: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============== VERIFY OTP ==============
  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 4-digit OTP'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isVerifyingOtp = true);

    try {
      final response = await ApiService.post(
        '/sign-up/',
        body: {
          'phone_number': _formattedPhoneNumber,
          'otp': otp,
          'signup': true,
        },
      );

      if (!mounted) return;
      setState(() => _isVerifyingOtp = false);

      if (response['data'] != null && response['data']['status'] == 200) {
        // ✅ Capture the NEW user's token — NOT the store owner's
        final newToken = response['data']['access_token']?.toString();
        _newUserToken = newToken;

        // OTP verified — move to name/details step
        setState(() => _registrationStep = 2);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response['data']?['message']?.toString() ??
                  'OTP verification failed. Try again.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isVerifyingOtp = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ============== REGISTER & ADD STAFF ==============
  Future<void> _registerAndAddStaff() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name is required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isRegistering = true);

    try {
      // Build profile data
      final profileData = <String, dynamic>{'first_name': name};
      final address = _addressController.text.trim();
      final city = _cityController.text.trim();
      final state = _stateController.text.trim();
      final pincode = _pincodeController.text.trim();

      if (address.isNotEmpty) profileData['address_line_1'] = address;
      if (city.isNotEmpty) profileData['city'] = city;
      if (state.isNotEmpty) profileData['state'] = state;
      if (pincode.isNotEmpty) profileData['pincode'] = pincode;

      // Update the NEW USER's profile using THEIR token (not the store owner's).
      // Using useBearerToken: true would inject the store owner's token and
      // update the wrong profile. We pass the new user's token explicitly.
      await ApiService.put(
        '/update-user-data/',
        body: {'data': profileData},
        headers: _newUserToken != null
            ? {'Authorization': 'Bearer $_newUserToken'}
            : null,
      );

      // Now retry adding the staff member
      final result = await StoreOwnerApiService.createStoreStaff(
        storeId: widget.storeId,
        phoneNumber: _formattedPhoneNumber,
        roleId: _selectedRoleId!,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: TranslatedText(
              'User registered & added as staff successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to add staff member'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  // ============================================================
  //                           BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final height = MediaQuery.of(context).size.height * 0.90 - bottomInset;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Minimal Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Ultra-thin sleek progress bar for wizard mode
            if (_registrationStep > 0)
              Container(
                height: 2,
                width: double.infinity,
                color: const Color(0xFFF1F5F9),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _registrationStep == 1 ? 0.5 : 1.0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),

            if (_registrationStep > 0) const SizedBox(height: 24),

            // Header (Only show if on step 0, otherwise the steps handle their own headers)
            if (_registrationStep == 0) ...[
              _buildHeader(),
              const SizedBox(height: 16),
            ],

            // Preview card (only on step 0 when keyboard is hidden)
            if (bottomInset == 0 && _registrationStep == 0) _buildStaffPreview(),
            if (_registrationStep == 0) const SizedBox(height: 16),

            // Content
            if (_registrationStep == 0) ...[
              _buildTabBar(),
              const SizedBox(height: 4),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: TabBarView(
                    controller: _tabController,
                    children: [_buildAccountTab(), _buildRoleTab()],
                  ),
                ),
              ),
            ] else if (_registrationStep == 1) ...[
              Expanded(child: _buildOtpStep()),
            ] else if (_registrationStep == 2) ...[
              Expanded(child: _buildDetailsStep()),
            ],
          ],
        ),
      ),
    );
  }

  // ============== HEADER ==============
  // Now only used for Step 0
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Add Staff Member',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          GestureDetector(
            onTap: _isSubmitting ? null : _submit,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(30),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Add',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ============== STEP 1: OTP VERIFICATION ==============
  Widget _buildOtpStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        // Premium Phone display card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0).withOpacity(0.5)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.phone_iphone_rounded,
                    color: Color(0xFF0F172A), size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Verification code sent to',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '+$_formattedPhoneNumber',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isSendingOtp)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF3B82F6),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 36),

        const Center(
          child: Text(
            'Enter code',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Ask the staff member for the 4-digit OTP',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Premium OTP Input
        OTPInputSection(
          otpCode: _otpController.text,
          onChanged: (code) {
            setState(() {
              _otpController.text = code;
              // Auto verify when 4 digits are entered
              if (code.length == 4) {
                _verifyOtp();
              }
            });
          },
        ),

        const SizedBox(height: 32),

        // Resend row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Didn't receive the code? ",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
            if (_canResend)
              GestureDetector(
                onTap: _isSendingOtp ? null : _sendOtp,
                child: const Text(
                  'Resend',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              )
            else
              Text(
                'Wait ${_resendTimer}s',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF94A3B8),
                ),
              ),
          ],
        ),

        const SizedBox(height: 40),

        _buildPrimaryButton(
          label: 'Verify & Continue',
          isLoading: _isVerifyingOtp,
          onTap: _otpController.text.length == 4 ? _verifyOtp : () {},
          icon: Icons.check_circle_outline_rounded,
        ),

        const SizedBox(height: 24),

        Center(
          child: TextButton(
            onPressed: () {
              setState(() {
                _registrationStep = 0;
                _otpController.clear();
              });
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('Change phone number'),
          ),
        ),
      ],
    );
  }

  // ============== STEP 2: NAME & DETAILS ==============
  Widget _buildDetailsStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        // Minimal Verified badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified_rounded,
                  color: Color(0xFF10B981), size: 20),
              const SizedBox(width: 12),
              const Text(
                'Phone Verified:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '+$_formattedPhoneNumber',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        const Text(
          'Staff Information',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Complete the profile to register and add this member.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[500],
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),

        const SizedBox(height: 24),

        // Name (Required)
        _buildTextField(
          controller: _nameController,
          label: 'Full Name',
          hint: 'e.g. Rahul Sharma',
          icon: Icons.person_outline_rounded,
          isRequired: true,
        ),

        const SizedBox(height: 24),

        // Optional section header
        Row(
          children: [
            Expanded(
              child: Container(
                height: 1,
                color: const Color(0xFFE2E8F0),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              'OPTIONAL DETAILS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey[400],
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                height: 1,
                color: const Color(0xFFE2E8F0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        _buildTextField(
          controller: _addressController,
          label: 'Address',
          hint: 'Street address or locality',
          icon: Icons.location_on_outlined,
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _cityController,
                label: 'City',
                hint: 'e.g. Mumbai',
                icon: Icons.location_city_outlined,
                compact: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                controller: _stateController,
                label: 'State',
                hint: 'e.g. MH',
                icon: Icons.map_outlined,
                compact: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        _buildTextField(
          controller: _pincodeController,
          label: 'Pincode',
          hint: '6-digit pincode',
          icon: Icons.pin_drop_outlined,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
        ),

        const SizedBox(height: 40),

        _buildPrimaryButton(
          label: 'Finish Registration',
          isLoading: _isRegistering,
          onTap: _registerAndAddStaff,
        ),
      ],
    );
  }

  // ============== REUSABLE WIDGETS ==============
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isRequired = false,
    bool compact = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFEF4444),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: compact ? 48 : 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF8FAFC),
                blurRadius: 4,
                spreadRadius: 2,
              )
            ],
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.grey[400],
                fontWeight: FontWeight.w400,
                fontSize: 14,
              ),
              prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: compact ? 12 : 14, // Adjusted for centering
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required bool isLoading,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 54, // Fixed height for consistency
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ============== PREVIEW ==============
  Widget _buildStaffPreview() {
    final phone =
        _phoneController.text.isEmpty ? 'Phone Number' : _phoneController.text;
    final role = _selectedRoleName ?? 'No Role Selected';

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
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              color: Color(0xFF64748B),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  phone,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    role,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'PENDING',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFFB45309),
              ),
            ),
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
                Icon(Icons.badge_rounded, size: 16),
                SizedBox(width: 6),
                Text('Account'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_rounded, size: 16),
                SizedBox(width: 6),
                Text('Role & Access'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        _buildSectionTitle('Staff Contact'),
        const SizedBox(height: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Phone Number',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. 9876543210',
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: const Icon(
                    Icons.phone_iphone_rounded,
                    color: Color(0xFF94A3B8),
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Phone number required';
                  if (value.length != 10) return 'Must be 10 digits';
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildInfoBox(
          icon: Icons.info_outline_rounded,
          title: 'How it works',
          description:
              'If the number is already registered, the staff member is added directly. Otherwise, an OTP will be sent for verification, and you\'ll enter their name to register them.',
        ),
      ],
    );
  }

  Widget _buildRoleTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        _buildSectionTitle('Assign Permissions'),
        const SizedBox(height: 12),
        widget.roles.isEmpty
            ? const Center(child: Text("No roles available"))
            : Column(
                children: widget.roles.map((role) {
                  final isSelected = _selectedRoleId == role['id'];
                  final Color primaryColor = const Color(0xFF2563EB); // Modern blue
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Color.alphaBlend(
                          primaryColor.withOpacity(isSelected ? 0.08 : 0.03),
                          Colors.white),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: isSelected
                              ? primaryColor.withOpacity(0.12)
                              : Colors.black.withOpacity(0.04),
                          blurRadius: isSelected ? 16 : 8,
                          offset: Offset(0, isSelected ? 6 : 2),
                        ),
                      ],
                      border: isSelected
                          ? Border.all(
                              color: primaryColor.withOpacity(0.3), width: 1.5)
                          : Border.all(
                              color: primaryColor.withOpacity(0.15), width: 1.0),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedRoleId = role['id'];
                              _selectedRoleName = role['role_name'];
                            });
                          },
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: isSelected ? 20 : 16,
                                vertical: isSelected ? 20 : 16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? primaryColor.withOpacity(0.15)
                                        : Colors.transparent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.shield_rounded,
                                    color: isSelected
                                        ? primaryColor
                                        : const Color(0xFF64748B),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        role['role_name'] ?? 'Unknown Role',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected
                                              ? primaryColor
                                              : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      if (role['description'] != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          role['description'],
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: primaryColor,
                                    size: 24,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Color(0xFF64748B),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildInfoBox({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF64748B), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF475569),
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
}
