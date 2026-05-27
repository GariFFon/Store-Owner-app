import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/screens/create_staff_bottom_sheet.dart';
import 'package:exanor/screens/face_registration_screen.dart';
import 'package:exanor/services/store_owner_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

class StaffManagementScreen extends StatefulWidget {
  final String storeId;

  const StaffManagementScreen({super.key, required this.storeId});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isLoading = true;
  List<Map<String, dynamic>> _staffList = [];
  List<Map<String, dynamic>> _rolesList = [];
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
        StoreOwnerApiService.viewUserRoles(widget.storeId),
        StoreOwnerApiService.getStoreStaff(widget.storeId),
      ]);

      if (mounted) {
        setState(() {
          _rolesList = results[0];
          _staffList = results[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateStaffRole(
    Map<String, dynamic> staff,
    String? newRoleName,
  ) async {
    if (newRoleName == null) return;

    final role = _rolesList.firstWhere(
      (r) => r['role_name'] == newRoleName,
      orElse: () => {},
    );

    if (role.isEmpty) return;

    final String? roleId = role['id'];
    if (roleId == null) return;

    // Optimistic update
    final oldRoleName = staff['role_name'];
    setState(() {
      staff['role_name'] = newRoleName;
    });

    try {
      final success = await StoreOwnerApiService.updateStoreStaff(
        storeId: widget.storeId,
        staffId: staff['id'],
        dataToBeUpdated: {'role_id': roleId},
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: TranslatedText('Role updated to $newRoleName'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Revert on failure
        if (mounted) {
          setState(() {
            staff['role_name'] = oldRoleName;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: TranslatedText('Failed to update role'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          staff['role_name'] = oldRoleName;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating role: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFFF8FAFC),
        extendBodyBehindAppBar: true,
        body: Column(
          children: [
            // 1. Expanded Banner
            _buildExpandedBanner(theme),

            // 2. Main Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? Center(child: Text(_errorMessage!))
                  : RefreshIndicator(
                      onRefresh: () async => await _fetchData(),
                      child: _buildBody(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedBanner(ThemeData theme) {
    const lightBlueBg = Color(0xFFEFF6FF);
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
                angle: -math.pi / 6,
                child: Icon(
                  Icons.groups_rounded,
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
                12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
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
                                color: Colors.blueGrey,
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
                            const TranslatedText(
                              'Staff', // Shortened title
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
                            const SizedBox(height: 2),
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
                              child: const TranslatedText(
                                'MANAGEMENT',
                                style: TextStyle(
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

                      // Refresh Button
                      SizedBox(
                        width: 70,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TranslatedText(
                              'REFRESH',
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
                              onTap: () => _fetchData(),
                              borderRadius: BorderRadius.circular(30),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blueGrey.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.refresh_rounded,
                                  size: 24,
                                  color: Colors.blueGrey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // New Staff Button
                      SizedBox(
                        width: 70,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TranslatedText(
                              'NEW',
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
                              onTap: () async {
                                final result = await showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => CreateStaffBottomSheet(
                                    storeId: widget.storeId,
                                    roles: _rolesList,
                                  ),
                                );

                                if (result == true) {
                                  _fetchData();
                                }
                              },
                              borderRadius: BorderRadius.circular(30),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: theme.primaryColor,
                                  border: Border.all(
                                    color: Colors.transparent,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.add_rounded,
                                  size: 24,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
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

  Widget _buildBody() {
    if (_staffList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_alt_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              "No Staff Members",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Add staff to manage your store",
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 800) {
          return _buildTabletTable();
        } else {
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(context).padding.bottom + 80,
            ),
            itemCount: _staffList.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) =>
                _buildMobileCard(_staffList[index]),
          );
        }
      },
    );
  }

  // ============== PROFESSIONAL TABLE VIEW ==============
  Widget _buildTabletTable() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.grey[100],
            dataTableTheme: DataTableThemeData(
              headingRowColor: MaterialStateProperty.all(Colors.transparent),
              dataRowColor: MaterialStateProperty.resolveWith<Color>((states) {
                if (states.contains(MaterialState.hovered)) {
                  return const Color(0xFFF8FAFC);
                }
                return Colors.white;
              }),
            ),
          ),
          child: DataTable(
            headingRowHeight: 48,
            dataRowHeight: 64,
            columnSpacing: 24,
            horizontalMargin: 24,
            columns: const [
              DataColumn(
                label: Text(
                  'NAME',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'ROLE',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'CONTACT',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  '',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
            rows: _staffList.map((staff) {
              final rawName = staff['user_first_name']?.toString() ?? '';
              final name = rawName.isNotEmpty ? rawName : 'U';
              final roleName = staff['role_name'] ?? 'Staff';
              final phone = staff['user_phone_number']?.toString() ?? '';

              return DataRow(
                cells: [
                  // Name & Avatar
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFFF1F5F9), // Slate 100
                          child: Text(
                            name[0].toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          rawName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Role
                  DataCell(
                    Text(
                      roleName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF475569),
                      ), // Simple text, no badge
                    ),
                  ),
                  // Contact
                  DataCell(
                    Text(
                      phone,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                  // Action
                  DataCell(
                    Align(
                      alignment: Alignment.centerRight,
                      child: _buildActionMenu(staff),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ============== PROFESSIONAL MOBILE CARD ==============
  Widget _buildMobileCard(Map<String, dynamic> staff) {
    final rawName = staff['user_first_name']?.toString() ?? '';
    final firstName = rawName.isNotEmpty ? rawName : 'U';
    final roleName = staff['role_name'] ?? 'Staff';
    final phoneNumber = staff['user_phone_number']?.toString() ?? '';
    final email = staff['user_email']?.toString() ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Minimal Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFF1F5F9),
                  child: Text(
                    firstName[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rawName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        roleName,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Menu
                _buildActionMenu(staff),
              ],
            ),
          ),

          if (phoneNumber.isNotEmpty || email.isNotEmpty) ...[
            Divider(height: 1, color: Colors.grey[100]),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (phoneNumber.isNotEmpty)
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 14,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            phoneNumber,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF475569),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionMenu(Map<String, dynamic> staff) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: Colors.grey[400]),
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      onSelected: (value) async {
        if (value == 'role') {
          _showRolePicker(staff);
        } else if (value == 'attendance') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Attendance feature coming soon!")),
          );
        } else if (value == 'face') {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FaceRegistrationScreen(
                staffId: staff['id'],
                staffName: staff['user_first_name'] ?? 'Staff',
              ),
            ),
          );
        }
      },
      itemBuilder: (context) => [
        _buildPopupMenuItem('role', 'Edit Role', Icons.shield_outlined),
        _buildPopupMenuItem(
          'attendance',
          'View Attendance',
          Icons.calendar_today_outlined,
        ),
        _buildPopupMenuItem('face', 'Register Face', Icons.face_outlined),
      ],
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem(
    String value,
    String text,
    IconData icon,
  ) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.blueGrey[700]),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
              color: Colors.blueGrey[800],
            ),
          ),
        ],
      ),
    );
  }

  void _showRolePicker(Map<String, dynamic> staff) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Assign Role',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a new role for ${staff['user_first_name'] ?? 'this user'}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            ..._rolesList.map((role) {
              final isSelected = role['role_name'] == staff['role_name'];
              final Color primaryColor = const Color(0xFF2563EB); // Modern blue
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                      primaryColor.withOpacity(isSelected ? 0.08 : 0.03),
                      Colors.white),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected
                          ? primaryColor.withOpacity(0.12)
                          : Colors.black.withOpacity(0.04),
                      blurRadius: isSelected ? 16 : 8,
                      offset: Offset(0, isSelected ? 6 : 2),
                    ),
                  ],
                  border: isSelected
                      ? Border.all(
                          color: primaryColor.withOpacity(0.3), width: 1.5)
                      : Border.all(
                          color: primaryColor.withOpacity(0.15), width: 1.0),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        if (!isSelected) {
                          _updateStaffRole(staff, role['role_name']);
                        }
                      },
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: isSelected ? 20 : 16,
                            vertical: isSelected ? 20 : 16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? primaryColor.withOpacity(0.15)
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.shield_rounded,
                                color: isSelected
                                    ? primaryColor
                                    : const Color(0xFF64748B),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    role['role_name'] ?? 'Unknown',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? primaryColor
                                          : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  if (role['description'] != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      role['description'],
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (isSelected)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'CURRENT',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
