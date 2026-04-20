// ── QR Verification Dialog ────────────────────────────────────────────────────
class _QrVerifyDialog extends StatefulWidget {
  final String qrId;
  final String currentStoreId;

  const _QrVerifyDialog({
    super.key,
    required this.qrId,
    required this.currentStoreId,
  });

  @override
  State<_QrVerifyDialog> createState() => _QrVerifyDialogState();
}

class _QrVerifyDialogState extends State<_QrVerifyDialog> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _verify();
  }

  Future<void> _verify() async {
    try {
      final res = await ApiService.post(
        '/verify-store-qr/',
        body: {'qr_id': widget.qrId},
        useBearerToken: true,
      );
      if (!mounted) return;
      if (res['statusCode'] == 200 && res['data'] != null) {
        final data = res['data'];
        if (data['status'] == 200) {
          setState(() {
            _result = data['response'];
            _loading = false;
          });
        } else {
          setState(() {
            _error = data['response']?.toString() ?? 'Verification failed';
            _loading = false;
          });
        }
      } else {
        setState(() {
          _error = 'Failed to verify QR. HTTP ${res['statusCode']}';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final isActive = result?['is_active'] == true;
    final resolvedStoreId = result?['store_id']?.toString() ?? '';
    final matchesStore = resolvedStoreId == widget.currentStoreId;
    final storeName = result?['store_name']?.toString() ?? 'Unknown';

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: Container(
          width: 400,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: Color(0xFF2563EB),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'QR Verification',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Verifying payload over API.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: _loading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))),
                    )
                  : _error != null
                    ? _buildErrorContent()
                    : _buildResultContent(
                        result!,
                        isActive: isActive,
                        matchesStore: matchesStore,
                        storeName: storeName,
                        resolvedStoreId: resolvedStoreId,
                      ),
              ),
              
              // Footer
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _loading ? null : () {
                        setState(() => _loading = true);
                        _verify();
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Re-verify'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorContent() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 24, color: Color(0xFFDC2626)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFFDC2626),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultContent(
    Map<String, dynamic> result, {
    required bool isActive,
    required bool matchesStore,
    required String storeName,
    required String resolvedStoreId,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Match / Mismatch banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: matchesStore ? const Color(0xFFDCFCE7) : const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                matchesStore ? Icons.verified_rounded : Icons.gpp_bad_rounded,
                color: matchesStore ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      matchesStore ? 'MATCHED STORE' : 'MISMATCH DETECTED',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: matchesStore ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      matchesStore 
                        ? 'This tag is correctly associated.' 
                        : 'This tag belongs to a different firm.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: matchesStore ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Key Info Container
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _infoRow('QR IDENTIFIER', widget.qrId, true),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _infoRow('STORE NAME', storeName, false),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _infoRow('STORE ID', resolvedStoreId, true),
            ],
          ),
        ),
        const SizedBox(height: 20),
        
        // Tags representation
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _badge(
              label: isActive ? 'System Active' : 'System Inactive',
              icon: isActive ? Icons.power_rounded : Icons.power_off_rounded,
              color: isActive ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
              bg: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
            ),
            if (matchesStore)
              _badge(
                label: 'Authenticated',
                icon: Icons.shield_rounded,
                color: const Color(0xFF2563EB),
                bg: const Color(0xFFEFF6FF),
              )
          ],
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value, bool isMono) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF94A3B8),
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
                fontFamily: isMono ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge({
    required String label,
    required IconData icon,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
