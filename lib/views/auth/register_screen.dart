import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lagfrontend/controllers/auth_controller.dart';
import 'package:lagfrontend/widgets/app_background.dart';
import 'package:lagfrontend/widgets/popup_form.dart';
import 'package:lagfrontend/widgets/reusable_input.dart';
import 'package:lagfrontend/views/auth/auth_gate.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Limpiar errores previos al entrar a la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthController>(context, listen: false).clearError();
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitRegister() async {
    if (!_formKey.currentState!.validate()) return;
    final authController = Provider.of<AuthController>(context, listen: false);
    await authController.registerAndLogin(
      _usernameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text,
    );
    if (!mounted) return;
    if (authController.isAuthenticated) {
      // Limpiar TODA la pila de navegación y volver a AuthGate
      // AuthGate ahora mostrará HomeScreen ya que isAuthenticated = true
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthGate()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: Center(
          child: PopupForm(
            icon: const Icon(Icons.person_add, color: Colors.white, size: 18),
            title: 'REGISTRO',
            actions: [
              Consumer<AuthController>(builder: (context, authController, _) {
                if (authController.isLoading) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                }
                return PopupActionButton(label: 'Registrar', onPressed: _submitRegister);
              }),
              PopupActionButton(
                label: 'Volver',
                onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const AuthGate()),
                  (route) => false,
                ),
              ),
            ],
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ReusableTextField(
                    controller: _usernameController,
                    label: 'Nombre de usuario',
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return '';
                      final v = value.trim().toLowerCase();
                      if (v == 'system') return '';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  ReusableTextField(
                    controller: _emailController,
                    label: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return '';
                      if (!value.contains('@')) return '';
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