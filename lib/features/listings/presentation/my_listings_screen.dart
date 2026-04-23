import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../home/presentation/widgets/listing_card.dart';
import 'listing_detail_screen.dart';
import 'add_listing.dart';

class MyListingsScreen extends StatelessWidget {
  const MyListingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: AppColors.textPrimary,
          ),
        ),
        title: const Text(
          "Mening e'lonlarim",
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('listings')
            .where('uid', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Xato: ${snapshot.error}',
                style: const TextStyle(color: AppColors.error),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const _EmptyState();
          }

          final docs = snapshot.data!.docs;

          // Ikki guruhga ajratish
          final approved = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return data['moderationStatus'] == 'approved';
          }).toList();

          final notApproved = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return data['moderationStatus'] != 'approved';
          }).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Tasdiqlanmaganlar ──
              if (notApproved.isNotEmpty) ...[
                _SectionHeader(
                  label: 'Kutilmoqda / Rad etilgan',
                  count: notApproved.length,
                  color: AppColors.error,
                ),
                const SizedBox(height: 10),
                ...notApproved.map(
                  (doc) => _MyListingCard(
                    data: doc.data() as Map<String, dynamic>,
                    docId: doc.id,
                  ),
                ),
                if (approved.isNotEmpty) const SizedBox(height: 8),
              ],

              // ── Tasdiqlanganlar ──
              if (approved.isNotEmpty) ...[
                _SectionHeader(
                  label: 'Tasdiqlanganlar',
                  count: approved.length,
                  color: AppColors.success,
                ),
                const SizedBox(height: 10),
                ...approved.map(
                  (doc) => _MyListingCard(
                    data: doc.data() as Map<String, dynamic>,
                    docId: doc.id,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _SectionHeader({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════
// MY LISTING CARD
// ═══════════════════════════════════════════
class _MyListingCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  const _MyListingCard({required this.data, required this.docId});

  bool get _isApproved => data['moderationStatus'] == 'approved';
  bool get _isRejected => data['moderationStatus'] == 'rejected';

  Future<void> _toggleActive(BuildContext context) async {
    // Faqat admin tasdiqlagan e'lonni faollashtirish mumkin
    if (!_isApproved) return;

    final isActive = data['isActive'] ?? false;
    await FirebaseFirestore.instance.collection('listings').doc(docId).update({
      'isActive': !isActive,
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isActive ? "E'lon faolsizlantirildi" : "E'lon faollashtirildi",
          ),
          backgroundColor: isActive ? AppColors.error : AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _delete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "E'lonni o'chirish",
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          "Bu e'lonni o'chirishni tasdiqlaysizmi?",
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Bekor qilish',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              "O'chirish",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('listings')
          .doc(docId)
          .delete();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("E'lon o'chirildi"),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  void _edit(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddListingScreen(
          editData: data,
          onSuccess: () => Navigator.pop(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isActive = data['isActive'] ?? false;
    final images = List<String>.from(data['images'] ?? []);
    final price = (data['price'] ?? 0).toDouble();
    final currency = (data['currency'] ?? 'USD').toString();
    final period = data['period'] ?? 'oylik';
    final rejectionReason = (data['rejectionReason'] ?? '').toString().trim();
    final moderationStatus = (data['moderationStatus'] ?? 'pending').toString();

    // Border rangi: rejected=qizil, pending=sariq, approved=oddiy
    final borderColor = _isRejected
        ? AppColors.error.withValues(alpha: 0.4)
        : moderationStatus == 'pending'
        ? const Color(0xFFFBBF24).withValues(alpha: 0.4)
        : AppColors.divider;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Rasm ──
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ListingDetailScreen(data: data),
              ),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: images.isNotEmpty
                  ? Image.network(
                      images[0],
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _placeholder(),
                    )
                  : _placeholder(),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Sarlavha + status ──
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        data['title'] ?? '',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(
                      moderationStatus: moderationStatus,
                      isActive: isActive,
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // ── Narx ──
                Text(
                  '${formatPrice(price)} $currency / $period',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                // ── Rad etish sababi ──
                if (_isRejected && rejectionReason.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            rejectionReason,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ── Pending xabari ──
                if (moderationStatus == 'pending') ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBBF24).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFFBBF24).withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.hourglass_top_rounded,
                          size: 16,
                          color: Color(0xFFFBBF24),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Admin tekshiruvini kutmoqda...',
                          style: TextStyle(
                            color: Color(0xFFFBBF24),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // ── Tugmalar ──
                Row(
                  children: [
                    // Faollashtirish / Faolsizlantirish
                    Expanded(
                      child: Tooltip(
                        message: _isApproved
                            ? ''
                            : 'Admin tasdiqlamaguncha faollashtirish mumkin emas',
                        child: OutlinedButton.icon(
                          onPressed: _isApproved
                              ? () => _toggleActive(context)
                              : null,
                          icon: Icon(
                            isActive
                                ? Icons.pause_circle_outline_rounded
                                : Icons.play_circle_outline_rounded,
                            size: 18,
                          ),
                          label: Text(
                            isActive ? 'Faolsizlantirish' : 'Faollashtirish',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _isApproved
                                ? (isActive
                                      ? AppColors.textSecondary
                                      : AppColors.success)
                                : AppColors.textSecondary,
                            side: BorderSide(
                              color: _isApproved
                                  ? (isActive
                                        ? AppColors.divider
                                        : AppColors.success)
                                  : AppColors.divider,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Tahrirlash
                    OutlinedButton.icon(
                      onPressed: () => _edit(context),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text(''),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // O'chirish
                    OutlinedButton.icon(
                      onPressed: () => _delete(context),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text(''),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(
                          color: AppColors.error.withValues(alpha: 0.5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
    height: 160,
    color: AppColors.surface,
    child: const Center(
      child: Icon(
        Icons.home_work_rounded,
        color: AppColors.textSecondary,
        size: 48,
      ),
    ),
  );
}

// ── Status badge ──────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String moderationStatus;
  final bool isActive;
  const _StatusBadge({required this.moderationStatus, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;

    if (moderationStatus == 'rejected') {
      color = AppColors.error;
      label = 'Rad etildi';
    } else if (moderationStatus == 'pending') {
      color = const Color(0xFFFBBF24);
      label = 'Kutilmoqda';
    } else {
      // approved
      color = isActive ? AppColors.success : AppColors.textSecondary;
      label = isActive ? 'Faol' : 'Faol emas';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.list_alt_rounded, size: 64, color: AppColors.textSecondary),
        SizedBox(height: 16),
        Text(
          "Hali e'lonlar yo'q",
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8),
        Text(
          "E'lon tab orqali yangi e'lon qo'shing",
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
      ],
    ),
  );
}
