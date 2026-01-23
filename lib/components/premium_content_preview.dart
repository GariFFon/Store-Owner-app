import 'package:flutter/material.dart';

class PremiumContentPreview extends StatefulWidget {
  final VoidCallback onChoosePlan;

  const PremiumContentPreview({super.key, required this.onChoosePlan});

  @override
  State<PremiumContentPreview> createState() => _PremiumContentPreviewState();
}

class _PremiumContentPreviewState extends State<PremiumContentPreview> {
  int _currentPage = 0;
  final PageController _pageController = PageController();

  final List<Map<String, String>> _premiumContent = [
    {
      'title': 'BREATH: A 30 Day Yoga Journey',
      'author': 'by Adriene',
      'image':
          'https://images.unsplash.com/photo-1506629905537-ade19c9e5bb6?w=400&h=200&fit=crop',
      'tag': 'FEATURED',
    },
    {
      'title': 'Meditation Mastery Course',
      'author': 'by David Chen',
      'image':
          'https://images.unsplash.com/photo-1593810450967-f9c42742e326?w=400&h=200&fit=crop',
      'tag': 'POPULAR',
    },
    {
      'title': 'Mindfulness for Beginners',
      'author': 'by Sarah Johnson',
      'image':
          'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?w=400&h=200&fit=crop',
      'tag': 'NEW',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Video preview section
          Container(
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.shadow.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: _premiumContent.length,
              itemBuilder: (context, index) {
                final content = _premiumContent[index];
                return _buildContentCard(content, theme);
              },
            ),
          ),

          const SizedBox(height: 20),

          // Page indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _premiumContent.asMap().entries.map((entry) {
              return Container(
                width: _currentPage == entry.key ? 24 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: _currentPage == entry.key
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurface.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 40),

          // Content description
          Text(
            'Watch Premium Content',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onBackground,
            ),
          ),

          const SizedBox(height: 16),

          Text(
            'You will get access on all our platforms.\nExplore and watch videos on your phone,\ntablet, and laptop.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 40),

          // Pricing info
          Text(
            'Starting at \$17.99/month',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 24),

          // Choose Plan button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: widget.onChoosePlan,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 0,
              ),
              child: Text(
                'Choose Your Plan',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Subscribed already link
          TextButton(
            onPressed: () {
              // Handle already subscribed
            },
            child: Text(
              'Subscribed already?',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentCard(Map<String, String> content, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        image: DecorationImage(
          image: NetworkImage(content['image']!),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                content['tag']!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            const Spacer(),

            // Title and author
            Text(
              content['title']!,
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              content['author']!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
