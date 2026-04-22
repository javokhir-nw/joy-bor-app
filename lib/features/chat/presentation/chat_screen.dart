// lib/features/chat/presentation/chat_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../data/chat_service.dart';
import '../../listings/presentation/listing_detail_screen.dart';

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> chatData;
  const ChatScreen({super.key, required this.chatData});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  late final String _chatId;
  late final String _otherUserName;

  @override
  void initState() {
    super.initState();
    _chatId = widget.chatData['id'];
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final isBuyer = uid == widget.chatData['buyerUid'];
    final sellerUid = widget.chatData['sellerUid'] ?? '';
    final names = widget.chatData['names'] as Map<String, dynamic>?;

    // chat_screen AppBar da:
    // buyer → sellerName
    // seller → buyerName
    _otherUserName = isBuyer
        ? (names?[sellerUid] ?? 'Egasi')
        : (names?[uid] ?? 'Xaridor');

    ChatService.markAsRead(_chatId);
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    _msgController.clear();
    await ChatService.sendMessage(_chatId, text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.textPrimary),
        ),
        title: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  _otherUserName.isNotEmpty
                      ? _otherUserName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _otherUserName,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: ChatService.messages(_chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary));
                }

                final docs = snapshot.data?.docs ?? [];
                _scrollToBottom();

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  itemCount: docs.length + 1,
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      return _ListingCard(
                        chatData: widget.chatData,
                        onTap: () {
                          final listingData = widget.chatData['listingData'];
                          if (listingData != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ListingDetailScreen(
                                  data: Map<String, dynamic>.from(listingData),
                                ),
                              ),
                            );
                          }
                        },
                      );
                    }
                    final data = docs[i - 1].data() as Map<String, dynamic>;
                    return _MessageBubble(
                      data: data,
                      otherUserName: _otherUserName,
                    );
                  },
                );
              },
            ),
          ),

          // Input
          Container(
            padding: EdgeInsets.fromLTRB(
                16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              border: Border(
                  top: BorderSide(color: AppColors.divider, width: 0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _msgController,
                      cursorColor: AppColors.primary,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14),
                      maxLines: null,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        hintText: 'Xabar yozing...',
                        hintStyle: TextStyle(
                            color: Color(0xFF64748B), fontSize: 14),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.secondary]),
                      borderRadius: BorderRadius.circular(23),
                    ),
                    child: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── E'lon kartochkasi ──
class _ListingCard extends StatelessWidget {
  final Map<String, dynamic> chatData;
  final VoidCallback onTap;
  const _ListingCard({required this.chatData, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final image = chatData['listingImage'] ?? '';
    final title = chatData['listingTitle'] ?? '';
    final price = (chatData['listingPrice'] ?? 0).toDouble();
    final currency = chatData['listingCurrency'] ?? 'USD';
    final period = chatData['listingPeriod'] ?? 'oylik';
    final hasListingData = chatData['listingData'] != null;

    return GestureDetector(
      onTap: hasListingData ? onTap : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppColors.primary.withOpacity(0.3), width: 1),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: image.isNotEmpty
                  ? Image.network(image,
                      width: 64, height: 64, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _placeholder())
                  : _placeholder(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('${_formatPrice(price)} $currency / $period',
                      style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            if (hasListingData)
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
      width: 64, height: 64,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.home_work_rounded,
          color: AppColors.textSecondary, size: 28));

  String _formatPrice(double price) {
    if (price >= 1000000) return '${(price / 1000000).toStringAsFixed(1)}M';
    if (price >= 1000) return '${(price / 1000).toStringAsFixed(0)}K';
    return price.toStringAsFixed(0);
  }
}

// ── Xabar bubble ──
class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> data;
  final String otherUserName;
  const _MessageBubble({required this.data, required this.otherUserName});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final isMe = data['senderId'] == uid;
    final time = data['createdAt'] as Timestamp?;
    final timeStr =
        time != null ? DateFormat('HH:mm').format(time.toDate()) : '';

    return Padding(
      padding: EdgeInsets.only(
          bottom: 4, left: isMe ? 48 : 0, right: isMe ? 0 : 48),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 3),
              child: Text(otherUserName,
                  style: TextStyle(
                      color: AppColors.primary.withOpacity(0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
          Container(
            padding: const EdgeInsets.only(
                left: 12, right: 8, top: 8, bottom: 6),
            decoration: BoxDecoration(
              gradient: isMe
                  ? const LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary])
                  : null,
              color: isMe ? null : const Color(0xFF1E293B),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(data['text'] ?? '',
                      style: TextStyle(
                          color: isMe ? Colors.white : AppColors.textPrimary,
                          fontSize: 14,
                          height: 1.4)),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 1),
                  child: Text(timeStr,
                      style: TextStyle(
                          color: isMe
                              ? Colors.white.withOpacity(0.65)
                              : AppColors.textSecondary,
                          fontSize: 10)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}