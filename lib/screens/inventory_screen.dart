import 'package:flutter/material.dart';
import 'package:exanor/services/store_owner_api_service.dart';
import 'package:exanor/components/translation_widget.dart';

class InventoryScreen extends StatefulWidget {
  final String storeId;

  const InventoryScreen({super.key, required this.storeId});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _godowns = [];
  List<Map<String, dynamic>> _racks = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        StoreOwnerApiService.getGodowns(widget.storeId),
        StoreOwnerApiService.getRacks(widget.storeId),
      ]);

      setState(() {
        _godowns = results[0];
        _racks = results[1];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getRacksForGodown(String godownId) {
    return _racks.where((rack) => rack['godown'] == godownId).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB), // Light gray background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const TranslatedText(
          'Inventory',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 32),
                  _buildGodownList(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    final bool isSmallScreen = MediaQuery.of(context).size.width < 600;

    Widget textSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TranslatedText(
          'Inventory Management',
          style: TextStyle(
            fontSize: isSmallScreen ? 24 : 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TranslatedText(
          'Manage your godowns, racks, and products',
          style: TextStyle(
            fontSize: isSmallScreen ? 14 : 16,
            color: Colors.black54,
          ),
        ),
      ],
    );

    Widget addButton = ElevatedButton.icon(
      onPressed: () {
        _showGodownSheet();
      },
      icon: const Icon(Icons.add, size: 20),
      label: const TranslatedText('Add Godown'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF007BFF), // Bright Blue
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
    );

    if (isSmallScreen) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          textSection,
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: addButton),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: textSection),
        const SizedBox(width: 16),
        addButton,
      ],
    );
  }

  Widget _buildGodownList() {
    if (_godowns.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: TranslatedText('No godowns found'),
        ),
      );
    }

    // Use Wrap for responsive layout (similar to grid)
    return Wrap(
      spacing: 24,
      runSpacing: 24,
      children: _godowns.map((godown) => _buildGodownCard(godown)).toList(),
    );
  }

  Widget _buildGodownCard(Map<String, dynamic> godown) {
    final godownId = godown['id'];
    final godownName = godown['name'] ?? 'Unknown Godown';
    final godownRacks = _getRacksForGodown(godownId);
    final activeRacksCount = godownRacks
        .where((r) => r['is_active'] == true)
        .length;
    final totalRacksCount = godownRacks.length;

    // Use LayoutBuilder to calculate width or use a fixed width/flex
    // Since we are inside a Wrap, let's give it a fixed width for desktop feel or full width for mobile
    // Adapting to screen width is better.
    return LayoutBuilder(
      builder: (context, constraints) {
        double cardWidth = constraints.maxWidth;
        // If screen is wide, show 2 cards per row (approx)
        if (MediaQuery.of(context).size.width > 800) {
          // Subtracting padding and spacing
          cardWidth = (MediaQuery.of(context).size.width - 48 - 24) / 2;
        }

        return Container(
          width: cardWidth,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEBF5FF), // Light blue bg
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.warehouse_outlined,
                      color: Color(0xFF007BFF),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          godownName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$activeRacksCount/$totalRacksCount racks active',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.edit_outlined,
                      color: Colors.grey.shade500,
                    ),
                    onPressed: () {
                      _showGodownSheet(godown: godown);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Racks Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Racks (${godownRacks.length})',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      // TODO: Add Rack
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const TranslatedText('Add Rack'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF007BFF),
                      textStyle: const TextStyle(fontWeight: FontWeight.w600),
                      backgroundColor: const Color(0xFFEBF5FF),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Racks List
              if (godownRacks.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Center(
                    child: Text(
                      'No racks created yet',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                      ),
                    ),
                  ),
                )
              else
                SizedBox(
                  height:
                      100, // Fixed height for racks row (scrollable if needed?)
                  // The image shows wrapping or just a few items. Let's use Wrap inside if items are few, or horizontal scroll.
                  // Image shows row. Let's try horizontal list view for racks.
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: godownRacks.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final rack = godownRacks[index];
                      return _buildRackItem(rack);
                    },
                  ),
                ),

              const SizedBox(height: 24),
              Divider(height: 1, color: Colors.grey.shade200),
              const SizedBox(height: 16),

              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: (godown['is_active'] == true)
                          ? const Color(0xFFDCFCE7) // Light green
                          : const Color(0xFFFEE2E2), // Light red
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      (godown['is_active'] == true) ? 'Active' : 'Inactive',
                      style: TextStyle(
                        color: (godown['is_active'] == true)
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFDC2626),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  // Address or Godown Name/Code at bottom right?
                  // The image shows 'G2' with a pin icon.
                  // The response has 'address' field.
                  if (godown['address'] != null || godown['name'] != null)
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          godown['address'] ?? godown['name'] ?? '',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRackItem(Map<String, dynamic> rack) {
    return Container(
      width: 100,
      decoration: BoxDecoration(
        color: const Color(0xFFFAF5FF), // Light purple tint from image
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF3E8FF)),
      ),
      padding: const EdgeInsets.all(12),
      child: Center(
        child: Text(
          rack['name'] ?? 'Rack',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF9333EA), // Purple text
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  void _showGodownSheet({Map<String, dynamic>? godown}) {
    final isEdit = godown != null;
    final nameController = TextEditingController(text: godown?['name'] ?? '');
    final descriptionController = TextEditingController(
      text: godown?['description'] ?? '',
    );
    final addressController = TextEditingController(
      text: godown?['address'] ?? '',
    );
    bool isPrimary = godown?['is_primary'] ?? false;
    bool isActive = godown?['is_active'] ?? true;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TranslatedText(
                          isEdit ? 'Edit Godown' : 'Create New Godown',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Form
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTextField(
                            controller: nameController,
                            label: 'Godown Name *',
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: descriptionController,
                            label: 'Description',
                            maxLines: 4,
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: addressController,
                            label: 'Address',
                            maxLines: 3,
                          ),
                          const SizedBox(height: 24),

                          _buildSwitch(
                            title: 'Primary Godown',
                            subtitle: 'Set as the main warehouse',
                            value: isPrimary,
                            onChanged: (val) {
                              setSheetState(() => isPrimary = val);
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildSwitch(
                            title: 'Active Status',
                            subtitle: 'Enable or disable this godown',
                            value: isActive,
                            onChanged: (val) {
                              setSheetState(() => isActive = val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Footer
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Spacer(), // Spacer
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: const TranslatedText(
                            'Cancel',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (nameController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Godown Name is required',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  setSheetState(() => isSubmitting = true);

                                  try {
                                    if (isEdit) {
                                      await StoreOwnerApiService.updateGodown(
                                        storeId: widget.storeId,
                                        godownId: godown['id'],
                                        name: nameController.text.trim(),
                                        description: descriptionController.text
                                            .trim(),
                                        address: addressController.text.trim(),
                                        isActive: isActive,
                                        isPrimary: isPrimary,
                                      );
                                    } else {
                                      await StoreOwnerApiService.createGodown(
                                        storeId: widget.storeId,
                                        name: nameController.text.trim(),
                                        description: descriptionController.text
                                            .trim(),
                                        address: addressController.text.trim(),
                                        isActive: isActive,
                                        isPrimary: isPrimary,
                                      );
                                    }

                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      _fetchData(); // Refresh list
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            isEdit
                                                ? 'Godown updated successfully'
                                                : 'Godown created successfully',
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(content: Text('Error: $e')),
                                      );
                                    }
                                  } finally {
                                    if (context.mounted) {
                                      setSheetState(() => isSubmitting = false);
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF007BFF),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : TranslatedText(
                                  isEdit ? 'Update' : 'Create',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: label,
        hintStyle: TextStyle(color: Colors.grey[400]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF007BFF)),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Transform.scale(
          scale: 0.8,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF007BFF),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
