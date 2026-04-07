import 'package:flutter/material.dart';
import 'package:nook/features/profile/presentation/widgets/favorite_card.dart';
import 'package:nook/features/profile/presentation/widgets/review_card.dart';
import 'package:nook/features/favorites/presentation/page/favorites_page.dart';
import 'package:nook/features/profile/presentation/pages/editprofile_page.dart';
import 'package:nook/features/profile/presentation/pages/reviews_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key,});


  @override
  Widget build(BuildContext context) {

    final reviews = [
      {'name': 'Name Name Name', 'date': '00/00/00', 'rating': 4.9, 'reviewText': 'The quick brown fox jumps over the lazy dog.', 'photos': <String>[]},
      {'name': 'Name Name Name', 'date': '00/00/00', 'rating': 4.9, 'reviewText': 'The quick brown fox jumps over the lazy dog.', 'photos': <String>[]},
      {'name': 'Name Name Name', 'date': '00/00/00', 'rating': 3.5, 'reviewText': 'The quick brown fox jumps over the lazy dog.', 'photos': <String>[]},
      {'name': 'Name Name Name', 'date': '00/00/00', 'rating': 5.0, 'reviewText': 'The quick brown fox jumps over the lazy dog.', 'photos': <String>[]},
      {'name': 'Name Name Name', 'date': '00/00/00', 'rating': 2.0, 'reviewText': 'Extra review that should not show.', 'photos': <String>[]},
    ];

    final visibleReviews = reviews.take(4).toList();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const SizedBox(height: 24),

            const ProfileHeroSection(),
            const SizedBox(height: 32),

            // Favorites row
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Favorites",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                    ),
                    _SeeMoreLink(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const FavoritesPage()),
                        );
                      },
                    ),
                  ],
                )
            ),


            const SizedBox(height: 12),

            SizedBox(
              height: 106,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                itemCount: 4,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  return FavoriteCard(heroTag: 'favorite_$index');
                },
              ),
            ),

            const SizedBox(height: 32),

            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Reviews",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                    ),
                    _SeeMoreLink(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ReviewsPage()),
                        );
                      },
                    ),
                  ],
                )
            ),



            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 22),
              itemCount: visibleReviews.length, // replace with your actual review list length
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final review = visibleReviews[index];
                return ReviewCard(
                  name: review['name'] as String,
                  date: review['date'] as String,
                  rating: review['rating'] as double,
                  reviewText: review['reviewText'] as String,
                  photos: review['photos'] as List<String>,
                );
              },
            ),

            const SizedBox(height: 32),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Settings",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  _SettingsTile(
                    label: 'Edit Profile',
                    icon: Icons.chevron_right,
                    iconColor: const Color(0xFF344E41),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const EditProfilePage()),
                      );
                    },
                  ),
                  const Divider(height: 1, color: Color(0xFFE0E0E0)),
                  _SettingsTile(
                    label: 'Logout',
                    icon: Icons.logout,
                    iconColor: Colors.red,
                    labelColor: Colors.black,
                    onTap: () => _showLogoutDialog(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),


          ],
        )

      )),
    );
  }
}


class ProfileHeroSection extends StatelessWidget {
  const ProfileHeroSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF344E41),
                width: 2.5
              )
            ),
            child: Padding(
              padding: const EdgeInsets.all(2.5),
              child: Container(
                width: 75,
                height: 75,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE8E8E8)
                ),
                child: const Icon(Icons.person_rounded,
                    size: 40, color: Color(0xFFBDBDBD)),
              ),
            )
          ),

          const SizedBox(width: 12),

          // Name + bio
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Charles Argawanon",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  "bahogolok@gmail.cum",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
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
}

class _SeeMoreLink extends StatefulWidget {
  final VoidCallback? onTap;

  const _SeeMoreLink({this.onTap});

  @override
  State<_SeeMoreLink> createState() => _SeeMoreLinkState();
}

class _SeeMoreLinkState extends State<_SeeMoreLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap, // ← uses the passed-in callback
        child: Text(
          'see more >',
          style: TextStyle(
            fontSize: 13,
            color: const Color(0xFF4CAF50),
            fontWeight: FontWeight.w400,
            decoration: _hovered ? TextDecoration.underline : TextDecoration.none,
            decorationColor: const Color(0xFF4CAF50),
          ),
        ),
      ),
    );
  }
}




// --- Settings Tile ---
class _SettingsTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final Color labelColor;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.labelColor = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 15, color: labelColor),
            ),
            Icon(icon, color: iconColor, size: 20),
          ],
        ),
      ),
    );
  }
}


// --- Logout Dialog ---
void _showLogoutDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Log out', style: TextStyle(fontWeight: FontWeight.w600)),
      content: const Text('Are you sure you want to log out?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
          },
          child: const Text('Log out', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}
