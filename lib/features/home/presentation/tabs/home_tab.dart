// lib/features/home/presentation/tabs/home_tab.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/listing_card.dart';

class HomeTab extends StatelessWidget {
  final ValueChanged<String> onCategorySelected;
  const HomeTab({super.key, required this.onCategorySelected});

  static const _categories = [
    {'icon': Icons.apartment_rounded, 'label': 'Kvartira'},
    {'icon': Icons.home_rounded, 'label': 'Uy'},
    {'icon': Icons.meeting_room_rounded, 'label': 'Xona'},
    {'icon': Icons.store_rounded, 'label': 'Ofis'},
    {'icon': Icons.terrain_rounded, 'label': 'Yer'},
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFeatured(),
          const SizedBox(height: 24),
          const Text('Kategoriyalar',
              style: TextStyle(color: AppColors.textPrimary,
                  fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          _buildCategories(),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("So'nggi e'lonlar",
                  style: TextStyle(color: AppColors.textPrimary,
                      fontSize: 18, fontWeight: FontWeight.w700)),
              TextButton(
                onPressed: () => onCategorySelected('Barchasi'),
                child: const Text('Barchasi',
                    style: TextStyle(color: AppColors.primary, fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildListings(),
        ],
      ),
    );
  }

  Widget _buildFeatured() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('listings')
          .where('isActive', isEqualTo: true)
          .where('isFeatured', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final docs = snapshot.data!.docs;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🔥 Featured',
                style: TextStyle(color: AppColors.textPrimary,
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            SizedBox(
              height: 220,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: docs.length,
                itemBuilder: (_, i) => SizedBox(
                  width: 260,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: ListingCard(
                        data: docs[i].data() as Map<String, dynamic>),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategories() {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (_, i) {
          final cat = _categories[i];
          return GestureDetector(
            onTap: () => onCategorySelected(cat['label'] as String),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(cat['icon'] as IconData,
                      color: AppColors.primary, size: 28),
                  const SizedBox(height: 6),
                  Text(cat['label'] as String,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildListings() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('listings')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const _EmptyState();
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (_, i) => ListingCard(
              data: snapshot.data!.docs[i].data() as Map<String, dynamic>),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      children: [
        SizedBox(height: 40),
        Icon(Icons.home_work_outlined, size: 64, color: AppColors.textSecondary),
        SizedBox(height: 16),
        Text("Hali e'lonlar yo'q",
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
      ],
    ),
  );
}