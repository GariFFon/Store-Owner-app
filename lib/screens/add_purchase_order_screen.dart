import 'dart:io';
import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/services/store_owner_api_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:exanor/screens/supplier_details_screen.dart';
import 'package:exanor/screens/product_details_screen.dart';

class AddPurchaseOrderScreen extends StatefulWidget {
  final String storeId;

  const AddPurchaseOrderScreen({super.key, required this.storeId});

  @override
  State<AddPurchaseOrderScreen> createState() => _AddPurchaseOrderScreenState();
}

class _AddPurchaseOrderScreenState extends State<AddPurchaseOrderScreen> {
  bool _isLoading = true;
  int _currentStep = 0;

  // Data from APIs
  List<Map<String, dynamic>> _units = [];
  List<Map<String, dynamic>> _godowns = [];
  List<Map<String, dynamic>> _racks = [];

  // Form Data
  String? _selectedSupplier;
  DateTime? _purchaseDate;
  final TextEditingController _invoiceIdController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  final List<String> _steps = [
    'Basic information',
    'Add products',
    'Add payment data',
    'Confirmation',
  ];

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    try {
      final results = await Future.wait([
        StoreOwnerApiService.getUnits(widget.storeId),
        StoreOwnerApiService.getGodowns(widget.storeId),
        StoreOwnerApiService.getRacks(widget.storeId),
      ]);

      if (mounted) {
        setState(() {
          _units = results[0];
          _godowns = results[1];
          _racks = results[2];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _purchaseDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  @override
  void dispose() {
    _invoiceIdController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(
        0xFFF8F9FD,
      ), // Light background like in image
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.pop(context)),
        title: const TranslatedText(
          'Back to Purchase List',
          style: TextStyle(fontSize: 14, color: Colors.blue),
        ),
        titleSpacing: 0,
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.blue),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                // Responsive layout:
                // formatted for mobile/tablet where we might stack or use Row
                // The image shows side-by-side, which implies wide screen.
                // Assuming mobile first, we might just put steps on top or use a distinct design.
                // However, let's try to match the "Two column" feel if space permits,
                // or just put the stepper at top for mobile.

                final isWide = constraints.maxWidth > 800;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: isWide
                      ? Column(
                          children: [
                            _buildHorizontalStepper(theme),
                            const SizedBox(height: 32),
                            Expanded(child: _buildCurrentStepContent(theme)),
                          ],
                        )
                      : Column(
                          children: [
                            _buildHorizontalStepper(theme),
                            const SizedBox(height: 24),
                            _buildCurrentStepContent(theme),
                          ],
                        ),
                );
              },
            ),
    );
  }

  Widget _buildHorizontalStepper(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(_steps.length, (index) {
              final isActive = index == _currentStep;
              final isCompleted = index < _currentStep;
              final isLast = index == _steps.length - 1;

              return Expanded(
                child: Row(
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isActive || isCompleted
                                ? Colors.blue
                                : Colors.grey[300],
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          height: 2,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          color: isCompleted ? Colors.blue : Colors.grey[300],
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(_steps.length, (index) {
              final isActive = index == _currentStep;
              return Expanded(
                child: Text(
                  _steps[index],
                  style: TextStyle(
                    fontSize: 12, // Smaller font for horizontal layout
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive ? Colors.blue : theme.colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Future<void> _showIntelligenceDialog() async {
    final result = await showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing while analyzing
      builder: (context) => IntelligenceUploadDialog(storeId: widget.storeId),
    );

    if (result != null && result is Map<String, dynamic> && mounted) {
      // Navigate to Supplier Details Screen
      final shouldContinue = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => SupplierDetailsScreen(data: result),
        ),
      );

      // If user clicked Continue on Supplier Details, show Product Details
      if (shouldContinue == true && mounted) {
        final productContinue = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailsScreen(data: result),
          ),
        );

        // If user clicked Continue on Product Details, populate the form
        if (productContinue == true && mounted) {
          _populateFormFromAi(result);
        }
      }
    }
  }

  void _populateFormFromAi(Map<String, dynamic> data) {
    setState(() {
      // Map fields
      if (data.containsKey('invoice_id')) {
        _invoiceIdController.text = data['invoice_id'].toString();
      }

      if (data.containsKey('invoice_date')) {
        // Parse date if possible
        try {
          final dateStr = data['invoice_date'].toString();
          // Assuming date format, might need adjustment based on API
          // If API returns yyyy-MM-dd, great.
          _dateController.text = dateStr;
          _purchaseDate = DateTime.tryParse(dateStr);
        } catch (e) {
          debugPrint('Error parsing date: $e');
        }
      }

      // Handle supplier selection if specific logic exists
      // For now we just log
      debugPrint('Populating from AI: $data');
    });
  }

  Widget _buildCurrentStepContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add Purchase Order',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _steps[_currentStep],
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Exanor Intelligence Button
              InkWell(
                onTap: _showIntelligenceDialog,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Fill Up with Exanor Intelligence',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.auto_awesome,
                        color: Colors.white.withOpacity(0.8),
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Form Content based on step
              if (_currentStep == 0) _buildStep1Form(theme),
              if (_currentStep == 1)
                Center(
                  child: Text(
                    "Product Selection Here (Units: ${_units.length}, Godowns: ${_godowns.length}, Racks: ${_racks.length})",
                  ),
                ),

              const SizedBox(height: 32),

              // Navigation Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: () => setState(() => _currentStep--),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                      child: const Text('Previous'),
                    ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      if (_currentStep < _steps.length - 1) {
                        setState(() => _currentStep++);
                      } else {
                        // Submit
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _currentStep == _steps.length - 1 ? 'Submit' : 'Next',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep1Form(ThemeData theme) {
    return Column(
      children: [
        // Supplier Dropdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedSupplier,
              hint: const Text('Pick a supplier'),
              isExpanded: true,
              items: ['Supplier A', 'Supplier B', 'Other'].map((String value) {
                // TODO: Fetch suppliers real data
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedSupplier = newValue;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Purchase Date
        InkWell(
          onTap: _selectDate,
          child: IgnorePointer(
            child: TextField(
              controller: _dateController,
              decoration: InputDecoration(
                labelText: 'Purchase Date *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Supplier Invoice Id
        TextField(
          controller: _invoiceIdController,
          decoration: InputDecoration(
            labelText: 'Supplier Invoice Id *',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.dividerColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.dividerColor),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }
}

class IntelligenceUploadDialog extends StatefulWidget {
  final String storeId;
  const IntelligenceUploadDialog({super.key, required this.storeId});

  @override
  State<IntelligenceUploadDialog> createState() =>
      _IntelligenceUploadDialogState();
}

class _IntelligenceUploadDialogState extends State<IntelligenceUploadDialog> {
  File? _selectedFile;
  bool _isAnalyzing = false;

  // To store the response if needed or just handle navigation
  // dynamic _analysisResult;

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
        });
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
  }

  Future<void> _analyzeWithAi() async {
    if (_selectedFile == null) return;

    setState(() {
      _isAnalyzing = true;
    });

    try {
      // Get Location
      // Get Location
      Position? position;
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          debugPrint('Location services are disabled.');
        } else {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }

          if (permission == LocationPermission.denied) {
            debugPrint('Location permissions are denied');
          } else if (permission == LocationPermission.deniedForever) {
            debugPrint('Location permissions are permanently denied');
          } else {
            // Try last known position first for speed
            position = await Geolocator.getLastKnownPosition();

            // If no last known position, get current
            position ??= await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.medium,
              timeLimit: const Duration(seconds: 5),
            );
          }
        }
      } catch (e) {
        debugPrint('Error getting location: $e');
      }

      final lat = position?.latitude ?? 0.0;
      final lng = position?.longitude ?? 0.0;

      debugPrint('📍 Location found: $lat, $lng');
      debugPrint('📤 Sending Payload to /purchase-entry-intelligence/:');
      debugPrint('   - store_id: ${widget.storeId}');
      debugPrint('   - store_access: true');
      debugPrint('   - file: (binary) ${_selectedFile!.path.split('/').last}');
      debugPrint('   - lat: $lat');
      debugPrint('   - lng: $lng');

      final result = await StoreOwnerApiService.uploadPurchaseInvoice(
        widget.storeId,
        _selectedFile!,
        lat,
        lng,
      );

      if (mounted) {
        // Close the dialog and return result
        Navigator.pop(context, result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Analysis failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAnalyzing) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(32),
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.psychology,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Analyzing with AI...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'AI is processing your data...',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 24),
              LinearProgressIndicator(backgroundColor: Colors.grey[200]),
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '35% Complete',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  Text(
                    'Step 2 of 4',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Dialog(
      backgroundColor: Colors.black, // Dark theme as per screenshot
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 600, // Wide dialog
        padding: const EdgeInsets.all(0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.white),
                  const SizedBox(width: 8),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upload Invoice',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Upload and analyze your purchase invoice',
                        style: TextStyle(color: Colors.grey, fontSize: 10),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Container(color: Colors.white, height: 1), // Divider
            // Body
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Upload Invoice',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Upload a PDF, JPG, or PNG file of your purchase invoice',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),

                  // Upload Area
                  GestureDetector(
                    onTap: _pickFile,
                    child: Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.grey[300]!,
                          style: BorderStyle.solid,
                        ), // Should be dashed ideally
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey[50], // Light background
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_selectedFile != null) ...[
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _selectedFile!.path.split('/').last,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton(
                              onPressed: _pickFile,
                              child: const Text("Change File"),
                            ),
                          ] else ...[
                            const Icon(
                              Icons.cloud_upload,
                              color: Colors.grey,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Click to upload or drag and drop',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'PDF, JPG, or PNG (Max 10MB)',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Footer Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('CANCEL'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: _selectedFile != null
                            ? _analyzeWithAi
                            : null,
                        icon: const Icon(Icons.auto_awesome, size: 16),
                        label: const Text('Analyze with AI'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black, // Dark button
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
