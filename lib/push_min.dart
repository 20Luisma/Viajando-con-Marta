// lib/push_min.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> initPushMin() async {
  // Inicializa Firebase (usa los .json/.plist que ya tienes)
  await Firebase.initializeApp();

  // Pide permisos (iOS y Android 13+)
  await Permission.notification.request();
  await FirebaseMessaging.instance.requestPermission(
    alert: true, badge: true, sound: true,
  );
}

/// Suscríbete al topic del viaje (ej: KENIA_2025)
Future<void> subscribeTrip(String tripId) async {
  final topic = 'news_trip_${tripId.replaceAll(' ', '_')}';
  await FirebaseMessaging.instance.subscribeToTopic(topic);
}

/// Desuscripción opcional al salir del viaje
Future<void> unsubscribeTrip(String tripId) async {
  final topic = 'news_trip_${tripId.replaceAll(' ', '_')}';
  await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
}
