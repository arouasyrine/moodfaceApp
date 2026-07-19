import 'package:flutter/material.dart';
import '../data_store.dart';
import '../translations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'chatbot.dart';


class CoachRecommendationsScreen extends StatefulWidget {
  final String emotion;
  final double confidence;

  const CoachRecommendationsScreen({
    super.key,
    required this.emotion,
    required this.confidence,
  });

  @override
  State<CoachRecommendationsScreen> createState() => _CoachRecommendationsScreenState();
}

class _CoachRecommendationsScreenState extends State<CoachRecommendationsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _breathingController;
  late Animation<double> _breathingAnimation;
  String _breathingText = "Inspirez...";
  bool _isPlayingMusic = false;

  // Données du Coach par émotion
  final Map<String, Map<String, dynamic>> _coachData = {
    "Heureux": {
      "quote": "Le bonheur n'est pas quelque chose de tout fait. Il vient de vos propres actions.",
      "author": "Dalaï Lama",
      "music": "Acoustic Pop & Lofi Joyeux",
      "playlist_url": "https://open.spotify.com/playlist/37i9dQZF1DXdPec7a6GXY5",
      "plan": [
        "Partagez votre joie avec un ami ou un proche en lui envoyant un message.",
        "Notez ce moment positif dans un journal d'humeur.",
        "Profitez de cet élan d'énergie pour accomplir une tâche créative."
      ],
      "breathing_instructions": "Cohérence cardiaque : inspirez 5 secondes, expirez 5 secondes.",
      "breath_in_seconds": 5,
      "breath_out_seconds": 5,
    },
    "Triste": {
      "quote": "Au milieu de l'hiver, j'apprenais enfin qu'il y avait en moi un été invincible.",
      "author": "Albert Camus",
      "music": "Piano Relaxant & Ambiances Douces",
      "playlist_url": "https://open.spotify.com/playlist/37i9dQZF1DX4sWSpwq3LiO",
      "plan": [
        "Prenez une boisson chaude (tisane, thé) et buvez-la lentement.",
        "Faites une courte promenade de 10 minutes dehors pour vous aérer.",
        "Autorisez-vous à ressentir cette émotion sans jugement, elle est temporaire."
      ],
      "breathing_instructions": "Respiration 4-7-8 : inspirez 4s, retenez 7s, expirez 8s.",
      "breath_in_seconds": 4,
      "breath_out_seconds": 8,
    },
    "Neutre": {
      "quote": "La paix de l'esprit est le plus grand des trésors.",
      "author": "Sagesse Populaire",
      "music": "Focus Flow & Lofi Chill Beats",
      "playlist_url": "https://open.spotify.com/playlist/37i9dQZF1DWWQRwui0EXPn",
      "plan": [
        "Étirez votre corps pendant 5 minutes pour relâcher les tensions physiques.",
        "Prenez une pause loin de tous vos écrans (téléphone, ordinateur) pendant 10 minutes.",
        "Fixez-vous un petit objectif inspirant ou une tâche plaisante pour la journée."
      ],
      "breathing_instructions": "Respiration abdominale simple : gonflez le ventre à l'inspiration.",
      "breath_in_seconds": 4,
      "breath_out_seconds": 4,
    },
    "En colère": {
      "quote": "La colère est une rafale de vent qui éteint la lampe de l'intelligence.",
      "author": "Robert Ingersoll",
      "music": "Sons de nature apaisants & Méditation Profonde",
      "playlist_url": "https://open.spotify.com/playlist/37i9dQZF1DX4PP38Bv144C",
      "plan": [
        "Éloignez-vous physiquement de la source de votre frustration.",
        "Faites un exercice physique rapide (étirements ou marche rapide) pour évacuer l'énergie accumulée.",
        "Passez vos mains sous l'eau froide pour aider à faire baisser votre température corporelle."
      ],
      "breathing_instructions": "Expiration prolongée : inspirez 4s, expirez lentement 8s par la bouche.",
      "breath_in_seconds": 4,
      "breath_out_seconds": 8,
    },
    "Peur": {
      "quote": "Nos peurs sont beaucoup plus nombreuses que nos dangers réels.",
      "author": "Sénèque",
      "music": "Fréquences de guérison (528 Hz) & Ondes Calmes",
      "playlist_url": "https://open.spotify.com/playlist/37i9dQZF1DWZqd5JICZI0u",
      "plan": [
        "Posez vos deux pieds à plat sur le sol (ancrage) et observez 3 objets autour de vous.",
        "Rappelez-vous que vous êtes en sécurité à cet instant précis.",
        "Buvez un grand verre d'eau fraîche très lentement."
      ],
      "breathing_instructions": "Respiration carrée : inspirez 4s, retenez 4s, expirez 4s, retenez 4s.",
      "breath_in_seconds": 4,
      "breath_out_seconds": 4,
    },
    "Surpris": {
      "quote": "L'émerveillement est le premier pas vers la connaissance.",
      "author": "Aristote",
      "music": "Jazz apaisant & Lofi Acoustique",
      "playlist_url": "https://open.spotify.com/playlist/37i9dQZF1DX4s9HbvjuIKm",
      "plan": [
        "Prenez 30 secondes pour digérer l'information ou l'événement imprévu.",
        "Essayez de voir si cette surprise ouvre une nouvelle opportunité positive.",
        "Souriez et accueillez le changement avec curiosité."
      ],
      "breathing_instructions": "Respiration relaxante : inspirez doucement et expirez profondément.",
      "breath_in_seconds": 4,
      "breath_out_seconds": 4,
    },
    "Dégoût": {
      "quote": "Prendre soin de son corps et de son esprit, c'est aussi choisir ce qu'on y laisse entrer.",
      "author": "Sagesse Zen",
      "music": "Sons de cours d'eau & Forêt zen",
      "playlist_url": "https://open.spotify.com/playlist/37i9dQZF1DX4sWSpwq3LiO",
      "plan": [
        "Changez de pièce ou ouvrez une fenêtre pour faire circuler l'air frais.",
        "Lavez-vous les mains et le visage à l'eau fraîche pour vous rafraîchir.",
        "Pensez à un parfum agréable ou regardez une image apaisante de nature."
      ],
      "breathing_instructions": "Respiration purifiante : inspirez par le nez, soufflez énergiquement par la bouche.",
      "breath_in_seconds": 3,
      "breath_out_seconds": 5,
    }
  };

  List<bool> _completedTasks = [];

  @override
  void initState() {
    super.initState();

    final data = _coachData[widget.emotion] ?? _coachData["Neutre"]!;
    final int inSec = data["breath_in_seconds"];
    final int outSec = data["breath_out_seconds"];
    
    final planList = data["plan"] as List? ?? [];
    _completedTasks = List<bool>.filled(planList.length, false);

    _breathingController = AnimationController(
      vsync: this,
      duration: Duration(seconds: inSec + outSec),
    );

    _breathingAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.6).chain(CurveTween(curve: Curves.easeInOut)),
        weight: inSec.toDouble(),
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.6, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: outSec.toDouble(),
      ),
    ]).animate(_breathingController);

    _breathingController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _breathingController.reset();
        _breathingController.forward();
      }
    });

    _breathingController.addListener(() {
      final double progress = _breathingController.value;
      final double boundary = inSec / (inSec + outSec);
      final double totalDuration = (inSec + outSec).toDouble();
      final double elapsed = progress * totalDuration;

      setState(() {
        if (progress < boundary) {
          final remaining = (inSec - elapsed).ceil();
          _breathingText = "Inspirez\n${remaining}s";
        } else {
          final remaining = (totalDuration - elapsed).ceil();
          _breathingText = "Expirez\n${remaining}s";
        }
      });
    });

    _breathingController.forward();
  }

  @override
  void dispose() {
    _breathingController.dispose();
    super.dispose();
  }

  // Analyse intelligente de l'historique de l'utilisateur
  String? _generateHistoryFeedback() {
    final history = DataStore().historyData;
    if (history.length < 3) return null;

    final now = DateTime.now();
    
    // 1. Détection du stress du soir (Peur, En colère ou Triste après 17h)
    final eveningRecords = history.where((r) {
      final hour = r.timestamp.hour;
      final isEvening = hour >= 17 || hour <= 4; // Soirée et nuit
      return isEvening && ((r.userDeclaredEmotion ?? r.emotion) == "Peur" || (r.userDeclaredEmotion ?? r.emotion) == "En colère" || (r.userDeclaredEmotion ?? r.emotion) == "Triste");
    }).toList();

    if (eveningRecords.length >= 2) {
      return "⚠️ Le Coach a remarqué que vous exprimez souvent du stress ou de la tristesse en soirée. Une routine de détente et une déconnexion des écrans dès 21h vous aideraient à passer une nuit plus sereine.";
    }

    // 2. Détection d'une tendance de tristesse globale
    final sadRecords = history.where((r) => (r.userDeclaredEmotion ?? r.emotion) == "Triste").toList();
    if (sadRecords.length >= 3 && (sadRecords.length / history.length) > 0.4) {
      return "💡 Vous traversez une période difficile en ce moment avec plusieurs détections de tristesse. N'oubliez pas de parler de vos ressentis à un proche, de marcher au soleil et de faire des pauses régulières.";
    }

    // 3. Détection de stabilité positive
    final happyRecords = history.where((r) => (r.userDeclaredEmotion ?? r.emotion) == "Heureux").toList();
    if (happyRecords.length >= 3 && (happyRecords.length / history.length) > 0.5) {
      return "✨ Félicitations ! Votre historique montre une tendance émotionnelle dominante joyeuse et positive ces derniers temps. Continuez à cultiver cette gratitude et à propager votre bonne humeur !";
    }

    return "🌱 Pensez à faire une détection d'émotion régulière (matin et soir) pour permettre au coach intelligent d'affiner son diagnostic et de vous proposer un meilleur suivi de votre bien-être.";
  }

  Color _getEmotionColor() {
    switch (widget.emotion) {
      case "Heureux": return Colors.green.shade600;
      case "Triste": return Colors.blue.shade600;
      case "Neutre": return Colors.orange.shade600;
      case "En colère": return Colors.red.shade600;
      case "Surpris": return Colors.purple.shade600;
      case "Peur": return Colors.indigo.shade600;
      case "Dégoût": return Colors.brown.shade600;
      default: return Colors.purple.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final emotionColor = _getEmotionColor();
    final data = _coachData[widget.emotion] ?? _coachData["Neutre"]!;
    final historyFeedback = _generateHistoryFeedback();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              emotionColor.withOpacity(0.15),
              Colors.white,
              Colors.purple.withOpacity(0.02)
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Appbar Custom
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.black87),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Text(
                        "COACH ÉMOTIONNEL",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4A148C),
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(width: 48), // Pour centrer le titre
                    ],
                  ),
                  const SizedBox(height: 25),

                  // Header d'analyse
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white),
                      boxShadow: [
                        BoxShadow(
                          color: emotionColor.withOpacity(0.08),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          "Humeur analysée",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.emotion,
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: emotionColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "Score de confiance : ${widget.confidence.toStringAsFixed(0)}%",
                            style: TextStyle(
                              fontSize: 14,
                              color: emotionColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Section Analyse d'historique (Coach Intelligent)
                  if (historyFeedback != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.purple.shade900, Color(0xFF6A1B9A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.purple.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          )
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.psychology_outlined, color: Colors.white, size: 28),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Analyse de votre historique",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  historyFeedback,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    color: Colors.white70,
                                    height: 1.4,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 1. Citation Motivante
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.white),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.format_quote_rounded, color: emotionColor, size: 30),
                            const SizedBox(width: 8),
                            const Text(
                              "Pensée inspirante",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "\"${data['quote']}\"",
                          style: const TextStyle(
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            "— ${data['author']}",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: emotionColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 2. Exercice de respiration interactif
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.air_rounded, color: Colors.blue, size: 26),
                            const SizedBox(width: 10),
                            Text(
                              "Exercice de respiration",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          data['breathing_instructions'],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 30),
                        // Bulle de respiration animée
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              if (_breathingController.isAnimating) {
                                _breathingController.stop();
                              } else {
                                _breathingController.forward();
                              }
                            });
                          },
                          child: AnimatedBuilder(
                            animation: _breathingAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _breathingAnimation.value,
                                child: Container(
                                  width: 110,
                                  height: 110,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: emotionColor.withOpacity(0.12),
                                    border: Border.all(
                                      color: emotionColor.withOpacity(0.4),
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: emotionColor.withOpacity(0.2),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _breathingController.isAnimating
                                            ? Icons.spa_outlined
                                            : Icons.play_arrow_rounded,
                                        color: emotionColor,
                                        size: 22,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _breathingController.isAnimating
                                            ? _breathingText
                                            : "Pause\n(Jouer)",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: emotionColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          height: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "Touchez le cercle pour démarrer ou mettre en pause",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 3. Recommandations de musique
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(Icons.music_note_rounded, color: Colors.purple, size: 28),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Musique relaxante suggérée",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                data['music'],
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (_isPlayingMusic) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Text(
                                      "Lecture externe lancée...",
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(2),
                                        child: const LinearProgressIndicator(
                                          minHeight: 3,
                                          backgroundColor: Colors.grey,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            final Uri url = Uri.parse(data['playlist_url']);
                            setState(() {
                              _isPlayingMusic = !_isPlayingMusic;
                            });
                            if (_isPlayingMusic) {
                              try {
                                final launched = await launchUrl(
                                  url,
                                  mode: LaunchMode.platformDefault,
                                );
                                if (!launched) {
                                  await launchUrl(
                                    url,
                                    mode: LaunchMode.inAppWebView,
                                  );
                                }
                              } catch (e) {
                                debugPrint("Erreur ouverture playlist: $e");
                                try {
                                  await launchUrl(
                                    url,
                                    mode: LaunchMode.externalApplication,
                                  );
                                } catch (e2) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("Impossible d'ouvrir la playlist : ${data['music']}"),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(12),
                            backgroundColor: _isPlayingMusic ? Colors.green.shade600 : Colors.purple,
                            foregroundColor: Colors.white,
                          ),
                          child: Icon(_isPlayingMusic ? Icons.pause_rounded : Icons.play_arrow_rounded),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 4. Mini-plan quotidien
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.assignment_turned_in_outlined, color: emotionColor, size: 26),
                            const SizedBox(width: 10),
                            const Text(
                              "Votre mini-plan d'action",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        ...List.generate(
                          (data['plan'] as List).length,
                          (index) => Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _completedTasks[index] = !_completedTasks[index];
                                    });
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(top: 2),
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: _completedTasks[index]
                                          ? emotionColor
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: _completedTasks[index]
                                            ? emotionColor
                                            : Colors.grey.shade400,
                                        width: 2,
                                      ),
                                    ),
                                    child: _completedTasks[index]
                                        ? const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 14,
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _completedTasks[index] = !_completedTasks[index];
                                      });
                                    },
                                    child: Text(
                                      data['plan'][index],
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        height: 1.4,
                                        color: _completedTasks[index]
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade800,
                                        decoration: _completedTasks[index]
                                            ? TextDecoration.lineThrough
                                            : TextDecoration.none,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 35),

                  // Bouton Parler à l'Assistant
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatbotScreen(
                              initialEmotion: widget.emotion,
                              initialConfidence: widget.confidence,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.support_agent_rounded),
                      label: const Text(
                        "DISCUTER AVEC L'ASSISTANT",
                        style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: emotionColor, width: 1.5),
                        foregroundColor: emotionColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Bouton Terminer
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: () {
                        // Retourner à l'accueil
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: emotionColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 5,
                        shadowColor: emotionColor.withOpacity(0.3),
                      ),
                      child: const Text(
                        "TERMINER L'ACCOMPAGNEMENT",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
