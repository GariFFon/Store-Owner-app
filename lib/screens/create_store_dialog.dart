import 'package:flutter/material.dart';
import 'package:exanor/services/store_owner_api_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CreateStoreDialog extends StatefulWidget {
  final String storeId;

  const CreateStoreDialog({super.key, required this.storeId});

  @override
  State<CreateStoreDialog> createState() => _CreateStoreDialogState();
}

class _CreateStoreDialogState extends State<CreateStoreDialog> {
  int _currentStep = 0;
  bool _isLoading = false;
  bool _isFetchingLocation = false;

  // Controllers
  final _storeNameController = TextEditingController();
  final _cityController = TextEditingController();
  final _areaController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _legalNameController = TextEditingController();
  final _websiteController = TextEditingController();
  final _gstController = TextEditingController();

  // State selection
  String? _selectedState;
  final List<String> _indianStates = [
    'Andhra Pradesh',
    'Arunachal Pradesh',
    'Assam',
    'Bihar',
    'Chhattisgarh',
    'Goa',
    'Gujarat',
    'Haryana',
    'Himachal Pradesh',
    'Jharkhand',
    'Karnataka',
    'Kerala',
    'Madhya Pradesh',
    'Maharashtra',
    'Manipur',
    'Meghalaya',
    'Mizoram',
    'Nagaland',
    'Odisha',
    'Punjab',
    'Rajasthan',
    'Sikkim',
    'Tamil Nadu',
    'Telangana',
    'Tripura',
    'Uttar Pradesh',
    'Uttarakhand',
    'West Bengal',
    'Andaman and Nicobar Islands',
    'Chandigarh',
    'Dadra and Nagar Haveli and Daman and Diu',
    'Delhi',
    'Jammu and Kashmir',
    'Ladakh',
    'Lakshadweep',
    'Puducherry',
  ];

  String _phoneCode = '+91';

  // GST
  final List<String> _gstTypes = ['Regular', 'Composition'];
  String _selectedGstType = 'Regular';
  bool _isGstEnabled = false;
  String? _selectedGstState;

  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _storeNameController.dispose();
    _cityController.dispose();
    _areaController.dispose();
    _pincodeController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _legalNameController.dispose();
    _websiteController.dispose();
    _gstController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocationFromPincode(String pincode) async {
    if (pincode.length != 6) return;

    setState(() {
      _isFetchingLocation = true;
    });

    try {
      final url = Uri.parse('https://api.postalpincode.in/pincode/$pincode');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty && data[0]['Status'] == 'Success') {
          final postOffices = data[0]['PostOffice'] as List<dynamic>;
          if (postOffices.isNotEmpty) {
            final firstOffice = postOffices[0];
            final district = firstOffice['District'];
            final state = firstOffice['State'];

            if (mounted) {
              setState(() {
                _cityController.text = district;

                // Try to match state with our list
                // Basic normalization for common differences if needed, but direct match first
                // API usually returns standard names like "Odisha", "Maharashtra"
                try {
                  final matchingState = _indianStates.firstWhere(
                    (s) => s.toLowerCase() == state.toString().toLowerCase(),
                    orElse: () => '',
                  );
                  if (matchingState.isNotEmpty) {
                    _selectedState = matchingState;
                    if (_isGstEnabled && _selectedGstState == null) {
                      _selectedGstState = matchingState;
                    }
                  }
                } catch (e) {
                  // Ignore if not found
                }
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching location: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingLocation = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Additional validation for required fields across steps if needed
    if (_storeNameController.text.isEmpty) {
      setState(() => _currentStep = 0);
      return;
    }
    if (_cityController.text.isEmpty || _selectedState == null) {
      setState(() => _currentStep = 1);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await StoreOwnerApiService.registerStore(
        storeId: widget.storeId,
        storeName: _storeNameController.text,
        legalName: _legalNameController.text.isNotEmpty
            ? _legalNameController.text
            : _storeNameController.text,
        city: _cityController.text,
        state: _selectedState!, // Validated above
        pin: int.tryParse(_pincodeController.text) ?? 0,
        isGstEnabled: _isGstEnabled,
        gstIn: _isGstEnabled ? _gstController.text : '',
        gstRegisteredState: _isGstEnabled
            ? (_selectedGstState ?? _selectedState ?? '')
            : '',
        gstRegistrationType: _isGstEnabled ? _selectedGstType : '',
        area: _areaController.text,
        phoneNumber: _phoneController.text,
        email: _emailController.text,
        websiteUrl: _websiteController.text,
      );

      if (mounted) {
        if (result.isNotEmpty && result['status'] == 200) {
          final newStoreId = result['data']?['store_id']?.toString();
          final newStoreName =
              result['data']?['store_name']?.toString() ??
              _storeNameController.text;
          final newStoreGst =
              result['data']?['gst_in']?.toString() ?? _gstController.text;
          final newStoreCity =
              result['data']?['city']?.toString() ?? _cityController.text;

          // Return the new store info
          Navigator.pop(context, {
            'id': newStoreId,
            'name': newStoreName,
            'gst_in': newStoreGst,
            'city': newStoreCity,
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Store created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result['message']?.toString() ?? 'Failed to create store',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _nextStep() {
    // Validate visible form fields (triggers red error text on invalid fields)
    if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
      return;
    }

    // Additional manual validation for non-TextFormField inputs
    bool isValid = true;
    String errorMessage = 'Please fill all required fields';

    if (_currentStep == 1) {
      if (_cityController.text.isEmpty || _selectedState == null) {
        isValid = false;
        errorMessage = 'Location details are incomplete';
      }
    } else if (_currentStep == 3) {
      if (_isGstEnabled &&
          (_gstController.text.isEmpty || _selectedGstState == null)) {
        isValid = false;
        errorMessage = 'Please fill all GST details';
      }
    }

    if (isValid) {
      setState(() {
        if (_currentStep < 3) {
          _currentStep++;
        } else {
          _submit();
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _prevStep() {
    setState(() {
      if (_currentStep > 0) {
        _currentStep--;
      } else {
        Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Define steps for the stepper
    final steps = ['Basic Info', 'Location', 'Business', 'GST'];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
      alignment: Alignment.topCenter,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 750),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 25,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with Integrated Action Button
            Stack(
              children: [
                Container(
                  height: 110,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                // Decorative Circle
                Positioned(
                  top: -30,
                  right: -30,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Add New Supplier',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Register a new store partner',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[50],
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Action Button in Header (Creative Placement)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Back Button - Always present in layout to prevent title reflow
                          // but hidden/disabled on first step
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: _currentStep > 0 ? 1.0 : 0.0,
                            child: IgnorePointer(
                              ignoring: _currentStep == 0,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: _prevStep,
                                    icon: const Icon(
                                      Icons.arrow_back_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.white.withOpacity(
                                        0.2,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: _isLoading ? null : _nextStep,
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF2563EB),
                                      ),
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _currentStep == 3 ? 'Finish' : 'Next',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF2563EB),
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          _currentStep == 3
                                              ? Icons.check_circle_rounded
                                              : Icons.arrow_forward_rounded,
                                          color: const Color(0xFF2563EB),
                                          size: 14,
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 32,
                            height: 32,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black.withOpacity(0.1),
                                shape: const CircleBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Sliding Stepper (Overlapping the header slightly for a layered look)
            Transform.translate(
              offset: const Offset(0, -24),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      alignment: Alignment(
                        -1.0 + (2.0 * _currentStep) / (steps.length - 1),
                        0,
                      ),
                      child: FractionallySizedBox(
                        widthFactor: 1 / steps.length,
                        heightFactor: 1.0,
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF3B82F6).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: List.generate(steps.length, (index) {
                        final isSelected = index == _currentStep;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              // Allow explicit navigation to any completed step or the immediate next one
                              if (index <= _currentStep) {
                                setState(() => _currentStep = index);
                              }
                            },
                            behavior: HitTestBehavior.translucent,
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF64748B),
                                ),
                                child: Text(
                                  steps[index],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),

            // Content
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                layoutBuilder:
                    (Widget? currentChild, List<Widget> previousChildren) {
                      return Stack(
                        alignment: Alignment.topCenter,
                        children: <Widget>[
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      );
                    },
                child: SingleChildScrollView(
                  key: ValueKey<int>(_currentStep),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  physics: const BouncingScrollPhysics(),
                  child: Form(key: _formKey, child: _buildStepContent()),
                ),
              ),
            ),

            // Bottom Spacer for rounded feel (No footer buttons here)
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildModernField(
              controller: _storeNameController,
              label: 'Store Name',
              hint: 'Enter store name',
              required: true,
              errorText: 'Store name is required',
              icon: Icons.store_mall_directory_rounded,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFDBEAFE)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: Color(0xFF3B82F6),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This name will be displayed to your customers and suppliers.',
                      style: TextStyle(
                        color: Colors.blueGrey[700],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      case 1:
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildModernField(
                    controller: _pincodeController,
                    label: 'PIN Code',
                    hint: '123456',
                    keyboardType: TextInputType.number,
                    required: true,
                    icon: Icons.pin_drop_rounded,
                  ),
                ),
                if (_isFetchingLocation) ...[
                  const SizedBox(width: 16),
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            _buildModernField(
              controller: _cityController,
              label: 'City',
              hint: 'City name',
              required: true,
              icon: Icons.location_city_rounded,
            ),
            const SizedBox(height: 16),
            _buildModernField(
              controller: _areaController,
              label: 'Area / Locality',
              hint: 'Enter area',
              icon: Icons.map_rounded,
            ),
            const SizedBox(height: 16),
            _buildModernDropdown(
              label: 'State',
              value: _selectedState,
              items: _indianStates,
              hint: 'Select State',
              icon: Icons.map_outlined,
              onChanged: (v) => setState(() => _selectedState = v),
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildModernField(
              controller: _phoneController,
              label: 'Phone Number',
              hint: '9876543210',
              keyboardType: TextInputType.phone,
              icon: Icons.phone_rounded,
              prefix: SizedBox(
                width: 40,
                child: Center(
                  child: Text(
                    '+91',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
              validator: (value) {
                if (value != null && value.isNotEmpty && value.length != 10) {
                  return 'Enter valid 10-digit number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildModernField(
              controller: _emailController,
              label: 'Email Address',
              hint: 'store@email.com',
              keyboardType: TextInputType.emailAddress,
              icon: Icons.email_rounded,
            ),
            const SizedBox(height: 16),
            _buildModernField(
              controller: _legalNameController,
              label: 'Legal Business Name',
              hint: 'Registered business name',
              icon: Icons.gavel_rounded,
            ),
            const SizedBox(height: 16),
            _buildModernField(
              controller: _websiteController,
              label: 'Website',
              hint: 'https://myshop.com',
              icon: Icons.language_rounded,
            ),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _isGstEnabled = !_isGstEnabled;
                  if (_isGstEnabled &&
                      _selectedGstState == null &&
                      _selectedState != null) {
                    _selectedGstState = _selectedState;
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isGstEnabled
                      ? const Color(0xFFEFF6FF)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isGstEnabled
                        ? const Color(0xFF3B82F6)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isGstEnabled
                          ? Icons.check_circle_rounded
                          : Icons.check_circle_outline_rounded,
                      color: _isGstEnabled
                          ? const Color(0xFF3B82F6)
                          : const Color(0xFF94A3B8),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Yes, this business is GST registered',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: _isGstEnabled
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                          if (_isGstEnabled)
                            Text(
                              'Enter your GST details below',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blueGrey[500],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isGstEnabled) ...[
              const SizedBox(height: 24),
              _buildModernField(
                controller: _gstController,
                label: 'GSTIN',
                hint: '22AAAAA0000A1Z5',
                required: true,
                icon: Icons.confirmation_number_rounded,
              ),
              const SizedBox(height: 16),
              _buildModernDropdown(
                label: 'Registered State',
                value: _selectedGstState,
                items: _indianStates,
                hint: 'Select State',
                icon: Icons.map_rounded,
                onChanged: (v) => setState(() => _selectedGstState = v),
              ),
              const SizedBox(height: 16),
              _buildModernDropdown(
                label: 'Registration Type',
                value: _selectedGstType,
                items: _gstTypes,
                hint: 'Select Type',
                icon: Icons.category_rounded,
                onChanged: (v) => setState(() => _selectedGstType = v!),
              ),
            ],
          ],
        );
      default:
        return Container();
    }
  }

  // --- HELPER METHODS FOR UNIFIED DESIGN ---

  Widget _buildModernField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool required = false,
    String? errorText,
    TextInputType? keyboardType,
    IconData? icon,
    Widget? prefix,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: const Color(0xFF64748B)),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            if (required)
              const Text(
                ' *',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
          validator:
              validator ??
              (value) {
                if (required && (value == null || value.isEmpty)) {
                  return errorText ?? 'This field is required';
                }
                return null;
              },
          onChanged: (val) {
            if (required) setState(() {});
            // Handle Pincode Check
            if (controller == _pincodeController && val.length == 6) {
              _fetchLocationFromPincode(val);
            }
          },
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.grey[400],
            ),
            prefixIcon: prefix,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF3B82F6),
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1.0),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String? hint,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: const Color(0xFF64748B)),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              hint: hint != null
                  ? Text(
                      hint,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[400],
                        fontWeight: FontWeight.w400,
                      ),
                    )
                  : null,
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF64748B),
                size: 20,
              ),
              isExpanded: true,
              menuMaxHeight: 300,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w600,
              ),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}
