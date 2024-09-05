import 'package:flutter/material.dart';

class LoadingWidget extends StatelessWidget {
  final String logoPath; // Path to your company logo asset
  const LoadingWidget({required this.logoPath, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Background with opacity for transparency
        Container(
          color: Colors.black.withOpacity(0.5), // Dark transparent background
        ),
        // Circular progress indicator with the logo at the center
        SizedBox(
          width: 150,  // Overall size of the loading widget (adjust as necessary)
          height: 150,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Circular progress indicator around the logo
              CircularProgressIndicator(
                strokeWidth: 8,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.yellow), // Customize the color
              ),
              // Company logo in the center of the circular progress indicator
              ClipOval(
                child: Container(
                  width: 80,  // Size of the logo (adjust as necessary)
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: AssetImage(logoPath),
                      fit: BoxFit.cover,  // Adjust the image fit to cover the circle
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
