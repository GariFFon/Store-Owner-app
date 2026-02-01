import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:exanor/services/store_owner_api_service.dart';
import 'package:exanor/components/translation_widget.dart';

class StaffManagementScreen extends StatefulWidget {
  final String storeId;

  const StaffManagementScreen({super.key, required this.storeId});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
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
        debugPrint(
          'Loaded ${_rolesList.length} roles and ${_staffList.length} staff members',
        );
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

  Color _getRandomAvatarColor(String name) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
    ];
    return colors[name.length % colors.length];
  }

  Future<void> _updateStaffRole(
    Map<String, dynamic> staff,
    String newRoleName,
  ) async {
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
              content: Text('Role updated to $newRoleName'),
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
              content: Text('Failed to update role'),
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
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const TranslatedText(
          'Staff Management',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchData,
                    child: const TranslatedText('Retry'),
                  ),
                ],
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 800;
                return RefreshIndicator(
                  onRefresh: _fetchData,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Section
                        if (isMobile)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Staff Management',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Manage your team members and their roles',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _showAddStaffBottomSheet,
                                icon: const Icon(Icons.add, size: 18),
                                label: const TranslatedText('Add Staff Member'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black87,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Staff Management',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Manage your team members and their roles',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              ElevatedButton.icon(
                                onPressed: _showAddStaffBottomSheet,
                                icon: const Icon(Icons.add, size: 18),
                                label: const TranslatedText('Add Staff Member'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black87,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 24),

                        // Stats Cards
                        if (isMobile)
                          SizedBox(
                            height: 110,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                SizedBox(
                                  width: 160,
                                  child: _buildStatCard(
                                    icon: Icons.people_outline,
                                    title: 'TOTAL STAFF',
                                    value: '${_staffList.length}',
                                    iconColor: Colors.blue,
                                    isSmall: true,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 160,
                                  child: _buildStatCard(
                                    icon: Icons.person_outline,
                                    title: 'PRESENT',
                                    value: '0',
                                    iconColor: Colors.green,
                                    isSmall: true,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 160,
                                  child: _buildStatCard(
                                    icon: Icons.person_off_outlined,
                                    title: 'ABSENT',
                                    value: '0',
                                    iconColor: Colors.red,
                                    isSmall: true,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  icon: Icons.people_outline,
                                  title: 'TOTAL STAFF',
                                  value: '${_staffList.length}',
                                  iconColor: Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildStatCard(
                                  icon: Icons.person_outline,
                                  title: 'PRESENT TODAY',
                                  value: '0',
                                  iconColor: Colors.green,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildStatCard(
                                  icon: Icons.person_off_outlined,
                                  title: 'ABSENT TODAY',
                                  value: '0',
                                  iconColor: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 24),

                        // Team Members List
                        if (isMobile)
                          _buildMobileList()
                        else
                          _buildDesktopTable(),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildMobileList() {
    if (_staffList.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: TranslatedText('No staff members found'),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _staffList.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final staff = _staffList[index];
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: _getRandomAvatarColor(
                      staff['user_first_name'] ?? 'U',
                    ),
                    child: Text(
                      (staff['user_first_name'] ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          staff['user_first_name'] ?? 'Unknown',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 0,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value:
                                  _rolesList.any(
                                    (r) => r['role_name'] == staff['role_name'],
                                  )
                                  ? staff['role_name']
                                  : null,
                              hint: Text(
                                staff['role_name'] ?? 'No Role',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              isDense: true,
                              icon: Icon(
                                Icons.arrow_drop_down,
                                size: 16,
                                color: Colors.blue.shade800,
                              ),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                              items: _rolesList.map<DropdownMenuItem<String>>((
                                role,
                              ) {
                                return DropdownMenuItem<String>(
                                  value: role['role_name'],
                                  child: Text(role['role_name'] ?? ''),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  _updateStaffRole(staff, newValue);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                    onSelected: (String value) {
                      _showComingSoonAlert(context);
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(
                            value: 'register_face',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.fingerprint,
                                  size: 20,
                                  color: Colors.grey,
                                ),
                                SizedBox(width: 8),
                                Text('Register Face'),
                              ],
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'take_attendance',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 20,
                                  color: Colors.grey,
                                ),
                                SizedBox(width: 8),
                                Text('Take Attendance'),
                              ],
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'view_attendance',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.visibility_outlined,
                                  size: 20,
                                  color: Colors.grey,
                                ),
                                SizedBox(width: 8),
                                Text('View Attendance Records'),
                              ],
                            ),
                          ),
                        ],
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Icon(Icons.email_outlined, size: 16, color: Colors.grey[400]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      staff['user_email'] ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.phone_outlined, size: 16, color: Colors.grey[400]),
                  const SizedBox(width: 8),
                  Text(
                    '${staff['user_phone_number'] ?? ''}',
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.grey[400]),
                  const SizedBox(width: 8),
                  Text(
                    'ID: ${(staff['id'] ?? '').toString().substring(0, 8)}...',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDesktopTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TranslatedText(
                  'Team Members',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                TranslatedText(
                  'Manage roles and permissions for your team',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Expanded(flex: 3, child: _buildHeaderCell('MEMBER')),
                Expanded(flex: 3, child: _buildHeaderCell('CONTACT')),
                Expanded(flex: 2, child: _buildHeaderCell('ROLE')),
                Expanded(flex: 2, child: _buildHeaderCell('STATUS')),
                const SizedBox(
                  width: 48,
                  child: Center(
                    child: Text(
                      'ACTIONS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_staffList.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: TranslatedText('No staff members found')),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _staffList.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final staff = _staffList[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      // Member
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: _getRandomAvatarColor(
                                staff['user_first_name'] ?? 'U',
                              ),
                              child: Text(
                                (staff['user_first_name'] ?? 'U')[0]
                                    .toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    staff['user_first_name'] ?? 'Unknown',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'ID: ${(staff['id'] ?? '').toString().substring(0, 8)}...',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Contact
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              staff['user_email'] ?? '',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${staff['user_phone_number'] ?? ''}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Role Dropdown
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 0,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.blue.shade300),
                            borderRadius: BorderRadius.circular(6),
                            color: Colors.white,
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value:
                                  _rolesList.any(
                                    (r) => r['role_name'] == staff['role_name'],
                                  )
                                  ? staff['role_name']
                                  : null,
                              hint: Text(
                                staff['role_name'] ?? 'Select Role',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
                              ),
                              isExpanded: true,
                              icon: const Icon(Icons.arrow_drop_down, size: 18),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                              items: _rolesList.map<DropdownMenuItem<String>>((
                                role,
                              ) {
                                return DropdownMenuItem<String>(
                                  value: role['role_name'],
                                  child: Text(role['role_name'] ?? ''),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  _updateStaffRole(staff, newValue);
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      // Status
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(left: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Not marked',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Actions
                      SizedBox(
                        width: 48,
                        child: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.grey),
                          onSelected: (String value) {
                            _showComingSoonAlert(context);
                          },
                          itemBuilder: (BuildContext context) =>
                              <PopupMenuEntry<String>>[
                                const PopupMenuItem<String>(
                                  value: 'register_face',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.fingerprint,
                                        size: 20,
                                        color: Colors.grey,
                                      ),
                                      SizedBox(width: 8),
                                      Text('Register Face'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem<String>(
                                  value: 'take_attendance',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        size: 20,
                                        color: Colors.grey,
                                      ),
                                      SizedBox(width: 8),
                                      Text('Take Attendance'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem<String>(
                                  value: 'view_attendance',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.visibility_outlined,
                                        size: 20,
                                        color: Colors.grey,
                                      ),
                                      SizedBox(width: 8),
                                      Text('View Attendance Records'),
                                    ],
                                  ),
                                ),
                              ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _showAddStaffBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddStaffSheet(
        roles: _rolesList,
        onAdd: (phoneNumber, roleId) {
          Navigator.pop(context);
          _handleAddStaff(phoneNumber, roleId);
        },
      ),
    );
  }

  Future<void> _handleAddStaff(String phoneNumber, String roleId) async {
    setState(() => _isLoading = true);

    // Add country code 91 default for India
    final formattedPhoneNumber = phoneNumber.length == 10
        ? '91$phoneNumber'
        : phoneNumber;

    try {
      final success = await StoreOwnerApiService.createStoreStaff(
        storeId: widget.storeId,
        phoneNumber: formattedPhoneNumber,
        roleId: roleId,
      );
      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('New staff member added successfully.'),
              backgroundColor: Colors.green,
            ),
          );
          _fetchData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to add staff member.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showComingSoonAlert(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Coming Soon'),
          content: const Text('This feature is coming soon!'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color iconColor,
    bool isSmall = false,
  }) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isSmall ? 8 : 12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: isSmall ? 20 : 24),
          ),
          SizedBox(width: isSmall ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isSmall ? 10 : 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500],
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: isSmall ? 2 : 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isSmall ? 20 : 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Colors.grey[500],
        letterSpacing: 0.5,
      ),
    );
  }
}

class _AddStaffSheet extends StatefulWidget {
  final List<Map<String, dynamic>> roles;
  final Function(String phoneNumber, String roleId) onAdd;

  const _AddStaffSheet({required this.roles, required this.onAdd});

  @override
  State<_AddStaffSheet> createState() => _AddStaffSheetState();
}

class _AddStaffSheetState extends State<_AddStaffSheet> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  String? _selectedRoleId;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add Staff Member',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 24,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Enter staff details to add them to your team',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 24),

            // Phone Number
            const Text(
              'Phone Number*',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: 'Enter 10 digit phone number',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Required';
                if (value.length != 10) return 'Must be 10 digits';
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Role
            const Text(
              'Role*',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedRoleId,
              decoration: InputDecoration(
                hintText: 'Select a role',
                hintStyle: TextStyle(color: Colors.black87, fontSize: 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              items: widget.roles.map((role) {
                return DropdownMenuItem<String>(
                  value: role['id'],
                  child: Text(
                    role['role_name'] ?? 'Unknown',
                    style: const TextStyle(fontSize: 13),
                  ),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedRoleId = value),
              validator: (value) => value == null ? 'Required' : null,
            ),
            const SizedBox(height: 32),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      widget.onAdd(_phoneController.text, _selectedRoleId!);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Add Staff'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
