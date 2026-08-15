import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_session_service.dart';
import 'manager_unread_service.dart';

class MessageSoundService {
  MessageSoundService._();

  static final AudioPlayer _player = AudioPlayer();
  static DateTime? _lastPlayedAt;

  /// Plays the notification sound effect when a message arrives.
  /// Uses a 1-second debounce window to prevent duplicate sound triggers.
  static Future<void> playNotificationSound() async {
    final now = DateTime.now();
    if (_lastPlayedAt != null &&
        now.difference(_lastPlayedAt!) < const Duration(milliseconds: 1000)) {
      return;
    }
    _lastPlayedAt = now;

    try {
      await _player.stop();
      await _player.play(
        AssetSource('audio/IPHONE NOTIFICATION SOUND EFFECT (PING DING).mp3'),
      );
    } catch (e) {
      debugPrint('Error playing message notification sound: $e');
    }
  }
}

/// App-wide listener that monitors incoming messages and triggers
/// a sound notification when a new message arrives for the current user.
class GlobalMessageSoundListener extends StatefulWidget {
  const GlobalMessageSoundListener({super.key, required this.child});

  final Widget child;

  @override
  State<GlobalMessageSoundListener> createState() =>
      _GlobalMessageSoundListenerState();
}

class _GlobalMessageSoundListenerState
    extends State<GlobalMessageSoundListener> {
  StreamSubscription<User?>? _authSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _convSub;
  Timer? _sessionPoller;
  final Map<String, Timestamp> _lastMessageTimestamps = {};
  bool _isInitialSnapshot = true;
  String? _activeUid;

  @override
  void initState() {
    super.initState();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      _checkUserSession(user?.uid);
    });
    _sessionPoller = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkUserSession(null);
    });
  }

  void _checkUserSession(String? authUid) {
    final uid = authUid ??
        FirebaseAuth.instance.currentUser?.uid ??
        AppSessionService.currentUserId;
    if (uid == _activeUid) return;
    _activeUid = uid;
    _convSub?.cancel();
    _lastMessageTimestamps.clear();
    _isInitialSnapshot = true;

    if (uid.isNotEmpty) {
      _convSub = ManagerUnreadService.conversationsStream(uid).listen(
        _onConversationsSnapshot,
        onError: (err) => debugPrint('Error in global message sound stream: $err'),
      );
    }
  }

  void _onConversationsSnapshot(
      QuerySnapshot<Map<String, dynamic>> snapshot) {
    final uid = _activeUid ?? '';
    if (uid.isEmpty) return;

    if (_isInitialSnapshot) {
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final lastMessageAt = data['lastMessageAt'];
        if (lastMessageAt is Timestamp) {
          _lastMessageTimestamps[doc.id] = lastMessageAt;
        }
      }
      _isInitialSnapshot = false;
      return;
    }

    bool newIncomingMessageArrived = false;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final lastSenderId = (data['lastSenderId'] as String?)?.trim() ?? '';
      final lastMessageAt = data['lastMessageAt'];

      if (lastMessageAt is Timestamp) {
        final previousAt = _lastMessageTimestamps[doc.id];
        _lastMessageTimestamps[doc.id] = lastMessageAt;

        if (lastSenderId.isNotEmpty &&
            lastSenderId != uid &&
            (previousAt == null || lastMessageAt.compareTo(previousAt) > 0)) {
          newIncomingMessageArrived = true;
        }
      }
    }

    if (newIncomingMessageArrived) {
      unawaited(MessageSoundService.playNotificationSound());
    }
  }

  @override
  void dispose() {
    _convSub?.cancel();
    _sessionPoller?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
