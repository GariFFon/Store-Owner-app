import 'package:flutter/material.dart';

class NotificationsHistoryScreen extends StatefulWidget {
  const NotificationsHistoryScreen({super.key});

  @override
  State<NotificationsHistoryScreen> createState() => _NotificationsHistoryScreenState();
}

class _NotificationsHistoryScreenState extends State<NotificationsHistoryScreen> {
  int _selectedTab = 0; // 0 for Unread, 1 for Read

  final List<Map<String, dynamic>> _dummyNotifications = [
    {
      'id': '1',
      'title': 'Your order has been verified',
      'body': 'We have successfully verified your order for your "Playstation 5 Pro" purchase.',
      'time': '1h ago',
      'isRead': false,
      'isNew': true,
      'icon': Icons.check,
      'image': null,
    },
    {
      'id': '2',
      'title': 'Summer Fashion Sale Is Here!',
      'body': 'Summer fashion sale is here! Enjoy -50% OFF ALL PURCHASES!',
      'time': '1h ago',
      'isRead': false,
      'isNew': false, // Just to vary icon display
      'icon': Icons.dry_cleaning_rounded, // Assuming dress icon
      'image': 'https://plus.unsplash.com/premium_photo-1664202526559-e21e9c0fb46a?q=80&w=600&auto=format&fit=crop', // Stock image placeholder
    },
    {
      'id': '3',
      'title': 'Delivery scheduled',
      'body': 'Your items will be delivered tomorrow between 9 AM and 1 PM.',
      'time': 'Yesterday',
      'isRead': true,
      'isNew': false,
      'icon': Icons.local_shipping_outlined,
      'image': null,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Smooth gradient background like the design
    final bgGradient = isDark 
        ? const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)], begin: Alignment.topLeft, end: Alignment.bottomRight)
        : const LinearGradient(colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)], begin: Alignment.topLeft, end: Alignment.bottomRight);

    // Filter notifications based on tab
    final displayedNotifications = _dummyNotifications.where((n) {
      if (_selectedTab == 0) return !(n['isRead'] as bool); // Unread
      return (n['isRead'] as bool); // Read
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent, // Controlled by container
      body: Container(
        decoration: BoxDecoration(gradient: bgGradient),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAppBar(isDark),
              const SizedBox(height: 16),
              _buildTabBar(isDark),
              const SizedBox(height: 24),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  'Today',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: displayedNotifications.isEmpty
                    ? Center(
                        child: Text(
                          "You're all caught up!",
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black54,
                            fontSize: 16,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        itemCount: displayedNotifications.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 16),
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          return _buildNotificationCard(
                              displayedNotifications[index], isDark);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, 
                color: isDark ? Colors.white : const Color(0xFF0F172A), size: 22),
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            'Notifications',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: isDark ? Colors.white10 : Colors.black12,
            backgroundImage: const NetworkImage('https://i.pravatar.cc/100?img=11'), // Dummy profile pic
            child: const Align(
              alignment: Alignment.bottomRight,
              child: CircleAvatar(
                radius: 5,
                backgroundColor: Colors.blueAccent,
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0).withOpacity(0.5),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Stack(
          children: [
            // Animated indicator
            AnimatedAlign(
              alignment: _selectedTab == 0 ? Alignment.centerLeft : Alignment.centerRight,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 0),
                    behavior: HitTestBehavior.opaque,
                    child: Center(
                      child: Text(
                        'Unread',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: _selectedTab == 0 ? FontWeight.w700 : FontWeight.w500,
                          color: _selectedTab == 0
                              ? (isDark ? Colors.white : const Color(0xFF0F172A))
                              : (isDark ? Colors.white54 : const Color(0xFF64748B)),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 1),
                    behavior: HitTestBehavior.opaque,
                    child: Center(
                      child: Text(
                        'Read',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: _selectedTab == 1 ? FontWeight.w700 : FontWeight.w500,
                          color: _selectedTab == 1
                              ? (isDark ? Colors.white : const Color(0xFF0F172A))
                              : (isDark ? Colors.white54 : const Color(0xFF64748B)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> data, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon Circle
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                  ),
                ),
                child: Icon(
                  data['icon'],
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              
              // Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            data['title'],
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          data['time'],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white54 : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data['body'],
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Optional Image attached
          if (data['image'] != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                data['image'],
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 140,
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_not_supported_rounded, color: Colors.grey),
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }
}
