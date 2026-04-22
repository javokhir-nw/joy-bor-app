import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../home/presentation/widgets/listing_card.dart';
import '../../listings/presentation/listing_detail_screen.dart';

class AdminListingsScreen extends StatefulWidget {
  const AdminListingsScreen({super.key});

  @override
  State<AdminListingsScreen> createState() => _AdminListingsScreenState();
}

class _AdminListingsScreenState extends State<AdminListingsScreen> {
  final _listingSearchController = TextEditingController();
  final _ownerSearchController = TextEditingController();
  String _listingQuery = '';
  String _ownerQuery = '';
  String _statusFilter = 'Barchasi';
  final _filters = ['Barchasi', 'Faol', 'Faol emas'];

  List<String> _foundOwnerUids = [];
  bool _ownerSearchDone = false;
  bool _ownerSearching = false;

  @override
  void dispose() {
    _listingSearchController.dispose();
    _ownerSearchController.dispose();
    super.dispose();
  }

  Future<void> _searchOwners(String query) async {
    if (query.isEmpty) {
      setState(() {
        _foundOwnerUids = [];
        _ownerSearchDone = false;
      });
      return;
    }
    setState(() => _ownerSearching = true);
    final q = query.toLowerCase();
    final qPhone = query.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('users').get();
      final uids = snapshot.docs.where((doc) {
        final d = doc.data();
        final name = (d['displayName'] ?? '').toString().toLowerCase();
        final email = (d['email'] ?? '').toString().toLowerCase();
        final phone = (d['phone'] ?? '')
            .toString()
            .replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
        return name.contains(q) ||
            email.contains(q) ||
            phone.contains(qPhone);
      }).map((doc) => doc.id).toList();
      setState(() {
        _foundOwnerUids = uids;
        _ownerSearchDone = true;
        _ownerSearching = false;
      });
    } catch (e) {
      setState(() => _ownerSearching = false);
    }
  }

  Stream<QuerySnapshot> get _stream {
    Query q = FirebaseFirestore.instance.collection('listings');
    if (_statusFilter == 'Faol') q = q.where('isActive', isEqualTo: true);
    if (_statusFilter == 'Faol emas') {
      q = q.where('isActive', isEqualTo: false);
    }
    return q.orderBy('createdAt', descending: true).snapshots();
  }

  List<QueryDocumentSnapshot> _filterDocs(
      List<QueryDocumentSnapshot> docs) {
    var result = docs;
    if (_listingQuery.isNotEmpty) {
      final q = _listingQuery.toLowerCase();
      result = result.where((doc) {
        final d = doc.data() as Map<String, dynamic>;
        return (d['title'] ?? '').toString().toLowerCase().contains(q) ||
            (d['address'] ?? '').toString().toLowerCase().contains(q);
      }).toList();
    }
    if (_ownerSearchDone && _foundOwnerUids.isNotEmpty) {
      result = result.where((doc) {
        final d = doc.data() as Map<String, dynamic>;
        return _foundOwnerUids.contains(d['uid']);
      }).toList();
    }
    if (_ownerSearchDone && _foundOwnerUids.isEmpty) return [];
    return result;
  }

  Future<void> _toggleActive(String docId, bool isActive) async {
    await FirebaseFirestore.instance
        .collection('listings')
        .doc(docId)
        .update({'isActive': !isActive});
  }

  Future<void> _toggleFeatured(String docId, bool isFeatured) async {
    await FirebaseFirestore.instance
        .collection('listings')
        .doc(docId)
        .update({'isFeatured': !isFeatured});
  }

  Future<void> _delete(BuildContext context, String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("E'lonni o'chirish",
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700)),
        content: const Text("Bu e'lonni o'chirishni tasdiqlaysizmi?",
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Bekor qilish',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("O'chirish",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('listings')
          .doc(docId)
          .delete();
    }
  }

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
        title: const Text("E'lonlar",
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF0F172A),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                _SearchBar(
                  controller: _listingSearchController,
                  hint: "Sarlavha yoki manzil...",
                  icon: Icons.home_work_outlined,
                  onChanged: (v) => setState(() => _listingQuery = v),
                  onClear: () {
                    _listingSearchController.clear();
                    setState(() => _listingQuery = '');
                  },
                  hasText: _listingQuery.isNotEmpty,
                ),
                const SizedBox(height: 10),
                _SearchBar(
                  controller: _ownerSearchController,
                  hint: "Egasi: ism, email yoki telefon...",
                  icon: Icons.person_search_outlined,
                  isLoading: _ownerSearching,
                  onChanged: (v) {
                    if (v.isEmpty) {
                      setState(() {
                        _foundOwnerUids = [];
                        _ownerSearchDone = false;
                      });
                    }
                  },
                  onSubmitted: _searchOwners,
                  onClear: () {
                    _ownerSearchController.clear();
                    setState(() {
                      _ownerQuery = '';
                      _foundOwnerUids = [];
                      _ownerSearchDone = false;
                    });
                  },
                  hasText: _ownerSearchController.text.isNotEmpty,
                  suffixHint: 'Enter bosing',
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _filters.map((f) {
                      final sel = _statusFilter == f;
                      return GestureDetector(
                        onTap: () => setState(() => _statusFilter = f),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: sel
                                ? AppColors.primary
                                : const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(f,
                              style: TextStyle(
                                color: sel
                                    ? Colors.white
                                    : AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: sel
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              )),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                if (_ownerSearchDone) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _foundOwnerUids.isNotEmpty
                          ? AppColors.success.withOpacity(0.1)
                          : AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      Icon(
                        _foundOwnerUids.isNotEmpty
                            ? Icons.person_rounded
                            : Icons.person_off_rounded,
                        size: 14,
                        color: _foundOwnerUids.isNotEmpty
                            ? AppColors.success
                            : AppColors.error,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _foundOwnerUids.isNotEmpty
                            ? '${_foundOwnerUids.length} ta egasi topildi'
                            : 'Egasi topilmadi',
                        style: TextStyle(
                          color: _foundOwnerUids.isNotEmpty
                              ? AppColors.success
                              : AppColors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ]),
                  ),
                ],
              ],
            ),
          ),
          Divider(color: AppColors.divider, height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary));
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Xato: ${snapshot.error}',
                          style:
                              const TextStyle(color: AppColors.error)));
                }

                final docs = _filterDocs(snapshot.data?.docs ?? []);

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off_rounded,
                            size: 48, color: AppColors.textSecondary),
                        const SizedBox(height: 12),
                        const Text("Natija topilmadi",
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data =
                        docs[index].data() as Map<String, dynamic>;
                    final docId = docs[index].id;
                    final isActive = data['isActive'] ?? true;
                    final isFeatured = data['isFeatured'] ?? false;
                    final moderationStatus =
                        data['moderationStatus'] as String?;

                    // approved yoki eski e'lonlar (moderationStatus null)
                    final canToggleActive =
                        moderationStatus == 'approved' ||
                            moderationStatus == null;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isFeatured
                              ? AppColors.accent.withOpacity(0.5)
                              : isActive
                                  ? AppColors.divider
                                  : AppColors.error.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          // Featured badge
                          if (isFeatured)
                            Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withOpacity(0.15),
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(16)),
                              ),
                              child: const Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.star_rounded,
                                      size: 14, color: AppColors.accent),
                                  SizedBox(width: 6),
                                  Text('Tavsiya etilgan',
                                      style: TextStyle(
                                          color: AppColors.accent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),

                          // Moderation status badge
                          if (moderationStatus == 'pending')
                            Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFBBF24)
                                    .withOpacity(0.1),
                                borderRadius: isFeatured
                                    ? BorderRadius.zero
                                    : const BorderRadius.vertical(
                                        top: Radius.circular(16)),
                              ),
                              child: const Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.pending_actions_rounded,
                                      size: 14,
                                      color: Color(0xFFFBBF24)),
                                  SizedBox(width: 6),
                                  Text('Moderatsiya kutilmoqda',
                                      style: TextStyle(
                                          color: Color(0xFFFBBF24),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),

                          if (moderationStatus == 'rejected')
                            Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.error.withOpacity(0.1),
                                borderRadius: isFeatured
                                    ? BorderRadius.zero
                                    : const BorderRadius.vertical(
                                        top: Radius.circular(16)),
                              ),
                              child: const Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.cancel_rounded,
                                      size: 14,
                                      color: AppColors.error),
                                  SizedBox(width: 6),
                                  Text('Rad etilgan',
                                      style: TextStyle(
                                          color: AppColors.error,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),

                          ListingCard(
                            data: data,
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        ListingDetailScreen(data: data))),
                          ),

                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: Column(
                              children: [
                                // Featured toggle
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _toggleFeatured(docId, isFeatured),
                                    icon: Icon(
                                      isFeatured
                                          ? Icons.star_rounded
                                          : Icons.star_outline_rounded,
                                      size: 18,
                                      color: isFeatured
                                          ? AppColors.accent
                                          : AppColors.textSecondary,
                                    ),
                                    label: Text(
                                      isFeatured
                                          ? 'Tavsiydan olib tashlash'
                                          : 'Tavsiya etish',
                                      style: TextStyle(
                                        color: isFeatured
                                            ? AppColors.accent
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: isFeatured
                                            ? AppColors.accent
                                                .withOpacity(0.5)
                                            : AppColors.divider,
                                      ),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Faollashtirish + O'chirish
                                Row(
                                  children: [
                                    if (canToggleActive) ...[
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () =>
                                              _toggleActive(docId, isActive),
                                          icon: Icon(
                                            isActive
                                                ? Icons
                                                    .pause_circle_outline_rounded
                                                : Icons
                                                    .play_circle_outline_rounded,
                                            size: 18,
                                          ),
                                          label: Text(isActive
                                              ? 'Faolsizlantirish'
                                              : 'Faollashtirish'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: isActive
                                                ? AppColors.textSecondary
                                                : AppColors.success,
                                            side: BorderSide(
                                                color: isActive
                                                    ? AppColors.divider
                                                    : AppColors.success),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        10)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                    ],
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          _delete(context, docId),
                                      icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          size: 18),
                                      label: const Text("O'chirish"),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.error,
                                        side: BorderSide(
                                            color: AppColors.error
                                                .withOpacity(0.5)),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
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
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool hasText;
  final bool isLoading;
  final String? suffixHint;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.hasText,
    required this.onChanged,
    required this.onClear,
    this.onSubmitted,
    this.isLoading = false,
    this.suffixHint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(icon, color: const Color(0xFF64748B), size: 20),
          const SizedBox(width: 8),
          Container(width: 1, height: 18, color: const Color(0xFF2D3748)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              cursorColor: AppColors.primary,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: hint,
                hintStyle: const TextStyle(
                    color: Color(0xFF64748B), fontSize: 14),
              ),
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              textInputAction: onSubmitted != null
                  ? TextInputAction.search
                  : TextInputAction.done,
            ),
          ),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2)),
            )
          else if (hasText)
            GestureDetector(
              onTap: onClear,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.close,
                    color: Color(0xFF64748B), size: 18),
              ),
            )
          else if (suffixHint != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(suffixHint!,
                  style: const TextStyle(
                      color: Color(0xFF475569), fontSize: 11)),
            ),
        ],
      ),
    );
  }
}