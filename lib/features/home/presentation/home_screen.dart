// lib/features/home/presentation/home_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_theme.dart';
import '../../listings/presentation/add_listing.dart';
import 'tabs/home_tab.dart';
import 'tabs/search_tab.dart';
import 'tabs/messages_tab.dart';
import 'tabs/profile_tab.dart';
import 'tabs/map_tab.dart';
import 'tabs/ai_search_tab.dart';

class HomeScreen extends StatefulWidget {
  final bool isAdmin;

  const HomeScreen({
    super.key,
    required this.isAdmin,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // Barcha login bo'lgan foydalanuvchilar e'lon yarata oladi
  static const bool _canAddListing = true;

  static const int _addIndex = 4;
  static const int _msgIndex = 5;
  static const int _profileIndex = 6;

  List<_NavItem> get _navItems => [
    const _NavItem(icon: Icons.grid_view_rounded, label: 'Asosiy'),
    const _NavItem(icon: Icons.search_rounded, label: 'Qidiruv'),
    const _NavItem(icon: Icons.map_outlined, activeIcon: Icons.map_rounded, label: 'Xarita'),
    const _NavItem(icon: Icons.auto_awesome_outlined, activeIcon: Icons.auto_awesome, label: 'AI'),
    if (_canAddListing)
      const _NavItem(
          icon: Icons.add_circle_outline_rounded,
          activeIcon: Icons.add_circle_rounded,
          label: "E'lon"),
    const _NavItem(
        icon: Icons.chat_bubble_outline_rounded,
        activeIcon: Icons.chat_bubble_rounded,
        label: 'Xabarlar'),
    const _NavItem(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: 'Profil'),
  ];

  // Jami o'qilmagan xabarlar soni
  Stream<int> get _unreadStream {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(0);

    return FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
      int total = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final unreadCount = data['unreadCount'] as Map<String, dynamic>?;
        total += (unreadCount?[uid] ?? 0) as int;
      }
      return total;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: _currentIndex == _addIndex ? null : _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0F172A),
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.home_work_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Text('Uy Bor',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5)),
        ],
      ),
      actions: [
        if (widget.isAdmin)
          Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              Icon(Icons.shield_rounded, size: 14, color: AppColors.accent),
              const SizedBox(width: 4),
              Text('Admin',
                  style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        IconButton(
          onPressed: () {},
          icon: Stack(children: [
            const Icon(Icons.notifications_outlined,
                color: AppColors.textPrimary, size: 26),
            Positioned(
              right: 0, top: 0,
              child: Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(
                      color: AppColors.error, shape: BoxShape.circle)),
            ),
          ]),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildBody() {
    if (_currentIndex == 0) {
      return HomeTab(
        onCategorySelected: (_) => setState(() => _currentIndex = 1),
      );
    }
    if (_currentIndex == 1) return const SearchTab();
    if (_currentIndex == 2) return const MapTab();
    if (_currentIndex == 3) return const AiSearchTab();
    if (_currentIndex == _addIndex) {
      return AddListingScreen(
          onSuccess: () => setState(() => _currentIndex = 0));
    }
    if (_currentIndex == _msgIndex) return const MessagesTab();
    if (_currentIndex == _profileIndex) {
      return ProfileTab(isAdmin: widget.isAdmin);
    }
    return HomeTab(
        onCategorySelected: (_) => setState(() => _currentIndex = 1));
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: StreamBuilder<int>(
            stream: _unreadStream,
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;

              return Row(
                children: List.generate(_navItems.length, (index) {
                  final item = _navItems[index];
                  final isSelected = _currentIndex == index;
                  final isMsgTab = index == _msgIndex;

                  return Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _currentIndex = index),
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withValues(alpha: 0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Icon(
                                  isSelected
                                      ? (item.activeIcon ?? item.icon)
                                      : item.icon,
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                  size: 24,
                                ),
                                // Xabarlar tab badge
                                if (isMsgTab &&
                                    unreadCount > 0 &&
                                    !isSelected)
                                  Positioned(
                                    right: -6, top: -4,
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(
                                        color: AppColors.error,
                                        shape: BoxShape.circle,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 16,
                                        minHeight: 16,
                                      ),
                                      child: Text(
                                        unreadCount > 99
                                            ? '99+'
                                            : '$unreadCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(item.label,
                              style: TextStyle(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              )),
                        ],
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    this.activeIcon,
    required this.label,
  });
}