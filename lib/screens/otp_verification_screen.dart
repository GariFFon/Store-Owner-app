import 'dart:async';
import 'package:flutter/material.dart';
import 'package:exanor/components/otp_input_section.dart';
import 'package:exanor/screens/HomeScreen.dart';
import 'package:exanor/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/components/universal_translation_wrapper.dart';
import 'package:exanor/services/enhanced_translation_service.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String phoneNumber;

  const OTPVerificationScreen({super.key, required this.phoneNumber});

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  String _otpCode = '';
  bool _isLoading = false;
  bool _isResendLoading = false;
  int _resendTimer = 60;
  Timer? _timer;
  bool _canResend = false;

  // Enhanced translation service
  final EnhancedTranslationService _enhancedTranslation =
      EnhancedTranslationService.instance;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _resendTimer = 60;
      _canResend = false;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer > 0) {
        setState(() {
          _resendTimer--;
        });
      } else {
        setState(() {
          _canResend = true;
        });
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: UniversalTranslationWrapper(
        excludePatterns: [
          '+',
          '@',
          '.com',
          'OTP',
          'API',
        ], // Don't translate phone numbers, technical terms
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 40),

              TranslatedText(
                'Verify your phone number',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  children: [
                    const TextSpan(text: "Enter the 4-digit code sent to\n"),
                    TextSpan(
                      text: widget.phoneNumber,
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // OTP Input
              OTPInputSection(
                otpCode: _otpCode,
                onChanged: (code) {
                  setState(() {
                    _otpCode = code;
                  });
                },
              ),

              const SizedBox(height: 24),

              // Resend Code
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TranslatedText(
                    "Didn't get the code? ",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  if (_isResendLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (_canResend)
                    GestureDetector(
                      onTap: _resendCode,
                      child: TranslatedText(
                        'Resend it.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    TranslatedText(
                      'Resend in ${_resendTimer}s',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 40),

              // Continue Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _otpCode.length == 4 ? _verifyOTP : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: theme.colorScheme.outline
                        .withOpacity(0.3),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : TranslatedText(
                          'Continue',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  void _resendCode() async {
    if (!_canResend || _isResendLoading) return;

    setState(() {
      _isResendLoading = true;
    });

    try {
      // phoneNumber is already in the correct format: 918822036338
      String phoneNumber = widget.phoneNumber;

      print('🔄 Resending OTP to: $phoneNumber');

      // Send OTP API call
      final response = await ApiService.post(
        '/send-otp/',
        body: {'phone_number': phoneNumber},
      );

      if (mounted) {
        setState(() {
          _isResendLoading = false;
        });

        if (response['data'] != null && response['data']['status'] == 200) {
          print('✅ OTP resent successfully');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: TranslatedText('Verification code sent!')),
          );
          _startResendTimer(); // Restart the timer
        } else {
          print('❌ Failed to resend OTP');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: TranslatedText(
                'Failed to resend OTP. Please try again.',
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error resending OTP: $e');
      if (mounted) {
        setState(() {
          _isResendLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: TranslatedText('Network error. Please try again.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _verifyOTP() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // phoneNumber is already in the format: 918822036338
      String phoneNumber = widget.phoneNumber;

      print('📞 Verifying OTP for phone: $phoneNumber');
      print('🔢 OTP Code: $_otpCode');

      // Call sign-up API
      final response = await ApiService.post(
        '/sign-up/',
        body: {'phone_number': phoneNumber, 'otp': _otpCode, 'signup': true},
      );

      print('📨 Sign-up Response: $response');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Response format:
        // {
        //   "status": 200,
        //   "message": "Login successful",
        //   "access_token": "...",
        //   "csrf_token": "...",
        //   "user_data": {...}
        // }

        if (response['data'] != null) {
          final responseData = response['data'];
          final status = responseData['status'];
          final message = responseData['message'] as String?;

          print('📊 Response Status: $status');
          print('📝 Response Message: $message');

          if (status == 200 && message == 'Login successful') {
            print('✅ Login successful - storing tokens and user data');

            // Store access token
            if (responseData['access_token'] != null) {
              await _storeToken('access_token', responseData['access_token']);
            }

            // Store CSRF token
            if (responseData['csrf_token'] != null) {
              await _storeToken('csrf_token', responseData['csrf_token']);
            }

            // Store user data
            if (responseData['user_data'] != null) {
              await _storeUserData(responseData['user_data']);
            }

            print('🎉 All data stored successfully - navigating to HomeScreen');

            // Navigate to homepage
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
            );
          } else {
            print('❌ Login/Signup failed: $message');
            _showErrorSnackBar(
              message ?? 'Verification failed. Please try again.',
            );
          }
        } else {
          print('❌ Invalid response format - no data field');
          _showErrorSnackBar('Invalid response format.');
        }
      }
    } catch (e) {
      print('❌ Error verifying OTP: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('OTP verification failed. Please try again.');
      }
    }
  }

  Future<void> _storeToken(String key, String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, token);
      print('✅ Stored $key: ${token.substring(0, 20)}...');
    } catch (e) {
      print('❌ Error storing $key: $e');
    }
  }

  Future<void> _storeUserData(Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Store user data - using 'id' from API response
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

      print('✅ User data stored successfully');
      print('👤 User ID: ${userData['id']}');
      print('👤 Name: ${userData['first_name']} ${userData['last_name']}');
      print('📞 Phone: ${userData['phone_number']}');
      print('📧 Email: ${userData['email']}');
      print('📍 Location: ${userData['city']}, ${userData['state']}');
    } catch (e) {
      print('❌ Error storing user data: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: TranslatedText(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
