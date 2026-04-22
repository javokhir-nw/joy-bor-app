import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../services/moderation_service.dart';

class AdminModerationScreen extends StatefulWidget {
  const AdminModerationScreen({super.key});

  @override
  State<AdminModerationScreen> createState() => _AdminModerationScreenState();
}

class _AdminModerationScreenState extends State<AdminModerationScreen> {
  String _riskFilter = 'Barchasi';
  final Set<String> _analyzingIds = {};
  final _riskFilters = [
    'Barchasi',
    'clean',
    'low_risk',
    'medium_risk',
    'high_risk',
  ];

  Stream<QuerySnapshot> get _stream {
    Query q = FirebaseFirestore.instance
        .collection('listings')
        .where('moderationStatus', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true);
    return q.snapshots();
  }

  List<QueryDocumentSnapshot> _filterDocs(
      List<QueryDocumentSnapshot> docs) {
    if (_riskFilter == 'Barchasi') return docs;
    return docs.where((doc) {
      final d = doc.data() as Map<String, dynamic>;
      return (d['riskLevel'] ?? '') == _riskFilter;
    }).toList();
  }

  Future<void> _analyze(String docId, Map<String, dynamic> data) async {
    if (_analyzingIds.contains(docId)) return;

    // API key borligini tekshirish
    final configDoc = await FirebaseFirestore.instance
        .collection('config')
        .doc('groq')
        .get();
    final apiKey = configDoc.data()?['api_key'] ?? '';
    if (apiKey.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              "Groq API key topilmadi. Firestore → config/groq → api_key qo'shing."),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }

    setState(() => _analyzingIds.add(docId));
    await ModerationService.analyze(
      docId: docId,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0) as int,
      currency: data['currency'] ?? 'USD',
    );
    if (mounted) setState(() => _analyzingIds.remove(docId));
  }

  Future<void> _approve(String docId) async {
    final confirm = await _showConfirmDialog(
      title: "Tasdiqlash",
      message: "E'lonni tasdiqlaysizmi? Tasdiqlangandan keyin qidiruvda ko'rinadi.",
      confirmText: "Tasdiqlash",
      confirmColor: AppColors.success,
    );
    if (confirm != true) return;

    await FirebaseFirestore.instance
        .collection('listings')
        .doc(docId)
        .update({
      'moderationStatus': 'approved',
      'isActive': true,
      'approvedAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("E'lon tasdiqlandi"),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _reject(String docId) async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Rad etish",
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Rad etish sababini kiriting:",
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              style: const TextStyle(color: AppColors.textPrimary),
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: "Sabab...",
                hintStyle: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Bekor qilish",
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Rad etish",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await FirebaseFirestore.instance
        .collection('listings')
        .doc(docId)
        .update({
      'moderationStatus': 'rejected',
      'isActive': false,
      'rejectionReason': reasonController.text.trim(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("E'lon rad etildi"),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700)),
        content: Text(message,
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Bekor qilish",
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(confirmText,
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Color _riskColor(String risk) {
    switch (risk) {
      case 'clean':
        return AppColors.success;
      case 'low_risk':
        return const Color(0xFF38BDF8);
      case 'medium_risk':
        return const Color(0xFFFBBF24);
      case 'high_risk':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  String _riskLabel(String risk) {
    switch (risk) {
      case 'clean':
        return '✅ Muammosiz';
      case 'low_risk':
        return '🔵 Kichik shubha';
      case 'medium_risk':
        return '🟡 O\'rta shubha';
      case 'high_risk':
        return '🔴 Yuqori shubha';
      default:
        return '⏳ Tahlil qilinmoqda...';
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
        title: const Text(
          "Moderatsiya",
          style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          // Risk filter
          Container(
            color: const Color(0xFF0F172A),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _riskFilters.map((f) {
                  final sel = _riskFilter == f;
                  final color = f == 'Barchasi'
                      ? AppColors.primary
                      : _riskColor(f);
                  return GestureDetector(
                    onTap: () => setState(() => _riskFilter = f),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel
                            ? color.withValues(alpha: 0.2)
                            : const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: sel ? color : AppColors.divider,
                        ),
                      ),
                      child: Text(
                        f == 'Barchasi' ? 'Barchasi' : _riskLabel(f),
                        style: TextStyle(
                          color: sel ? color : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: sel
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(color: Color(0xFF1E293B), height: 1),

          // Ro'yxat
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary));
                }

                final docs =
                    _filterDocs(snapshot.data?.docs ?? []);

                if (docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline_rounded,
                            size: 56, color: AppColors.success),
                        SizedBox(height: 12),
                        Text("Kutilayotgan e'lonlar yo'q",
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                        SizedBox(height: 4),
                        Text("Barcha e'lonlar ko'rib chiqilgan",
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13)),
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
                    final riskLevel =
                        (data['riskLevel'] ?? '') as String;
                    final aiAnalysis =
                        data['aiAnalysis'] as Map<String, dynamic>?;
                    final riskColor = riskLevel.isEmpty
                        ? AppColors.textSecondary
                        : _riskColor(riskLevel);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: riskLevel.isEmpty
                              ? AppColors.divider
                              : riskColor.withValues(alpha: 0.4),
                          width: riskLevel == 'high_risk' ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Risk badge
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: riskColor.withValues(alpha: 0.1),
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(16)),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  riskLevel.isEmpty
                                      ? '⏳ AI tahlil qilmoqda...'
                                      : _riskLabel(riskLevel),
                                  style: TextStyle(
                                    color: riskLevel.isEmpty
                                        ? AppColors.textSecondary
                                        : riskColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Rasmlar
                          if ((data['images'] as List?)?.isNotEmpty == true) ...[
                            SizedBox(
                              height: 160,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                                itemCount: (data['images'] as List).length,
                                itemBuilder: (_, i) {
                                  final url = ((data['images'] as List)[i] ?? '').toString();
                                  if (url.isEmpty) return const SizedBox.shrink();
                                  return GestureDetector(
                                    onTap: () => showDialog(
                                      context: context,
                                      builder: (_) => Dialog(
                                        backgroundColor: Colors.black,
                                        insetPadding: EdgeInsets.zero,
                                        child: InteractiveViewer(
                                          child: Image.network(url, fit: BoxFit.contain),
                                        ),
                                      ),
                                    ),
                                    child: Container(
                                      width: 140,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        color: const Color(0xFF0F172A),
                                      ),
                                      clipBehavior: Clip.hardEdge,
                                      child: Image.network(
                                        url,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, e, s) => const Center(
                                          child: Icon(Icons.broken_image,
                                              color: AppColors.textSecondary),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],

                          // E'lon ma'lumotlari
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                // Sarlavha
                                Text(
                                  data['title'] ?? '',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),

                                // Narx
                                Text(
                                  '${data['price']} ${data['currency']} / ${data['period']}',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // Tavsif
                                if ((data['description'] ?? '')
                                    .toString()
                                    .isNotEmpty) ...[
                                  Text(
                                    data['description'],
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                      height: 1.5,
                                    ),
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 12),
                                ],

                                // AI tahlil natijalari
                                if (aiAnalysis != null) ...[
                                  const Divider(
                                      color: Color(0xFF334155)),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'AI tahlili:',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  if ((aiAnalysis['reason'] ?? '')
                                      .toString()
                                      .isNotEmpty)
                                    Text(
                                      aiAnalysis['reason'],
                                      style: TextStyle(
                                        color: riskColor,
                                        fontSize: 13,
                                      ),
                                    ),
                                  if ((aiAnalysis['issues'] as List?)
                                          ?.isNotEmpty ==
                                      true) ...[
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: (aiAnalysis['issues']
                                              as List)
                                          .map((issue) => Container(
                                                padding:
                                                    const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 10,
                                                        vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: riskColor
                                                      .withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius
                                                          .circular(20),
                                                  border: Border.all(
                                                      color: riskColor
                                                          .withValues(alpha: 0.3)),
                                                ),
                                                child: Text(
                                                  issue.toString(),
                                                  style: TextStyle(
                                                    color: riskColor,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ))
                                          .toList(),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                ],

                                // AI tahlil tugmasi — har doim ko'rinadi
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: _analyzingIds.contains(docId)
                                        ? null
                                        : () => _analyze(docId, data),
                                    icon: _analyzingIds.contains(docId)
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: AppColors.accent),
                                          )
                                        : const Icon(
                                            Icons.auto_awesome_rounded,
                                            size: 16),
                                    label: Text(_analyzingIds.contains(docId)
                                        ? 'Tahlil qilinmoqda...'
                                        : riskLevel.isEmpty
                                            ? 'AI tahlil qilish'
                                            : 'Qayta tahlil qilish'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.accent,
                                      side: BorderSide(
                                          color: AppColors.accent
                                              .withValues(alpha: 0.4)),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // Tasdiqlash / Rad etish tugmalari
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () =>
                                            _approve(docId),
                                        icon: const Icon(
                                            Icons.check_rounded,
                                            size: 18),
                                        label:
                                            const Text("Tasdiqlash"),
                                        style:
                                            ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppColors.success,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      10)),
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  vertical: 12),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _reject(docId),
                                        icon: const Icon(
                                            Icons.close_rounded,
                                            size: 18),
                                        label: const Text("Rad etish"),
                                        style:
                                            OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.error,
                                          side: BorderSide(
                                              color: AppColors.error
                                                  .withValues(alpha: 0.5)),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      10)),
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  vertical: 12),
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