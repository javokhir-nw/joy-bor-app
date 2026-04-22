import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_state.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/chat/presentation/chat_screen.dart';

// Navigator key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ── Global notifier lar ──
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);
final ValueNotifier<String> langNotifier = ValueNotifier('uz');

// Local notifications plugin
final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

// Background handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (!kIsWeb) await _showNotification(message);
}

// Notification ko'rsatish
Future<void> _showNotification(RemoteMessage message) async {
  final notification = message.notification;
  if (notification == null) return;

  await _localNotifications.show(
    notification.hashCode,
    notification.title,
    notification.body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
      ),
    ),
    payload: message.data['chatId'],
  );
}

// Notification bosilganda chat ochish
Future<void> _openChat(String? chatId) async {
  if (chatId == null || chatId.isEmpty) return;
  try {
    final doc = await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .get();
    if (!doc.exists) return;

    navigatorKey.currentState?.push(MaterialPageRoute(
      builder: (_) =>
          ChatScreen(chatData: doc.data() as Map<String, dynamic>),
    ));
  } catch (e) {
    debugPrint('Chat ochishda xato: $e');
  }
}

// Local notifications sozlash
Future<void> _initLocalNotifications() async {
  if (kIsWeb) return;

  const initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  );

  await _localNotifications.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (details) {
      _openChat(details.payload);
    },
  );
}

// ── SharedPreferences dan yuklash ──
Future<void> _loadPrefs() async {
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('isDark') ?? true;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  langNotifier.value = prefs.getString('lang') ?? 'uz';
}

// ── FCM Token saqlash (export qilinadi) ──
Future<void> saveFcmToken() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized) return;

    final token = await messaging.getToken();
    if (token == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({'fcmToken': token});

    debugPrint('FCM Token: $token');

    messaging.onTokenRefresh.listen((newToken) async {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'fcmToken': newToken});
    });
  } catch (e) {
    debugPrint('FCM Token xato: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // SharedPreferences dan theme va til yuklash
  await _loadPrefs();

  // Background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Local notifications sozlash
  await _initLocalNotifications();

  if (!kIsWeb) await saveFcmToken();

  // Foreground notification
  FirebaseMessaging.onMessage.listen((message) {
    debugPrint('Foreground: ${message.notification?.title}');
    if (!kIsWeb) _showNotification(message);
  });

  // Background da notification bosilganda
  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    _openChat(message.data['chatId']);
  });

  // App o'chiq bo'lganda notification bosilganda
  final initial = await FirebaseMessaging.instance.getInitialMessage();
  if (initial != null) {
    Future.delayed(const Duration(seconds: 1), () {
      _openChat(initial.data['chatId']);
    });
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, _) => MaterialApp(
        title: 'Uy Bor',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,   // ← light theme (app_theme.dart ga qo'shish kerak)
        darkTheme: AppTheme.darkTheme,
        themeMode: mode,
        navigatorKey: navigatorKey,
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasData) {
              if (!kIsWeb) saveFcmToken();

              // Real-time stream: ro'yxatdan o'tish jarayonida doc yozilganda
              // avtomatik HomeScreen'ga o'tadi
              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(snapshot.data!.uid)
                    .snapshots(),
                builder: (context, userSnap) {
                  if (userSnap.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (userSnap.hasError) {
                    // Firestore rules xatosi — sign out qilmasdan kutish
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (!userSnap.hasData || !userSnap.data!.exists) {
                    if (AuthState.isRegistering) {
                      // Ro'yxatdan o'tish davom etmoqda — kutish
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }
                    // Firestore doc yo'q — sign out
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      FirebaseAuth.instance.signOut();
                    });
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final data =
                      userSnap.data!.data() as Map<String, dynamic>;
                  final isAdmin = data['isAdmin'] ?? false;

                  return HomeScreen(isAdmin: isAdmin);
                },
              );
            }

            return const LoginScreen();
          },
        ),
      ),
    );
  }
}