import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:exanor/screens/otp_verification_screen.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/components/universal_translation_wrapper.dart';
import 'package:exanor/services/enhanced_translation_service.dart';
import 'package:exanor/components/language_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PhoneRegistrationScreen extends StatefulWidget {
  const PhoneRegistrationScreen({super.key});

  @override
  State<PhoneRegistrationScreen> createState() =>
      _PhoneRegistrationScreenState();
}

class _PhoneRegistrationScreenState extends State<PhoneRegistrationScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  CountryCode _selectedCountry = CountryCode.fromCountryCode('IN');
  bool _isLoading = false;

  // Enhanced translation service
  final EnhancedTranslationService _enhancedTranslation =
      EnhancedTranslationService.instance;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Disabled automatic language selector to prevent navigation conflicts
    // User can still manually select language using the button below
    // _checkFirstTimeLanguageSelection();
  }

  // Commented out to prevent navigation conflicts
  // User can still manually select language using the button in the UI
  /*
  Future<void> _checkFirstTimeLanguageSelection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final selectedLanguage = prefs.getString('selected_language');

      // Check if no language has been selected (first time launch)
      // or if language is still set to default English
      if (selectedLanguage == null) {
        // Wait for the widget to build, then show language selector
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showFirstTimeLanguageSelector();
          }
        });
      }
    } catch (e) {
      print('❌ Error checking first-time language selection: $e');
    }
  }

  Future<void> _showFirstTimeLanguageSelector() async {
    try {
      await showLanguageSelector(
        context,
        navigateToSplashOnSelection:
            false, // Changed to false to prevent navigation issues
        onLanguageSelected: (language) {
          print('🌐 First-time language selected: ${language.name}');
        },
      );
    } catch (e) {
      print('❌ Error showing first-time language selector: $e');
    }
  }
  */

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: UniversalTranslationWrapper(
        excludePatterns: [
          '+',
          '@',
          '.com',
          'API',
        ], // Don't translate phone numbers, technical terms
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
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
                    child: ClipOval(
                      child: Image.asset(
                        'assets/icon/exanor_icon_512x512px.png',
                        width: 60,
                        height: 60,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Title
                  TranslatedText(
                    'Enter your phone number',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 12),

                  TranslatedText(
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
                      TranslatedText(
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
                            countryFilter: const [
                              'IN',
                              'US',
                              'GB',
                              'CA',
                              'AU',
                            ], // Common countries for easier access
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
                          : TranslatedText(
                              'Continue',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Language Selection Button
                  Center(
                    child: GestureDetector(
                      onTap: () async {
                        await showLanguageSelector(
                          context,
                          navigateToSplashOnSelection: false,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: theme.colorScheme.outline.withOpacity(0.3),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.language,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            TranslatedText(
                              'Select your language',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
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
          // Response format: {"status":200,"message":"OTP Sent"}
          if (response['data'] != null && response['data']['status'] == 200) {
            print('✅ OTP sent successfully');

            // Navigate to OTP verification screen
            // Pass the full numeric phone number (e.g., 918822036338)
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OTPVerificationScreen(
                  phoneNumber:
                      fullPhoneNumber, // Pass full numeric phone number
                ),
              ),
            );
          } else {
            // Show error message
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
        content: TranslatedText(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
