import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../screens/theme_provider.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

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
    final t = context.watch<ThemeProvider>();

    // ✅ TRUE GLASSMORPHIC: very low opacity so content bleeds through blur
    final navBg         = t.isDark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.20);
    final activeTabBg   = t.isDark ? Colors.white.withOpacity(0.12) : t.brand.withOpacity(0.15);
    final activeColor   = t.isDark ? const Color(0xFF38BDF8) : t.brand;
    final inactiveColor = t.isDark ? Colors.white.withOpacity(0.55) : Colors.black.withOpacity(0.40);
    final borderColor   = t.isDark ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.60);

    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 16, top: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(50),
        child: BackdropFilter(
          // ✅ Strong blur — content shows through
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              color: navBg,
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: borderColor, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 30,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavItem(icon: Icons.school_rounded,      label: 'KAPILA',      index: 0, currentIndex: currentIndex, onTap: onTap, activeColor: activeColor, activeTabBg: activeTabBg, inactiveColor: inactiveColor),
                  _NavItem(icon: Icons.trending_up_rounded, label: 'Performance', index: 1, currentIndex: currentIndex, onTap: onTap, activeColor: activeColor, activeTabBg: activeTabBg, inactiveColor: inactiveColor),
                  Container(
                    width: 1, height: 28,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, borderColor, Colors.transparent],
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  _NavItem(icon: Icons.article_rounded,     label: 'Posts', index: 2, currentIndex: currentIndex, onTap: onTap, activeColor: activeColor, activeTabBg: activeTabBg, inactiveColor: inactiveColor),
                  _NavItem(icon: Icons.chat_bubble_rounded, label: 'Chat',  index: 3, currentIndex: currentIndex, onTap: onTap, activeColor: activeColor, activeTabBg: activeTabBg, inactiveColor: inactiveColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int currentIndex;
  final Function(int) onTap;
  final Color activeColor;
  final Color activeTabBg;
  final Color inactiveColor;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
    required this.activeColor,
    required this.activeTabBg,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentIndex == index;

    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? activeTabBg : Colors.transparent,
          borderRadius: BorderRadius.circular(40),
          border: isActive
              ? Border.all(color: activeColor.withOpacity(0.25), width: 1)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isActive ? activeColor : inactiveColor, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isActive ? activeColor : inactiveColor,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}