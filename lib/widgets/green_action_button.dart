import 'package:flutter/material.dart';

class GreenActionButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color color;

  const GreenActionButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.color = Colors.green, // Default color is green
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.black, // Set text color to black
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}