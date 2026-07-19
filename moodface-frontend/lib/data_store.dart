import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class AnalysisRecord {
  final int? id;
  final String date;
  final String time;
  final String emotion;
  final String confidence;
  IconData icon;
  Color color;
  final DateTime timestamp;
  final String? imagePath;
  
  // Nouvelles colonnes du journal émotionnel intelligent
  String? note;
  List<String>? tags;
  String? userDeclaredEmotion;

  AnalysisRecord({
    this.id,
    required this.date,
    required this.time,
    required this.emotion,
    required this.confidence,
    required this.icon,
    required this.color,
    required this.timestamp,
    this.imagePath,
    this.note,
    this.tags,
    this.userDeclaredEmotion,
  });


  String? get localImagePath {
    if (imagePath != null && File(imagePath!).existsSync()) return imagePath;
    final dir = DataStore().documentsDirectoryPath;
    if (dir != null) {
      if (id != null) {
        final idPath = "$dir/analysis_id_$id.png";
        if (File(idPath).existsSync()) return idPath;
      }
      final timePath = "$dir/analysis_${timestamp.millisecondsSinceEpoch}.png";
      if (File(timePath).existsSync()) return timePath;
    }
    return null;
  }
}

class DataStore {
  // Instance unique (Singleton)
  static final DataStore _instance = DataStore._internal();
  factory DataStore() => _instance;
  DataStore._internal();

  // Chemin du dossier documents pour vérification synchrone des images
  String? documentsDirectoryPath;

  Future<void> initDir() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      documentsDirectoryPath = directory.path;
    } catch (e) {
      debugPrint("Erreur initialisation dossier documents: $e");
    }
  }

  // Infos de l'utilisateur connecté
  int? userId;
  String? userName;
  String? userEmail;
  String? profileImagePath;
  bool notificationsEnabled = true;
  List<String> notificationFrequencies = ["Semaine"]; // ["Jour", "Semaine", "Mois"]
  final ValueNotifier<String> languageNotifier = ValueNotifier<String>("Français");
  String get appLanguage => languageNotifier.value;
  set appLanguage(String val) {
    languageNotifier.value = val;
  }
  String selectedModelType = "pretrained"; // "pretrained" ou "custom"

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
        final userDeclaredEmotion = r['user_declared_emotion'] as String?;
        final userDeclaredEmotionFrench = (userDeclaredEmotion != null && userDeclaredEmotion.isNotEmpty) ? _translateEmotion(userDeclaredEmotion) : null;
        final displayEmotion = userDeclaredEmotionFrench ?? emotionFrench;
        final icon = _getEmotionIcon(displayEmotion);
        final color = _getEmotionColor(displayEmotion);

        final recordId = r['id'] as int?;
        final note = r['note'] as String?;
        final tagsRaw = r['tags'] as String?;
        final tags = tagsRaw != null
            ? tagsRaw.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList()
            : <String>[];
        
        historyData.add(AnalysisRecord(
          id: recordId,
          date: formattedDate,
          time: formattedTime,
          emotion: emotionFrench,
          confidence: "${confidence.toStringAsFixed(0)}%",
          icon: icon,
          color: color,
          timestamp: dateTime,
          note: note,
          tags: tags,
          userDeclaredEmotion: userDeclaredEmotionFrench,
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

  IconData getEmotionIcon(String emotion) => _getEmotionIcon(emotion);
  Color getEmotionColor(String emotion) => _getEmotionColor(emotion);


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
    int count = historyData.where((r) {
      final em = r.userDeclaredEmotion ?? r.emotion;
      return _normalizeEmotionKey(em) == key;
    }).length;
    double percentage = (count / historyData.length) * 100;
    return "${percentage.toStringAsFixed(0)}%";
  }

  // Récupérer la valeur décimale de répartition (pour la barre de progression)
  double getEmotionPercentageValue(String emotion) {
    if (historyData.isEmpty) return 0.0;
    final key = _normalizeEmotionKey(emotion);
    int count = historyData.where((r) {
      final em = r.userDeclaredEmotion ?? r.emotion;
      return _normalizeEmotionKey(em) == key;
    }).length;
    return count / historyData.length;
  }

  // Calcul de l'humeur dominante pour une liste de records
  String _calculateDominantMood(List<AnalysisRecord> records) {
    if (records.isEmpty) return "Aucune";
    
    final Map<String, int> counts = {};
    for (var r in records) {
      final em = r.userDeclaredEmotion ?? r.emotion;
      counts[em] = (counts[em] ?? 0) + 1;
    }
    
    String dominant = "";
    int maxCount = 0;
    counts.forEach((emotion, count) {
      if (count > maxCount) {
        maxCount = count;
        dominant = emotion;
      }
    });
    
    return dominant;
  }

  // Humeur dominante du jour
  String getDailyDominantMood() {
    final now = DateTime.now();
    final todayRecords = historyData.where((r) => 
      r.timestamp.year == now.year && 
      r.timestamp.month == now.month && 
      r.timestamp.day == now.day
    ).toList();
    return _calculateDominantMood(todayRecords);
  }

  // Humeur dominante de la semaine
  String getWeeklyDominantMood() {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final weeklyRecords = historyData.where((r) => r.timestamp.isAfter(sevenDaysAgo)).toList();
    return _calculateDominantMood(weeklyRecords);
  }

  // Humeur dominante du mois
  String getMonthlyDominantMood() {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final monthlyRecords = historyData.where((r) => r.timestamp.isAfter(thirtyDaysAgo)).toList();
    return _calculateDominantMood(monthlyRecords);
  }

  // Obtenir l'émotion dominante avec son pourcentage pour une liste d'enregistrements
  Map<String, dynamic> getDominantEmotionWithPct(List<AnalysisRecord> records) {
    if (records.isEmpty) {
      return {"emotion": "Aucune", "pct": 0};
    }
    final Map<String, int> counts = {};
    for (var r in records) {
      final em = r.userDeclaredEmotion ?? r.emotion;
      counts[em] = (counts[em] ?? 0) + 1;
    }
    String dominant = "";
    int maxCount = 0;
    counts.forEach((emotion, count) {
      if (count > maxCount) {
        maxCount = count;
        dominant = emotion;
      }
    });
    double pct = (maxCount / records.length) * 100;
    return {"emotion": dominant, "pct": pct.round()};
  }

  // Calcul du score de stabilité émotionnelle (0-100)
  int calculateEmotionalStability(List<AnalysisRecord> records) {
    if (records.length <= 1) return 100;
    double totalDiff = 0.0;
    
    // Obtenir la valeur numérique pour chaque humeur
    double _getMoodVal(String emotion) {
      switch (emotion.toLowerCase()) {
        case "heureux":
        case "happy": return 5.0;
        case "surpris":
        case "surprise": return 4.0;
        case "neutre":
        case "neutral": return 3.0;
        case "triste":
        case "sad": return 2.0;
        case "peur":
        case "fear": return 1.5;
        case "dégoût":
        case "degout":
        case "disgust":
        case "en colère":
        case "colère":
        case "angry": return 1.0;
        default: return 3.0;
      }
    }

    // Calculer la différence absolue entre enregistrements consécutifs (par ordre chronologique)
    final sortedRecords = List<AnalysisRecord>.from(records)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    for (int i = 0; i < sortedRecords.length - 1; i++) {
      double val1 = _getMoodVal(sortedRecords[i].userDeclaredEmotion ?? sortedRecords[i].emotion);
      double val2 = _getMoodVal(sortedRecords[i + 1].userDeclaredEmotion ?? sortedRecords[i + 1].emotion);
      totalDiff += (val1 - val2).abs();
    }
    double avgDiff = totalDiff / (sortedRecords.length - 1);
    // Différence maximale est 4.0 (5.0 - 1.0)
    double stability = (1.0 - (avgDiff / 4.0)) * 100;
    return stability.clamp(0, 100).round();
  }

  // Obtenir les jours de la semaine les plus positifs
  List<String> getMostPositiveDays(List<AnalysisRecord> records) {
    if (records.isEmpty) return ["Aucun"];
    
    final Map<int, List<AnalysisRecord>> weekdayRecords = {};
    for (var r in records) {
      int day = r.timestamp.weekday;
      weekdayRecords.putIfAbsent(day, () => []).add(r);
    }
    
    final Map<int, double> weekdayScores = {};
    weekdayRecords.forEach((day, recs) {
      double scoreSum = 0;
      for (var r in recs) {
        final em = (r.userDeclaredEmotion ?? r.emotion).toLowerCase();
        if (em == "heureux" || em == "happy") {
          scoreSum += 1.0;
        } else if (em == "surpris" || em == "surprise") {
          scoreSum += 0.8;
        } else if (em == "neutre" || em == "neutral") {
          scoreSum += 0.5;
        } else {
          scoreSum += 0.1;
        }
      }
      weekdayScores[day] = scoreSum / recs.length;
    });
    
    final sortedDays = weekdayScores.keys.toList()
      ..sort((a, b) => weekdayScores[b]!.compareTo(weekdayScores[a]!));
    
    final Map<int, String> dayNames = {
      DateTime.monday: "Lundi",
      DateTime.tuesday: "Mardi",
      DateTime.wednesday: "Mercredi",
      DateTime.thursday: "Jeudi",
      DateTime.friday: "Vendredi",
      DateTime.saturday: "Samedi",
      DateTime.sunday: "Dimanche",
    };
    
    final result = sortedDays
        .where((day) => weekdayScores[day]! >= 0.4)
        .map((day) => dayNames[day]!)
        .toList();
        
    if (result.isEmpty) {
      return ["Aucun"];
    }
    return result.take(2).toList();
  }

  // Obtenir la période de la journée où les émotions négatives augmentent
  String getNegativeEmotionPeaks(List<AnalysisRecord> records) {
    if (records.isEmpty) return "Aucun moment critique";
    
    // 0: Nuit (00h-06h), 1: Matin (06h-12h), 2: Après-midi (12h-18h), 3: Soirée (18h-00h)
    final Map<int, int> negCounts = {0: 0, 1: 0, 2: 0, 3: 0};
    final Map<int, int> totalCounts = {0: 0, 1: 0, 2: 0, 3: 0};
    
    for (var r in records) {
      int hour = r.timestamp.hour;
      int block = 0;
      if (hour >= 6 && hour < 12) {
        block = 1;
      } else if (hour >= 12 && hour < 18) {
        block = 2;
      } else if (hour >= 18 && hour < 24) {
        block = 3;
      } else {
        block = 0;
      }
      
      totalCounts[block] = (totalCounts[block] ?? 0) + 1;
      
      final em = (r.userDeclaredEmotion ?? r.emotion).toLowerCase();
      if (em == "triste" || em == "sad" || 
          em == "peur" || em == "fear" || 
          em == "en colère" || em == "colère" || em == "angry" || 
          em == "dégoût" || em == "degout" || em == "disgust") {
        negCounts[block] = (negCounts[block] ?? 0) + 1;
      }
    }
    
    int peakBlock = -1;
    double maxRatio = 0.0;
    
    negCounts.forEach((block, count) {
      int total = totalCounts[block] ?? 0;
      if (total > 0) {
        double ratio = count / total;
        if (ratio > maxRatio && count > 0) {
          maxRatio = ratio;
          peakBlock = block;
        }
      }
    });
    
    final Map<int, String> blockNames = {
      0: "la Nuit (00h-06h)",
      1: "le Matin (06h-12h)",
      2: "l'Après-midi (12h-18h)",
      3: "la Soirée (18h-24h)",
    };
    
    if (peakBlock == -1 || maxRatio == 0.0) {
      return "Aucun moment critique";
    }
    
    return "${blockNames[peakBlock]} - ${(maxRatio * 100).toStringAsFixed(0)}% de négativité";
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
