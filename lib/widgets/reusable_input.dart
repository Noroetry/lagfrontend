import 'package:flutter/material.dart';
import 'package:lagfrontend/theme/app_theme.dart';

/// Reusable single-line input used inside popups and forms.
/// Ensures consistent height, padding and decoration across the app.
class ReusableTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const ReusableTextField({
    super.key,
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppTheme.inputHeight,
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          contentPadding: AppTheme.inputContentPadding,
          border: const OutlineInputBorder(),
          // Hide the error text but keep the error border visible
          errorStyle: const TextStyle(height: 0, fontSize: 0),
          errorBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.redAccent)),
          focusedErrorBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.redAccent, width: 1.5)),
        ),
      ),
    );
  }
}
