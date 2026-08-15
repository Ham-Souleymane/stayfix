import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'app_env.dart';
import 'message_sound_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Handling background FCM message: ${message.messageId}');
}

class PushNotificationService {
  PushNotificationService._();

  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'stayfix_messages_channel';
  static const String _channelName = 'Stayfix Messages';
  static const String _channelDescription =
      'Notifications for new chat messages in Stayfix';

  static bool _isInitialized = false;

  /// Returns the identifier of the current running app ('stayfix' or 'stayfix_job').
  static String getCurrentAppKey() {
    try {
      final options = Firebase.app().options;
      final appId = options.appId.toLowerCase();
      final iosBundleId = (options.iosBundleId ?? '').toLowerCase();
      if (appId.contains('81872a8ef6e91d6f5058cd') ||
          iosBundleId.contains('stayfixjob') ||
          iosBundleId.contains('stayfix_job')) {
        return 'stayfix_job';
      }
    } catch (_) {}
    return 'stayfix';
  }

  /// Initializes FCM and local notifications for foreground, background, and terminated states.
  static Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      // Background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Request notification permissions from OS
      final settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('FCM Authorization Status: ${settings.authorizationStatus}');

      // Create Android Notification Channel
      const androidChannel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);

      // Initialize Local Notifications plugin
      const initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/launcher_icon');
      const initializationSettingsIOS = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('Notification tapped: ${response.payload}');
        },
      );

      // Foreground message handler
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Foreground FCM message received: ${message.notification?.title}');
        _showForegroundLocalNotification(message);
      });

      // FCM token refresh listener
      _fcm.onTokenRefresh.listen((token) {
        final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
        if (uid.isNotEmpty) {
          saveTokenForUser(uid);
        }
      });

      // Automatically save FCM token for logged in user & listen for auth changes
      final initialUid = FirebaseAuth.instance.currentUser?.uid;
      if (initialUid != null && initialUid.isNotEmpty) {
        unawaited(saveTokenForUser(initialUid));
      }
      FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null && user.uid.isNotEmpty) {
          unawaited(saveTokenForUser(user.uid));
        }
      });
    } catch (e) {
      debugPrint('Error initializing PushNotificationService: $e');
    }
  }

  /// Saves the device FCM token to the user document in Firestore scoped by appKey.
  static Future<void> saveTokenForUser(String uid) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) return;

    try {
      final token = await _fcm.getToken();
      if (token == null || token.isEmpty) return;

      final appKey = getCurrentAppKey();
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(normalizedUid);

      await userRef.set({
        'fcmToken': token,
        'fcmTokens': FieldValue.arrayUnion([token]),
        'fcmTokensByApp.$appKey': FieldValue.arrayUnion([token]),
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('FCM token saved for user $normalizedUid under app $appKey');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  /// Removes the device FCM token when logging out so it no longer receives pushes.
  static Future<void> removeTokenForCurrentUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    try {
      final token = await _fcm.getToken();
      if (token == null || token.isEmpty) return;

      final appKey = getCurrentAppKey();
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

      await userRef.update({
        'fcmTokens': FieldValue.arrayRemove([token]),
        'fcmTokensByApp.$appKey': FieldValue.arrayRemove([token]),
      });
      debugPrint('FCM token removed for user $uid under app $appKey');
    } catch (e) {
      debugPrint('Error removing FCM token: $e');
    }
  }

  /// Display local notification when app is in foreground
  static Future<void> _showForegroundLocalNotification(
      RemoteMessage message) async {
    final targetApp =
        (message.data['targetApp'] as String?)?.trim().toLowerCase();
    final currentApp = getCurrentAppKey();

    // Ignore foreground notifications intended for a different application
    if (targetApp != null &&
        targetApp.isNotEmpty &&
        targetApp != 'all' &&
        targetApp != currentApp) {
      debugPrint(
        'Ignoring foreground notification for targetApp=$targetApp because currentApp=$currentApp',
      );
      return;
    }

    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] ?? 'Stayfix Message';
    final body = notification?.body ?? message.data['body'] ?? 'Nouveau message reçu';

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      platformDetails,
      payload: jsonEncode(message.data),
    );

    // Play app sound
    unawaited(MessageSoundService.playNotificationSound());
  }

  /// Shows a system local notification directly (useful for background triggers or tests)
  static Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }

  static String _resolveTargetAppForParticipant({
    required String recipientUid,
    Map<String, dynamic>? conversationData,
  }) {
    if (conversationData == null || conversationData.isEmpty) {
      return 'stayfix';
    }

    final type =
        (conversationData['type'] as String?)?.trim().toLowerCase() ?? '';
    final workerId =
        (conversationData['workerId'] as String?)?.trim() ?? '';
    final managerId =
        (conversationData['managerId'] as String?)?.trim() ?? '';
    final appOrigin =
        (conversationData['appOrigin'] as String?)?.trim().toLowerCase() ?? '';

    // If it is a manager <-> worker intervenant chat:
    if (type == 'intervenant') {
      if (workerId.isNotEmpty && recipientUid == workerId) {
        return 'stayfix_job';
      }
      if (managerId.isNotEmpty && recipientUid == managerId) {
        return 'stayfix';
      }
      return appOrigin == 'stayfix_job' ? 'stayfix_job' : 'stayfix';
    }

    if (appOrigin == 'stayfix_job' || type == 'job' || type == 'mission') {
      return 'stayfix_job';
    }

    return 'stayfix';
  }

  static String _resolveTargetAppFromConversation(
      Map<String, dynamic>? conversationData) {
    if (conversationData == null || conversationData.isEmpty) {
      return 'stayfix';
    }
    final appOrigin =
        (conversationData['appOrigin'] as String?)?.trim().toLowerCase() ?? '';
    if (appOrigin == 'stayfix_job') return 'stayfix_job';
    return 'stayfix';
  }

  /// Sends a system push notification to conversation participants when a new message is sent.
  static Future<void> sendNotificationToParticipants({
    required List<String> participantIds,
    required String senderName,
    required String messageText,
    required String conversationId,
    List<String>? mutedBy,
    Map<String, dynamic>? conversationData,
  }) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    final targetTokens = <String>{};
    final targetApp = _resolveTargetAppFromConversation(conversationData);

    for (final participantId in participantIds) {
      final pid = participantId.trim();
      if (pid.isEmpty || pid == currentUid) continue;
      if (mutedBy != null && mutedBy.contains(pid)) continue;

      final targetAppForPid = _resolveTargetAppForParticipant(
        recipientUid: pid,
        conversationData: conversationData,
      );

      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(pid)
            .get();
        final data = userDoc.data();
        if (data != null) {
          final fcmTokensByApp = data['fcmTokensByApp'];
          var addedAppSpecificToken = false;

          if (fcmTokensByApp is Map) {
            final appTokens = fcmTokensByApp[targetAppForPid];
            if (appTokens is List && appTokens.isNotEmpty) {
              for (final t in appTokens) {
                final tokenStr = t?.toString().trim() ?? '';
                if (tokenStr.isNotEmpty) {
                  targetTokens.add(tokenStr);
                  addedAppSpecificToken = true;
                }
              }
            }
          }

          // Fallback: If no app-specific token was registered yet, fallback to legacy flat tokens
          if (!addedAppSpecificToken) {
            final singleToken = (data['fcmToken'] as String?)?.trim() ?? '';
            if (singleToken.isNotEmpty) targetTokens.add(singleToken);

            final listTokens = data['fcmTokens'];
            if (listTokens is List) {
              for (final t in listTokens) {
                final tokenStr = t?.toString().trim() ?? '';
                if (tokenStr.isNotEmpty) targetTokens.add(tokenStr);
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error loading FCM tokens for $pid: $e');
      }
    }

    if (targetTokens.isEmpty) {
      debugPrint('No target FCM tokens found for push delivery.');
      return;
    }

    try {
      final baseUrl = await AppEnv.get(
        'VPS_MEDIA_BASE_URL',
        fallback: 'https://media.stayfix.co',
      );
      final normalizedUrl =
          baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
      final uri = Uri.parse('$normalizedUrl/api/push/send');

      final client = http.Client();
      try {
        final response = await client
            .post(
              uri,
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode({
                'tokens': targetTokens.toList(),
                'title': senderName.isNotEmpty ? senderName : 'Stayfix',
                'body': messageText.isNotEmpty ? messageText : 'Nouveau message',
                'conversationId': conversationId,
                'targetApp': targetApp,
              }),
            )
            .timeout(const Duration(seconds: 10));

        debugPrint(
          'Push notification dispatch result [${response.statusCode}]: ${response.body}',
        );
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('Error sending push notification via VPS API: $e');
    }
  }
}
