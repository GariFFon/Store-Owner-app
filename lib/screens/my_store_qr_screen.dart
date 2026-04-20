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
  // This file has the updated UI methods for MyStoreQrScreen

  // new_ui.dart containing pristine code
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Match the bg color
      body: Column(
        children: [
          _buildExpandedBanner(),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -20),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
                child: Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Expanded(child: _buildBody()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedBanner() {
    const lightBlueBg = Color(
      0xFFEFF6FF,
    ); // The blue used in Products/Table Mgmt
    const watermarkColor = Color(0xFFDBEAFE);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: lightBlueBg,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF94A3B8).withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRect(
        child: Stack(
          children: [
            // Watermark
            Positioned(
              right: -30,
              top: -10,
              child: Transform.rotate(
                angle: -0.2, // math.pi / -6
                child: Icon(
                  Icons.qr_code_scanner_rounded,
                  size: 180,
                  color: watermarkColor.withOpacity(0.6),
                ),
              ),
            ),
            // Content
            Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                MediaQuery.of(context).padding.top + 8,
                12,
                48, // generous bottom padding to allow for overlap
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back Button
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.blueGrey.withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                      child: const Center(
                        child: Padding(
                          padding: EdgeInsets.only(right: 2),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.black87,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Store QR Assets',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B),
                            letterSpacing: -0.5,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            "${_qrList.length} STICKERS",
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.blue,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Add Button (Register)
                  SizedBox(
                    width: 70,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'REGISTER',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Colors.blueGrey[400],
                            letterSpacing: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: _showRegisterDialog,
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blueGrey.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              size: 24,
                              color: Colors.blueGrey[700],
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
    );
  }

  Widget _buildBody() {
    // Avoid full screen flash during background refresh
    if (_loading && _qrList.isEmpty && _stickerUrl == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF2563EB)),
      );
    }

    if (_error != null && _qrList.isEmpty && _stickerUrl == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 60,
                color: Colors.red[300],
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFF2563EB),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 800;

          if (isDesktop) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 4, child: _buildStickerCard()),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 6,
                    child: _buildLinkedQRsList(isDesktop: true),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStickerCard(),
                const SizedBox(height: 16),
                _buildLinkedQRsList(isDesktop: false),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStickerCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF2563EB).withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF), // matching blue
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
              border: Border(
                bottom: BorderSide(
                  color: const Color(0xFF2563EB).withOpacity(0.1),
                ),
              ),
            ),
            child: const Text(
              'ACTIVE STORE STICKER',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2563EB),
                letterSpacing: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 200),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _stickerLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Color(0xFF2563EB),
                          ),
                        )
                      : _stickerUrl == null
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.qr_code_2_rounded,
                              size: 48,
                              color: Color(0xFFCBD5E1),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Sticker not available',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        )
                      : Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              _stickerUrl!,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 12),
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
                        : const Icon(Icons.file_download_rounded, size: 18),
                    label: Text(
                      _downloading ? 'Downloading...' : 'Save Sticker',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
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

  Widget _buildLinkedQRsList({required bool isDesktop}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'LINKED QR UUIDS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF64748B),
                letterSpacing: 1.0,
              ),
            ),
            // Standalone refresh button exclusively for list part
            IconButton(
              icon: const Icon(
                Icons.refresh_rounded,
                size: 20,
                color: Color(0xFF94A3B8),
              ),
              onPressed: _fetchQrList,
              tooltip: 'Refresh Links',
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(4),
            ),
          ],
        ),
        const SizedBox(height: 8), // Replaced 12 with 8
        if (_qrList.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.link_off_rounded,
                    size: 48,
                    color: Color(0xFFE2E8F0),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No tags linked',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tap the + ADD icon above to register.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else if (isDesktop)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.2,
            ),
            itemCount: _qrList.length,
            itemBuilder: (_, i) => _buildQrCard(_qrList[i]),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _qrList.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _buildQrCard(_qrList[i]),
          ),
      ],
    );
  }

  Widget _buildQrCard(Map<String, dynamic> qr) {
    final qrId = qr['qr_id']?.toString() ?? '—';
    final isActive = qr['is_active'] == true;
    final dateStr = _fmtDate(qr['timestamp']);

    final Color primaryColor = isActive
        ? const Color(0xFF10B981)
        : const Color(0xFF94A3B8);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Extra large background QR mark perfectly placed
            Positioned(
              right: -25,
              bottom: -35,
              child: Transform.rotate(
                angle: -0.2, // slight tilt for aesthetic
                child: Icon(
                  Icons.qr_code_2_rounded,
                  size: 150,
                  color: primaryColor.withOpacity(0.05),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Date and Status Badge (Symmetric feel)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Date
                      Row(
                        children: [
                          const Icon(
                            Icons.date_range_rounded,
                            size: 12,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            dateStr,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isActive
                                  ? Icons.check_circle_rounded
                                  : Icons.cancel_rounded,
                              size: 10,
                              color: primaryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isActive ? 'ACTIVE' : 'INACTIVE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Bottom Row: UUID and Verify Action
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // UUID
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'QR IDENTIFIER',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF94A3B8),
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              qrId,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E293B),
                                fontFamily: 'monospace',
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Verify Button
                      InkWell(
                        onTap: () => _showVerifyDialog(qrId),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF), // Soft blue
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF2563EB).withOpacity(0.2),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_user_rounded,
                                size: 14,
                                color: Color(0xFF2563EB),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Verify',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ],
                          ),
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
        if (uuid == null)
          continue; // not a recognisable UUID/URL, keep scanning
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
                        setDlg(
                          () => err =
                              'No valid UUID found. Please check and try again.',
                        );
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
