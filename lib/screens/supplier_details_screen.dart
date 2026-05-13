import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// Safely parse supplier_already_exists which may be bool, String, or int.
  bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    if (value is int) return value != 0;
    return false;
  }

  /// Extract store ID from a map trying multiple common key names.
  String? _extractStoreId(Map<String, dynamic> data) {
    final candidates = [
      'store_id',
      'id',
      'supplier_store_id',
      'new_store_id',
      'registered_store_id',
    ];
    for (final key in candidates) {
      final val = data[key];
      if (val != null && val.toString().isNotEmpty) {
        return val.toString();
      }
    }
    return null;
  }

  Future<void> _checkAndSearchSupplier() async {
    final response = widget.data['response'] ?? {};
    final supplierDetails = response['supplier_details'] ?? {};
    final bool supplierExists = _parseBool(
      supplierDetails['supplier_already_exists'],
    );
    final gstIn = supplierDetails['supplier_gst_in']?.toString() ?? '';

    debugPrint(
      'Supplier check: exists=$supplierExists, gstIn=$gstIn, raw_exists=${supplierDetails['supplier_already_exists']}',
    );

    if (supplierExists && gstIn.isNotEmpty) {
      setState(() {
        _isSearchingSupplier = true;
      });

      try {
        final stores = await StoreOwnerApiService.searchStore(gstIn);
        debugPrint('Search store results count: ${stores.length}');
        if (stores.isNotEmpty && mounted) {
          final storeData = stores[0];
          debugPrint('Supplier search result: $storeData');
          setState(() {
            _supplierStoreId = _extractStoreId(storeData);
            _isSearchingSupplier = false;
          });
          debugPrint('Found supplier store ID: $_supplierStoreId');
        } else {
          debugPrint(
            'No stores found for GST: $gstIn — supplier needs to be created',
          );
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

    final supplierName = supplierDetails['supplier_name']?.toString() ?? '';
    final legalName =
        supplierDetails['supplier_legal_business_name']?.toString() ??
        supplierName;
    final gstIn = supplierDetails['supplier_gst_in']?.toString() ?? '';
    final gstRegistrationType =
        supplierDetails['supplier_gst_registration_type']
            ?.toString()
            .toLowerCase() ??
        'regular';
    final city = addressDetails['supplier_city']?.toString() ?? '';
    final state = addressDetails['supplier_state']?.toString() ?? '';
    final pincode =
        int.tryParse(addressDetails['supplier_pincode']?.toString() ?? '0') ??
        0;
    final area = addressDetails['supplier_locality']?.toString() ?? '';

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

      debugPrint('Register store full result: $result');

      if (mounted) {
        if (result.isNotEmpty && result['status'] == 200) {
          // Look for store ID in multiple possible response locations
          String? newStoreId;

          // Try result['response'] first (most common API pattern)
          if (result['response'] is Map) {
            newStoreId = _extractStoreId(
              Map<String, dynamic>.from(result['response'] as Map),
            );
          }
          // Try result['data'] next
          if (newStoreId == null && result['data'] is Map) {
            newStoreId = _extractStoreId(
              Map<String, dynamic>.from(result['data'] as Map),
            );
          }
          // Try the result root level
          if (newStoreId == null) {
            newStoreId = _extractStoreId(result);
          }

          debugPrint('Extracted new supplier store ID: $newStoreId');

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

          // Auto-continue to products after successful creation
          if (_supplierStoreId != null && _supplierStoreId!.isNotEmpty) {
            Navigator.pop(context, {
              'continue': true,
              'supplierStoreId': _supplierStoreId,
            });
          }
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
      debugPrint('Error creating supplier: $e');
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
    // Parse
    final response = widget.data['response'] ?? {};
    final supplierDetails = response['supplier_details'] ?? {};
    final addressDetails = supplierDetails['supplier_address_details'] ?? {};
    final bankDetails = supplierDetails['supplier_bank_details'] ?? {};

    final supplierName = supplierDetails['supplier_name'] ?? 'Unknown Supplier';
    final legalName = supplierDetails['supplier_legal_business_name'] ?? 'N/A';
    final gstIn = supplierDetails['supplier_gst_in'] ?? 'N/A';
    final gstStatus =
        supplierDetails['supplier_gst_registration_type'] ?? 'REGULAR';

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
    final account = bankDetails['account_number']?.toString() ?? '';
    final ifsc = bankDetails['ifsc'] ?? '';
    final invoiceId = response['invoice_id'] ?? 'N/A';
    final invoiceDate = response['invoice_date'] ?? 'N/A';

    final reconciliation = response['extraction_reconciliation'] as Map<String, dynamic>?;
    final isReconciled = reconciliation?['is_reconciled'] == true;
    final reconciliationNote = reconciliation?['reconciliation_note']?.toString() ?? '';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 800;

                        // Status Card: show "found" only if we have a store ID,
                        // show "needs creation" if AI says exists but not in our DB
                        final bool supplierInSystem =
                            _supplierStoreId != null &&
                            _supplierStoreId!.isNotEmpty;
                        final statusCard = _buildStatusCard(
                          supplierInSystem || _supplierCreated,
                        );

                        // Supplier Basic Info
                        final businessCard = _buildSectionCard(
                          title: 'Business Details',
                          icon: Icons.store_mall_directory_rounded,
                          color: Colors.blue,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoRow(
                                title: 'Store Name',
                                value: supplierName,
                                icon: Icons.storefront_rounded,
                              ),
                              _buildDivider(),
                              _buildInfoRow(
                                title: 'Legal Name',
                                value: legalName,
                                icon: Icons.verified_user_rounded,
                              ),
                              _buildDivider(),
                              _buildInfoRow(
                                title: 'Phone',
                                value: phone.toString(),
                                icon: Icons.phone_rounded,
                              ),
                              _buildDivider(),
                              _buildInfoRow(
                                title: 'GSTIN',
                                value: gstIn,
                                icon: Icons.assignment_turned_in_rounded,
                                isHighlighted: true,
                              ),
                              _buildDivider(),
                              _buildInfoRow(
                                title: 'GST Type',
                                value: gstStatus,
                                icon: Icons.category_rounded,
                              ),
                            ],
                          ),
                        );

                        // Location
                        final locationCard = _buildSectionCard(
                          title: 'Location & Address',
                          icon: Icons.location_on_rounded,
                          color: Colors.orange,
                          child: _buildInfoRow(
                            title: 'Address',
                            value: address,
                            icon: Icons.map_rounded,
                          ),
                        );

                        // Bank Details
                        final bankCard = _buildSectionCard(
                          title: 'Bank Information',
                          icon: Icons.account_balance_rounded,
                          color: Colors.teal,
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildInfoRow(
                                  title: 'Account No.',
                                  value: (account.isEmpty || account == '0')
                                      ? 'N/A'
                                      : account,
                                  icon: Icons.credit_card_rounded,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildInfoRow(
                                  title: 'IFSC Code',
                                  value: ifsc.isEmpty ? 'N/A' : ifsc,
                                  icon: Icons.numbers_rounded,
                                ),
                              ),
                            ],
                          ),
                        );

                        // Invoice Context
                        final invoiceCard = _buildSectionCard(
                          title: 'Invoice Context',
                          icon: Icons.receipt_long_rounded,
                          color: Colors.purple,
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildInfoRow(
                                  title: 'Invoice ID',
                                  value: invoiceId,
                                  icon: Icons.tag_rounded,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildInfoRow(
                                  title: 'Date',
                                  value: invoiceDate,
                                  icon: Icons.calendar_today_rounded,
                                ),
                              ),
                            ],
                          ),
                        );

                        final reconciliationBanner = !isReconciled && reconciliationNote.isNotEmpty
                            ? _buildReconciliationBanner(reconciliationNote)
                            : const SizedBox.shrink();

                        if (isWide) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              statusCard,
                              const SizedBox(height: 16),
                              reconciliationBanner,
                              const SizedBox(height: 24),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      children: [
                                        businessCard,
                                        const SizedBox(height: 24),
                                        locationCard,
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        bankCard,
                                        const SizedBox(height: 24),
                                        invoiceCard,
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 100),
                            ],
                          );
                        } else {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              statusCard,
                              const SizedBox(height: 16),
                              reconciliationBanner,
                              const SizedBox(height: 24),
                              businessCard,
                              const SizedBox(height: 16),
                              locationCard,
                              const SizedBox(height: 16),
                              bankCard,
                              const SizedBox(height: 16),
                              invoiceCard,
                              const SizedBox(height: 100),
                            ],
                          );
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomSheet: _buildBottomBar(
          context,
          // Only show "Continue" if the supplier actually has a store ID
          // in our system. If AI said exists but search found nothing,
          // show "Create Supplier" instead.
          _supplierStoreId != null && _supplierStoreId!.isNotEmpty,
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF94A3B8).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -10,
            child: Transform.rotate(
              angle: -math.pi / 6,
              child: Icon(
                Icons.store_mall_directory_rounded,
                size: 160,
                color: const Color(0xFFDBEAFE).withOpacity(0.5),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.of(context).padding.top + 12,
              16,
              20,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Supplier Details',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                          letterSpacing: -0.5,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'STEP 1/3',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Review supplier info',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.blueGrey[600],
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
        ],
      ),
    );
  }

  Widget _buildStatusCard(bool exists) {
    final isSearching = _isSearchingSupplier;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: exists ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: exists ? const Color(0xFFBBF7D0) : const Color(0xFFFED7AA),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: exists ? Colors.green : Colors.orange,
              shape: BoxShape.circle,
            ),
            child: isSearching
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Icon(
                    exists ? Icons.check_rounded : Icons.priority_high_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSearching
                      ? 'Checking Database...'
                      : exists
                      ? 'Supplier Found'
                      : 'New Supplier',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: exists
                        ? const Color(0xFF15803D)
                        : const Color(0xFFC2410C),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isSearching
                      ? 'Matching GSTIN with our records'
                      : exists
                      ? 'This supplier is already in your database.'
                      : 'This supplier needs to be added to your system.',
                  style: TextStyle(
                    fontSize: 12,
                    color: exists
                        ? const Color(0xFF166534)
                        : const Color(0xFF9A3412),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReconciliationBanner(String note) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFF97316),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Invoice Reconciliation Warning',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9A3412),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  note,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9A3412),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required String title,
    required String value,
    required IconData icon,
    bool isHighlighted = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: Colors.blueGrey[300]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.blueGrey[400],
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: isHighlighted
                    ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
                    : null,
                decoration: isHighlighted
                    ? BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      )
                    : null,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: isHighlighted ? 13 : 14,
                    fontWeight: FontWeight.w600,
                    color: isHighlighted
                        ? Colors.blue[700]
                        : const Color(0xFF334155),
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context, bool exists) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: () {
          if (exists) {
            if (_supplierStoreId == null || _supplierStoreId!.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Supplier store ID not found. Please wait or try again.',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            Navigator.pop(context, {
              'continue': true,
              'supplierStoreId': _supplierStoreId,
            });
          } else {
            if (!_isCreatingSupplier) _createSupplier();
          }
        },
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: exists
                  ? [const Color(0xFF3B82F6), const Color(0xFF2563EB)]
                  : [const Color(0xFFF97316), const Color(0xFFEA580C)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color:
                    (exists ? const Color(0xFF3B82F6) : const Color(0xFFF97316))
                        .withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _isCreatingSupplier
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      exists
                          ? 'Continue to Products'
                          : 'Create Supplier & Continue',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      exists
                          ? Icons.arrow_forward_rounded
                          : Icons.add_business_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Divider(
        height: 1,
        color: Colors.black.withOpacity(0.06),
        thickness: 1,
      ),
    );
  }
}
