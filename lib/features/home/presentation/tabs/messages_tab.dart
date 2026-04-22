// lib/features/home/presentation/tabs/messages_tab.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../chat/data/chat_service.dart';
import '../../../chat/presentation/chat_screen.dart';

class MessagesTab extends StatelessWidget {
  const MessagesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: StreamBuilder<QuerySnapshot>(
        stream: ChatService.myChats(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const _EmptyState();
          }

          final docs = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              return _ChatTile(data: data);
            },
          );
        },
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ChatTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final unread = (data['unreadCount'] ?? {})[uid] ?? 0;
    final hasUnread = unread > 0;
    final lastMsg = data['lastMessage'] ?? '';
    final time = data['lastMessageTime'] as Timestamp?;
    final timeStr =
        time != null ? DateFormat('HH:mm').format(time.toDate()) : '';

    final isBuyer = uid == data['buyerUid'];
    final sellerUid = data['sellerUid'] ?? '';
    final names = data['names'] as Map<String, dynamic>?;

    // messages_tab da ko'rinadigan ism:
    // buyer → e'lon nomi
    // seller → buyerName
    final displayName = isBuyer
        ? (data['listingTitle'] ?? "E'lon")
        : (names?[uid] ?? 'Xaridor');

    final avatarLetter = isBuyer
        ? (data['listingTitle'] ?? 'E').substring(0, 1).toUpperCase()
        : (names?[uid] ?? 'X').substring(0, 1).toUpperCase();

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(chatData: data),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasUnread
                ? AppColors.primary.withOpacity(0.3)
                : AppColors.divider,
          ),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                gradient: isBuyer
                    ? const LinearGradient(
                        colors: [Color(0xFF1E293B), Color(0xFF334155)])
                    : const LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary]),
                borderRadius: BorderRadius.circular(14),
                border: isBuyer
                    ? Border.all(color: AppColors.primary.withOpacity(0.3))
                    : null,
              ),
              child: isBuyer
                  ? const Icon(Icons.home_work_rounded,
                      color: AppColors.primary, size: 24)
                  : Center(
                      child: Text(avatarLetter,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20)),
                    ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Asosiy ism
                  Text(displayName,
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: hasUnread
                              ? FontWeight.w700
                              : FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),

                  // Seller uchun e'lon nomi subtitle
                  if (!isBuyer)
                    Text(data['listingTitle'] ?? '',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  if (!isBuyer) const SizedBox(height: 3),

                  // So'nggi xabar
                  Text(lastMsg,
                      style: TextStyle(
                          color: hasUnread
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: hasUnread
                              ? FontWeight.w500
                              : FontWeight.w400),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),

            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(timeStr,
                    style: TextStyle(
                        color: hasUnread
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        fontSize: 11)),
                const SizedBox(height: 4),
                if (hasUnread)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('$unread',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline_rounded,
                size: 64, color: AppColors.textSecondary),
            SizedBox(height: 16),
            Text('Xabarlar yo\'q',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text('E\'lon sahifasidan muloqot boshlang',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 14)),
          ],
        ),
      );
}