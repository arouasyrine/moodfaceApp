import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data_store.dart';
import '../translations.dart';
import '../mood_service.dart';



class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<String>? quickReplies;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.quickReplies,
  });
}

class ChatbotScreen extends StatefulWidget {
  final String? initialEmotion; // Si ouvert après une analyse
  final double? initialConfidence;

  const ChatbotScreen({
    super.key,
    this.initialEmotion,
    this.initialConfidence,
  });

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  void _initializeChat() {
    // 1. Message de bienvenue standard
    _messages.add(
      ChatMessage(
        text: "Bonjour ! Je suis ton assistant de bien-être émotionnel. 🌟\n\nJe suis là pour t'accompagner, t'écouter, te proposer des exercices de relaxation et t'orienter vers de bonnes habitudes au quotidien.\n\n*Note : Je ne suis pas un professionnel de santé (médecin ou psychologue). Si tu as besoin d'une thérapie ou d'un suivi médical, je t'invite à consulter un spécialiste.*",
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );

    // 2. Si ouvert après une analyse ou s'il y a une analyse récente
    final emotion = widget.initialEmotion ?? (DataStore().lastRecord?.userDeclaredEmotion ?? DataStore().lastRecord?.emotion);
    final confidence = widget.initialConfidence ?? 
        (DataStore().lastRecord != null 
            ? (double.tryParse(DataStore().lastRecord!.confidence.replaceAll('%', '')) ?? 100.0)
            : null);

    if (emotion != null) {
      final emotionDisplay = Translations.translateEmotion(emotion);
      final confDisplay = confidence != null ? " avec une confiance de ${confidence.toStringAsFixed(0)}%" : "";
      
      _messages.add(
        ChatMessage(
          text: "Je vois que ta dernière analyse indique que tu te sens **$emotionDisplay**$confDisplay. Comment te sens-tu par rapport à cela ? Veux-tu qu'on en discute ?",
          isUser: false,
          timestamp: DateTime.now().add(const Duration(milliseconds: 200)),
          quickReplies: [
            "Parler de mon humeur",
            "Proposer une activité 🧘",
            "Résumé de ma journée 📊",
            "Conseils bien-être 🌿",
          ],
        ),
      );
    } else {
      _messages.add(
        ChatMessage(
          text: "Comment se passe ta journée ? Je suis à ton écoute. Choisis une option ci-dessous ou écris-moi directement !",
          isUser: false,
          timestamp: DateTime.now().add(const Duration(milliseconds: 200)),
          quickReplies: [
            "Proposer une activité 🧘",
            "Résumé de ma journée 📊",
            "Conseils bien-être 🌿",
          ],
        ),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSubmitted(String text) async {
    if (text.trim().isEmpty) return;
    _textController.clear();

    setState(() {
      _messages.add(
        ChatMessage(
          text: text,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      _isTyping = true;
    });
    _scrollToBottom();

    // Préparer l'historique des messages pour l'envoyer au backend
    final recentMessages = _messages.length > 10 
        ? _messages.sublist(_messages.length - 10) 
        : _messages;
        
    final history = recentMessages.map((msg) => {
      "text": msg.text,
      "isUser": msg.isUser,
    }).toList();

    try {
      final response = await http.post(
        Uri.parse("${MoodService.baseUrl}/chatbot"),
        headers: {
          "Content-Type": "application/json",
          "ngrok-skip-browser-warning": "true",
        },
        body: jsonEncode({
          "messages": history,
          "language": DataStore().appLanguage,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final replyText = data['response'] ?? "Désolé, je n'ai pas pu générer de réponse.";
        
        setState(() {
          _messages.add(ChatMessage(
            text: replyText,
            isUser: false,
            timestamp: DateTime.now(),
            quickReplies: [
              "Proposer une activité 🧘",
              "Résumé de ma journée 📊",
              "Conseils bien-être 🌿",
              "Menu principal"
            ],
          ));
        });
      } else {
        // Fallback local en cas d'erreur serveur
        final localReply = _generateResponse(text);
        setState(() {
          _messages.add(localReply);
        });
      }
    } catch (e) {
      // Fallback local en cas de problème de connexion
      final localReply = _generateResponse(text);
      setState(() {
        _messages.add(localReply);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isTyping = false;
        });
        _scrollToBottom();
      }
    }
  }

  ChatMessage _generateResponse(String userText) {
    final text = userText.toLowerCase().trim();
    
    // Détection médicale / psychologique
    final List<String> medicalTriggers = [
      'depressif', 'depression', 'suicide', 'suicidaire', 'malade', 
      'psychologue', 'psy', 'medecin', 'traitement', 'medicament', 
      'hopital', 'therapie', 'anxiete severe', 'anxieux severe', 
      'mourir', 'mort', 'psychiatre', 'clinique'
    ];
    
    if (medicalTriggers.any((trigger) => text.contains(trigger))) {
      return ChatMessage(
        text: "Je ressens ta détresse et je suis là pour t'écouter, mais je tiens à te rappeler que je suis un assistant de bien-être et non un professionnel de santé (médecin ou psychologue). Si tu te sens très mal ou si tu as des pensées sombres, s'il te plaît, contacte immédiatement un médecin, un professionnel de santé ou un service d'urgence (comme le 15, le 112, ou le 3114 pour la prévention du suicide). Prendre soin de soi, c'est aussi savoir s'entourer de l'aide adéquate. ❤️",
        isUser: false,
        timestamp: DateTime.now(),
        quickReplies: ["Menu principal", "Conseils bien-être 🌿"],
      );
    }

    // Déclencheurs de réponses
    if (text == "menu principal" || text == "retour au menu principal") {
      return ChatMessage(
        text: "Que souhaites-tu faire maintenant ? Je suis là pour t'aider.",
        isUser: false,
        timestamp: DateTime.now(),
        quickReplies: [
          "Parler de mon humeur",
          "Proposer une activité 🧘",
          "Résumé de ma journée 📊",
          "Conseils bien-être 🌿",
        ],
      );
    }

    if (text.contains("humeur") || text == "parler de mon humeur") {
      return ChatMessage(
        text: "C'est une excellente démarche. Exprimer ses émotions est libérateur. Raconte-moi : qu'est-ce qui t'a fait te sentir ainsi aujourd'hui ? Y a-t-il eu un événement déclencheur ?",
        isUser: false,
        timestamp: DateTime.now(),
        quickReplies: [
          "Le travail / les études 💼",
          "Mes relations / ma famille 👥",
          "La fatigue physique 🔋",
          "Rien de particulier ✨",
        ],
      );
    }

    if (text.contains("travail") || text.contains("etude") || text.contains("étude") || text.contains("examen") || text.contains("boulot")) {
      return ChatMessage(
        text: "Le travail ou les études occupent une grande partie de notre temps et peuvent parfois générer de la pression. N'oublie pas de faire de petites coupures régulières de 5 minutes toutes les heures : étire tes bras, ferme tes yeux pour les reposer des écrans et bois une gorgée d'eau.",
        isUser: false,
        timestamp: DateTime.now(),
        quickReplies: ["Proposer une activité 🧘", "Menu principal"],
      );
    }

    if (text.contains("relation") || text.contains("famille") || text.contains("ami") || text.contains("rencontre") || text.contains("dispute")) {
      return ChatMessage(
        text: "Les relations sociales et familiales influencent grandement notre bien-être émotionnel. Parler calmement de ses limites et partager des moments de qualité avec ceux qu'on aime permet de renforcer notre équilibre. Veux-tu faire une pause relaxante pour relâcher la pression ?",
        isUser: false,
        timestamp: DateTime.now(),
        quickReplies: ["Proposer une activité 🧘", "Menu principal"],
      );
    }

    if (text.contains("fatigue") || text.contains("fatigué") || text.contains("épuisé") || text.contains("epuise") || text.contains("sommeil") || text.contains("dormir")) {
      return ChatMessage(
        text: "La fatigue physique affecte directement notre mental et nos émotions. Je te conseille d'adopter des routines douces : \n\n• Bois un grand verre d'eau\n• Fais quelques étirements légers\n• Instaure une routine sans écran 30 minutes avant de dormir (préfère un livre ou de la musique douce).\n\nVeux-tu que je te propose une activité relaxante ?",
        isUser: false,
        timestamp: DateTime.now(),
        quickReplies: ["Proposer une activité 🧘", "Conseils bien-être 🌿"],
      );
    }

    if (text.contains("activité") || text.contains("activite") || text.contains("proposer une activité")) {
      return ChatMessage(
        text: "Voici des activités rapides et efficaces pour te détendre et te ressourcer. Laquelle te tente le plus ?",
        isUser: false,
        timestamp: DateTime.now(),
        quickReplies: [
          "Exercice de respiration 💨",
          "Écouter de la musique 🎵",
          "Prendre l'air 🌳",
          "Menu principal",
        ],
      );
    }

    if (text.contains("respiration") || text.contains("respirer")) {
      return ChatMessage(
        text: "Excellente idée ! La respiration abdominale ou carrée permet d'apaiser instantanément le système nerveux. Je te conseille d'utiliser l'outil de cohérence cardiaque animé du **Coach Émotionnel** sur l'application pour te guider pas à pas ! C'est très ressourçant.",
        isUser: false,
        timestamp: DateTime.now(),
        quickReplies: ["Écouter de la musique 🎵", "Menu principal"],
      );
    }

    if (text.contains("musique") || text.contains("playlist") || text.contains("écouter")) {
      return ChatMessage(
        text: "La musique a le pouvoir de transformer notre état d'esprit. Rends-toi sur l'écran **Coach Émotionnel** de ton application pour écouter la playlist Spotify personnalisée que nous avons préparée spécialement pour ton humeur actuelle !",
        isUser: false,
        timestamp: DateTime.now(),
        quickReplies: ["Conseils bien-être 🌿", "Menu principal"],
      );
    }

    if (text.contains("air") || text.contains("promenade") || text.contains("nature") || text.contains("marcher")) {
      return ChatMessage(
        text: "Prendre l'air et marcher quelques minutes permet de changer d'environnement et de libérer des endorphines. Même 5 à 10 minutes de marche au calme dehors peuvent faire une grande différence pour ton moral ! En route ? 🚶‍♂️",
        isUser: false,
        timestamp: DateTime.now(),
        quickReplies: ["Menu principal"],
      );
    }

    if (text.contains("résumé") || text.contains("resume") || text.contains("résumé de ma journée")) {
      final now = DateTime.now();
      final todayRecords = DataStore().historyData.where((r) => 
        r.timestamp.year == now.year && 
        r.timestamp.month == now.month && 
        r.timestamp.day == now.day
      ).toList();

      if (todayRecords.isEmpty) {
        return ChatMessage(
          text: "Tu n'as pas encore réalisé d'analyse d'émotion aujourd'hui. Fais un scan rapide avec ta caméra pour commencer à suivre ton humeur de la journée !",
          isUser: false,
          timestamp: DateTime.now(),
          quickReplies: ["Menu principal"],
        );
      }

      final dominant = DataStore().getDailyDominantMood();
      final lastMood = todayRecords.first.userDeclaredEmotion ?? todayRecords.first.emotion;
      
      return ChatMessage(
        text: "📊 **Résumé émotionnel de ta journée :**\n\n• Tu as effectué **${todayRecords.length}** analyse(s) aujourd'hui.\n• Ton humeur dominante a été **$dominant**.\n• Ta dernière humeur enregistrée est **$lastMood**.\n\nC'est un excellent réflexe de suivre tes émotions. Sois fier de cette écoute attentive de toi-même ! 🌱",
        isUser: false,
        timestamp: DateTime.now(),
        quickReplies: ["Conseils bien-être 🌿", "Menu principal"],
      );
    }

    if (text.contains("conseil") || text.contains("habitude") || text.contains("bien-être") || text.contains("bien etre")) {
      return ChatMessage(
        text: "Voici 4 habitudes simples et scientifiquement prouvées pour améliorer ton équilibre émotionnel : \n\n1. 📵 **Routine sommeil** : Éteins tes écrans 30 minutes avant de te coucher.\n2. 💧 **Hydratation** : Pense à boire régulièrement de l'eau dans la journée (1,5L idéalement).\n3. 🧘 **Respiration** : Fais 3 grandes inspirations et expirations abdominales quand tu te sens tendu.\n4. 🚶 **Mouvement** : Prends 10 minutes pour marcher ou t'étirer doucement.\n\nQuelle habitude souhaites-tu essayer d'intégrer aujourd'hui ?",
        isUser: false,
        timestamp: DateTime.now(),
        quickReplies: ["Proposer une activité 🧘", "Menu principal"],
      );
    }

    // Réactions générales sur les mots clés positifs
    final List<String> positiveTriggers = ['heureux', 'joie', 'genial', 'génial', 'super', 'bien', 'content', 'cool', 'heureuse', 'merveilleux', 'top'];
    if (positiveTriggers.any((trigger) => text.contains(trigger))) {
      return ChatMessage(
        text: "C'est une merveilleuse nouvelle ! Je suis ravi d'entendre que tu te sens bien. Profite pleinement de cette belle énergie et diffuse-la autour de toi. Y a-t-il quelque chose en particulier qui a ensoleillé ta journée ?",
        isUser: false,
        timestamp: DateTime.now(),
        quickReplies: ["Le travail / les études 💼", "Une bonne nouvelle 🌟", "Rien de particulier ✨"],
      );
    }

    // Réactions générales sur les mots clés négatifs
    final List<String> negativeTriggers = ['triste', 'colere', 'colère', 'enerve', 'énervé', 'marre', 'stress', 'stresse', 'stressé', 'peur', 'angoisse', 'mal', 'difficile', 'dur'];
    if (negativeTriggers.any((trigger) => text.contains(trigger))) {
      return ChatMessage(
        text: "Je suis désolé d'entendre cela. C'est tout à fait normal de traverser des moments plus difficiles ou d'avoir des émotions intenses. N'oublie pas d'être bienveillant envers toi-même. Veux-tu qu'on prenne un moment pour relâcher les tensions physiques et mentales ?",
        isUser: false,
        timestamp: DateTime.now(),
        quickReplies: ["Proposer une activité 🧘", "Conseils bien-être 🌿", "Menu principal"],
      );
    }

    // Réponse par défaut
    return ChatMessage(
      text: "Merci de partager cela avec moi. En tant qu'assistant de bien-être, je suis ravi de t'accompagner. \n\nDis-moi, comment puis-je t'aider à te détendre ou à faire le point maintenant ?",
      isUser: false,
      timestamp: DateTime.now(),
      quickReplies: [
        "Proposer une activité 🧘",
        "Résumé de ma journée 📊",
        "Conseils bien-être 🌿",
        "Menu principal",
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF4A148C)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF9C27B0).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.support_agent_rounded,
                color: Color(0xFF9C27B0),
                size: 24,
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Assistant Bien-être",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A148C),
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.circle, color: Colors.green, size: 8),
                    SizedBox(width: 4),
                    Text(
                      "En ligne • Conseil non médical",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF3E5F5), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Banner Disclaimer de Non-Responsabilité médicale (Toujours visible et rassurante)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Colors.amber.shade800, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Je suis un chatbot bien-être et non un médecin. Pour tout diagnostic ou traitement médical, veuillez consulter un professionnel de santé.",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Liste des messages
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    return _buildMessageBubble(message);
                  },
                ),
              ),

              // Indicateur que le bot écrit
              if (_isTyping)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 5,
                            )
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              "L'assistant réfléchit...",
                              style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Quick replies à afficher au dessus de la barre de saisie
              if (_messages.isNotEmpty && _messages.last.quickReplies != null && !_isTyping)
                _buildQuickRepliesList(_messages.last.quickReplies!),

              // Barre de saisie de message
              _buildInputBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;
    final alignment = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = isUser ? const Color(0xFF8E24AA) : Colors.white;
    final textColor = isUser ? Colors.white : Colors.black87;
    final bubbleRadius = isUser
        ? const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF9C27B0).withOpacity(0.1),
                  child: const Icon(Icons.support_agent_rounded, color: Color(0xFF9C27B0), size: 18),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: bubbleRadius,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isUser ? 0.05 : 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                    border: isUser ? null : Border.all(color: Colors.grey.shade100),
                  ),
                  child: _buildFormattedText(
                    message.text,
                    TextStyle(
                      color: textColor,
                      fontSize: 14.5,
                      height: 1.4,
                      fontWeight: isUser ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.purple.shade100,
                  backgroundImage: DataStore().profileImagePath != null
                      ? FileImage(File(DataStore().profileImagePath!))
                      : null,
                  child: DataStore().profileImagePath == null
                      ? Text(
                          (DataStore().userName ?? 'U').substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: Color(0xFF4A148C), fontWeight: FontWeight.bold, fontSize: 14),
                        )
                      : null,
                ),
              ],
            ],
          ),
          Padding(
            padding: EdgeInsets.only(
              left: isUser ? 0 : 40,
              right: isUser ? 40 : 0,
              top: 4,
            ),
            child: Text(
              "${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}",
              style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormattedText(String text, TextStyle baseStyle) {
    final List<InlineSpan> spans = [];
    final parts = text.split('**');
    for (int i = 0; i < parts.length; i++) {
      if (i % 2 == 1) {
        spans.add(TextSpan(
          text: parts[i],
          style: baseStyle.copyWith(fontWeight: FontWeight.bold),
        ));
      } else {
        spans.add(TextSpan(
          text: parts[i],
          style: baseStyle,
        ));
      }
    }
    return RichText(
      text: TextSpan(children: spans),
    );
  }

  Widget _buildQuickRepliesList(List<String> replies) {
    return Container(
      height: 48,
      margin: const EdgeInsets.only(top: 5),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: replies.length,
        itemBuilder: (context, index) {
          final replyText = replies[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ActionChip(
              label: Text(
                replyText,
                style: const TextStyle(
                  color: Color(0xFF6A1B9A),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFE1BEE7), width: 1.5),
              elevation: 2,
              shadowColor: Colors.purple.withOpacity(0.1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              onPressed: () => _handleSubmitted(replyText),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 15),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(fontSize: 15, color: Colors.black87),
                      decoration: const InputDecoration(
                        hintText: "Écrire un message...",
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                      ),
                      onSubmitted: _handleSubmitted,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.clear_rounded, color: Colors.grey),
                    onPressed: () => _textController.clear(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _handleSubmitted(_textController.text),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF8E24AA), Color(0xFF6A1B9A)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
