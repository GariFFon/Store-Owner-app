import 'package:flutter/material.dart';
import 'package:exanor/services/api_service.dart';
import 'dart:ui';
import 'package:image_picker/image_picker.dart';
import 'package:exanor/screens/location_selection_screen.dart';

class CreateStoreScreen extends StatefulWidget {
  const CreateStoreScreen({super.key});

  @override
  State<CreateStoreScreen> createState() => _CreateStoreScreenState();
}

class _CreateStoreScreenState extends State<CreateStoreScreen> {
  bool _isLoading = true;
  List<dynamic> _categories = [];
  String? _selectedCategoryId;
  String? _errorMessage;

  // Steps for the sidebar
  final List<String> _steps = [
    "Select your category",
    "Add store details",
    "Upload Store Images",
    "Add GST information",
    "Submit form",
  ];

  int _currentStep = 0;

  // Controllers for Step 2
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // Controllers for Step 4 (Address)
  final TextEditingController _addressLine1Controller = TextEditingController();
  final TextEditingController _addressLine2Controller = TextEditingController();
  final TextEditingController _localityController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();

  // Image files for Step 3
  XFile? _storeLogo;
  XFile? _storeBanner;
  final ImagePicker _picker = ImagePicker();

  // GST Step State
  bool _showGSTForm = false;
  final TextEditingController _gstNumberController = TextEditingController();
  final TextEditingController _gstRegisteredStateController =
      TextEditingController();
  String _gstRegistrationType = 'Regular'; // Regular, Composite
  bool _isTdsEnabled = false;
  bool _isOtherTerritory = false;
  String _gstr1Periodicity = 'Monthly'; // Monthly, Quarterly
  bool _enableGSTRateDetails = false;
  bool _advanceReceiptTaxLiability = false;
  bool _reverseChargeTaxLiability = false;
  bool _enableGSTClassifications = false;
  bool _lutOrBondDetailsProvided = false;

  // E-Way Bill Info
  bool _applicableEWayBill = false;
  final TextEditingController _eWayBillThresholdIncludesController =
      TextEditingController(); // Dropped down? assuming text for now
  final TextEditingController _eWayBillThresholdAmountController =
      TextEditingController(text: '0');
  bool _applicableIntrastateEWayBill = false;
  final TextEditingController _intrastateEWayBillThresholdAmountController =
      TextEditingController(text: '0');

  // E-Invoicing
  bool _applicableEInvoicing = false;

  // GST Certificate
  XFile? _gstCertificate;

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

    // Dispose GST Controllers
    _gstNumberController.dispose();
    _gstRegisteredStateController.dispose();
    _eWayBillThresholdIncludesController.dispose();
    _eWayBillThresholdAmountController.dispose();
    _intrastateEWayBillThresholdAmountController.dispose();

    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final response = await ApiService.post(
        '/store-categories/',
        body: {"query": {}},
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];
        if (data['status'] == 200 && data['response'] != null) {
          if (mounted) {
            setState(() {
              _categories = data['response'] is List ? data['response'] : [];
              _isLoading = false;
            });
          }
        } else {
          _handleError('No categories found');
        }
      } else {
        _handleError('Failed to fetch categories');
      }
    } catch (e) {
      _handleError('Error fetching categories: $e');
    }
  }

  Future<void> _pickImage(bool isLogo) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        if (isLogo) {
          _storeLogo = image;
        } else {
          _storeBanner = image;
        }
      });
    }
  }

  void _handleError(String message) {
    if (mounted) {
      setState(() {
        _errorMessage = message;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Check if screen width is less than 600px (Mobile breakpoint)
            bool isMobile = constraints.maxWidth < 600;

            return Column(
              children: [
                // Top Header: "Create a Store"
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      Text(
                        'Create a Store',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),

                // Responsive Content
                Expanded(
                  child: isMobile
                      ? _buildMobileLayout()
                      : _buildDesktopLayout(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sidebar Stepper
        Container(
          width: 300,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ListView.separated(
            itemCount: _steps.length,
            separatorBuilder: (context, index) => Container(
              margin: const EdgeInsets.only(left: 19),
              height: 30, // Connect lines
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: index < _currentStep
                        ? Colors.blue
                        : Colors.grey.shade300,
                    width: 1,
                  ),
                ),
              ),
            ),
            itemBuilder: (context, index) {
              return _buildStepItem(index);
            },
          ),
        ),

        // Main Content Area
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(40.0),
            child: _buildStepContent(crossAxisCount: 4),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        // Mobile Header Step Indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          color: Colors.grey[50],
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue,
                ),
                child: Text(
                  "${_currentStep + 1}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Step ${_currentStep + 1} of ${_steps.length}",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _steps[_currentStep],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Main Content Area
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: _buildStepContent(crossAxisCount: 2),
          ),
        ),
      ],
    );
  }

  Widget _buildStepContent({required int crossAxisCount}) {
    Widget content;
    String title;
    String subtitle;

    switch (_currentStep) {
      case 0:
        title = 'Choose category';
        subtitle = 'Please choose a category for the store';
        content = _isLoading
            ? Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? Center(child: Text(_errorMessage!))
            : _buildCategoryGrid(crossAxisCount);
        break;
      case 1:
        title = 'Fillup basic details';
        subtitle = 'Please fillup the required fields';
        content = _buildStoreDetailsStep();
        break;
      case 2:
        title = 'Upload Store Images';
        subtitle = 'Choose store logo and banner';
        content = _buildImageUploadStep();
        break;
      case 3:
        title = 'Add GST information';
        subtitle = 'Please fillup your GST information';
        content = _buildGSTStep();
        break;
      default:
        title = _steps[_currentStep];
        subtitle = 'Content for step ${_currentStep + 1}';
        content = Center(child: Text("Step ${_currentStep + 1} Content"));
    }

    // If we are on the Submit Step (Index 4), we render a full custom centred view
    // skipping the standard title/subtitle/button layout.
    if (_currentStep == 4) {
      return _buildSubmitStep();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Text(subtitle, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
        const SizedBox(height: 40),
        Expanded(child: content),

        // Bottom Actions
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () async {
                // If on GST Step (3), Back goes to Map Selection
                if (_currentStep == 3) {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LocationSelectionScreen(
                        isStoreCreationMode: true,
                      ),
                    ),
                  );

                  if (mounted) {
                    if (result != null && result is Map<String, dynamic>) {
                      setState(() {
                        _updateAddressFromResult(result);
                        // Stay on Step 3 (GST) as we just finished map
                      });
                    } else {
                      // User cancelled Map, go back to Images (Step 2)
                      setState(() {
                        _currentStep = 2;
                      });
                    }
                  }
                  return;
                }

                if (_currentStep > 0) {
                  setState(() {
                    _currentStep--;
                  });
                } else {
                  Navigator.pop(context);
                }
              },
              child: Text(
                'Back',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                if (_currentStep < _steps.length - 1) {
                  // Validate selection
                  if (_currentStep == 0 && _selectedCategoryId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Please select a category")),
                    );
                    return;
                  }
                  if (_currentStep == 1) {
                    if (_storeNameController.text.isEmpty ||
                        _phoneController.text.isEmpty ||
                        _emailController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Please fill all fields")),
                      );
                      return;
                    }
                  }

                  // Step 2: Upload Store Images -> Map
                  if (_currentStep == 2) {
                    // Proceed to Map Selection
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LocationSelectionScreen(
                          isStoreCreationMode: true,
                        ),
                      ),
                    );

                    if (result != null && result is Map<String, dynamic>) {
                      setState(() {
                        _updateAddressFromResult(result);

                        // Advance to next step (GST)
                        _currentStep++;
                      });
                    }
                    return;
                  }

                  setState(() {
                    _currentStep++;
                  });
                }
              },
              child: Text(
                'Next',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStoreDetailsStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField("Store Name *", _storeNameController),
          const SizedBox(height: 20),
          _buildTextField("Phone Number *", _phoneController, isNumber: true),
          const SizedBox(height: 20),
          _buildTextField("Email *", _emailController, isEmail: true),
        ],
      ),
    );
  }

  Widget _buildImageUploadStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Store Logo",
            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _pickImage(true),
            child: Row(
              children: [
                Text(
                  "Choose file",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 10),
                Text(
                  _storeLogo != null ? _storeLogo!.name : "No file chosen",
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "Store Banner",
            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _pickImage(false),
            child: Row(
              children: [
                Text(
                  "Choose file",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 10),
                Text(
                  _storeBanner != null ? _storeBanner!.name : "No file chosen",
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGSTStep() {
    if (!_showGSTForm) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Do you have a GST number?",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              ElevatedButton(
                onPressed: () {
                  // NO, SUBMIT -> Skip GST form, go to next step
                  setState(() {
                    _currentStep++;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: Text("NO, SUBMIT"),
              ),
              const SizedBox(width: 16),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _showGSTForm = true;
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: BorderSide(color: Colors.blue.shade200),
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: Text("YES, GO TO GST FORM"),
              ),
            ],
          ),
        ],
      );
    }

    // Full GST Form
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "GST Information",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _showGSTForm = false;
                  });
                },
                child: Text(
                  "No GST Number?",
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            ],
          ),
          Text(
            "Please fillup your GST information",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),

          _buildTextField("GST Number", _gstNumberController),
          const SizedBox(height: 16),
          _buildTextField(
            "GST Registered State",
            _gstRegisteredStateController,
          ),
          const SizedBox(height: 24),

          Text(
            "GST Registration Type",
            style: TextStyle(color: Colors.grey[700], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildRadio(
                "Regular",
                _gstRegistrationType,
                (val) => setState(() => _gstRegistrationType = val!),
              ),
              const SizedBox(width: 20),
              _buildRadio(
                "Composite",
                _gstRegistrationType,
                (val) => setState(() => _gstRegistrationType = val!),
              ),
            ],
          ),

          const SizedBox(height: 16),
          _buildCheckbox(
            "Tds enabled",
            _isTdsEnabled,
            (val) => setState(() => _isTdsEnabled = val!),
          ),
          _buildCheckbox(
            "Access of Other Territory",
            _isOtherTerritory,
            (val) => setState(() => _isOtherTerritory = val!),
          ),

          const SizedBox(height: 24),
          Text(
            "GSTR1 Periodicity",
            style: TextStyle(color: Colors.grey[700], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildRadio(
                "Monthly",
                _gstr1Periodicity,
                (val) => setState(() => _gstr1Periodicity = val!),
                groupValueOverride: _gstr1Periodicity,
              ),
              const SizedBox(width: 20),
              _buildRadio(
                "Quarterly",
                _gstr1Periodicity,
                (val) => setState(() => _gstr1Periodicity = val!),
                groupValueOverride: _gstr1Periodicity,
              ),
            ],
          ),

          const SizedBox(height: 16),
          _buildCheckbox(
            "Enable GST Rate Details",
            _enableGSTRateDetails,
            (val) => setState(() => _enableGSTRateDetails = val!),
          ),
          _buildCheckbox(
            "Advance Receipt Tax Liability",
            _advanceReceiptTaxLiability,
            (val) => setState(() => _advanceReceiptTaxLiability = val!),
          ),
          _buildCheckbox(
            "Reverse Charge Tax Liability",
            _reverseChargeTaxLiability,
            (val) => setState(() => _reverseChargeTaxLiability = val!),
          ),
          _buildCheckbox(
            "Enable GST Classifications",
            _enableGSTClassifications,
            (val) => setState(() => _enableGSTClassifications = val!),
          ),
          _buildCheckbox(
            "LUT or Bond Details Provided",
            _lutOrBondDetailsProvided,
            (val) => setState(() => _lutOrBondDetailsProvided = val!),
          ),

          const SizedBox(height: 24),
          Text(
            "E-Way Bill Information",
            style: TextStyle(color: Colors.grey[700], fontSize: 16),
          ),
          const SizedBox(height: 8),
          _buildCheckbox(
            "Applicable E-Way Bill",
            _applicableEWayBill,
            (val) => setState(() => _applicableEWayBill = val!),
          ),

          if (_applicableEWayBill) ...[
            const SizedBox(height: 16),
            _buildTextField(
              "E-Way Bill Threshold Includes",
              _eWayBillThresholdIncludesController,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              "E-Way Bill Threshold Amount",
              _eWayBillThresholdAmountController,
              isNumber: true,
            ),
            const SizedBox(height: 16),
            _buildCheckbox(
              "Applicable Intrastate E-Way Bill",
              _applicableIntrastateEWayBill,
              (val) => setState(() => _applicableIntrastateEWayBill = val!),
            ),
            if (_applicableIntrastateEWayBill) ...[
              const SizedBox(height: 16),
              _buildTextField(
                "Intrastate E-Way Bill Threshold Amount",
                _intrastateEWayBillThresholdAmountController,
                isNumber: true,
              ),
            ],
          ],

          const SizedBox(height: 24),
          Text(
            "E-Invoicing Information",
            style: TextStyle(color: Colors.grey[700], fontSize: 16),
          ),
          const SizedBox(height: 8),
          _buildCheckbox(
            "Applicable E-Invoicing",
            _applicableEInvoicing,
            (val) => setState(() => _applicableEInvoicing = val!),
          ),

          const SizedBox(height: 24),
          Text(
            "GST Certificate",
            style: TextStyle(color: Colors.grey[700], fontSize: 16),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final XFile? file = await _picker.pickImage(
                source: ImageSource.gallery,
              );
              if (file != null) {
                setState(() {
                  _gstCertificate = file;
                });
              }
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Text(
                    "Choose file",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _gstCertificate != null
                          ? _gstCertificate!.name
                          : "No file chosen",
                      style: TextStyle(color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildRadio(
    String label,
    String groupValue,
    Function(String?) onChanged, {
    String? groupValueOverride,
  }) {
    // groupValueOverride is used because I reused the variable name in signature incorrectly in my thought process,
    // but the radio widget needs the actual group value.
    // Actually, I can just use the groupValue passed in.
    // Wait, for GSTR1 periodicity, I used `_gstr1Periodicity` which is a String.
    // `groupValue` argument is the current selected value.
    // `value` argument is the value represented by this radio.
    // So the signature should be `_buildRadio(String label, String value, String groupValue, ...)`?
    // Let's simplify: `_buildRadio(String label, String value, Function(String?) onChanged)` and access state directly? No, helper should be pure-ish.

    // Let's redefine helper signature in implementation below.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Radio<String>(
          value:
              label, // Using label as value for simplicity, e.g. "Monthly", "Regular"
          groupValue: groupValue,
          onChanged: onChanged,
          activeColor: Colors.blue,
        ),
        Text(label),
      ],
    );
  }

  Widget _buildCheckbox(String label, bool value, Function(bool?) onChanged) {
    return Row(
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.blue,
          side: BorderSide(color: Colors.grey),
        ),
        Text(label),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
    bool isEmail = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: TextField(
            controller: controller,
            keyboardType: isNumber
                ? TextInputType.phone
                : isEmail
                ? TextInputType.emailAddress
                : TextInputType.text,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: label,
              hintStyle: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepItem(int index) {
    bool isActive = index == _currentStep;
    bool isCompleted = index < _currentStep;

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? Colors.blue
                : isCompleted
                ? Colors.grey.shade300
                : Colors.grey.shade200,
          ),
          child: Text(
            "${index + 1}",
            style: TextStyle(
              color: isActive ? Colors.white : Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          _steps[index],
          style: TextStyle(
            fontSize: 16,
            fontWeight: isActive || isCompleted
                ? FontWeight.w600
                : FontWeight.w400,
            color: isActive ? Colors.black : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryGrid(int crossAxisCount) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.8,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        final isSelected = _selectedCategoryId == category['id'];

        return InkWell(
          onTap: () {
            setState(() {
              _selectedCategoryId = category['id'];
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      color: isSelected ? Colors.blue : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.1),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                    ],
                  ),
                  child: Image.network(
                    category['category_icon'] ?? '',
                    errorBuilder: (ctx, _, __) =>
                        Icon(Icons.category, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                category['category_name'] ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                  overflow: TextOverflow.ellipsis,
                ),
                maxLines: 2,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubmitStep() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Review & Submit",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Please review all the information before\nsubmitting your store registration",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _currentStep--;
                  });
                },
                child: Text(
                  "Go Back",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              ElevatedButton(
                onPressed: _submitStoreForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: Text(
                  "Submit Form",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submitStoreForm() async {
    // TODO: Implement API submission
    print("Submitting Store Form...");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Submitting form... (Mock implementation)")),
    );
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
}
