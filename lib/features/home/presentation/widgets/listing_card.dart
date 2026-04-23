// lib/features/home/presentation/widgets/listing_card.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../listings/presentation/listing_detail_screen.dart';

const double kRate = 12000;

String formatPrice(double price) {
  if (price >= 1000000) return '${(price / 1000000).toStringAsFixed(1)}M';
  if (price >= 1000) return '${(price / 1000).toStringAsFixed(0)}K';
  return price.toStringAsFixed(0);
}

class ListingCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback? onTap;

  const ListingCard({super.key, required this.data, this.onTap});

  @override
  State<ListingCard> createState() => _ListingCardState();
}

class _ListingCardState extends State<ListingCard> {
  bool _saved = false;
  bool _loadingSave = false;

  @override
  void initState() {
    super.initState();
    _checkSaved();
  }

  Future<void> _checkSaved() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final saved = List<String>.from(doc.data()?['savedListings'] ?? []);
    if (mounted) setState(() => _saved = saved.contains(widget.data['id']));
  }

  Future<void> _toggleSave() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _loadingSave = true);
    final ref = FirebaseFirestore.instance.collection('users').doc(uid);
    if (_saved) {
      await ref.update({
        'savedListings': FieldValue.arrayRemove([widget.data['id']])
      });
    } else {
      await ref.update({
        'savedListings': FieldValue.arrayUnion([widget.data['id']])
      });
    }
    if (mounted) setState(() { _saved = !_saved; _loadingSave = false; });
  }

  @override
  Widget build(BuildContext context) {
    final images = List<String>.from(widget.data['images'] ?? []);
    final price = (widget.data['price'] ?? 0).toDouble();
    final currency = (widget.data['currency'] ?? 'USD').toString();
    final period = widget.data['period'] ?? 'oylik';

    final mainPrice = '${formatPrice(price)} $currency / $period';
    final altPrice = currency == 'USD'
        ? '≈ ${formatPrice(price * kRate)} UZS'
        : '≈ \$${formatPrice(price / kRate)}';

    return GestureDetector(
      onTap: widget.onTap ??
          () => Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) => ListingDetailScreen(data: widget.data))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImages(images),
            _buildInfo(mainPrice, altPrice),
          ],
        ),
      ),
    );
  }

  Widget _buildImages(List<String> images) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: images.isNotEmpty
          ? SizedBox(
              height: 180,
              child: Stack(
                children: [
                  PageView.builder(
                    itemCount: images.length,
                    itemBuilder: (context, i) => Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(images[i],
                            fit: BoxFit.cover,
                            loadingBuilder: (_, child, progress) =>
                                progress == null
                                    ? child
                                    : Container(
                                        color: AppColors.surface,
                                        child: const Center(
                                            child: CircularProgressIndicator(
                                                color: AppColors.primary,
                                                strokeWidth: 2))),
                            errorBuilder: (_, _, _) => _placeholder()),
                        if (images.length > 1)
                          Positioned(
                              bottom: 8, right: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(12)),
                                child: Text('${i + 1}/${images.length}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                              )),
                      ],
                    ),
                  ),
                  // ── Bookmark tugmasi ──
                  Positioned(
                    top: 10, right: 10,
                    child: GestureDetector(
                      onTap: _toggleSave,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _loadingSave
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : Icon(
                                _saved
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_outline_rounded,
                                color: _saved
                                    ? AppColors.accent
                                    : Colors.white,
                                size: 20,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : _placeholder(),
    );
  }

  Widget _placeholder() => Container(
      height: 180,
      color: AppColors.surface,
      child: const Center(
          child: Icon(Icons.home_work_rounded,
              color: AppColors.textSecondary, size: 48)));

  Widget _buildInfo(String mainPrice, String altPrice) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(widget.data['category'] ?? '',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          Text(widget.data['title'] ?? '',
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Text(mainPrice,
              style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(altPrice,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          const SizedBox(height: 8),
          if ((widget.data['address'] ?? '').isNotEmpty)
            Row(children: [
              const Icon(Icons.location_on_outlined,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                  child: Text(widget.data['address'],
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)),
            ]),
          const SizedBox(height: 8),
          Row(children: [
            if ((widget.data['rooms'] ?? 0) > 0) ...[
              const Icon(Icons.meeting_room_outlined,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text('${widget.data['rooms']} xona',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(width: 12),
            ],
            if ((widget.data['area'] ?? 0) > 0) ...[
              const Icon(Icons.square_foot_rounded,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text('${widget.data['area']} m²',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
            ],
          ]),
        ],
      ),
    );
  }
}