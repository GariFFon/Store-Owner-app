import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:exanor/models/product_model.dart';
import 'package:exanor/services/api_service.dart';

class ProductVariantSheet extends StatefulWidget {
  final List<dynamic> variants;
  final Product product;
  final String storeId;
  final Function(int) onAddToCartSuccess;

  const ProductVariantSheet({
    super.key,
    required this.variants,
    required this.product,
    required this.storeId,
    required this.onAddToCartSuccess,
  });

  @override
  State<ProductVariantSheet> createState() => _ProductVariantSheetState();
}

class _ProductVariantSheetState extends State<ProductVariantSheet> {
  // Map of Variation Name -> Selected Value ID Strings
  // Using IDs to match API requirements
  final Map<String, String> _selectedVariationIds = {};

  // State for validation
  bool _isValidating = false;
  bool _isAdding = false;
  String? _error;

  // Confirmed details from validation
  double _currentPrice = 0.0;
  bool _isAvailable = true;
  int _quantity = 1;
  String? _productCombinationId;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _initializeSelections();
    // Validate immediately with initial selections
    _validateAvailability();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _initializeSelections() {
    // Parse variants based on user sample structure (nested variants list)
    // Structure: List -> Map with 'variation_name', 'variation_value' (List)
    for (var variantGroup in widget.variants) {
      if (variantGroup is Map) {
        final name = variantGroup['variation_name'];
        final values =
            variantGroup['variation_value']; // Note: 'variation_value' not 'variation_values' based on sample

        if (name != null && values is List && values.isNotEmpty) {
          // Default to first
          final firstVal = values.first;
          if (firstVal is Map && firstVal['id'] != null) {
            _selectedVariationIds[name] = firstVal['id'];
          }
        }
      }
    }
  }

  Future<void> _validateAvailability() async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // Debounce to avoid spamming if user taps rapidly
    _debounce = Timer(const Duration(milliseconds: 200), () async {
      if (!mounted) return;

      setState(() {
        _isValidating = true;
        _error = null;
      });

      try {
        // Construct variations list: just the IDs
        final variationIds = _selectedVariationIds.values.toList();

        final requestBody = {
          "product_id": widget.product.id,
          "store_id": widget.storeId,
          "quantity": _quantity,
          "variations": variationIds,
        };

        final response = await ApiService.post(
          '/validate-product-availability/',
          body: requestBody,
          useBearerToken: true,
        );

        if (response['data'] != null) {
          // status might be != 200 based on availability logic, check body
          final data = response['data']['response'];
          if (data != null) {
            if (mounted) {
              setState(() {
                // Ensure types match API sample
                _isAvailable = data['is_available'] ?? false;

                // Pricing
                if (data['pricing_details'] != null) {
                  _currentPrice =
                      (data['pricing_details']['selling_amount_including_tax']
                              as num)
                          .toDouble();
                }

                _productCombinationId = data['product_combination_id'];
                debugPrint("Validated Combination: $_productCombinationId");
                _isValidating = false;
              });
            }
          } else {
            // Handle unexpected structure
            if (mounted) setState(() => _isValidating = false);
          }
        }
      } catch (e) {
        print("Validation error: $e");
        if (mounted) {
          setState(() {
            _isValidating = false;
            // Don't show error to user immediately on validation fail, just maybe disable button or show unavail
          });
        }
      }
    });
  }

  Future<void> _addToCart() async {
    if (!_isAvailable) return;

    setState(() {
      _isAdding = true;
      _error = null;
    });

    try {
      final requestBody = {
        "quantity": _quantity,
        "product_id": widget.product.id,
        "store_id": widget.storeId,
        "variations": _selectedVariationIds.values.toList(),
      };

      final response = await ApiService.post(
        '/add-product-in-cart/',
        body: requestBody,
        useBearerToken: true,
      );

      if (response['data'] != null && response['data']['status'] == 200) {
        widget.onAddToCartSuccess(_quantity);
      } else {
        setState(() {
          _error = response['data']?['message'] ?? "Failed to add to cart";
        });
      }
    } catch (e) {
      setState(() {
        _error = "An error occurred";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isAdding = false;
        });
      }
    }
  }

  void _updateQuantity(int delta) {
    if (_quantity + delta < 1) return;
    setState(() {
      _quantity += delta;
      // Trigger validation to get updated price or stock check
      _validateAvailability();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 20,
        left: 0,
        right: 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title Header with Padding
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.product.productName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(height: 24),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),

          // Variants List
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.variants.map((variantGroup) {
                  if (variantGroup is! Map) return const SizedBox.shrink();

                  final name = variantGroup['variation_name'] ?? 'Option';
                  final values =
                      variantGroup['variation_value']
                          as List?; // 'variation_value' from sample

                  if (values == null || values.isEmpty)
                    return const SizedBox.shrink();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.toString().toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.grey[600],
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: values.map((val) {
                            final valId = val['id'];
                            final valName =
                                val['variation_value_name'] ??
                                'Unknown'; // from sample
                            final isSelected =
                                _selectedVariationIds[name] == valId;

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedVariationIds[name] = valId;
                                });
                                _validateAvailability(); // Re-validate on change
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? primaryColor.withOpacity(0.1)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? primaryColor
                                        : Colors.grey[300]!,
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Text(
                                  valName,
                                  style: TextStyle(
                                    color: isSelected
                                        ? primaryColor
                                        : Colors.black87,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const Divider(height: 1),

          // Bottom Bar: Quantity + Add Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Quantity Stepper
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => _updateQuantity(-1),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Icon(
                            Icons.remove,
                            size: 20,
                            color: _quantity > 1 ? primaryColor : Colors.grey,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 30,
                        child: Text(
                          '$_quantity',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => _updateQuantity(1),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Icon(Icons.add, size: 20, color: primaryColor),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // Add Item Button
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: (_isAdding || !_isAvailable)
                          ? null
                          : _addToCart,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            primaryColor, // Matching 'Add Item' style often used
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: _isAdding || _isValidating
                          ? Shimmer.fromColors(
                              baseColor: Colors.white.withOpacity(0.4),
                              highlightColor: Colors.white,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'ADD ITEM',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '₹${_currentPrice.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : !_isAvailable
                          ? const Text(
                              'Item Unavailable',
                              style: TextStyle(
                                // Disabled text color is usually handled by theme, but explicit here ensures visibility if needed
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'ADD ITEM',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '₹${_currentPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
