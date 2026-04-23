// lib/features/listings/presentation/listing_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../home/presentation/widgets/listing_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../chat/data/chat_service.dart';
import '../../chat/presentation/chat_screen.dart';

class ListingDetailScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  const ListingDetailScreen({super.key, required this.data});

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  int _currentImage = 0;
  final PageController _pageController = PageController();
  String _ownerPhone = '';

  @override
  void initState() {
    super.initState();
    _incrementViews();
    _loadOwnerPhone();
  }

  Future<void> _loadOwnerPhone() async {
    // Prefer listing's own phone field; fall back to owner's profile phone
    final listingPhone = (widget.data['phone'] ?? '').toString().trim();
    if (listingPhone.isNotEmpty) {
      if (mounted) setState(() => _ownerPhone = listingPhone);
      return;
    }
    final ownerUid = widget.data['uid'] ?? '';
    if (ownerUid.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(ownerUid)
          .get();
      final profilePhone = (doc.data()?['phone'] ?? '').toString().trim();
      if (mounted) setState(() => _ownerPhone = profilePhone);
    } catch (_) {}
  }

  Future<void> _incrementViews() async {
    final id = widget.data['id'] ?? '';
    if (id.isEmpty) return;
    await FirebaseFirestore.instance.collection('listings').doc(id).update({
      'views': FieldValue.increment(1),
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _callPhone() async {
    if (_ownerPhone.isEmpty) return;
    final uri = Uri.parse('tel:$_ownerPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openChat() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final sellerUid = widget.data['uid'] ?? '';
    if (sellerUid == user.uid) return;

    final images = List<String>.from(widget.data['images'] ?? []);
    final price = (widget.data['price'] ?? 0).toDouble();
    final currency = widget.data['currency'] ?? 'USD';
    final period = widget.data['period'] ?? 'oylik';
    final sellerName = widget.data['ownerName'] ?? 'Foydalanuvchi';

    final chatId = await ChatService.getOrCreateChat(
      sellerUid: sellerUid,
      sellerName: sellerName,
      listingId: widget.data['id'] ?? '',
      listingTitle: widget.data['title'] ?? '',
      listingImage: images.isNotEmpty ? images[0] : '',
      listingPrice: price,
      listingCurrency: currency,
      listingPeriod: period,
    );

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatData: {
              'id': chatId,
              'listingData': widget.data, // ← to'liq ma'lumot
              'listingTitle': widget.data['title'] ?? '',
              'listingImage': images.isNotEmpty ? images[0] : '',
              'listingPrice': price,
              'listingCurrency': currency,
              'listingPeriod': period,
              'names': {user.uid: sellerName},
            },
          ),
        ),
      );
    }
  }

  bool get _isOwner =>
      FirebaseAuth.instance.currentUser?.uid == widget.data['uid'];

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final images = List<String>.from(data['images'] ?? []);
    final price = (data['price'] ?? 0).toDouble();
    final currency = (data['currency'] ?? 'USD').toString();
    final period = data['period'] ?? 'oylik';
    final hasLocation = data['location'] != null;
    final hasPhone = _ownerPhone.isNotEmpty;

    final mainPrice = '${formatPrice(price)} $currency / $period';
    final altPrice = currency == 'USD'
        ? '≈ ${formatPrice(price * kRate)} UZS'
        : '≈ \$${formatPrice(price / kRate)}';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: CustomScrollView(
        slivers: [
          // ── Rasmlar ──
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: const Color(0xFF0F172A),
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: images.isNotEmpty
                  ? Stack(
                      children: [
                        PageView.builder(
                          controller: _pageController,
                          itemCount: images.length,
                          onPageChanged: (i) =>
                              setState(() => _currentImage = i),
                          itemBuilder: (_, i) => Image.network(
                            images[i],
                            fit: BoxFit.cover,
                            loadingBuilder: (_, child, progress) =>
                                progress == null
                                ? child
                                : Container(
                                    color: AppColors.surface,
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: AppColors.primary,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                            errorBuilder: (_, _, _) => Container(
                              color: AppColors.surface,
                              child: const Icon(
                                Icons.home_work_rounded,
                                color: AppColors.textSecondary,
                                size: 64,
                              ),
                            ),
                          ),
                        ),
                        if (images.length > 1)
                          Positioned(
                            bottom: 16,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                images.length,
                                (i) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  width: _currentImage == i ? 20 : 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: _currentImage == i
                                        ? AppColors.primary
                                        : Colors.white54,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_currentImage + 1}/${images.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      color: AppColors.surface,
                      child: const Center(
                        child: Icon(
                          Icons.home_work_rounded,
                          color: AppColors.textSecondary,
                          size: 80,
                        ),
                      ),
                    ),
            ),
          ),

          // ── Kontent ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          data['category'] ?? '',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(
                            Icons.remove_red_eye_outlined,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${data['views'] ?? 0}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Text(
                    data['title'] ?? '',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    mainPrice,
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    altPrice,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Parametrlar
                  if ((data['rooms'] ?? 0) > 0 || (data['area'] ?? 0) > 0) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          if ((data['rooms'] ?? 0) > 0)
                            Expanded(
                              child: _InfoItem(
                                icon: Icons.meeting_room_outlined,
                                label: 'Xonalar',
                                value: '${data['rooms']}',
                              ),
                            ),
                          if ((data['rooms'] ?? 0) > 0 &&
                              (data['area'] ?? 0) > 0)
                            Container(
                              width: 1,
                              height: 40,
                              color: AppColors.divider,
                            ),
                          if ((data['area'] ?? 0) > 0)
                            Expanded(
                              child: _InfoItem(
                                icon: Icons.square_foot_rounded,
                                label: 'Maydon',
                                value: '${data['area']} m²',
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Manzil
                  if ((data['address'] ?? '').isNotEmpty) ...[
                    const _SectionLabel('📍 Manzil'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              data['address'],
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Xarita
                  if (hasLocation) ...[
                    const _SectionLabel('🗺️ Xaritada'),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        height: 200,
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: LatLng(
                              data['location'].latitude,
                              data['location'].longitude,
                            ),
                            zoom: 15,
                          ),
                          markers: {
                            Marker(
                              markerId: const MarkerId('listing'),
                              position: LatLng(
                                data['location'].latitude,
                                data['location'].longitude,
                              ),
                            ),
                          },
                          zoomControlsEnabled: false,
                          myLocationButtonEnabled: false,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Tavsif
                  if ((data['description'] ?? '').isNotEmpty) ...[
                    const _SectionLabel('📝 Tavsif'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        data['description'],
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Egasi
                  const _SectionLabel('👤 Egasi'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.secondary],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              (data['ownerName'] ?? 'U')
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          data['ownerName'] ?? "Noma'lum",
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),

      // ── Bottom tugmalar ──
      bottomNavigationBar: _isOwner
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                border: Border(
                  top: BorderSide(color: AppColors.divider, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  // Chat tugmasi
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openChat,
                      icon: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 18,
                      ),
                      label: const Text('Xabar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        minimumSize: const Size(0, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),

                  if (hasPhone) ...[
                    const SizedBox(width: 12),
                    // Telefon tugmasi
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _callPhone,
                        icon: const Icon(Icons.phone_rounded, size: 18),
                        label: const Text('Qo\'ng\'iroq'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: AppColors.textPrimary,
      fontSize: 16,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}
