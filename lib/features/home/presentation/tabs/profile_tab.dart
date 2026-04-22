// lib/features/home/presentation/tabs/profile_tab.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uy_bor_app/features/auth/presentation/face_verification_screen.dart';
import 'package:uy_bor_app/features/listings/presentation/saved_listings_screen.dart';
import 'package:uy_bor_app/features/profile/presentation/edit_profile_screen.dart';
import 'package:uy_bor_app/features/settings/presentation/settings_screen.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../admin/presentation/admin_panel_screen.dart';
import '../../../listings/presentation/my_listings_screen.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ProfileTab extends StatelessWidget {
  final bool isAdmin;
  const ProfileTab({super.key, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .snapshots(),
      builder: (context, snap) {
        final userData =
            snap.hasData && snap.data!.exists ? snap.data!.data() as Map<String, dynamic> : <String, dynamic>{};

        final isVerified = userData['isVerified'] == true;
        final username = userData['username'] as String? ?? '';
        final displayName =
            userData['displayName'] as String? ?? user?.displayName ?? '';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              _buildAvatar(displayName),
              const SizedBox(height: 16),

              // Name
              Text(
                displayName.isNotEmpty ? displayName : 'Foydalanuvchi',
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700),
              ),

              // Username
              if (username.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  '@$username',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 14),
                ),
              ],

              const SizedBox(height: 10),

              // Verification badge
              _VerificationBadge(isVerified: isVerified),

              // Admin badge
              if (isAdmin) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_rounded,
                            size: 14, color: AppColors.accent),
                        SizedBox(width: 6),
                        Text('Admin',
                            style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ]),
                ),
              ],

              const SizedBox(height: 32),

              _buildSection('ASOSIY', [
                _MenuItem(
                  icon: Icons.list_alt_rounded,
                  label: "Mening e'lonlarim",
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MyListingsScreen())),
                ),
                _MenuItem(
                  icon: Icons.edit_outlined,
                  label: 'Profilni tahrirlash',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const EditProfileScreen())),
                ),
                if (!isVerified)
                  _MenuItem(
                    icon: Icons.face_outlined,
                    label: 'Yuz tekshiruvi',
                    color: AppColors.accent,
                    onTap: () => _startFaceVerification(context, user),
                  ),
                _MenuItem(
                  icon: Icons.bookmark_outline_rounded,
                  label: 'Saqlanganlar',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SavedListingsScreen())),
                ),
                _MenuItem(
                  icon: Icons.settings_outlined,
                  label: 'Sozlamalar',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SettingsScreen())),
                ),
              ]),

              if (isAdmin) ...[
                const SizedBox(height: 16),
                _buildSection('ADMIN PANEL', [
                  _MenuItem(
                    icon: Icons.dashboard_rounded,
                    label: 'Boshqaruv paneli',
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AdminPanelScreen())),
                    color: AppColors.accent,
                  ),
                ]),
              ],

              const SizedBox(height: 16),
              _buildSection('', [
                _MenuItem(
                  icon: Icons.logout_rounded,
                  label: 'Chiqish',
                  color: AppColors.error,
                  onTap: () => FirebaseAuth.instance.signOut(),
                ),
              ]),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Future<void> _startFaceVerification(
      BuildContext context, User? user) async {
    if (user == null) return;

    final result = await Navigator.push<FaceVerificationResult>(
      context,
      MaterialPageRoute(builder: (_) => const FaceVerificationScreen()),
    );

    if (result == null || result.skipped) return;

    try {
      String? facePhotoUrl;
      final photo = result.photo;
      if (photo != null) {
        final ref =
            FirebaseStorage.instance.ref('face_photos/${user.uid}.jpg');
        final bytes = await photo.readAsBytes();
        await ref.putData(
            bytes, SettableMetadata(contentType: 'image/jpeg'));
        facePhotoUrl = await ref.getDownloadURL();
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'isVerified': true,
        'facePhotoUrl': facePhotoUrl,
      });
    } catch (_) {
      // Silently ignore upload errors
    }
  }

  Widget _buildAvatar(String displayName) {
    final letter =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.secondary]),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Center(
        child: Text(letter,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildSection(String title, List<_MenuItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty) ...[
          Text(title,
              style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8)),
          const SizedBox(height: 8),
        ],
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: items.asMap().entries.map((e) {
              final i = e.key;
              final item = e.value;
              return Column(
                children: [
                  ListTile(
                    onTap: item.onTap,
                    leading: Icon(item.icon,
                        color: item.color ?? AppColors.textPrimary,
                        size: 22),
                    title: Text(item.label,
                        style: TextStyle(
                            color: item.color ?? AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500)),
                    trailing: item.color == null
                        ? const Icon(Icons.chevron_right_rounded,
                            color: Color(0xFF64748B), size: 20)
                        : null,
                    horizontalTitleGap: 8,
                    minLeadingWidth: 0,
                    dense: true,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                  ),
                  if (i < items.length - 1)
                    Divider(
                        color: AppColors.divider,
                        height: 1,
                        indent: 52),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ── Verification badge widget ────────────────────────────────────────────────
class _VerificationBadge extends StatelessWidget {
  final bool isVerified;
  const _VerificationBadge({required this.isVerified});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: isVerified
            ? const Color(0xFF1A56DB).withValues(alpha: 0.15)
            : const Color(0xFFF59E0B).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isVerified
              ? const Color(0xFF1A56DB).withValues(alpha: 0.4)
              : const Color(0xFFF59E0B).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVerified
                ? Icons.verified_rounded
                : Icons.warning_amber_rounded,
            size: 14,
            color: isVerified
                ? AppColors.primary
                : const Color(0xFFF59E0B),
          ),
          const SizedBox(width: 6),
          Text(
            isVerified ? 'Tasdiqlangan' : 'Tasdiqlanmagan',
            style: TextStyle(
              color: isVerified
                  ? AppColors.primary
                  : const Color(0xFFF59E0B),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  _MenuItem(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.color});
}
