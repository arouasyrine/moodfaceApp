import 'package:flutter/material.dart';
import 'home.dart';
import 'signup.dart';
import 'forgot_password.dart';
import 'package:camera/camera.dart';
import '../mood_service.dart';
import '../data_store.dart';
import '../translations.dart';
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const LoginScreen({super.key, required this.cameras});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static bool _initialLinkProcessed = false;
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false; /*mot de passe caché par défaut*/
  final TextEditingController _emailController =
      TextEditingController(); /*controleur pour le champ email*/
  final TextEditingController _passwordController = TextEditingController();
  /*controleur pour le champ mot de passe*/
  final MoodService _moodService = MoodService();

  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinking();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _initDeepLinking() {
    _appLinks = AppLinks();

    // Écouter les liens arrivant pendant que l'app tourne
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        _handleIncomingLink(uri);
      },
      onError: (err) {
        print("Erreur de deep link: $err");
      },
    );

    // Traiter le lien de démarrage initial s'il y en a un seulement une fois par cycle de vie de l'app
    if (!_initialLinkProcessed) {
      _initialLinkProcessed = true;
      _appLinks.getInitialLink().then((uri) {
        if (uri != null) {
          _handleIncomingLink(uri);
        }
      });
    }
  }

  void _handleIncomingLink(Uri uri) async {
    // Le lien ressemble à moodface://auth?status=success&id=X&name=Y&email=Z
    if (uri.scheme == 'moodface' && uri.host == 'auth') {
      final status = uri.queryParameters['status'];
      if (status == 'success') {
        final idStr = uri.queryParameters['id'];
        final name = uri.queryParameters['name'] ?? 'Utilisateur';
        final email = uri.queryParameters['email'] ?? '';
        final id = int.tryParse(idStr ?? '') ?? 999;

        // Connecter l'utilisateur
        DataStore().clear();
        DataStore().userId = id;
        DataStore().userName = name;
        DataStore().userEmail = email;

        await DataStore().loadProfileImage();

        // Charger l'historique
        final history = await _moodService.getUserHistory(id);
        if (history != null) {
          DataStore().loadFromBackend(history);
        }

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Bienvenue $name ! Connexion réussie."),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(cameras: widget.cameras),
          ),
        );
      } else {
        final message =
            uri.queryParameters['message'] ?? "Erreur d'authentification.";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Échec de la connexion : $message"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final result = await _moodService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;
      Navigator.pop(context); // Fermer le loader

      if (result != null && result['status'] == 'success') {
        final userData = result['user'];
        DataStore().userId = userData['id'];
        DataStore().userName = userData['name'];
        DataStore().userEmail = userData['email'];

        // Charger la photo de profil locale
        await DataStore().loadProfileImage();

        // Charger l'historique depuis la base de données
        final history = await _moodService.getUserHistory(userData['id']);
        if (history != null) {
          DataStore().loadFromBackend(history);
        }

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(cameras: widget.cameras),
          ),
        );
      } else {
        final errorMsg = result != null && result['message'] != null
            ? result['message']
            : "Mot de passe incorrect.";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      /*empêche le clavier de pousser le contenu vers le haut*/
      body: Stack(
        /*Stack permet de superposer des widgets les uns sur les autres, ici pour le fond et le contenu de la page*/
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF3E5F5), // Very light purple
                  Colors.white,
                  Color(0xFFEDE7F6), // Very light indigo
                ],
              ),
            ),
          ),
          // Subtle background circles
          Positioned(
            /*Positioned permet de placer un widget à une position spécifique dans le Stack*/
            top: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            /*SafeArea pour éviter que le contenu ne soit caché par les bords de l'écran*/
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  _buildLogo(),
                  const SizedBox(height: 30),
                  _buildWelcomeText(),
                  const Spacer(flex: 2),
                  _buildLoginForm(),
                  const Spacer(flex: 1),
                  Text(
                    Translations.t('or_login_with'),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  _buildSocialLogin(),
                  const SizedBox(height: 25),
                  _buildLink(),
                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF9C27B0), Color(0xFFE91E63)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          /*ajout d'une ombre portée pour donner un effet de profondeur au logo*/
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 20,
            /*ombre portée pour donner un effet de profondeur*/
            offset: const Offset(0, 10) /*décalage de l'ombre vers le bas*/,
          ),
        ],
      ),
      child: const Icon(
        Icons.face_retouching_natural_rounded,
        size: 55,
        color: Colors.white,
      ),
    );
  }

  Widget _buildWelcomeText() {
    return Column(
      children: [
        Text(
          Translations.t('welcome_title'),
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Color(0xFF4A148C),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          Translations.t('welcome_subtitle'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.purple.shade900.withOpacity(0.6),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _buildTextField(
            controller: _emailController,
            hint: Translations.t('email'),
            icon: Icons.email_outlined,
            backgroundColor: Colors.black.withOpacity(0.02),
            validator: (value) {
              if (value == null || value.isEmpty)
                return 'Veuillez entrer votre email';
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value))
                return 'Email invalide';
              return null;
            },
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _passwordController,
            hint: Translations.t('password'),
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            backgroundColor: Colors.black.withOpacity(0.02),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Mot de passe requis';
              if (value.length < 6) return 'Minimum 6 caractères';
              return null;
            },
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ForgotPasswordScreen(),
                  ),
                );
              },
              child: Text(
                Translations.t('forgot_password'),
                style: TextStyle(
                  color: Colors.purple.shade800,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildActionButton(
            title: Translations.t('login_btn'),
            onPressed: _handleLogin,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String title,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9C27B0).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          /*fond transparent pour laisser passer le gradient du conteneur parent*/
          shadowColor: Colors.transparent,
          /*supprime l'ombre par défaut du bouton pour ne garder que celle du conteneur parent*/
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    Color? backgroundColor,
    String? Function(String?)?
    validator /*fonction de validation pour le champ, retourne un message d'erreur si la validation échoue ou null si elle réussit*/,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword && !_isPasswordVisible,
        style: const TextStyle(color: Colors.black, fontSize: 15),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.purple.shade300, size: 22),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    color: const Color.fromARGB(255, 202, 60, 190),
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _isPasswordVisible = !_isPasswordVisible),
                )
              : null,
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black, fontSize: 15),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
        validator: validator,
      ),
    );
  }

  bool _validateSocialLoginCredentials(String provider) {
    final email = _emailController.text.trim();

    // Si l'e-mail est vide, on l'autorise pour que l'utilisateur le saisisse sur la page de connexion
    if (email.isEmpty) return true;

    if (!_isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Veuillez entrer un email $provider valide.",
          ),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    return true;
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

  Future<bool> _confirmGoogleAccountExists() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !_isValidEmail(email)) return false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final response = await _moodService.checkGoogleAccount(email);

    if (!mounted) return false;
    Navigator.pop(context);

    if (response == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Impossible de vérifier le compte Google. Réessayez."),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    if (response['exists_in_google'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response['message'] ?? "Ce compte Google n'existe pas.",
          ),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    final existsInDb = response['exists_in_db'] == true;
    final accountName = response['name'] ?? 'Utilisateur Google';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          existsInDb
              ? "Compte Google trouvé pour $accountName. Vous pouvez continuer."
              : "Adresse Google vérifiée. Un nouveau compte pourra être créé.",
        ),
        backgroundColor: Colors.green,
      ),
    );

    return true;
  }

  void _handleSocialLogin(String provider) async {
    if (!mounted) return;

    if (!_validateSocialLoginCredentials(provider)) {
      return;
    }

    final email = _emailController.text.trim();
    if (provider.toLowerCase() == 'google' && email.isNotEmpty) {
      if (!await _confirmGoogleAccountExists()) {
        return;
      }
    }

    final launched = await _moodService.launchSocialAuth(
      provider,
      email: email.isNotEmpty ? email : null,
    );

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Impossible d'ouvrir la connexion $provider."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSocialLogin() {
    return Column(
      children: [
        _buildSocialButton(
          title: "Se connecter avec Google",
          assetPath: "images/google.webp",
          onPressed: () => _handleSocialLogin("Google"),
          colors: [Colors.white, Colors.white],
          textColor: const Color(0xFF3C4043),
          border: Border.all(color: Colors.grey.shade300, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSocialButton(
          title: "Se connecter avec Facebook",
          assetPath: "images/facebook.webp",
          onPressed: () => _handleSocialLogin("Facebook"),
          colors: [const Color(0xFF1877F2), const Color(0xFF166FE5)],
          textColor: Colors.white,
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required String title,
    required String assetPath,
    required VoidCallback onPressed,
    required List<Color> colors,
    required Color textColor,
    Border? border,
    List<BoxShadow>? boxShadow,
  }) {
    return Container(
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: colors,
        ),
        border: border,
        boxShadow: boxShadow ?? [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              assetPath,
              height: 24,
              width: 24,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.error_outline,
                color: Colors.grey,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          Translations.t('no_account'),
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SignupScreen(cameras: widget.cameras),
              ),
            );
          },
          child: Text(
            Translations.t('register'),
            style: const TextStyle(
              color: Color(0xFF9C27B0),
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
