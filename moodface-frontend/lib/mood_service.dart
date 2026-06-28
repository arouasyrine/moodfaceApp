import 'package:http/http.dart' as http;
import 'dart:convert';/*importation de la bibliothèque dart:convert pour la conversion JSON*/
import 'dart:io';/*importation de la bibliothèque dart:io pour la gestion des fichiers et des entrées/sorties*/

class MoodService {
  static const String baseUrl = "http://10.168.227.97:8001";

  Future<Map<String, dynamic>?> sendImageToBackend(File imageFile, {int? userId}) async {
    try {
      final url = userId != null ? "$baseUrl/predict?user_id=$userId" : "$baseUrl/predict";
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(url),//l'URL de l'API pour la prédiction des émotions (avec ID utilisateur s'il est connecté)
      );

      // Ajouter le fichier image
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),//le nom du champ 'file' doit correspondre à celui attendu par le backend
      );

      // Envoyer la requête
      var streamedResponse = await request.send();//envoie la requête et attend la réponse du serveur
      var response = await http.Response.fromStream(streamedResponse);//convertit la réponse en un objet Response pour pouvoir accéder au corps de la réponse

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

  Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/login"),
        headers: {"Content-Type": "application/json"},
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
          return {"status": "error", "message": errorBody['detail'] ?? "Email ou mot de passe incorrect."};
        } catch (_) {
          return {"status": "error", "message": "Erreur serveur (${response.statusCode})"};
        }
      }
    } catch (e) {
      print("Erreur Connexion: $e");
      return {"status": "error", "message": "Impossible de contacter le serveur. Vérifiez votre connexion internet."};
    }
  }

  Future<Map<String, dynamic>?> register(String name, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/register"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "name": name,
          "email": email,
          "password": password,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        try {
          final errorBody = jsonDecode(response.body);
          return {"status": "error", "message": errorBody['detail'] ?? "Erreur de serveur."};
        } catch (_) {
          return {"status": "error", "message": "Erreur serveur (${response.statusCode})"};
        }
      }
    } catch (e) {
      print("Erreur Connexion: $e");
      return {"status": "error", "message": "Impossible de contacter le serveur. Vérifiez votre connexion internet."};
    }
  }

  Future<Map<String, dynamic>?> updateUser(int userId, String name, String email) async {
    try {
      final response = await http.put(
        Uri.parse("$baseUrl/users/$userId"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "name": name,
          "email": email,
        }),
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

  Future<Map<String, dynamic>?> changePassword(int userId, String oldPassword, String newPassword) async {
    try {
      final response = await http.put(
        Uri.parse("$baseUrl/users/$userId/change-password"),
        headers: {"Content-Type": "application/json"},
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
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        try {
          final errorBody = jsonDecode(response.body);
          return {"status": "error", "message": errorBody['detail'] ?? "Erreur de serveur."};
        } catch (_) {
          return {"status": "error", "message": "Erreur serveur (${response.statusCode})"};
        }
      }
    } catch (e) {
      print("Erreur Connexion Forgot Password: $e");
      return null;
    }
  }
}
