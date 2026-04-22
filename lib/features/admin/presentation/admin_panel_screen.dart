// lib/features/admin/presentation/admin_panel_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uy_bor_app/features/admin/presentation/admin_moderation_screen.dart';
import '../../../core/theme/app_theme.dart';
import 'admin_users_screen.dart';
import 'admin_listings_screen.dart';

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.textPrimary),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_rounded, color: AppColors.accent, size: 20),
            const SizedBox(width: 8),
            const Text('Admin panel',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Statistika
            const Text('Statistika',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.people_alt_rounded,
                    label: 'Foydalanuvchilar',
                    color: AppColors.primary,
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .snapshots(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.home_work_rounded,
                    label: "Jami e'lonlar",
                    color: AppColors.accent,
                    stream: FirebaseFirestore.instance
                        .collection('listings')
                        .snapshots(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.check_circle_rounded,
                    label: "Faol e'lonlar",
                    color: AppColors.success,
                    stream: FirebaseFirestore.instance
                        .collection('listings')
                        .where('isActive', isEqualTo: true)
                        .snapshots(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.cancel_rounded,
                    label: "Faol emas",
                    color: AppColors.error,
                    stream: FirebaseFirestore.instance
                        .collection('listings')
                        .where('isActive', isEqualTo: false)
                        .snapshots(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Menyu
            const Text('Boshqaruv',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            _MenuCard(
              icon: Icons.people_alt_rounded,
              title: 'Foydalanuvchilar',
              subtitle: "Barcha foydalanuvchilarni ko'rish va boshqarish",
              color: AppColors.primary,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const AdminUsersScreen())),
            ),
            const SizedBox(height: 12),
            _MenuCard(
              icon: Icons.home_work_rounded,
              title: "E'lonlar",
              subtitle: "Barcha e'lonlarni ko'rish va boshqarish",
              color: AppColors.accent,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const AdminListingsScreen())),
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('listings')
                  .where('moderationStatus', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, snapshot) {
                final count = snapshot.data?.docs.length ?? 0;
                return _MenuCard(
                  icon: Icons.pending_actions_rounded,
                  title: 'Moderatsiya',
                  subtitle: "Yangi e'lonlarni ko'rib chiqish",
                  color: count > 0 ? AppColors.error : AppColors.textSecondary,
                  badge: count > 0 ? '$count' : null,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AdminModerationScreen()),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Stream<QuerySnapshot> stream;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.stream,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: stream,
            builder: (context, snapshot) {
              final count = snapshot.data?.docs.length ?? 0;
              return Text('$count',
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w700));
            },
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final String? badge; // qo'shildi

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(badge!,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              )
            else
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary, size: 22),
          ],
        ),
      ),
    );
  }
}