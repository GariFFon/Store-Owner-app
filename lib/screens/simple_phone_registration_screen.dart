import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:exanor/screens/simple_otp_verification_screen.dart';
import 'package:exanor/services/api_service.dart';

class SimplePhoneRegistrationScreen extends StatefulWidget {
  const SimplePhoneRegistrationScreen({super.key});

  @override
  State<SimplePhoneRegistrationScreen> createState() =>
      _SimplePhoneRegistrationScreenState();
}

class _SimplePhoneRegistrationScreenState
    extends State<SimplePhoneRegistrationScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  CountryCode _selectedCountry = CountryCode.fromCountryCode('IN');
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    print('📱 SimplePhoneRegistrationScreen: initState called');
  }

  @override
  void dispose() {
    print('📱 SimplePhoneRegistrationScreen: dispose called');
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('📱 SimplePhoneRegistrationScreen: build called');
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24.0,
            24.0,
            24.0,
            MediaQuery.of(context).viewInsets.bottom + 24.0,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),

                // Header Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.phone_android,
                    size: 40,
                    color: theme.colorScheme.primary,
                  ),
                ),

                const SizedBox(height: 24),

                // Title
                Text(
                  'Enter your phone number',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                Text(
                  "We'll send you a verification code",
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 40),

                // Phone Number Input
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Phone Number',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your phone number';
                        }
                        if (value.length != 10) {
                          return 'Please enter a valid 10-digit phone number';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        hintText: '9876543210',
                        hintStyle: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                        prefixIcon: CountryCodePicker(
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
                          flagWidth: 25,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          textStyle: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                          dialogTextStyle: theme.textTheme.bodyMedium,
                          searchStyle: theme.textTheme.bodyMedium,
                          searchDecoration: InputDecoration(
                            hintText: 'Search country',
                            hintStyle: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.5,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          countryFilter: const ['IN', 'US', 'GB', 'CA', 'AU'],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: theme.colorScheme.outline.withOpacity(0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: theme.colorScheme.outline.withOpacity(0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: theme.colorScheme.error,
                          ),
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Continue Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitPhoneNumber,
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
        ),
      ),
    );
  }

  void _submitPhoneNumber() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Format phone number to 12 digits (e.g., 918822036338)
        final cleanPhoneNumber = _phoneController.text.replaceAll(
          RegExp(r'\D'),
          '',
        );
        final countryCode =
            _selectedCountry.dialCode?.replaceAll('+', '') ?? '91';
        final fullPhoneNumber = '$countryCode$cleanPhoneNumber';

        print('📞 Sending OTP to: $fullPhoneNumber');

        // Send OTP API call
        final response = await ApiService.post(
          '/send-otp/',
          body: {'phone_number': fullPhoneNumber},
        );

        print('📨 Send OTP Response: $response');

        if (mounted) {
          setState(() {
            _isLoading = false;
          });

          // Check if response status is 200
          if (response['data'] != null && response['data']['status'] == 200) {
            print('✅ OTP sent successfully');

            // Navigate to OTP verification screen
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    SimpleOTPVerificationScreen(phoneNumber: fullPhoneNumber),
              ),
            );
          } else {
            print('❌ Failed to send OTP: ${response['data']}');
            _showErrorSnackBar('Failed to send OTP. Please try again.');
          }
        }
      } catch (e) {
        print('❌ Error sending OTP: $e');
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
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
