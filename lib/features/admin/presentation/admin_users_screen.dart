// lib/features/admin/presentation/admin_users_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggleAdmin(String uid, bool isAdmin) async {
    final newAdmin = !isAdmin;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({
      'isAdmin': newAdmin,
      'role': newAdmin ? 'admin' : 'user',
    });
  }

  // Telefon raqamni normalize qilish
  String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
  }

  List<QueryDocumentSnapshot> _filter(List<QueryDocumentSnapshot> docs) {
    if (_query.isEmpty) return docs;

    final q = _query.toLowerCase();
    final qPhone = _normalizePhone(_query);

    return docs.where((doc) {
      final d = doc.data() as Map<String, dynamic>;
      final name = (d['displayName'] ?? '').toString().toLowerCase();
      final email = (d['email'] ?? '').toString().toLowerCase();
      final phone = _normalizePhone((d['phone'] ?? '').toString());

      return name.contains(q) ||
          email.contains(q) ||
          phone.contains(qPhone);
    }).toList();
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
        title: const Text('Foydalanuvchilar',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: const Color(0xFF0F172A),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  const Icon(Icons.search_rounded,
                      color: Color(0xFF64748B), size: 20),
                  const SizedBox(width: 8),
                  Container(width: 1, height: 18,
                      color: const Color(0xFF2D3748)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      cursorColor: AppColors.primary,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'Ism, email yoki telefon...',
                        hintStyle: TextStyle(
                            color: Color(0xFF64748B), fontSize: 14),
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                  if (_query.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(Icons.close,
                            color: Color(0xFF64748B), size: 18),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Divider(color: AppColors.divider, height: 1),

          // Ro'yxat
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                      child: Text("Foydalanuvchilar yo'q",
                          style: TextStyle(
                              color: AppColors.textSecondary)));
                }

                final docs = _filter(snapshot.data!.docs);

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off_rounded,
                            size: 48, color: AppColors.textSecondary),
                        const SizedBox(height: 12),
                        Text("'$_query' bo'yicha natija topilmadi",
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14)),
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
                    final uid = docs[index].id;
                    final isAdmin = data['isAdmin'] ?? false;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [
                                    AppColors.primary,
                                    AppColors.secondary
                                  ]),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: Text(
                                    (data['displayName'] ??
                                            data['email'] ??
                                            'U')
                                        .substring(0, 1)
                                        .toUpperCase(),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['displayName'] ?? "Noma'lum",
                                      style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      data['email'] ?? '',
                                      style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if ((data['phone'] ?? '').isNotEmpty)
                                      Text(
                                        data['phone'],
                                        style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12),
                                      ),
                                  ],
                                ),
                              ),
                              if (isAdmin)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.accent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text('Admin',
                                      style: TextStyle(
                                          color: AppColors.accent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Divider(color: AppColors.divider, height: 1),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _ToggleItem(
                                  label: 'Admin',
                                  icon: Icons.shield_rounded,
                                  color: AppColors.accent,
                                  value: isAdmin,
                                  onChanged: (_) =>
                                      _toggleAdmin(uid, isAdmin),
                                ),
                              ),
                            ],
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

class _ToggleItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: value ? color.withValues(alpha: 0.1) : const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: value ? color.withValues(alpha: 0.3) : AppColors.divider),
      ),
      child: Row(
        children: [
          Icon(icon,
              color: value ? color : AppColors.textSecondary, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: value ? color : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: color,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}