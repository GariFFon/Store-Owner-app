import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:exanor/components/otp_input_section.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/widgets/auth_layout.dart';
import 'package:exanor/screens/store_selection_screen.dart';
import 'package:exanor/screens/location_selection_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  CountryCode _selectedCountry = CountryCode.fromCountryCode('IN');
  bool _isLoading = false;
  bool _isOtpSent = false;
  String? _fullPhoneNumber;
  String _otpCode = '';

  // Timer State
  int _resendTimer = 60;
  Timer? _timer;
  bool _canResend = false;
  bool _isResendLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Intercept Back Button
    return PopScope(
      canPop: !_isOtpSent,
      onPopInvoked: (didPop) {
        if (didPop) return;
        setState(() {
          _isOtpSent = false;
          _otpCode = '';
        });
      },
      child: AuthLayout(
        title: _isOtpSent ? 'Verify OTP' : 'Welcome Back',
        subtitle: _isOtpSent
            ? 'Enter the OTP sent to your mobile'
            : 'Login / Sign up to your account',
        // onBack removed - relying on System Back button via PopScope
        child: Form(
          key: _formKey,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _isOtpSent ? _buildOtpView() : _buildPhoneView(),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneView() {
    return Column(
      key: const ValueKey('phone_view'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Mobile Number",
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8), // Highly reduced spacing
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 100,
                child: CountryCodePicker(
                  onChanged: (val) => setState(() => _selectedCountry = val),
                  initialSelection: 'IN',
                  favorite: const ['+91', 'IN'],
                  showFlag: true,
                  showFlagMain: true,
                  flagWidth: 24,
                  padding: EdgeInsets.zero,
                  textStyle: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(width: 1, height: 24, color: Colors.grey.shade300),
              Expanded(
                child: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                  ],
                  validator: (value) {
                    if (value == null || value.length != 10) return null;
                    return null;
                  },
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    hintText: '00000 00000',
                    hintStyle: GoogleFonts.inter(color: Colors.grey.shade300),
                    filled: false,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24), // Highly reduced spacing
        SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitPhoneNumber,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4285F4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    'Send OTP',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16), // Minimal bottom padding
      ],
    );
  }

  Widget _buildOtpView() {
    return Column(
      key: const ValueKey('otp_view'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Back Arrow removed completely
        OTPInputSection(
          otpCode: _otpCode,
          onChanged: (code) {
            setState(() {
              _otpCode = code;
            });
          },
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Didn't get code? ",
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            if (_isResendLoading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (_canResend)
              GestureDetector(
                onTap: _resendCode,
                child: Text(
                  'Resend',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF4285F4),
                  ),
                ),
              )
            else
              Text(
                'Resend in ${_resendTimer}s',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade400,
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _verifyOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4285F4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    'Verify & Login',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16), // Minimal bottom padding
      ],
    );
  }

  // ─── Timer Logic ───────────────────────────────────────────────

  void _startResendTimer() {
    setState(() {
      _resendTimer = 60;
      _canResend = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer > 0) {
        setState(() => _resendTimer--);
      } else {
        setState(() => _canResend = true);
        timer.cancel();
      }
    });
  }

  Future<void> _resendCode() async {
    if (!_canResend || _isResendLoading) return;
    setState(() => _isResendLoading = true);
    try {
      final response = await ApiService.post(
        '/send-otp/',
        body: {'phone_number': _fullPhoneNumber},
      );
      if (mounted) {
        setState(() => _isResendLoading = false);
        if (response['data'] != null && response['data']['status'] == 200) {
          _showSuccessSnackBar('OTP resent successfully');
          _startResendTimer();
        } else {
          _showErrorSnackBar('Failed to resend OTP');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isResendLoading = false);
        _showErrorSnackBar('Network error');
      }
    }
  }

  // ─── Send OTP ──────────────────────────────────────────────────

  void _submitPhoneNumber() async {
    if (_formKey.currentState!.validate()) {
      if (_phoneController.text.length != 10) {
        _showErrorSnackBar('Please enter a valid 10-digit mobile number');
        return;
      }
      setState(() => _isLoading = true);
      try {
        final cleanPhoneNumber = _phoneController.text.replaceAll(
          RegExp(r'\D'),
          '',
        );
        final countryCode =
            _selectedCountry.dialCode?.replaceAll('+', '') ?? '91';
        _fullPhoneNumber = '$countryCode$cleanPhoneNumber';

        final response = await ApiService.post(
          '/send-otp/',
          body: {'phone_number': _fullPhoneNumber},
        );

        if (mounted) {
          setState(() => _isLoading = false);
          if (response['data'] != null && response['data']['status'] == 200) {
            setState(() => _isOtpSent = true);
            _showSuccessSnackBar('OTP sent successfully');
            _startResendTimer();
          } else {
            _showErrorSnackBar('Failed to send OTP. Please try again.');
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showErrorSnackBar('Network error. Please try again.');
        }
      }
    }
  }

  // ─── Verify OTP ────────────────────────────────────────────────

  void _verifyOtp() async {
    if (_otpCode.length != 4) {
      _showErrorSnackBar('Please enter a valid 4-digit OTP');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.post(
        '/sign-up/',
        body: {
          'phone_number': _fullPhoneNumber,
          'otp': _otpCode,
          'signup': true,
        },
      );

      // Save cookies if present
      if (response['headers'] != null) {
        await _saveCookiesFromHeaders(response['headers']);
      }

      if (mounted) {
        setState(() => _isLoading = false);

        if (response['data'] != null) {
          final responseData = response['data'];
          final status = responseData['status'];
          final message = responseData['message'] as String?;

          if (status == 200 && message == 'Login successful') {
            final prefs = await SharedPreferences.getInstance();
            final bool hasExistingData = prefs.containsKey('user_id');

            // Store tokens
            if (responseData['access_token'] != null) {
              await _storeToken('access_token', responseData['access_token']);
            }
            if (responseData['csrf_token'] != null) {
              await _storeToken('csrf_token', responseData['csrf_token']);
            }

            // Store user data
            if (responseData['user_data'] != null) {
              await _storeUserData(responseData['user_data']);
            }

            // Navigate based on whether the user already exists
            if (hasExistingData) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const StoreSelectionScreen()),
                (route) => false,
              );
            } else {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => const LocationSelectionScreen(),
                ),
                (route) => false,
              );
            }
          } else {
            _showErrorSnackBar(message ?? 'Invalid OTP. Please try again.');
          }
        } else {
          _showErrorSnackBar('Invalid response format.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Verification failed. Please try again.');
      }
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────

  Future<void> _storeToken(String key, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, token);
  }

  Future<void> _storeUserData(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    if (userData['id'] != null) {
      await prefs.setString('user_id', userData['id']);
    }
    if (userData['first_name'] != null) {
      await prefs.setString('first_name', userData['first_name']);
    }
    if (userData['last_name'] != null) {
      await prefs.setString('last_name', userData['last_name']);
    }
    if (userData['phone_number'] != null) {
      await prefs.setString(
        'phone_number',
        userData['phone_number'].toString(),
      );
    }
    if (userData['email'] != null) {
      await prefs.setString('email', userData['email']);
    }
    if (userData['img_url'] != null) {
      await prefs.setString('img_url', userData['img_url']);
    }
    if (userData['gender'] != null) {
      await prefs.setString('gender', userData['gender']);
    }
    if (userData['address_line_1'] != null) {
      await prefs.setString('address_line_1', userData['address_line_1']);
    }
    if (userData['address_line_2'] != null) {
      await prefs.setString('address_line_2', userData['address_line_2']);
    }
    if (userData['city'] != null) {
      await prefs.setString('city', userData['city']);
    }
    if (userData['state'] != null) {
      await prefs.setString('state', userData['state']);
    }
    if (userData['pincode'] != null) {
      await prefs.setInt('pincode', userData['pincode']);
    }
    if (userData['lat'] != null) {
      await prefs.setString('lat', userData['lat']);
    }
    if (userData['lng'] != null) {
      await prefs.setString('lng', userData['lng']);
    }
  }

  Future<void> _saveCookiesFromHeaders(Map<String, String> headers) async {
    final setCookies = headers.entries
        .where((entry) => entry.key.toLowerCase() == 'set-cookie')
        .toList();
    for (final cookie in setCookies) {
      await _parseCookieString(cookie.value);
    }
  }

  Future<void> _parseCookieString(String cookieString) async {
    final parts = cookieString.split(';');
    if (parts.isEmpty) return;
    final nameValue = parts[0].trim();
    final separatorIndex = nameValue.indexOf('=');
    if (separatorIndex == -1) return;
    final name = nameValue.substring(0, separatorIndex).trim();
    final value = nameValue.substring(separatorIndex + 1).trim();

    final prefs = await SharedPreferences.getInstance();
    if (name.toLowerCase() == 'refresh_token' ||
        name.toLowerCase() == 'refreshtoken') {
      await prefs.setString('refresh_token_cookie', value);
    } else if (name.toLowerCase() == 'csrf_token' ||
        name.toLowerCase() == 'csrftoken') {
      await prefs.setString('csrf_token_cookie', value);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
