import 'package:exanor/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class MyStoreQrScreen extends StatefulWidget {
  final String storeId;
  final String? storeName;

  const MyStoreQrScreen({super.key, required this.storeId, this.storeName});

  @override
  State<MyStoreQrScreen> createState() => _MyStoreQrScreenState();
}

class _MyStoreQrScreenState extends State<MyStoreQrScreen> {
  // ── State ─────────────────────────────────────────────────────────────────
  bool _loading = true;
  String? _error;

  String? _stickerUrl;
  bool _stickerLoading = true;

  List<Map<String, dynamic>> _qrList = [];
  String? _storeName;

  bool _downloading = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── API calls ─────────────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await Future.wait([_fetchQrList(), _fetchSticker()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchQrList() async {
    try {
      final res = await ApiService.post(
        '/link-qr-to-store/',
        body: {'store_id': widget.storeId, 'list': true},
        useBearerToken: true,
      );
      if (!mounted) return;
      final data = res['data'] as Map<String, dynamic>?;
      if (data != null && (data['status'] == 200)) {
        final raw = data['list'];
        setState(() {
          _storeName = data['store_name']?.toString() ?? widget.storeName;
          _qrList = raw is List
              ? raw.map((e) => Map<String, dynamic>.from(e)).toList()
              : [];
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchSticker() async {
    setState(() => _stickerLoading = true);
    try {
      final res = await ApiService.post(
        '/generate-qr-code-sticker/',
        body: {'store_id': widget.storeId},
        useBearerToken: true,
      );
      if (!mounted) return;
      final data = res['data'] as Map<String, dynamic>?;
      if (data != null && data['status'] == 200) {
        setState(() {
          _stickerUrl = data['url']?.toString();
          _stickerLoading = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _stickerLoading = false);
  }

  Future<void> _downloadSticker() async {
    if (_stickerUrl == null || _downloading) return;
    setState(() => _downloading = true);
    try {
      final response = await http.get(Uri.parse(_stickerUrl!));
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/store_qr_sticker.png');
      await file.writeAsBytes(response.bodyBytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sticker saved to ${file.path}'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _registerQr(String qrId) async {
    try {
      final res = await ApiService.post(
        '/link-qr-to-store/',
        body: {'store_id': widget.storeId, 'qr_id': qrId, 'list': true},
        useBearerToken: true,
      );
      if (!mounted) return;
      final data = res['data'] as Map<String, dynamic>?;
      final status = data?['status'] as int?;
      if (status == 200) {
        final raw = data?['list'];
        setState(() {
          _qrList = raw is List
              ? raw.map((e) => Map<String, dynamic>.from(e)).toList()
              : _qrList;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QR registered successfully'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      } else {
        final msg = data?['response']?.toString() ?? 'Failed to register QR.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Verify QR dialog ─────────────────────────────────────────────────────
  Future<void> _showVerifyDialog(String qrId) async {
    // Show dialog immediately with a loading state, then populate
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _QrVerifyDialog(qrId: qrId, storeId: widget.storeId),
    );
  }

  // ── Register QR ──────────────────────────────────────────────────────────
  /// Opens the camera scanner. The scanner screen also has a
  /// "Type UUID Manually" bottom button that shows the text dialog.
  void _showRegisterDialog() {
    Navigator.of(context).push(
      MaterialPageRoute<String>(
        fullscreenDialog: true,
        builder: (_) => _QrScanRegisterScreen(
          onScanned: (qrId) async {
            await _registerQr(qrId);
          },
        ),
      ),
    );
  }

  /// Fallback: manual UUID entry dialog (also reachable from scanner screen).
  void _showManualEntryDialog() {
    final ctrl = TextEditingController();
    bool saving = false;
    String? err;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Enter QR UUID',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Type or paste the UUID printed on the bulk-generated QR sticker.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'QR UUID',
                    hintText: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
                    hintStyle: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFCBD5E1),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xFF2563EB),
                        width: 1.5,
                      ),
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.content_paste_rounded, size: 18),
                      onPressed: () async {
                        final d = await Clipboard.getData('text/plain');
                        if (d?.text != null) ctrl.text = d!.text!;
                      },
                    ),
                  ),
                ),
                if (err != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    err!,
                    style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      final id = ctrl.text.trim();
                      if (id.isEmpty) {
                        setDlg(() => err = 'Please enter a QR UUID.');
                        return;
                      }
                      setDlg(() {
                        saving = true;
                        err = null;
                      });
                      Navigator.of(ctx).pop();
                      await _registerQr(id);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Register',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _fmtDate(dynamic ts) {
    if (ts == null) return '—';
    try {
      final dt = DateTime.fromMillisecondsSinceEpoch(
        (ts as num).toInt() * 1000,
      );
      return 'Linked on ${DateFormat('dd MMM yyyy').format(dt)}';
    } catch (_) {
      return '—';
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          _buildAppBar(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _buildError()
                : _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: Color(0xFF334155),
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Store QR',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B),
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Download your store sticker or register a bulk QR UUID to this store.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Register QR button
                  OutlinedButton.icon(
                    onPressed: _showRegisterDialog,
                    icon: const Icon(Icons.link_rounded, size: 16),
                    label: const Text(
                      'Register QR',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      side: const BorderSide(color: Color(0xFF2563EB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 52, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFF2563EB),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Sticker card ────────────────────────────────────────────
          _buildStickerCard(),
          const SizedBox(height: 20),

          // ── Linked QR stickers ───────────────────────────────────────
          Row(
            children: [
              Text(
                'LINKED QR STICKERS (${_qrList.length})',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: Color(0xFF94A3B8),
                ),
                onPressed: () async {
                  await _fetchQrList();
                  setState(() {});
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_qrList.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Center(
                child: Text(
                  'No QR stickers linked yet.\nTap "Register QR" to link one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                ),
              ),
            )
          else
            for (final qr in _qrList) _buildQrCard(qr),
        ],
      ),
    );
  }

  Widget _buildStickerCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Sticker image
          if (_stickerLoading)
            Container(
              height: 280,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: CircularProgressIndicator()),
            )
          else if (_stickerUrl == null)
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.qr_code_2_rounded,
                      size: 60,
                      color: Color(0xFFCBD5E1),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Sticker not available',
                      style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                _stickerUrl!,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image_outlined,
                  size: 60,
                  color: Color(0xFFCBD5E1),
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Download button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _stickerUrl == null || _downloading
                  ? null
                  : _downloadSticker,
              icon: _downloading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download_rounded, size: 20),
              label: Text(
                _downloading ? 'Downloading…' : 'Download Sticker',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrCard(Map<String, dynamic> qr) {
    final qrId = qr['qr_id']?.toString() ?? '—';
    final isActive = qr['is_active'] == true;
    final dateStr = _fmtDate(qr['timestamp']);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Status icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFFDCFCE7)
                  : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
              size: 18,
              color: isActive
                  ? const Color(0xFF16A34A)
                  : const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(width: 12),

          // QR ID + date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  qrId,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateStr,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Active badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFFDCFCE7)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isActive ? 'Active' : 'Inactive',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isActive
                    ? const Color(0xFF16A34A)
                    : const Color(0xFF94A3B8),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Verify button
          OutlinedButton.icon(
            onPressed: () => _showVerifyDialog(qrId),
            icon: const Icon(Icons.verified_rounded, size: 14),
            label: const Text(
              'Verify',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2563EB),
              side: const BorderSide(color: Color(0xFF2563EB)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

// ── QR Verification Dialog ────────────────────────────────────────────────────
class _QrVerifyDialog extends StatefulWidget {
  final String qrId;
  final String storeId;
  const _QrVerifyDialog({required this.qrId, required this.storeId});

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
        '/get-store-id-from-linked-qr/',
        body: {'qr_id': widget.qrId},
        useBearerToken: true,
      );
      if (!mounted) return;
      final data = res['data'] as Map<String, dynamic>?;
      final status = data?['status'] as int?;
      if (status == 200) {
        setState(() {
          _result = data;
          _loading = false;
        });
      } else {
        setState(() {
          _error =
              data?['response']?.toString() ??
              'Could not verify QR (status $status).';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final isActive = result?['is_active'] == true;
    final resolvedStoreId = result?['store_id']?.toString() ?? '';
    final matchesStore = resolvedStoreId == widget.storeId;
    final storeName = result?['store_name']?.toString() ?? '—';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Color(0xFFEEF2FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_rounded,
              size: 18,
              color: Color(0xFF4F46E5),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'QR Verification',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              size: 20,
              color: Color(0xFF94A3B8),
            ),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 340,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
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
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Close',
            style: TextStyle(
              color: Color(0xFF2563EB),
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 18,
                  color: Color(0xFFDC2626),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.w500,
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

  Widget _buildResultContent(
    Map<String, dynamic> result, {
    required bool isActive,
    required bool matchesStore,
    required String storeName,
    required String resolvedStoreId,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: matchesStore
                ? const Color(0xFFF0FDF4)
                : const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                matchesStore
                    ? Icons.check_circle_rounded
                    : Icons.warning_amber_rounded,
                size: 20,
                color: matchesStore
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFD97706),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  matchesStore
                      ? '✅ QR is correctly linked to this store.'
                      : '⚠️ QR is linked to a different store.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: matchesStore
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFD97706),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // QR UUID
        _infoRow('QR UUID', widget.qrId, monospace: true),
        const SizedBox(height: 14),

        // Store Name
        _infoRow('STORE NAME', storeName),
        const SizedBox(height: 14),

        // Store ID
        _infoRow('STORE ID', resolvedStoreId, monospace: true),
        const SizedBox(height: 16),

        const Divider(color: Color(0xFFE2E8F0)),
        const SizedBox(height: 12),

        // Badges row
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            // Active / Inactive
            _badge(
              label: isActive ? 'Active' : 'Inactive',
              icon: isActive
                  ? Icons.check_circle_rounded
                  : Icons.cancel_rounded,
              color: isActive
                  ? const Color(0xFF16A34A)
                  : const Color(0xFF94A3B8),
              bg: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
            ),
            // Matches / Mismatch
            _badge(
              label: matchesStore ? 'Matches this store' : 'Wrong store',
              icon: matchesStore
                  ? Icons.store_rounded
                  : Icons.store_mall_directory_outlined,
              color: matchesStore
                  ? const Color(0xFF4F46E5)
                  : const Color(0xFFD97706),
              bg: matchesStore
                  ? const Color(0xFFEEF2FF)
                  : const Color(0xFFFFF7ED),
            ),
          ],
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value, {bool monospace = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B),
            fontFamily: monospace ? 'monospace' : null,
          ),
        ),
      ],
    );
  }

  Widget _badge({
    required String label,
    required IconData icon,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QR Camera Scanner Screen
// ─────────────────────────────────────────────────────────────────────────────
class _QrScanRegisterScreen extends StatefulWidget {
  /// Called with the scanned UUID once detected.
  final Future<void> Function(String qrId) onScanned;

  const _QrScanRegisterScreen({required this.onScanned});

  @override
  State<_QrScanRegisterScreen> createState() => _QrScanRegisterScreenState();
}

class _QrScanRegisterScreenState extends State<_QrScanRegisterScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _ctrl = MobileScannerController();
  bool _scanned = false; // prevent double-fire
  bool _torchOn = false;

  late AnimationController _anim;
  late Animation<double> _scanLine;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scanLine = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _anim.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw != null && raw.isNotEmpty) {
        final uuid = _extractUuid(raw);
        if (uuid == null) continue; // not a recognisable UUID/URL, keep scanning
        _scanned = true;
        _ctrl.stop();
        Navigator.of(context).pop(); // close scanner
        widget.onScanned(uuid); // trigger API
        return;
      }
    }
  }

  /// Extracts a UUID from [raw].
  ///
  /// Handles three cases:
  ///   1. [raw] is already a bare UUID       → returned as-is.
  ///   2. [raw] is a URL with UUID in a query →  e.g. ?id=<uuid>
  ///   3. [raw] is a URL with UUID in path   → any path segment that looks like a UUID.
  ///
  /// Returns `null` if no UUID can be found.
  static final _uuidRe = RegExp(
    r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
    caseSensitive: false,
  );

  static String? _extractUuid(String raw) {
    final trimmed = raw.trim();

    // 1. Already a bare UUID?
    if (_uuidRe.hasMatch(trimmed) &&
        _uuidRe.firstMatch(trimmed)!.group(0) == trimmed) {
      return trimmed;
    }

    // 2 & 3. Try to parse as URL and look everywhere for a UUID.
    final uri = Uri.tryParse(trimmed);
    if (uri != null) {
      // Query parameters (e.g. ?id=<uuid>, ?qr=<uuid>)
      for (final v in uri.queryParameters.values) {
        final m = _uuidRe.firstMatch(v);
        if (m != null) return m.group(0)!.toLowerCase();
      }
      // Path segments (e.g. /qr/2a7dc210-.../)
      for (final seg in uri.pathSegments) {
        final m = _uuidRe.firstMatch(seg);
        if (m != null) return m.group(0)!.toLowerCase();
      }
    }

    // 4. Fallback: first UUID found anywhere in the raw string.
    final m = _uuidRe.firstMatch(trimmed);
    if (m != null) return m.group(0)!.toLowerCase();

    return null; // nothing found
  }

  void _openManualEntry() {
    final ctrl = TextEditingController();
    String? err;
    bool saving = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Enter QR UUID',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Type or paste the UUID printed on the bulk-generated QR sticker.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'QR UUID',
                    hintText: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
                    hintStyle: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFCBD5E1),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xFF2563EB),
                        width: 1.5,
                      ),
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.content_paste_rounded, size: 18),
                      onPressed: () async {
                        final d = await Clipboard.getData('text/plain');
                        if (d?.text != null) ctrl.text = d!.text!;
                      },
                    ),
                  ),
                ),
                if (err != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    err!,
                    style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      final id = ctrl.text.trim();
                      if (id.isEmpty) {
                        setDlg(() => err = 'Please enter a QR UUID.');
                        return;
                      }
                      final uuid = _QrScanRegisterScreenState._extractUuid(id);
                      if (uuid == null) {
                        setDlg(() => err = 'No valid UUID found. Please check and try again.');
                        return;
                      }
                      setDlg(() {
                        saving = true;
                        err = null;
                      });
                      Navigator.of(ctx).pop(); // close dialog
                      Navigator.of(context).pop(); // close scanner
                      await widget.onScanned(uuid);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Register',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Camera feed ─────────────────────────────────────────────────
          MobileScanner(controller: _ctrl, onDetect: _onDetect),

          // ── Dark overlay with cut-out ────────────────────────────────────
          CustomPaint(
            painter: _ScannerOverlayPainter(),
            child: const SizedBox.expand(),
          ),

          // ── Animated scan line inside viewfinder ─────────────────────────
          Center(
            child: SizedBox(
              width: 260,
              height: 260,
              child: AnimatedBuilder(
                animation: _scanLine,
                builder: (_, __) => Align(
                  alignment: Alignment(0, (_scanLine.value * 2) - 1),
                  child: Container(
                    height: 2.5,
                    width: 240,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          const Color(0xFF2563EB).withValues(alpha: 0.9),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Top bar ──────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  // Close
                  const BackButton(color: Colors.white),
                  const Spacer(),
                  const Text(
                    'Scan QR Sticker',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  // Torch
                  IconButton(
                    icon: Icon(
                      _torchOn ? Icons.flash_on : Icons.flash_off,
                      color: _torchOn ? const Color(0xFFFBBF24) : Colors.white,
                    ),
                    onPressed: () {
                      _ctrl.toggleTorch();
                      setState(() => _torchOn = !_torchOn);
                    },
                  ),
                  // Flip camera
                  IconButton(
                    icon: const Icon(
                      Icons.cameraswitch_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () => _ctrl.switchCamera(),
                  ),
                ],
              ),
            ),
          ),

          // ── Instruction label ────────────────────────────────────────────
          const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 300),
              child: Text(
                'Point the camera at the QR sticker UUID barcode',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // ── Type manually button ─────────────────────────────────────────
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openManualEntry,
                    icon: const Icon(
                      Icons.keyboard_alt_outlined,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Type QR ID Manually',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white54, width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Scanner viewfinder overlay painter ─────────────────────────────────────
class _ScannerOverlayPainter extends CustomPainter {
  static const _side = 260.0;
  static const _corner = 24.0;
  static const _strokeW = 3.5;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final l = cx - _side / 2;
    final t = cy - _side / 2;
    final r = cx + _side / 2;
    final b = cy + _side / 2;

    // Dark scrim everywhere except the cut-out square
    final scrimPaint = Paint()..color = Colors.black.withValues(alpha: 0.62);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()
          ..addRRect(RRect.fromLTRBR(l, t, r, b, const Radius.circular(12))),
      ),
      scrimPaint,
    );

    // Blue corner brackets
    final p = Paint()
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeW
      ..strokeCap = StrokeCap.round;

    void corner(double x, double y, double dx, double dy) {
      final path = Path()
        ..moveTo(x, y + dy * _corner)
        ..lineTo(x, y)
        ..lineTo(x + dx * _corner, y);
      canvas.drawPath(path, p);
    }

    corner(l, t, 1, 1); // top-left
    corner(r, t, -1, 1); // top-right
    corner(l, b, 1, -1); // bottom-left
    corner(r, b, -1, -1); // bottom-right
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
