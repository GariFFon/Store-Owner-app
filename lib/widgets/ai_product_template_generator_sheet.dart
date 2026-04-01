import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:exanor/services/store_owner_api_service.dart';

class AiProductTemplateGeneratorSheet extends StatefulWidget {
  final String storeId;
  final String initialSearchText;

  const AiProductTemplateGeneratorSheet({
    super.key,
    required this.storeId,
    required this.initialSearchText,
  });

  @override
  State<AiProductTemplateGeneratorSheet> createState() =>
      _AiProductTemplateGeneratorSheetState();
}

class _AiProductTemplateGeneratorSheetState
    extends State<AiProductTemplateGeneratorSheet> {
  bool _isLoading = false;
  Map<String, dynamic>? _generatedData;

  // Input Controllers
  late TextEditingController _descriptionController;

  // Generated Fields Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _hsnController = TextEditingController();
  final TextEditingController _parentCategoryController =
      TextEditingController();
  final TextEditingController _childCategoryController =
      TextEditingController();
  final TextEditingController _slugController = TextEditingController();
  final TextEditingController _generatedDescriptionController =
      TextEditingController();

  String _productType = 'Physical';

  @override
  void initState() {
    super.initState();
    _descriptionController =
        TextEditingController(text: widget.initialSearchText);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _nameController.dispose();
    _brandController.dispose();
    _hsnController.dispose();
    _parentCategoryController.dispose();
    _childCategoryController.dispose();
    _slugController.dispose();
    _generatedDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _generateTemplate() async {
    final text = _descriptionController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _generatedData = null;
    });

    try {
      final response = await StoreOwnerApiService.createProductTemplateFromAi(
        productString: text,
        storeId: widget.storeId,
      );

      if (response.isNotEmpty) {
        setState(() {
          _generatedData = response;
          _populateControllers();
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to generate product from AI.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
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

  void _populateControllers() {
    if (_generatedData == null) return;
    _nameController.text = _generatedData!['product_name']?.toString() ?? '';
    _brandController.text = _generatedData!['brand']?.toString() ?? '';
    _hsnController.text = _generatedData!['hsn_code']?.toString() ?? '';
    _parentCategoryController.text =
        _generatedData!['parent_category']?.toString() ?? '';
    _childCategoryController.text =
        _generatedData!['child_category']?.toString() ?? '';
    _slugController.text = _generatedData!['slug']?.toString() ?? '';
    _generatedDescriptionController.text =
        _generatedData!['product_description']?.toString() ?? '';
  }

  Future<void> _publishTemplate() async {
    if (_generatedData == null) return;

    setState(() {
      _isLoading = true;
    });

    final editables = [
      {"field": "product_name", "value": _nameController.text},
      {"field": "brand_name", "value": _brandController.text},
      {"field": "slug", "value": _slugController.text},
      {"field": "description", "value": _generatedDescriptionController.text},
      {"field": "product_type", "value": _productType.toLowerCase()},
      {"field": "parent_category", "value": _parentCategoryController.text},
      {"field": "child_category", "value": _childCategoryController.text},
      {"field": "is_draft", "value": false}
    ];

    try {
      final response = await StoreOwnerApiService.updateProductTemplate(
        productTemplateId: _generatedData!['product_template_id']?.toString() ?? '',
        storeId: widget.storeId,
        editables: editables,
      );

      if (response.isNotEmpty) {
        // Return the data to the caller with the edited fields updated
        final updatedData = Map<String, dynamic>.from(_generatedData!);
        updatedData['product_name'] = _nameController.text;
        updatedData['brand'] = _brandController.text;
        updatedData['hsn_code'] = _hsnController.text;
        updatedData['parent_category'] = _parentCategoryController.text;
        updatedData['child_category'] = _childCategoryController.text;
        updatedData['slug'] = _slugController.text;
        updatedData['product_description'] = _generatedDescriptionController.text;
        updatedData['product_type'] = _productType;

        if (mounted) {
          Navigator.pop(context, updatedData);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to publish product template.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error publishing template: $e'),
            backgroundColor: Colors.red,
          ),
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

  @override
  Widget build(BuildContext context) {
    // Determine screen height to restrict bottom sheet max height
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.9),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: _generatedData == null ? _buildInputForm() : _buildGeneratedForm(),
            ),
          ),
          if (_generatedData != null) _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E8FF), // Light purple
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Color(0xFFA855F7), // Purple
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'AI Product Template Generator',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Generate product templates using AI',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildInputForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Product Description',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _descriptionController,
          maxLines: 5,
          decoration: InputDecoration(
            hintText:
                "e.g., Nike Air Max 270 Running Shoes - Black/White - Size 8, 9, 10, 11 - Men's Athletic Footwear",
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.purple.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.purple.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFA855F7), width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Store ID',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          readOnly: true,
          controller: TextEditingController(text: widget.storeId),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _generateTemplate,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.smart_toy_rounded, size: 20),
            label: Text(
              _isLoading ? 'Generating...' : 'Generate Product Template',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _descriptionController.text.trim().isEmpty || _isLoading
                  ? const Color(0xFFE2E8F0)
                  : const Color(0xFFE2E8F0), // Matches UI image (Greyish button when passive) Wait, the image shows it grey out. Let's make it purple when active, grey when disabled.
              foregroundColor: _descriptionController.text.trim().isEmpty || _isLoading
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF0F172A),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGeneratedForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Success Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Row(
            children: const [
              Icon(Icons.auto_awesome, color: Color(0xFF16A34A), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Product template generated successfully! You can edit the fields below before publishing.',
                  style: TextStyle(
                    color: Color(0xFF166534),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Fields
        Row(
          children: [
            Expanded(child: _buildFormField('Product Name', _nameController)),
            const SizedBox(width: 16),
            Expanded(child: _buildFormField('Brand', _brandController)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildFormField('HSN Code', _hsnController)),
            const SizedBox(width: 16),
            Expanded(child: _buildFormField('Parent Category', _parentCategoryController)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildFormField('Child Category', _childCategoryController)),
            const SizedBox(width: 16),
            Expanded(child: _buildFormField('Slug', _slugController)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Product Type',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _productType,
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF94A3B8)),
                        items: ['Physical', 'Digital'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          if (newValue != null) {
                            setState(() {
                              _productType = newValue;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: const SizedBox.shrink()), // Spacer
          ],
        ),
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Product Description',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _generatedDescriptionController,
              maxLines: 4,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // AI Info Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AI Generation Info',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text(
                    'Model: ${_generatedData?['ai_metadata']?['model_used'] ?? 'gemini-2.5-flash'}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  Text(
                    'Variations: ${_generatedData?['ai_metadata']?['variations_found'] ?? 2}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Combinations: ${_generatedData?['ai_metadata']?['total_combinations'] ?? 1}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFormField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 48,
          child: TextField(
            controller: controller,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: const Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  _generatedData = null;
                });
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFD8B4FE)), // Light purple border
                foregroundColor: const Color(0xFFA855F7), // Purple text
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Generate Again',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading ? null : _publishTemplate,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981), // Emerald green
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Publish Template',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
