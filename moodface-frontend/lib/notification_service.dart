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
    final dailyMood = DataStore().getDailyDominantMood();
    
    String body = Translations.t('notification_test_body_success');
    if (dailyMood != "Aucune") {
      final localizedMood = Translations.translateEmotion(dailyMood);
      body = Translations.t('notification_test_body_active').replaceAll('{mood}', localizedMood);
    }
    
    await showNotification(
      id: 999,
      title: "MoodFace AI",
      body: body,
    );
  }

  // Envoi d'une notification après une analyse réussie
  Future<void> sendAnalysisNotification(String emotion, String confidence) async {
    final localizedEmotion = Translations.translateEmotion(emotion);
    final bodyTemplate = Translations.t('notification_analysis_body');
    final body = bodyTemplate
        .replaceAll('{emotion}', localizedEmotion)
        .replaceAll('{confidence}', confidence);
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: Translations.t('new_analysis'),
      body: body,
    );
  }

  // Configuration et planification des notifications périodiques (Jour, Semaine, Mois)
  Future<void> configureScheduledNotifications() async {
    // Annuler les anciennes planifications pour éviter les doublons
    await _notificationsPlugin.cancel(id: 1); // ID 1 = Quotidien
    await _notificationsPlugin.cancel(id: 2); // ID 2 = Hebdomadaire
    await _notificationsPlugin.cancel(id: 3); // ID 3 = Mensuel (Simulé)

    if (!DataStore().notificationsEnabled) return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'moodface_periodic_channel',
      'MoodFace Rapports',
      channelDescription: 'Notifications périodiques pour MoodFace AI',
      importance: Importance.max,
      priority: Priority.high,
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

    final frequencies = DataStore().notificationFrequencies;

    final dailyMood = DataStore().getDailyDominantMood();
    final weeklyMood = DataStore().getWeeklyDominantMood();
    final monthlyMood = DataStore().getMonthlyDominantMood();

    String dailyBody;
    if (dailyMood != "Aucune") {
      final localizedMood = Translations.translateEmotion(dailyMood);
      dailyBody = Translations.t('notification_daily_mood_body').replaceAll('{mood}', localizedMood);
    } else {
      dailyBody = Translations.t('notification_daily_empty_body');
    }

    String weeklyBody;
    if (weeklyMood != "Aucune") {
      final localizedMood = Translations.translateEmotion(weeklyMood);
      weeklyBody = Translations.t('notification_weekly_mood_body').replaceAll('{mood}', localizedMood);
    } else {
      weeklyBody = Translations.t('notification_weekly_empty_body');
    }

    String monthlyBody;
    if (monthlyMood != "Aucune") {
      final localizedMood = Translations.translateEmotion(monthlyMood);
      monthlyBody = Translations.t('notification_monthly_mood_body').replaceAll('{mood}', localizedMood);
    } else {
      monthlyBody = Translations.t('notification_monthly_empty_body');
    }

    if (frequencies.contains("Jour")) {
      await _notificationsPlugin.periodicallyShow(
        id: 1,
        title: Translations.t('notification_daily_report_title'),
        body: dailyBody,
        repeatInterval: RepeatInterval.daily,
        notificationDetails: platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }

    if (frequencies.contains("Semaine")) {
      await _notificationsPlugin.periodicallyShow(
        id: 2,
        title: Translations.t('notification_weekly_report_title'),
        body: weeklyBody,
        repeatInterval: RepeatInterval.weekly,
        notificationDetails: platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }

    if (frequencies.contains("Mois")) {
      await _notificationsPlugin.periodicallyShow(
        id: 3,
        title: Translations.t('notification_monthly_report_title'),
        body: monthlyBody,
        repeatInterval: RepeatInterval.weekly, 
        notificationDetails: platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }
}
