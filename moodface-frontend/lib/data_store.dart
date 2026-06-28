import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class AnalysisRecord {
  final String date;
  final String time;
  final String emotion;
  final String confidence;
  final IconData icon;
  final Color color;
  final DateTime timestamp;

  AnalysisRecord({
    required this.date,
    required this.time,
    required this.emotion,
    required this.confidence,
    required this.icon,
    required this.color,
    required this.timestamp,
  });
}

class DataStore {
  // Instance unique (Singleton)
  static final DataStore _instance = DataStore._internal();
  factory DataStore() => _instance;
  DataStore._internal();

  // Infos de l'utilisateur connecté
  int? userId;
  String? userName;
  String? userEmail;
  String? profileImagePath;
  bool notificationsEnabled = true;
  List<String> notificationFrequencies = ["Semaine"]; // ["Jour", "Semaine", "Mois"]
  String appLanguage = "Français";

  // Liste des analyses
  final List<AnalysisRecord> historyData = [];

  // Charger la photo de profil de l'utilisateur connecté depuis le stockage local
  Future<void> loadProfileImage() async {
    if (userId == null) return;
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/profile_image_$userId.png');
      if (await file.exists()) {
        profileImagePath = file.path;
      } else {
        profileImagePath = null;
      }
    } catch (e) {
      debugPrint("Erreur chargement image de profil: $e");
    }
  }

  // Sauvegarder localement la photo de profil sélectionnée pour l'utilisateur connecté
  Future<void> saveProfileImage(String sourcePath) async {
    if (userId == null) return;
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/profile_image_$userId.png');
      final savedFile = await File(sourcePath).copy(file.path);
      profileImagePath = savedFile.path;
    } catch (e) {
      debugPrint("Erreur sauvegarde image de profil: $e");
    }
  }

  // Ajouter une nouvelle analyse
  void addRecord(AnalysisRecord record) {
    historyData.insert(0, record); // Insérer au début de la liste
  }

  // Charger l'historique depuis la base de données (backend)
  void loadFromBackend(List<dynamic> backendRecords) {
    historyData.clear();
    for (var r in backendRecords) {
      try {
        String? timestampStr = r['timestamp'];
        if (timestampStr == null) continue;
        
        if (!timestampStr.endsWith('Z') && !timestampStr.contains('+')) {
          timestampStr += 'Z';
        }
        final dateTime = DateTime.parse(timestampStr).toLocal();
        final formattedDate = "${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}";
        final pmAm = dateTime.hour >= 12 ? 'PM' : 'AM';
        final hour12 = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
        final formattedTime = "${hour12.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')} $pmAm";
        
        final emotion = r['emotion'] ?? "";
        final confidenceVal = r['confidence'];
        double confidence = 0.0;
        if (confidenceVal is num) {
          confidence = confidenceVal.toDouble();
        } else if (confidenceVal is String) {
          confidence = double.tryParse(confidenceVal) ?? 0.0;
        }
        
        final emotionFrench = _translateEmotion(emotion);
        final icon = _getEmotionIcon(emotionFrench);
        final color = _getEmotionColor(emotionFrench);
        
        historyData.add(AnalysisRecord(
          date: formattedDate,
          time: formattedTime,
          emotion: emotionFrench,
          confidence: "${confidence.toStringAsFixed(0)}%",
          icon: icon,
          color: color,
          timestamp: dateTime,
        ));
      } catch (e) {
        debugPrint("Erreur lors de la lecture d'un enregistrement d'historique : $e");
      }
    }
  }

  // Traduction/Formatage des émotions en français
  String _translateEmotion(String emotion) {
    switch (emotion.toLowerCase()) {
      case "happy": return "Heureux";
      case "sad": return "Triste";
      case "neutral": return "Neutre";
      case "angry": return "En colère";
      case "surprise": return "Surpris";
      case "fear": return "Peur";
      case "disgust": return "Dégoût";
      default: 
        if (emotion.isEmpty) return "";
        return emotion[0].toUpperCase() + emotion.substring(1).toLowerCase();
    }
  }

  // Icône correspondante à l'humeur
  IconData _getEmotionIcon(String emotion) {
    switch (emotion.toLowerCase()) {
      case "heureux":
      case "happy": return Icons.sentiment_very_satisfied;
      case "triste":
      case "sad": return Icons.sentiment_very_dissatisfied;
      case "neutre":
      case "neutral": return Icons.sentiment_neutral;
      case "en colère":
      case "colère":
      case "angry": return Icons.sentiment_very_dissatisfied;
      case "surpris":
      case "surprise": return Icons.face;
      case "peur":
      case "fear": return Icons.surround_sound;
      case "dégoût":
      case "degout":
      case "disgust": return Icons.sentiment_dissatisfied;
      default: return Icons.mood;
    }
  }

  // Couleur correspondante à l'humeur
  Color _getEmotionColor(String emotion) {
    switch (emotion.toLowerCase()) {
      case "heureux":
      case "happy": return Colors.green;
      case "triste":
      case "sad": return Colors.blue;
      case "neutre":
      case "neutral": return Colors.orange;
      case "en colère":
      case "colère":
      case "angry": return Colors.red;
      case "surpris":
      case "surprise": return Colors.purple;
      case "peur":
      case "fear": return Colors.indigo;
      case "dégoût":
      case "degout":
      case "disgust": return Colors.brown;
      default: return Colors.grey;
    }
  }

  // Obtenir le nombre total d'analyses
  int get totalAnalyses => historyData.length;

  // Récupérer la valeur normalisée pour comparer les émotions
  String _normalizeEmotionKey(String emotion) {
    switch (emotion.toLowerCase()) {
      case "happy":
      case "heureux":
        return "heureux";
      case "sad":
      case "triste":
        return "triste";
      case "neutral":
      case "neutre":
        return "neutre";
      case "angry":
      case "en colère":
      case "colère":
        return "colère";
      case "surprise":
      case "surpris":
        return "surpris";
      case "fear":
      case "peur":
        return "peur";
      case "disgust":
      case "dégoût":
      case "degout":
        return "dégoût";
      default:
        return emotion.toLowerCase();
    }
  }

  // Récupérer la dernière analyse
  AnalysisRecord? get lastRecord => historyData.isNotEmpty ? historyData.first : null;

  // Calculer le pourcentage de répartition des émotions pour l'affichage
  String getEmotionPercentage(String emotion) {
    if (historyData.isEmpty) return "0%";
    final key = _normalizeEmotionKey(emotion);
    int count = historyData.where((r) => _normalizeEmotionKey(r.emotion) == key).length;
    double percentage = (count / historyData.length) * 100;
    return "${percentage.toStringAsFixed(0)}%";
  }

  // Récupérer la valeur décimale de répartition (pour la barre de progression)
  double getEmotionPercentageValue(String emotion) {
    if (historyData.isEmpty) return 0.0;
    final key = _normalizeEmotionKey(emotion);
    int count = historyData.where((r) => _normalizeEmotionKey(r.emotion) == key).length;
    return count / historyData.length;
  }

  // Vider les données (pour un nouveau compte)
  void clear() {
    historyData.clear();
    userId = null;
    userName = null;
    userEmail = null;
    profileImagePath = null;
    notificationsEnabled = true;
    notificationFrequencies = ["Semaine"];
    appLanguage = "Français";
  }
}
