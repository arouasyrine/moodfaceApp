# MoodFace AI 🧠📸 - Application Mobile d'Analyse Émotionnelle Intelligente

Bienvenue dans le projet **MoodFace AI**. Cette application mobile innante combine la puissance de la **vision par ordinateur (IA)** et du développement mobile multiplateforme pour analyser les expressions faciales en temps réel, suivre l'évolution de l'état émotionnel des utilisateurs, et leur proposer un journal intime connecté et intelligent.

---

## 📌 Architecture Globale du Système

Le projet est conçu selon une architecture découplée (client-serveur) pour garantir la performance, la sécurité et la modularité :

```mermaid
graph TD
    A[Application Flutter - Client Mobile] -->|Requêtes HTTP / API REST| B(FastAPI Gateway - Backend)
    B -->|Authentification & Historique| C{Base de Données SQLite}
    B -->|Pipeline Vision par Ordinateur| D(Pipeline Analyse IA)
    D -->|Détection Initiale Rapide| E[MediaPipe Face Detection]
    D -->|Détection de Repli Ultra-Robuste| F[RetinaFace]
    D -->|Classification Émotionnelle| G[Modèles DeepFace]
    G -->|Résultats (Émotion Dominante + Confiance)| B
```

---

## 🛠️ Stack Technique

### 📱 Frontend (Client Mobile)
*   **Framework** : [Flutter](https://flutter.dev/) (Dart) pour une interface native, fluide et multiplateforme (iOS/Android/Windows).
*   **Gestion d'État & Persistance** : Shared Preferences et DataStore local pour une fluidité optimale.
*   **Rapports & Audio** : Génération de rapports PDF et synthèse vocale de l'analyse.

### ⚙️ Backend (Serveur API & IA)
*   **Framework Web** : [FastAPI](https://fastapi.tiangolo.com/) (Python) pour sa rapidité d'exécution asynchrone et sa documentation automatique interactive.
*   **Vision par Ordinateur** : 
    *   **MediaPipe** (Google) pour une détection ultra-rapide des visages.
    *   **DeepFace** & **RetinaFace** pour la classification fine parmi 7 émotions : *Joie, Triste, Neutre, Colère, Surprise, Peur, Dégoût*.
*   **Base de Données** : **SQLite** avec l'ORM **SQLAlchemy** pour un stockage léger, fiable et sans configuration lourde.
*   **Messagerie SMTP** : Envoi de courriels réels ou simulés de réinitialisation de mot de passe.

---

## 📂 Structure du Code Source

```text
MoodfaceAPP/
├── moodface-frontend/      # Projet Flutter (Code Source de l'application)
│   ├── lib/
│   │   ├── main.dart       # Point d'entrée de l'application mobile
│   │   ├── mood_service.dart# Appels API REST et gestion de la connexion Ngrok
│   │   ├── screens/        # Écrans (Caméra, Historique, Profil, Statistiques...)
│   │   └── widgets/        # Composants réutilisables (Journal intime...)
│   └── pubspec.yaml        # Dépendances Flutter (http, camera, charts...)
│
├── moodface-backend/       # Projet Python FastAPI (Serveur IA & Database)
│   ├── main.py             # Point d'entrée, configuration CORS, routes de l'API
│   ├── analyzer.py         # Pipeline de détection et de classification d'émotions
│   ├── database.py         # Configuration SQLAlchemy et session de base de données
│   ├── models.py           # Schémas de tables SQL (Utilisateurs et Enregistrements)
│   ├── schemas.py          # Modèles de validation de données (Pydantic)
│   ├── crud.py             # Requêtes de base de données et hachage PBKDF2-SHA256
│   ├── migrate_db.py       # Script d'application des migrations de la base
│   ├── clear_db.py         # Script de réinitialisation de la base (mode démo)
│   └── requirements.txt    # Dépendances Python (fastapi, deepface, mediapipe...)
```

---

## 🚀 Guide de Démarrage Rapide (Pour la Soutenance)

Pour présenter l'application en direct devant les encadrants ou le jury, suivez ces étapes :

### 1. Démarrer le Backend Python
Ouvrez un terminal dans le dossier `moodface-backend` :
```bash
# Activer l'environnement virtuel Python
.\venv\Scripts\activate

# Lancer le serveur avec Uvicorn
python main.py
```
*Le serveur démarrera automatiquement sur **`http://localhost:8001`**.*

### 2. Démarrer le Tunnel Ngrok (Pour tester sur Téléphone Réel)
Ngrok permet d'exposer votre serveur local de manière sécurisée sur Internet afin que l'application mobile installée sur votre téléphone puisse communiquer avec le backend.

Si Ngrok est déjà configuré, lancez-le sur le port `8001` :
```bash
ngrok http 8001 --domain=discard-salon-jumbo.ngrok-free.dev
```
*Note : L'application Flutter est préconfigurée pour communiquer directement avec ce domaine Ngrok statique.*

### 3. Exécuter l'Application Flutter
Ouvrez un terminal dans le dossier `moodface-frontend` :
```bash
# Mettre à jour les dépendances Flutter
flutter pub get

# Lancer l'application sur un appareil connecté, émulateur ou navigateur web
flutter run
```

---

## 💎 Fonctionnalités Avancées Implémentées

1.  **Pipeline d'Analyse Hybride** : Le backend utilise d'abord **MediaPipe** pour sa rapidité. Si aucun visage n'est détecté (ex. mauvaise luminosité ou visage incliné), il bascule sur **RetinaFace** pour garantir l'analyse.
2.  **Bypass Automatique Ngrok** : Le code de communication HTTP (`mood_service.dart`) intègre automatiquement les en-têtes nécessaires pour contourner la page d'avertissement gratuite de Ngrok.
3.  **Journal Émotionnel** : L'utilisateur peut ajouter des notes personnelles, des étiquettes (tags) et déclarer son humeur ressentie après chaque prise de vue pour comparer sa perception à celle de l'IA.
4.  **Authentification Google Simulée & Réelle** : Configuration flexible du portail d'authentification sociale.
5.  **Génération de Synthèse** : Analyse statistique de l'humeur hebdomadaire de l'utilisateur avec génération de conseils personnalisés.
