import 'package:flutter/material.dart';

class SupplierDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  const SupplierDetailsDialog({
    super.key,
    required this.data,
    required this.onContinue,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    // Parse the nested response structure
    final response = data['response'] ?? {};
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

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.black),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Supplier Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'AI-extracted supplier information from your invoice',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: onBack),
                ],
              ),
            ),
            const Divider(height: 1),

            // content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Supplier Name Header
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          color: Colors.blue,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          supplierName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Details Grid
                    _buildSection('Legal Business Name', legalName),
                    const SizedBox(height: 16),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GST Information',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'GST IN: $gstIn',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                gstStatus,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    _buildSection('Address', address),
                    const SizedBox(height: 16),
                    _buildSection('Phone', phone),
                    const SizedBox(height: 16),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bank Details',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Account: $account',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          'IFSC: $ifsc',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(child: _buildSection('Invoice ID', invoiceId)),
                        Expanded(
                          child: _buildSection('Invoice Date', invoiceDate),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Status Banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: supplierExists
                            ? Colors.green.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            supplierExists ? Icons.check : Icons.info,
                            color: supplierExists
                                ? Colors.green
                                : Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            supplierExists
                                ? 'Supplier exists in your system'
                                : 'Supplier not found in your system',
                            style: TextStyle(
                              color: supplierExists
                                  ? Colors.green
                                  : Colors.orange[800],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 1),
            // Footer
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('Back'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: onContinue,
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('Continue'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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

  Widget _buildSection(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
