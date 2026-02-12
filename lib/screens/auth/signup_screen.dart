import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:exanor/screens/simple_otp_verification_screen.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/widgets/auth_layout.dart';
import 'package:google_fonts/google_fonts.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  CountryCode _selectedCountry = CountryCode.fromCountryCode('IN');
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Using the same clean split-screen AuthLayout
    return AuthLayout(
      title: 'Create Account',
      subtitle: 'Sign up to get started',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Label
            Text(
              "Mobile Number",
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),

            // Clean Phone Input Decoration (No grey box, just outline)
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: Colors.transparent, // Transparent to avoid grey bg
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
                // No boxShadow
              ),
              child: Row(
                children: [
                  // Country Code Picker - Fixed Width & No Truncation
                  SizedBox(
                    width: 100, // Reverted to 100
                    child: CountryCodePicker(
                      onChanged: (CountryCode countryCode) {
                        setState(() {
                          _selectedCountry = countryCode;
                        });
                      },
                      initialSelection: 'IN',
                      favorite: const ['+91', 'IN'],
                      showCountryOnly: false,
                      showOnlyCountryWhenClosed: false,
                      alignLeft: false,
                      showFlag: true,
                      showFlagMain: true,
                      flagWidth: 24,
                      padding: EdgeInsets.zero,
                      textStyle: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      dialogTextStyle: GoogleFonts.inter(),
                      searchStyle: GoogleFonts.inter(),
                      searchDecoration: InputDecoration(
                        hintText: 'Search',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                  ),

                  // Vertical Divider
                  Container(width: 1, height: 24, color: Colors.grey.shade300),

                  // Phone Number Text Field
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: GoogleFonts.inter(
                        fontSize: 18, // Larger, beautiful typing
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: Colors.black87,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                      ],
                      validator: (value) {
                        // Remove text validation inside the layout (handle it in submit like Login)
                        return null;
                      },
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                        hintText: '00000 00000',
                        hintStyle: GoogleFonts.inter(
                          color: Colors.grey.shade300,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                        // Explicitly removing filled/fillColor
                        filled: false,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Send OTP Button
            SizedBox(
              height: 54, // Slightly taller
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitPhoneNumber,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4285F4),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent, // Ensure no "grey" shadow
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 24),

            // Footer Login Link
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Already have an account? ",
                  style: GoogleFonts.inter(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Navigate to Login/Pop
                    Navigator.pop(context);
                  },
                  child: Text(
                    "Login",
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF4285F4),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _submitPhoneNumber() async {
    if (_formKey.currentState!.validate()) {
      // Handle validation in submit like Login
      if (_phoneController.text.isEmpty) {
        _showErrorSnackBar('Mobile number is required.');
        return;
      }
      if (_phoneController.text.length != 10) {
        _showErrorSnackBar('Please enter a valid 10-digit mobile number.');
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        final cleanPhoneNumber = _phoneController.text.replaceAll(
          RegExp(r'\D'),
          '',
        );
        final countryCode =
            _selectedCountry.dialCode?.replaceAll('+', '') ?? '91';
        final fullPhoneNumber = '$countryCode$cleanPhoneNumber';

        final response = await ApiService.post(
          '/send-otp/',
          body: {'phone_number': fullPhoneNumber},
        );

        if (mounted) {
          setState(() {
            _isLoading = false;
          });

          if (response['data'] != null && response['data']['status'] == 200) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    SimpleOTPVerificationScreen(phoneNumber: fullPhoneNumber),
              ),
            );
          } else {
            _showErrorSnackBar('Failed to send OTP. Please try again.');
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          _showErrorSnackBar(
            'Network error. Please check your connection and try again.',
          );
        }
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
