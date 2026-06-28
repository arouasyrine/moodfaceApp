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
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;/*mot de passe caché par défaut*/
  final TextEditingController _emailController = TextEditingController();/*controleur pour le champ email*/
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
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleIncomingLink(uri);
    }, onError: (err) {
      print("Erreur de deep link: $err");
    });
    
    // Traiter le lien de démarrage initial s'il y en a un
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        _handleIncomingLink(uri);
      }
    });
  }

  void _handleIncomingLink(Uri uri) async {
    // Le lien ressemble à moodface://auth?status=success&id=X&name=Y&email=Z
    if (uri.scheme == 'moodface' && uri.host == 'auth') {
      final status = uri.queryParameters['status'];
      if (status == 'success') {
        final idStr = uri.queryParameters['id'];
        final name = uri.queryParameters['name'] ?? 'GitHub User';
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
          MaterialPageRoute(builder: (_) => HomeScreen(cameras: widget.cameras)),
        );
      } else {
        final message = uri.queryParameters['message'] ?? "Erreur d'authentification.";
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
          MaterialPageRoute(builder: (_) => HomeScreen(cameras: widget.cameras)),
        );
      } else {
        final errorMsg = result != null && result['message'] != null
            ? result['message']
            : "Email ou mot de passe incorrect. Compte inexistant.";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,/*empêche le clavier de pousser le contenu vers le haut*/
      body: Stack(/*Stack permet de superposer des widgets les uns sur les autres, ici pour le fond et le contenu de la page*/
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
          Positioned(/*Positioned permet de placer un widget à une position spécifique dans le Stack*/
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
          SafeArea(/*SafeArea pour éviter que le contenu ne soit caché par les bords de l'écran*/
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
        boxShadow: [/*ajout d'une ombre portée pour donner un effet de profondeur au logo*/
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 20,/*ombre portée pour donner un effet de profondeur*/
            offset: const Offset(0, 10),/*décalage de l'ombre vers le bas*/
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
              if (value == null || value.isEmpty) return 'Veuillez entrer votre email';
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) return 'Email invalide';
              return null;
            },
          ),
          const SizedBox(height: 15),
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
                  MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
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
          _buildLoginButton(),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    Color? backgroundColor,
    String? Function(String?)? validator,/*fonction de validation pour le champ, retourne un message d'erreur si la validation échoue ou null si elle réussit*/
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
        style: const TextStyle( color: Colors.black, fontSize: 15),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.purple.shade300, size: 22),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _isPasswordVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                    color: const Color.fromARGB(255, 202, 60, 190),
                    size: 20,
                  ),
                  onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                )
              : null,
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black, fontSize: 15),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildLoginButton() {
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
        onPressed: _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,/*fond transparent pour laisser passer le gradient du conteneur parent*/
          shadowColor: Colors.transparent,/*supprime l'ombre par défaut du bouton pour ne garder que celle du conteneur parent*/
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: Text(
          Translations.t('login_btn'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  void _handleSocialLogin(String provider) async {
    if (provider == "GitHub") {
      final url = Uri.parse("${MoodService.baseUrl}/auth/github");
      try {
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Impossible d'ouvrir le navigateur web.")),
            );
          }
        }
      } catch (e) {
        print("Erreur lors de l'ouverture du lien : $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erreur : $e")),
          );
        }
      }
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;/*vérifie que le widget est toujours dans l'arbre avant de faire une navigation*/
      Navigator.pop(context); // Close loading
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Connexion via $provider réussie !"),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(cameras: widget.cameras)),
      );
    });
  }

  Widget _buildSocialLogin() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSocialIcon("images/google.webp", () => _handleSocialLogin("Google")),
        const SizedBox(width: 25),
        _buildSocialIcon("images/facebook.webp", () => _handleSocialLogin("Facebook")),
        const SizedBox(width: 25),
        _buildSocialIcon("images/github.webp", () => _handleSocialLogin("GitHub")),
      ],
    );
  }

  Widget _buildSocialIcon(String assetPath, VoidCallback onTap/*fonction à appeler lors du tap sur l'icône*/) {
    return Container(
      width: 55,
      height: 55,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: Colors.grey.shade50),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Center(
            child: Image.asset(
              assetPath,
              height: 28,
              width: 28,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.error_outline),/*affiche une icône d'erreur si l'image ne peut pas être chargée*/
            ),
          ),
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
              MaterialPageRoute(builder: (_) => SignupScreen(cameras: widget.cameras)),
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

