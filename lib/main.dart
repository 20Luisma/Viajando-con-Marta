import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';

import 'firebase_options.dart';
import 'login_screen.dart';
import 'home/home_screen.dart';
import 'theme/palette.dart';

/// Handler para notificaciones en segundo plano / app terminada.
/// (No hace falta para 'notification' payloads, pero lo dejamos listo
/// por si en el futuro envías 'data-only').
@pragma('vm:entry-point') // necesario en release
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Puedes hacer logging o pre-carga aquí si quieres.
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Registrar handler de background antes de usar FirebaseMessaging.
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ---- Pedir permisos (solo móviles) ----
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    // Android 13+ (y iOS) – permiso del SO
    try {
      final p = await Permission.notification.status;
      if (!p.isGranted) {
        await Permission.notification.request();
      }
    } catch (_) {}

    // Permisos a nivel FCM (iOS necesita esto; en Android es no-op)
    await FirebaseMessaging.instance.requestPermission(
      alert: true, badge: true, sound: true,
    );

    // iOS: mostrar notificaciones también en primer plano
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true, badge: true, sound: true,
    );
  }

  runApp(const MyApp());
}

/// Suscribe el dispositivo al topic del viaje.
/// Llama a esta función DESPUÉS del login, cuando ya sepas el tripId.
Future<void> subscribeTrip(String tripId) async {
  final topic = 'news_trip_${tripId.replaceAll(' ', '_')}';
  await FirebaseMessaging.instance.subscribeToTopic(topic);
}

/// Desuscripción opcional si el usuario cierra sesión o cambia de viaje.
Future<void> unsubscribeTrip(String tripId) async {
  final topic = 'news_trip_${tripId.replaceAll(' ', '_')}';
  await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Viajando con Marta',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Palette.brown,
        scaffoldBackgroundColor: Palette.sand,
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const HomeScreen(),
      },
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  static const _duration = Duration(milliseconds: 2600);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration)
      ..forward().whenComplete(() {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Palette.sand,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOut,
            builder: (context, v, _) => Opacity(
              opacity: v,
              child: Transform.translate(
                offset: Offset(0, (1 - v) * 12),
                child: Image.asset(
                  'assets/images/intro.png',
                  height: size.height * 0.34,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
