import 'dart:async';
import 'package:flutter/material.dart';
import 'package:exanor/components/otp_input_section.dart';
import 'package:exanor/screens/HomeScreen.dart';
import 'package:exanor/screens/location_selection_screen.dart';
import 'package:exanor/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SimpleOTPVerificationScreen extends StatefulWidget {
  final String phoneNumber;

  const SimpleOTPVerificationScreen({super.key, required this.phoneNumber});

  @override
  State<SimpleOTPVerificationScreen> createState() =>
      _SimpleOTPVerificationScreenState();
}

class _SimpleOTPVerificationScreenState
    extends State<SimpleOTPVerificationScreen> {
  String _otpCode = '';
  bool _isLoading = false;
  bool _isResendLoading = false;
  int _resendTimer = 60;
  Timer? _timer;
  bool _canResend = false;

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
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24.0,
          24.0,
          24.0,
          MediaQuery.of(context).viewInsets.bottom + 24.0,
        ),
        child: Column(
          children: [
            const SizedBox(height: 40),

            Text(
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
                Text(
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
                    child: Text(
                      'Resend it.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  Text(
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
                    : Text(
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
    );
  }

  void _resendCode() async {
    if (!_canResend || _isResendLoading) return;

    setState(() {
      _isResendLoading = true;
    });

    try {
      String phoneNumber = widget.phoneNumber;
      print('🔄 Resending OTP to: $phoneNumber');

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
            const SnackBar(content: Text('Verification code sent!')),
          );
          _startResendTimer();
        } else {
          print('❌ Failed to resend OTP');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to resend OTP. Please try again.'),
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
            content: const Text('Network error. Please try again.'),
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
      String phoneNumber = widget.phoneNumber;
      print('📞 Verifying OTP for phone: $phoneNumber');
      print('🔢 OTP Code: $_otpCode');

      final response = await ApiService.post(
        '/sign-up/',
        body: {'phone_number': phoneNumber, 'otp': _otpCode, 'signup': true},
      );

      print('📨 Sign-up Response: $response');

      // Extract and save cookies from response headers
      if (response['headers'] != null) {
        print('🍪 Checking response headers for cookies...');
        await _saveCookiesFromHeaders(response['headers']);
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (response['data'] != null) {
          final responseData = response['data'];
          final status = responseData['status'];
          final message = responseData['message'] as String?;

          print('📊 Response Status: $status');
          print('📝 Response Message: $message');

          if (status == 200 && message == 'Login successful') {
            print('✅ Login successful - checking existing data...');

            final prefs = await SharedPreferences.getInstance();
            // Check if user has previously stored data (using user_id as proxy)
            final bool hasExistingData = prefs.containsKey('user_id');
            print('📂 Existing user data found: $hasExistingData');

            // Store/Update access token
            if (responseData['access_token'] != null) {
              await _storeToken('access_token', responseData['access_token']);
            }

            // Store/Update CSRF token
            if (responseData['csrf_token'] != null) {
              await _storeToken('csrf_token', responseData['csrf_token']);
            }

            // Store/Update user data
            if (responseData['user_data'] != null) {
              await _storeUserData(responseData['user_data']);
            }

            if (hasExistingData) {
              print('🎉 Existing user - navigating to HomeScreen');
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
                (route) => false,
              );
            } else {
              print(
                '🆕 New user setup - navigating to LocationSelectionScreen',
              );
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const LocationSelectionScreen(),
                ),
                (route) => false,
              );
            }
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

  /// Save cookies from HTTP response headers
  Future<void> _saveCookiesFromHeaders(Map<String, String> headers) async {
    try {
      // Look for Set-Cookie headers (HTTP header keys can be lowercase)
      final setCookies = headers.entries
          .where((entry) => entry.key.toLowerCase() == 'set-cookie')
          .toList();

      if (setCookies.isEmpty) {
        print('ℹ️ No Set-Cookie headers found in response');
        return;
      }

      print('🍪 Found ${setCookies.length} Set-Cookie header(s)');

      for (final cookie in setCookies) {
        print('🍪 Processing cookie: ${cookie.value.substring(0, 50)}...');
        await _parseCookieString(cookie.value);
      }
    } catch (e) {
      print('❌ Error saving cookies from headers: $e');
    }
  }

  /// Parse a single Set-Cookie header value
  Future<void> _parseCookieString(String cookieString) async {
    try {
      // Split by semicolon - first part is name=value
      final parts = cookieString.split(';');
      if (parts.isEmpty) return;

      final nameValue = parts[0].trim();
      final separatorIndex = nameValue.indexOf('=');
      if (separatorIndex == -1) return;

      final name = nameValue.substring(0, separatorIndex).trim();
      final value = nameValue.substring(separatorIndex + 1).trim();

      final prefs = await SharedPreferences.getInstance();

      // Store refresh_token cookie
      if (name.toLowerCase() == 'refresh_token' ||
          name.toLowerCase() == 'refreshtoken') {
        await prefs.setString('refresh_token_cookie', value);
        print('✅ Saved refresh_token cookie (${value.length} chars)');
      }
      // Store csrf_token cookie
      else if (name.toLowerCase() == 'csrf_token' ||
          name.toLowerCase() == 'csrftoken') {
        await prefs.setString('csrf_token_cookie', value);
        print('✅ Saved csrf_token cookie (${value.length} chars)');
      }
    } catch (e) {
      print('❌ Error parsing cookie string: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
