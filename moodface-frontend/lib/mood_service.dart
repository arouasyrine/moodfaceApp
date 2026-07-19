import 'package:http/http.dart' as http;
import 'dart:convert'; /*importation de la bibliothèque dart:convert pour la conversion JSON*/
import 'dart:io'; /*importation de la bibliothèque dart:io pour la gestion des fichiers et des entrées/sorties*/
import 'package:url_launcher/url_launcher.dart';
import 'data_store.dart';

class MoodService {
  // Remplacez par votre domaine Ngrok statique gratuit (ex: https://mon-app.ngrok-free.app)
  static const String baseUrl = "https://discard-salon-jumbo.ngrok-free.dev";

  Uri getSocialAuthUrl(String provider) {
    final normalizedProvider = provider.toLowerCase();
    final path = switch (normalizedProvider) {
      'google' => 'google',
      'facebook' => 'facebook',
      'github' => 'github',
      _ => normalizedProvider,
    };

    return Uri.parse('$baseUrl/auth/$path');
  }

  Future<bool> launchSocialAuth(String provider, {String? email}) async {
    var url = getSocialAuthUrl(provider);
    if (email != null && email.isNotEmpty) {
      url = url.replace(queryParameters: {'email': email});
    }

    try {
      final bool launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return true;
    } catch (e) {
      print('Tentative directe d’ouverture de $provider échouée: $e');
    }

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
        return true;
      }
    } catch (e) {
      print('Erreur fallback canLaunchUrl pour $provider: $e');
    }

    return false;
  }

  Future<Map<String, dynamic>?> sendImageToBackend(
    File imageFile, {
    int? userId,
    String? modelType,
  }) async {
    try {
      final targetModelType = modelType ?? DataStore().selectedModelType;
      final url = userId != null
          ? "$baseUrl/predict?user_id=$userId&model_type=$targetModelType"
          : "$baseUrl/predict?model_type=$targetModelType";
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(
          url,
        ), //l'URL de l'API pour la prédiction des émotions (avec ID utilisateur s'il est connecté)
      );

      // Contourner la page d'avertissement de Ngrok pour éviter les erreurs de format JSON
      request.headers['ngrok-skip-browser-warning'] = 'true';

      // Ajouter le fichier image
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
        ), //le nom du champ 'file' doit correspondre à celui attendu par le backend
      );

      // Envoyer la requête
      var streamedResponse = await request
          .send(); //envoie la requête et attend la réponse du serveur
      var response = await http.Response.fromStream(
        streamedResponse,
      ); //convertit la réponse en un objet Response pour pouvoir accéder au corps de la réponse

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("Erreur Serveur: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Erreur Connexion: $e");
      return null;
    }
  }

  // Récupérer l'historique de l'utilisateur depuis la base de données
  Future<List<dynamic>?> getUserHistory(int userId) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/history/$userId"),
        headers: {"ngrok-skip-browser-warning": "true"},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("Erreur Historique API: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Erreur Connexion Historique: $e");
      return null;
    }
  }

  Future<bool> checkEmail(String email) async {
    try {
      final response = await http.get(
        Uri.parse(
          "$baseUrl/auth/check-email?email=${Uri.encodeComponent(email)}",
        ),
        headers: {"ngrok-skip-browser-warning": "true"},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['exists'] == true;
      }
    } catch (e) {
      print("Erreur checkEmail: $e");
    }
    return false;
  }

  Future<Map<String, dynamic>?> checkGoogleAccount(String email) async {
    try {
      final response = await http.get(
        Uri.parse(
          "$baseUrl/auth/check-google-account?email=${Uri.encodeComponent(email)}",
        ),
        headers: {"ngrok-skip-browser-warning": "true"},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      print("Erreur checkGoogleAccount status: ${response.statusCode}");
    } catch (e) {
      print("Erreur checkGoogleAccount: $e");
    }
    return null;
  }

  Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/login"),
        headers: {
          "Content-Type": "application/json",
          "ngrok-skip-browser-warning": "true",
        },
        body: jsonEncode({
          "name": "", // name est requis par schemas.UserCreate sur le backend
          "email": email,
          "password": password,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        try {
          final errorBody = jsonDecode(response.body);
          return {
            "status": "error",
            "message":
                errorBody['detail'] ?? "Email ou mot de passe incorrect.",
          };
        } catch (_) {
          return {
            "status": "error",
            "message": "Erreur serveur (${response.statusCode})",
          };
        }
      }
    } catch (e) {
      print("Erreur Connexion: $e");
      return {
        "status": "error",
        "message":
            "Impossible de contacter le serveur. Vérifiez votre connexion internet.",
      };
    }
  }

  Future<Map<String, dynamic>?> register(
    String name,
    String email,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/register"),
        headers: {
          "Content-Type": "application/json",
          "ngrok-skip-browser-warning": "true",
        },
        body: jsonEncode({"name": name, "email": email, "password": password}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        try {
          final errorBody = jsonDecode(response.body);
          return {
            "status": "error",
            "message": errorBody['detail'] ?? "Erreur de serveur.",
          };
        } catch (_) {
          return {
            "status": "error",
            "message": "Erreur serveur (${response.statusCode})",
          };
        }
      }
    } catch (e) {
      print("Erreur Connexion: $e");
      return {
        "status": "error",
        "message":
            "Impossible de contacter le serveur. Vérifiez votre connexion internet.",
      };
    }
  }

  Future<Map<String, dynamic>?> updateUser(
    int userId,
    String name,
    String email,
  ) async {
    try {
      final response = await http.put(
        Uri.parse("$baseUrl/users/$userId"),
        headers: {
          "Content-Type": "application/json",
          "ngrok-skip-browser-warning": "true",
        },
        body: jsonEncode({"name": name, "email": email}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("Erreur Connexion API Update User: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Erreur Connexion: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> changePassword(
    int userId,
    String oldPassword,
    String newPassword,
  ) async {
    try {
      final response = await http.put(
        Uri.parse("$baseUrl/users/$userId/change-password"),
        headers: {
          "Content-Type": "application/json",
          "ngrok-skip-browser-warning": "true",
        },
        body: jsonEncode({
          "old_password": oldPassword,
          "new_password": newPassword,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("Erreur Connexion API Change Password: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Erreur Connexion: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> forgotPassword(String email) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/forgot-password"),
        headers: {
          "Content-Type": "application/json",
          "ngrok-skip-browser-warning": "true",
        },
        body: jsonEncode({"email": email}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        try {
          final errorBody = jsonDecode(response.body);
          return {
            "status": "error",
            "message": errorBody['detail'] ?? "Erreur de serveur.",
          };
        } catch (_) {
          return {
            "status": "error",
            "message": "Erreur serveur (${response.statusCode})",
          };
        }
      }
    } catch (e) {
      print("Erreur Connexion Forgot Password: $e");
      return null;
    }
  }

  // Mettre à jour la note, les tags et l'émotion déclarée pour une analyse
  Future<bool> updateJournalRecord(int recordId, String note, List<String> tags, String userDeclaredEmotion) async {
    try {
      final response = await http.put(
        Uri.parse("$baseUrl/history/$recordId/journal"),
        headers: {
          "Content-Type": "application/json",
          "ngrok-skip-browser-warning": "true",
        },
        body: jsonEncode({
          "note": note,
          "tags": tags.join(","),
          "user_declared_emotion": userDeclaredEmotion,
        }),
      );
      if (response.statusCode == 200) {
        return true;
      }
      print("Erreur mise à jour journal: ${response.statusCode}");
    } catch (e) {
      print("Erreur Connexion Mise à jour journal: $e");
    }
    return false;
  }

  // Récupérer le résumé hebdomadaire généré par l'IA
  Future<Map<String, dynamic>?> getWeeklySummary(int userId) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/history/$userId/weekly-summary"),
        headers: {"ngrok-skip-browser-warning": "true"},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      print("Erreur API Weekly Summary: ${response.statusCode}");
    } catch (e) {
      print("Erreur Connexion Weekly Summary: $e");
    }
    return null;
  }

  // Supprimer un enregistrement d'historique
  Future<bool> deleteHistoryRecord(int recordId) async {
    try {
      final response = await http.delete(
        Uri.parse("$baseUrl/history/$recordId"),
        headers: {"ngrok-skip-browser-warning": "true"},
      );
      if (response.statusCode == 200) {
        return true;
      }
      print("Erreur suppression historique: ${response.statusCode}");
    } catch (e) {
      print("Erreur Connexion Suppression historique: $e");
    }
    return false;
  }
}

