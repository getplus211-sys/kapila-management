import 'package:flutter/material.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  // 👇 User data
  final String? fullName;
  final String? username;
  final String? profilePictureUrl;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.fullName,
    this.username,
    this.profilePictureUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNavItem(
                icon: Icons.home,
                label: 'Home',
                index: 0,
              ),
              _buildNavItem(
                icon: Icons.trending_up,
                label: 'Performance',
                index: 1,
              ),
              _buildNavItem(
                icon: Icons.article,
                label: 'Posts',
                index: 2,
              ),
              _buildNavItem(
                icon: Icons.chat_bubble,
                label: 'Chat',
                index: 3,
              ),

              // ✅ PROFILE (image / first letter)
              _buildProfileNavItem(
                label: 'Profile',
                index: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= NORMAL NAV ITEM =================
  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isActive = currentIndex == index;

    return GestureDetector(
      onTap: () => onTap(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? Colors.orange : Colors.black,
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.orange : Colors.black,
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // ================= PROFILE NAV ITEM =================
  Widget _buildProfileNavItem({
    required String label,
    required int index,
  }) {
    final isActive = currentIndex == index;

    return GestureDetector(
      onTap: () => onTap(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildProfileAvatar(isActive),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.orange : Colors.black,
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // ================= PROFILE AVATAR =================
  Widget _buildProfileAvatar(bool isActive) {
    final hasImage =
        profilePictureUrl != null && profilePictureUrl!.trim().isNotEmpty;

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey.shade300,
        border: Border.all(
          color: isActive ? Colors.orange : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: hasImage
          ? ClipOval(
              child: Image.network(
                profilePictureUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildInitialText(),
              ),
            )
          : _buildInitialText(),
    );
  }

  // ================= FIRST LETTER (FIXED) =================
  Widget _buildInitialText() {
    String letter = '?';

    // 👇 SAFE + GUARANTEED LOGIC
    final name = (fullName ?? username ?? '').trim();

    if (name.isNotEmpty) {
      // Handles spaces like "Kapil Patel"
      letter = name.split(RegExp(r'\s+')).first[0].toUpperCase();
    }

    return Center(
      child: Text(
        letter,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }
}
