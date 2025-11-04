import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lagfrontend/controllers/auth_controller.dart';
import 'package:lagfrontend/widgets/app_background.dart';
import 'package:lagfrontend/widgets/popup_form.dart';
import 'package:lagfrontend/widgets/reusable_input.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameOrEmailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameOrEmailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;
    final authController = Provider.of<AuthController>(context, listen: false);
    await authController.login(_usernameOrEmailController.text.trim(), _passwordController.text);
    if (!mounted) return;
    if (authController.isAuthenticated) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
    // if not authenticated, the error message from AuthController will show under the button
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: Center(
          child: PopupForm(
            icon: const Icon(Icons.login, color: Colors.white, size: 18),
            title: 'INICIO',
            actions: [
              // Keep the actions list simple and consistent with WelcomeScreen: two
              // PopupActionButton widgets. The first button adapts when loading.
              Consumer<AuthController>(builder: (context, authController, _) {
                if (authController.isLoading) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                }
                return PopupActionButton(label: 'Entrar', onPressed: _submitLogin);
              }),
              PopupActionButton(label: 'Volver', onPressed: () => Navigator.of(context).maybePop()),
            ],
            // child: the form itself (placed last to satisfy analyzer rule)
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Use the reusable input to keep consistent sizing
                  ReusableTextField(
                    controller: _usernameOrEmailController,
                    label: 'Usuario o email',
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return '';
                      final v = value.trim().toLowerCase();
                      if (!v.contains('@') && v == 'system') return '';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  ReusableTextField(
                    controller: _passwordController,
                    label: 'Contraseña',
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) return '';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  // Show inline error text under the form fields (above actions)
                  Consumer<AuthController>(builder: (context, authController, _) {
                    if (authController.errorMessage == null || authController.errorMessage!.isEmpty) return const SizedBox.shrink();
                    return Text(
                      authController.errorMessage!,
                      style: const TextStyle(color: Colors.redAccent),
                      textAlign: TextAlign.center,
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}