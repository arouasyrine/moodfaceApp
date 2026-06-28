import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'data_store.dart';
import 'translations.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Configuration pour Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Configuration pour iOS
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    try {
      await _notificationsPlugin.initialize(
        settings: initializationSettings,
      );
      
      // Demander l'autorisation pour Android 13+
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (e) {
      debugPrint("Erreur initialisation notifications: $e");
    }
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!DataStore().notificationsEnabled) return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'moodface_channel',
      'MoodFace Notifications',
      channelDescription: 'Notifications pour MoodFace AI',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    try {
      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: platformDetails,
      );
    } catch (e) {
      debugPrint("Erreur envoi notification: $e");
    }
  }

  // Envoi d'une notification de test lors de la configuration
  Future<void> sendTestNotification() async {
    await showNotification(
      id: 999,
      title: "MoodFace AI",
      body: "Les notifications de rapports d'humeur sont maintenant fonctionnelles !",
    );
  }

  // Envoi d'une notification après une analyse réussie
  Future<void> sendAnalysisNotification(String emotion, String confidence) async {
    final localizedEmotion = Translations.translateEmotion(emotion);
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: Translations.t('new_analysis'),
      body: "Nouvelle analyse enregistrée : $localizedEmotion (Confiance : $confidence)",
    );
  }
}
