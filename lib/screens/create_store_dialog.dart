import 'package:flutter/material.dart';
import 'package:exanor/services/store_owner_api_service.dart';

class CreateStoreDialog extends StatefulWidget {
  final String storeId;

  const CreateStoreDialog({super.key, required this.storeId});

  @override
  State<CreateStoreDialog> createState() => _CreateStoreDialogState();
}

class _CreateStoreDialogState extends State<CreateStoreDialog> {
  int _currentStep = 0;
  bool _isLoading = false;

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
    // Validate current step fields
    bool isValid = true;

    if (_currentStep == 0) {
      if (_storeNameController.text.isEmpty) isValid = false;
    } else if (_currentStep == 1) {
      if (_cityController.text.isEmpty ||
          _selectedState == null ||
          _pincodeController.text.isEmpty)
        isValid = false;
    } else if (_currentStep == 3) {
      if (_isGstEnabled) {
        if (_gstController.text.isEmpty || _selectedGstState == null)
          isValid = false;
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
        const SnackBar(
          content: Text('Please fill all required fields'),
          duration: Duration(seconds: 1),
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
    return Dialog(
      insetPadding: EdgeInsets.zero, // Full screen or close to it like modal
      backgroundColor: Colors.white,
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height, // Full screen dialog
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Create New Store',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // Stepper Indicator
            _buildStepper(),

            const Divider(),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(key: _formKey, child: _buildStepContent()),
              ),
            ),

            // Footer Buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _prevStep,
                    child: Text(
                      _currentStep == 0 ? 'Cancel' : 'Back',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _nextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _currentStep == 3 ? 'Create Store' : 'Next',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepper() {
    final steps = [
      'Basic Info',
      'Location',
      'Business Details',
      'GST (Optional)',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[50], // Light background for stepper
      child: Row(
        children: List.generate(steps.length, (index) {
          bool isActive = index == _currentStep;
          bool isCompleted = index < _currentStep;

          return Expanded(
            child: Row(
              children: [
                // Circle with number/check
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isActive || isCompleted
                        ? Colors.blue[700]
                        : Colors.grey[400],
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                // Label (hidden on small screens if needed, but let's try to show)
                Expanded(
                  child: Text(
                    steps[index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isActive ? Colors.black : Colors.grey[600],
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
                // Connector line (except for last item)
                if (index < steps.length - 1)
                  Container(width: 20, height: 1, color: Colors.grey[300]),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField(
              controller: _storeNameController,
              label: 'Store Name *',
              hint: '',
              required: true,
              errorText: 'Store name is required',
            ),
            const SizedBox(height: 8),
            Text(
              '* Required field. Enter the display name for this store.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        );
      case 1:
        return Column(
          children: [
            _buildTextField(
              controller: _cityController,
              label: 'City',
              required: true,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _areaController,
              label: 'Area/Locality',
            ),
            const SizedBox(height: 16),
            // State Dropdown
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'State',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedState,
                      hint: const Text('Select State'),
                      items: _indianStates.map((String state) {
                        return DropdownMenuItem<String>(
                          value: state,
                          child: Text(state),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          _selectedState = newValue!;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _pincodeController,
              label: 'PIN Code',
              hint: 'E.g., 400001',
              keyboardType: TextInputType.number,
              required: true,
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Code + Phone Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 100,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Code',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Text('🇮🇳', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 4),
                            Expanded(child: Text(_phoneCode)),
                            Icon(Icons.arrow_drop_down, size: 18),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    hint: 'E.g., 9876543210',
                    keyboardType: TextInputType.phone,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _emailController,
              label: 'Email',
              hint: 'E.g., store@example.com',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _legalNameController,
              label: 'Legal Business Name',
            ),
            const SizedBox(height: 8),
            Text(
              'As per legal documents',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _websiteController,
              label: 'Website URL',
              hint: 'E.g., https://example.com',
            ),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox
            Row(
              children: [
                SizedBox(
                  height: 24,
                  width: 24,
                  child: Checkbox(
                    value: _isGstEnabled,
                    onChanged: (val) {
                      setState(() {
                        _isGstEnabled = val ?? false;
                        // Auto-select state if not set
                        if (_isGstEnabled &&
                            _selectedGstState == null &&
                            _selectedState != null) {
                          _selectedGstState = _selectedState;
                        }
                      });
                    },
                    activeColor: Colors.blue[700],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Enable GST',
                  style: TextStyle(fontSize: 16, color: Colors.grey[800]),
                ),
              ],
            ),

            if (_isGstEnabled) ...[
              const SizedBox(height: 24),

              // GSTIN
              TextFormField(
                controller: _gstController,
                decoration: InputDecoration(
                  hintText: 'GSTIN *',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'E.g., 22AAAAA0000A1Z5',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),

              const SizedBox(height: 16),

              // GST State
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedGstState,
                    hint: Text(
                      'GST Registered State *',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                    icon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                    items: _indianStates.map((String state) {
                      return DropdownMenuItem<String>(
                        value: state,
                        child: Text(state),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        _selectedGstState = newValue!;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'GST Registration Type',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedGstType,
                    icon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                    items: _gstTypes.map((String type) {
                      return DropdownMenuItem<String>(
                        value: type,
                        child: Text(type),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        _selectedGstType = newValue!;
                      });
                    },
                  ),
                ),
              ),
            ],
          ],
        );
      default:
        return Container();
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool required = false,
    String? errorText,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Make label part of border or outside? Image shows standard outline input with floating label or label inside border.
        // Actually image shows customized input.
        // Let's stick to standard InputDecoration for simplicity and robustness.
        // Wait, image: blue border when active, gray when inactive. Label is floating title in blue.
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ), // Label above
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: (value) {
            if (required && (value == null || value.isEmpty)) {
              return errorText ?? 'This field is required';
            }
            return null;
          },
          onChanged: (val) {
            // For generic validation updates
            if (required) setState(() {});
          },
          decoration: InputDecoration(
            hintText: hint,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
          ),
        ),
        if (required &&
            controller.text.isEmpty &&
            _currentStep ==
                0) // Just showing the error text below field style as per image
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              errorText ?? 'Required',
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
