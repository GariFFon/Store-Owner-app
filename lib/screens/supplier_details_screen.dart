import 'package:flutter/material.dart';
import 'package:exanor/services/store_owner_api_service.dart';

class SupplierDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final String storeId;

  const SupplierDetailsScreen({
    super.key,
    required this.data,
    required this.storeId,
  });

  @override
  State<SupplierDetailsScreen> createState() => _SupplierDetailsScreenState();
}

class _SupplierDetailsScreenState extends State<SupplierDetailsScreen> {
  bool _isCreatingSupplier = false;
  bool _isSearchingSupplier = false;
  String? _supplierStoreId;
  bool _supplierCreated = false;

  @override
  void initState() {
    super.initState();
    _checkAndSearchSupplier();
  }

  Future<void> _checkAndSearchSupplier() async {
    final response = widget.data['response'] ?? {};
    final supplierDetails = response['supplier_details'] ?? {};
    final bool supplierExists =
        supplierDetails['supplier_already_exists'] ?? false;
    final gstIn = supplierDetails['supplier_gst_in'] ?? '';

    if (supplierExists && gstIn.isNotEmpty) {
      setState(() {
        _isSearchingSupplier = true;
      });

      try {
        final stores = await StoreOwnerApiService.searchStore(gstIn);
        if (stores.isNotEmpty && mounted) {
          setState(() {
            _supplierStoreId = stores[0]['id']?.toString();
            _isSearchingSupplier = false;
          });
          debugPrint('Found supplier store ID: $_supplierStoreId');
        } else {
          setState(() {
            _isSearchingSupplier = false;
          });
        }
      } catch (e) {
        debugPrint('Error searching supplier: $e');
        if (mounted) {
          setState(() {
            _isSearchingSupplier = false;
          });
        }
      }
    }
  }

  Future<void> _createSupplier() async {
    final response = widget.data['response'] ?? {};
    final supplierDetails = response['supplier_details'] ?? {};
    final addressDetails = supplierDetails['supplier_address_details'] ?? {};

    final supplierName = supplierDetails['supplier_name'] ?? '';
    final legalName =
        supplierDetails['supplier_legal_business_name'] ?? supplierName;
    final gstIn = supplierDetails['supplier_gst_in'] ?? '';
    final gstRegistrationType =
        supplierDetails['supplier_gst_registration_type']
            ?.toString()
            .toLowerCase() ??
        'regular';
    final city = addressDetails['supplier_city'] ?? '';
    final state = addressDetails['supplier_state'] ?? '';
    final pincode =
        int.tryParse(addressDetails['supplier_pincode']?.toString() ?? '0') ??
        0;
    final area = addressDetails['supplier_locality'] ?? '';
    final phone = supplierDetails['supplier_phone_number'] ?? 0;

    setState(() {
      _isCreatingSupplier = true;
    });

    try {
      final result = await StoreOwnerApiService.registerStore(
        storeId: widget.storeId,
        storeName: supplierName,
        legalName: legalName,
        city: city,
        state: state,
        pin: pincode,
        isGstEnabled: gstIn.isNotEmpty,
        gstIn: gstIn,
        gstRegisteredState: state,
        gstRegistrationType: gstRegistrationType,
        area: area,
      );

      if (mounted) {
        if (result.isNotEmpty && result['status'] == 200) {
          final newStoreId = result['data']?['store_id']?.toString();
          setState(() {
            _supplierStoreId = newStoreId;
            _supplierCreated = true;
            _isCreatingSupplier = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Supplier created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          setState(() {
            _isCreatingSupplier = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result['message']?.toString() ?? 'Failed to create supplier',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCreatingSupplier = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Parse the nested response structure
    final response = widget.data['response'] ?? {};
    final supplierDetails = response['supplier_details'] ?? {};
    final addressDetails = supplierDetails['supplier_address_details'] ?? {};
    final bankDetails = supplierDetails['supplier_bank_details'] ?? {};

    // Extract fields
    final bool supplierExists =
        supplierDetails['supplier_already_exists'] ?? false;
    final supplierName = supplierDetails['supplier_name'] ?? 'Unknown Supplier';
    final legalName = supplierDetails['supplier_legal_business_name'] ?? 'N/A';
    final gstIn = supplierDetails['supplier_gst_in'] ?? 'N/A';
    final gstStatus =
        supplierDetails['supplier_gst_registration_type'] ?? 'REGULAR';

    // Build full address
    final addressLine1 = addressDetails['supplier_address_line_1'] ?? '';
    final addressLine2 = addressDetails['supplier_address_line_2'] ?? '';
    final locality = addressDetails['supplier_locality'] ?? '';
    final city = addressDetails['supplier_city'] ?? '';
    final state = addressDetails['supplier_state'] ?? '';
    final pincode = addressDetails['supplier_pincode']?.toString() ?? '';
    final country = addressDetails['supplier_country'] ?? '';

    final addressParts = [
      if (addressLine1.isNotEmpty) addressLine1,
      if (addressLine2.isNotEmpty) addressLine2,
      if (locality.isNotEmpty) locality,
      if (city.isNotEmpty) city,
      if (state.isNotEmpty) state,
      if (pincode.isNotEmpty) pincode,
      if (country.isNotEmpty) country,
    ];
    final address = addressParts.isNotEmpty ? addressParts.join(', ') : 'N/A';

    final phone = supplierDetails['supplier_phone_number'] ?? 'N/A';
    final account = bankDetails['account_number']?.toString() ?? '0';
    final ifsc = bankDetails['ifsc'] ?? '';
    final invoiceId = response['invoice_id'] ?? 'N/A';
    final invoiceDate = response['invoice_date'] ?? 'N/A';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.blue),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Back to Purchase List',
          style: TextStyle(fontSize: 14, color: Colors.blue),
        ),
        titleSpacing: 0,
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Supplier Name Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          color: Colors.blue,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            supplierName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Details Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailItem('Legal Business Name', legalName),
                        const SizedBox(height: 16),

                        const Text(
                          'GST Information',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            Chip(
                              label: Text('GST IN: $gstIn'),
                              backgroundColor: Colors.green.withOpacity(0.1),
                              labelStyle: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            Chip(
                              label: Text(gstStatus),
                              backgroundColor: Colors.grey[200],
                              labelStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        _buildDetailItem('Address', address),
                        const SizedBox(height: 16),
                        _buildDetailItem('Phone', phone.toString()),
                        const SizedBox(height: 16),

                        const Text(
                          'Bank Details',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Account: $account',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          'IFSC: $ifsc',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),

                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: _buildDetailItem('Invoice ID', invoiceId),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildDetailItem(
                                'Invoice Date',
                                invoiceDate,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Status Banner
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (supplierExists || _supplierCreated)
                                ? Colors.green.withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              if (_isSearchingSupplier)
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              else
                                Icon(
                                  (supplierExists || _supplierCreated)
                                      ? Icons.check_circle
                                      : Icons.info,
                                  color: (supplierExists || _supplierCreated)
                                      ? Colors.green
                                      : Colors.orange,
                                  size: 20,
                                ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _isSearchingSupplier
                                      ? 'Searching for supplier...'
                                      : (supplierExists || _supplierCreated)
                                      ? 'Supplier exists in your system'
                                      : 'Supplier not found in your system',
                                  style: TextStyle(
                                    color: (supplierExists || _supplierCreated)
                                        ? Colors.green
                                        : Colors.orange[800],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: (supplierExists || _supplierCreated)
                    ? ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context, {
                            'continue': true,
                            'supplierStoreId': _supplierStoreId,
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: _isCreatingSupplier ? null : _createSupplier,
                        icon: _isCreatingSupplier
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.add_business, size: 20),
                        label: Text(
                          _isCreatingSupplier
                              ? 'Creating Supplier...'
                              : 'Create Supplier',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
