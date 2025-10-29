import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lagfrontend/controllers/auth_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  // 🟢 CAMBIO 1: Renombrar el controlador para reflejar el uso dual
  final TextEditingController _usernameOrEmailController = TextEditingController(); 
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameOrEmailController.dispose(); // 🟢 CAMBIO 2: Disponer del nuevo controlador
    _passwordController.dispose();
    super.dispose();
  }

  void _submitLogin() async {
    if (_formKey.currentState!.validate()) {
      final authController = Provider.of<AuthController>(context, listen: false);
      
      // 🟢 CAMBIO 3: Pasar el texto del nuevo controlador al método login
      await authController.login(
        _usernameOrEmailController.text, // Aquí se envía el Username O Email
        _passwordController.text,
      );

      if (!mounted) return;

      if (authController.isAuthenticated) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authController.errorMessage ?? 'Error desconocido al iniciar sesión')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Iniciar Sesión'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextFormField(
                  // 🟢 CAMBIO 4: Asignar el nuevo controlador al campo de texto
                  controller: _usernameOrEmailController,
                  // Nota: Mantenemos el teclado por defecto, ya que podría ser un username
                  keyboardType: TextInputType.text, 
                  decoration: const InputDecoration(
                    labelText: 'Username o Email',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, introduce tu username o email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16.0),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, introduce tu contraseña';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32.0),
                Consumer<AuthController>(
                  builder: (context, authController, child) {
                    return authController.isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                            onPressed: _submitLogin,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Entrar', style: TextStyle(fontSize: 18)),
                          );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}