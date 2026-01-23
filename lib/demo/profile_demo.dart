import 'package:flutter/material.dart';
// import 'package:exanor/screens/user_profile_screen.dart';
// import 'package:exanor/components/featured_professional_card.dart';

class ProfileDemo extends StatelessWidget {
  const ProfileDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile Demo')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Featured Professional Cards',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),

            // Demo FeaturedProfessionalCard
            // FeaturedProfessionalCard(
            //   userId: 'demo1',
            //   userName: 'Kim Parkinson',
            //   userHandle: 'theunderdog',
            //   userBio:
            //       'I will inspire 10 million people to do what they love the best they can!',
            //   profileImageUrl:
            //       'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
            //   isVerified: true,
            //   isOnline: true,
            //   rating: 5.0,
            //   reviewCount: 26,
            //   ratePerMinute: 3.00,
            //   minTalkTime: 5,
            //   totalSessions: 36,
            //   subscriptionPrice: 9.99,
            //   category: 'Marketing & Branding',
            // ),
            const SizedBox(height: 16),

            // Demo Direct Navigation Button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () {
                  // Navigator.push(
                  //   context,
                  //   MaterialPageRoute(
                  //     builder: (context) => const UserProfileScreen(
                  //       userId: 'demo2',
                  //       userName: 'Sarah Johnson',
                  //       userHandle: 'sarahcoach',
                  //       userBio:
                  //           'Life coach helping people achieve their dreams and build confidence.',
                  //       profileImageUrl:
                  //           'https://images.unsplash.com/photo-1494790108755-2616b612b5a5?w=150',
                  //       isVerified: true,
                  //       isOnline: false,
                  //       rating: 4.8,
                  //       reviewCount: 42,
                  //       ratePerMinute: 2.50,
                  //       minTalkTime: 10,
                  //       totalSessions: 85,
                  //       subscriptionPrice: 7.99,
                  //       isConnection: false,
                  //       enableConnectionRequest: false,
                  //     ),
                  //   ),
                  // );
                },
                child: const Text('Open Sarah\'s Profile Directly'),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
