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
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
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
    const lightBlueBg = Color(0xFFEFF6FF); // The blue used in Products/Table Mgmt
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
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.blue.withOpacity(0.2)),
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
      return const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)));
    }
    
    if (_error != null && _qrList.isEmpty && _stickerUrl == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 60, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
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
                  Expanded(
                    flex: 4,
                    child: _buildStickerCard(),
                  ),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1 ২০০),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF), // matching blue
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              border: Border(bottom: BorderSide(color: const Color(0xFF2563EB).withOpacity(0.1))),
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
                    onPressed: _stickerUrl == null || _downloading ? null : _downloadSticker,
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
              icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF94A3B8)),
              onPressed: _fetchQrList,
              tooltip: 'Refresh Links',
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(4),
            )
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
                  const Icon(Icons.link_off_rounded, size: 48, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 12),
                  const Text(
                    'No tags linked',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B)
                    )
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

    final Color primaryColor = isActive ? const Color(0xFF10B981) : const Color(0xFF94A3B8);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryColor.withOpacity(0.3),
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
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
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
                          const Icon(Icons.date_range_rounded, size: 12, color: Color(0xFF94A3B8)),
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
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
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF), // Soft blue
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.2)),
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
