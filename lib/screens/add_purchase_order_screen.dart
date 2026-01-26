import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/services/store_owner_api_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 250,
                              child: _buildVerticalStepper(theme),
                            ),
                            const SizedBox(width: 32),
                            Expanded(child: _buildCurrentStepContent(theme)),
                          ],
                        )
                      : Column(
                          children: [
                            _buildVerticalStepper(
                              theme,
                            ), // Or horizontal for mobile
                            const SizedBox(height: 24),
                            _buildCurrentStepContent(theme),
                          ],
                        ),
                );
              },
            ),
    );
  }

  Widget _buildVerticalStepper(ThemeData theme) {
    return Column(
      children: List.generate(_steps.length, (index) {
        final isActive = index == _currentStep;
        final isCompleted = index < _currentStep;

        return InkWell(
          onTap: () {
            // Optional: Allow jumping steps if accessible
            // setState(() => _currentStep = index);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 24),
            child: Row(
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
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STEP ${index + 1}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      _steps[index],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isActive
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isActive
                            ? Colors.blue
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }),
    );
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
              Container(
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
