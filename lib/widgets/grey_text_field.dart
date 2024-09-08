import 'package:flutter/material.dart';

class GreyTextField extends StatelessWidget {
  final String labelText;
  final bool isPassword;
  final int maxLines;
  final TextEditingController? controller;
  final TextInputType? keyboardType; 

  const GreyTextField({
    super.key,
    required this.labelText,
    this.isPassword = false,
    this.maxLines = 1,
    this.controller,
    this.keyboardType, 
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      obscureText: isPassword,
      maxLines: maxLines,
      controller: controller,
      keyboardType: keyboardType, 
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: Colors.white),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}