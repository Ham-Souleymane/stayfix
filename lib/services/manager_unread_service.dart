import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ManagerUnreadService {
  ManagerUnreadService._();

  static String get currentUid =>
      FirebaseAuth.instance.currentUser?.uid ?? '';

  static Stream<QuerySnapshot<Map<String, dynamic>>> conversationsStream(
    String uid,
  ) {
    if (uid.trim().isEmpty) {
      return const Stream.empty();
    }
    return FirebaseFirestore.instance
        .collection('conversations')
        .where('participants', arrayContains: uid)
        .snapshots();
  }

  static bool isConversationUnread(
    Map<String, dynamic> data,
    String uid,
  ) {
    final managerId = (data['managerId'] as String?)?.trim();
    final createdBy = (data['createdBy'] as String?)?.trim();
    if (managerId != null && managerId.isNotEmpty && managerId != uid) {
      return false;
    }
    if ((managerId == null || managerId.isEmpty) &&
        createdBy != null &&
        createdBy.isNotEmpty &&
        createdBy != uid) {
      return false;
    }

    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) return false;

    final lastMessageAt = data['lastMessageAt'];
    if (lastMessageAt is! Timestamp) return false;

    final lastSenderId = (data['lastSenderId'] as String?)?.trim() ?? '';
    if (lastSenderId.isNotEmpty && lastSenderId == normalizedUid) {
      return false;
    }

    final unreadBy = data['unreadBy'];
    if (unreadBy is Map) {
      final value = unreadBy[normalizedUid];
      // Explicitly marked as read (0) → definitively not unread.
      if (value is num && value <= 0) {
        return false;
      }
      if (value is num && value > 0) {
        return true;
      }
    }

    // Fallback: compare lastReadAt vs lastMessageAt timestamps.
    final lastReadAt = data['lastReadAt'];
    if (lastReadAt is! Map) return true;
    final myLastRead = lastReadAt[normalizedUid];
    if (myLastRead is! Timestamp) return true;
    return lastMessageAt.compareTo(myLastRead) > 0;
  }

  static bool snapshotHasUnread(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    String uid,
  ) {
    for (final doc in snapshot.docs) {
      if (isConversationUnread(doc.data(), uid)) {
        return true;
      }
    }
    return false;
  }

  static Future<void> markConversationAsRead(String conversationId) async {
    final uid = currentUid;
    if (uid.isEmpty || conversationId.trim().isEmpty) return;
    await FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .set({
      'unreadBy.$uid': 0,
      'lastReadAt.$uid': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
