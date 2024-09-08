import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/services.dart'; // Import this for asset image loading
import 'package:http/http.dart' as http;

Future<BitmapDescriptor> createCustomMarkerWithImage(String imageUrl) async {
  try {
    final http.Response response = await http.get(Uri.parse(imageUrl));

    if (response.statusCode == 200) {
      // Decode the image into a UI image
      final Uint8List imageBytes = response.bodyBytes;
      final ui.Codec codec = await ui.instantiateImageCodec(imageBytes, targetWidth: 100); // Adjust size as needed
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ui.Image image = frame.image;

      // Create a canvas to draw a circular image
      final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(pictureRecorder);

      final double size = 100.0; // Size of the marker
      final Paint paint = Paint()..color = Colors.white;
      
      // Draw a circular background
      canvas.drawCircle(Offset(size / 2, size / 2), size / 2, paint);
      
      // Add an outer border for the circular image
      paint..color = Colors.blueAccent..style = PaintingStyle.stroke..strokeWidth = 5;
      canvas.drawCircle(Offset(size / 2, size / 2), size / 2 - 2.5, paint);
      
      // Create a circular clip path
      final Path path = Path()
        ..addOval(Rect.fromCircle(center: Offset(size / 2, size / 2), radius: size / 2 - 5))
        ..close();
      
      // Clip the image within the circular path
      canvas.clipPath(path);

      // Draw the profile picture
      paint..style = PaintingStyle.fill;
      canvas.drawImage(image, Offset.zero, paint);

      final ui.Picture picture = pictureRecorder.endRecording();
      final ui.Image markerAsImage = await picture.toImage(size.toInt(), size.toInt());
      
      final ByteData? byteData = await markerAsImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final Uint8List markerImageBytes = byteData.buffer.asUint8List();
        return BitmapDescriptor.fromBytes(markerImageBytes);
      }
    } else {
      print('Failed to load image: ${response.statusCode}');
    }
  } catch (e) {
    print('Error creating custom marker: $e');
  }

  // Fallback: if fetching the image fails, use the local image from assets
  return await createCustomMarkerFromAsset();
}

// Helper function to create a marker from a local asset image
Future<BitmapDescriptor> createCustomMarkerFromAsset() async {
  final ByteData data = await rootBundle.load('assets/icons/ShuffleLogo.jpeg');
  final Uint8List imageBytes = data.buffer.asUint8List();
  
  final ui.Codec codec = await ui.instantiateImageCodec(imageBytes, targetWidth: 100); // Adjust size if needed
  final ui.FrameInfo frame = await codec.getNextFrame();
  final ui.Image image = frame.image;

  final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(pictureRecorder);

  final double size = 100.0; // Size of the marker
  final Paint paint = Paint()..color = Colors.white;
  
  // Draw a circular background
  canvas.drawCircle(Offset(size / 2, size / 2), size / 2, paint);
  
  // Add an outer border for the circular image
  paint..color = Colors.blueAccent..style = PaintingStyle.stroke..strokeWidth = 5;
  canvas.drawCircle(Offset(size / 2, size / 2), size / 2 - 2.5, paint);
  
  // Create a circular clip path
  final Path path = Path()
    ..addOval(Rect.fromCircle(center: Offset(size / 2, size / 2), radius: size / 2 - 5))
    ..close();
  
  // Clip the image within the circular path
  canvas.clipPath(path);

  // Draw the local image
  paint..style = PaintingStyle.fill;
  canvas.drawImage(image, Offset.zero, paint);

  final ui.Picture picture = pictureRecorder.endRecording();
  final ui.Image markerAsImage = await picture.toImage(size.toInt(), size.toInt());

  final ByteData? byteData = await markerAsImage.toByteData(format: ui.ImageByteFormat.png);
  if (byteData != null) {
    final Uint8List markerImageBytes = byteData.buffer.asUint8List();
    return BitmapDescriptor.fromBytes(markerImageBytes);
  }

  // Fallback: return the default marker if asset loading fails
  return BitmapDescriptor.defaultMarker;
}
