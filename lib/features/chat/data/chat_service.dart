// lib/features/chat/data/chat_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String get currentUid => _auth.currentUser!.uid;

  static String chatId(String sellerUid, String listingId) {
    final buyer = currentUid;
    final ids = [buyer, sellerUid]..sort();
    return '${ids.join('_')}_$listingId';
  }

  static Future<String> getOrCreateChat({
    required String sellerUid,
    required String sellerName,
    required String listingId,
    required String listingTitle,
    required String listingImage,
    required double listingPrice,
    required String listingCurrency,
    required String listingPeriod,
  }) async {
    final id = chatId(sellerUid, listingId);
    final ref = _db.collection('chats').doc(id);
    final doc = await ref.get();

    final buyerDoc = await _db.collection('users').doc(currentUid).get();
    final buyerData = buyerDoc.data();
    final buyerName = buyerData?['displayName']
        ?? buyerData?['name']
        ?? 'Foydalanuvchi';

    if (!doc.exists) {
      await ref.set({
        'id': id,
        'listingId': listingId,
        'listingTitle': listingTitle,
        'listingImage': listingImage,
        'listingPrice': listingPrice,
        'listingCurrency': listingCurrency,
        'listingPeriod': listingPeriod,
        'participants': [currentUid, sellerUid],
        'buyerUid': currentUid,
        'sellerUid': sellerUid,
        'names': {
          currentUid: sellerName,
          sellerUid: buyerName,
        },
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount': {currentUid: 0, sellerUid: 0},
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      final existing = doc.data() as Map<String, dynamic>;
      if (!existing.containsKey('names')) {
        await ref.update({
          'names': {
            currentUid: sellerName,
            sellerUid: buyerName,
          },
        });
      }
    }
    return id;
  }

  static Future<void> sendMessage(String chatId, String text) async {
    if (text.trim().isEmpty) return;

    final batch = _db.batch();
    final msgRef = _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc();

    batch.set(msgRef, {
      'id': msgRef.id,
      'text': text.trim(),
      'senderId': currentUid,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    final chatRef = _db.collection('chats').doc(chatId);
    final chatDoc = await chatRef.get();
    final data = chatDoc.data() as Map<String, dynamic>;
    final participants = List<String>.from(data['participants']);
    final otherUid = participants.firstWhere((uid) => uid != currentUid);

    batch.update(chatRef, {
      'lastMessage': text.trim(),
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCount.$otherUid': FieldValue.increment(1),
    });

    await batch.commit();
  }

  static Future<void> markAsRead(String chatId) async {
    await _db.collection('chats').doc(chatId).update({
      'unreadCount.$currentUid': 0,
    });
  }

  static Stream<QuerySnapshot> myChats() {
    return _db
        .collection('chats')
        .where('participants', arrayContains: currentUid)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }

  static Stream<QuerySnapshot> messages(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }
}