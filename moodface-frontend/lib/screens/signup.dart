import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'home.dart';
import '../data_store.dart';
import '../mood_service.dart';
import 'package:url_launcher/url_launcher.dart';

class SignupScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const SignupScreen({super.key, required this.cameras});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final MoodService _moodService = MoodService();

  void _handleSignup() async {
    if (_formKey.currentState!.validate()) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final result = await _moodService.register(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;
      Navigator.pop(context); // Fermer le loader

      if (result != null && result['status'] != 'error') {
        // Réinitialiser les données pour le nouveau compte
        DataStore().clear();
        DataStore().userId = result['id'];
        DataStore().userName = result['name'];
        DataStore().userEmail = result['email'];

        // Charger la photo de profil locale (sera vide pour un nouveau compte)
        await DataStore().loadProfileImage();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Compte créé avec succès ! Bienvenue."),
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
        final errorMsg = result != null && result['message'] != null
            ? result['message']
            : "Échec de l'inscription. Cet email est peut-être déjà utilisé.";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

  Future<bool> _confirmGoogleAccountExists() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !_isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Veuillez entrer un email Google valide avant de continuer.",
          ),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

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

  void _handleSocialSignup(String provider) async {
    if (provider == "Google") {
      if (!await _confirmGoogleAccountExists()) {
        return;
      }
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final launched = await _moodService.launchSocialAuth(provider);

    if (!mounted) return;
    Navigator.pop(context); // Close loading

    if (launched) {
      if (mounted) {
        Navigator.pop(
          context,
        ); // Retourner à l'écran de connexion pour gérer le deep link
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Impossible d'ouvrir la connexion $provider."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF4A148C),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF3E5F5), Colors.white, Color(0xFFEDE7F6)],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  _buildHeader(),
                  const SizedBox(height: 30),
                  _buildSignupForm(),
                  const SizedBox(height: 25),
                  const Text(
                    "Ou s'inscrire avec",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  _buildSocialSignupSection(),
                  const SizedBox(height: 25),
                  _buildLoginLink(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF9C27B0), Color(0xFFE91E63)],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.2),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.person_add_rounded,
            size: 40,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          "Créer un compte",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Color(0xFF4A148C),
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSignupForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _buildTextField(
            controller: _nameController,
            hint: "Nom complet",
            icon: Icons.person_outline_rounded,
            validator: (value) =>
                value == null || value.isEmpty ? "Entrez votre nom" : null,
          ),
          const SizedBox(height: 15),
          _buildTextField(
            controller: _emailController,
            hint: "Email",
            icon: Icons.email_outlined,
            validator: (value) {
              if (value == null || value.isEmpty)
                return 'Veuillez entrer votre email';
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value))
                return 'Email invalide';
              return null;
            },
          ),
          const SizedBox(height: 15),
          _buildTextField(
            controller: _passwordController,
            hint: "Mot de passe",
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            showPassword: _isPasswordVisible,
            onToggleVisibility: () =>
                setState(() => _isPasswordVisible = !_isPasswordVisible),
            validator: (value) => value != null && value.length < 6
                ? "Minimum 6 caractères"
                : null,
          ),
          const SizedBox(height: 15),
          _buildTextField(
            controller: _confirmPasswordController,
            hint: "Confirmer le mot de passe",
            icon: Icons.lock_reset_rounded,
            isPassword: true,
            showPassword: _isConfirmPasswordVisible,
            onToggleVisibility: () => setState(
              () => _isConfirmPasswordVisible = !_isConfirmPasswordVisible,
            ),
            validator: (value) {
              if (value != _passwordController.text)
                return "Les mots de passe ne correspondent pas";
              return null;
            },
          ),
          const SizedBox(height: 30),
          _buildSignupButton(),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool showPassword = false,
    VoidCallback? onToggleVisibility,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(18),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword && !showPassword,
        style: const TextStyle(fontSize: 15, color: Colors.black),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.purple.shade300, size: 22),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    showPassword
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    color: Colors.purple.shade300,
                    size: 20,
                  ),
                  onPressed: onToggleVisibility,
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

  Widget _buildSignupButton() {
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
        onPressed: _handleSignup,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: const Text(
          "S'inscrire",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildSocialSignupSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSocialIcon(
          "images/google.webp",
          () => _handleSocialSignup("Google"),
        ),
        const SizedBox(width: 25),
        _buildSocialIcon(
          "images/facebook.webp",
          () => _handleSocialSignup("Facebook"),
        ),
        const SizedBox(width: 25),
        _buildSocialIcon(
          "images/github.webp",
          () => _handleSocialSignup("GitHub"),
        ),
      ],
    );
  }

  Widget _buildSocialIcon(String assetPath, VoidCallback onTap) {
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
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.error_outline),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Déjà un compte ?",
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            "Se connecter",
            style: TextStyle(
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
