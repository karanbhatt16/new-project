// ignore_for_file: avoid_print
/// Run this script to generate splash screen assets.
/// Usage: cd tool && dart pub get && dart run generate_splash_assets.dart
/// 
/// This creates beautiful VibeU splash logos.

import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

void main() async {
  print('🎨 Generating VibeU splash screen assets...\n');
  
  // Create assets/splash directory if it doesn't exist
  final dir = Directory('../assets/splash');
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  // Generate the logos
  generateLogo(
    outputPath: '../assets/splash/vibeu_logo.png',
    heartColor: img.ColorRgba8(255, 255, 255, 255), // White for pink bg
    textColor: img.ColorRgba8(255, 255, 255, 255),
  );
  print('✅ Created assets/splash/vibeu_logo.png');

  generateLogo(
    outputPath: '../assets/splash/vibeu_logo_dark.png',
    heartColor: img.ColorRgba8(255, 75, 110, 255), // Pink for dark bg
    textColor: img.ColorRgba8(255, 75, 110, 255),
  );
  print('✅ Created assets/splash/vibeu_logo_dark.png');

  print('\n🎉 Splash assets generated successfully!');
  print('\nNext step: Run this command from project root:');
  print('  dart run flutter_native_splash:create\n');
}

void generateLogo({
  required String outputPath,
  required img.Color heartColor,
  required img.Color textColor,
}) {
  const size = 512;
  final image = img.Image(width: size, height: size);
  
  // Fill with transparent background
  img.fill(image, color: img.ColorRgba8(0, 0, 0, 0));
  
  // Draw heart shape - centered and sized nicely
  drawHeart(image, size ~/ 2, size ~/ 2 - 50, 140, heartColor);
  
  // Draw vibe waves on left side
  drawVibeWave(image, 85, size ~/ 2 - 30, 45, heartColor, 0.8);
  drawVibeWave(image, 55, size ~/ 2 - 30, 60, heartColor, 0.5);
  
  // Draw vibe waves on right side (mirrored)
  drawVibeWave(image, size - 85, size ~/ 2 - 30, 45, heartColor, 0.8, flipX: true);
  drawVibeWave(image, size - 55, size ~/ 2 - 30, 60, heartColor, 0.5, flipX: true);
  
  // Draw "VibeU" text at bottom
  drawText(image, 'VibeU', size ~/ 2, size - 100, textColor, 50);
  
  // Save as PNG
  final pngBytes = img.encodePng(image);
  File(outputPath).writeAsBytesSync(pngBytes);
}

void drawHeart(img.Image image, int cx, int cy, int size, img.Color color) {
  // Draw a heart shape using the mathematical heart curve
  for (int y = -size; y <= size; y++) {
    for (int x = -size; x <= size; x++) {
      // Normalized coordinates
      double nx = x / (size * 0.6);
      double ny = -y / (size * 0.6); // Flip y for correct orientation
      
      // Heart equation: (x^2 + y^2 - 1)^3 - x^2*y^3 < 0
      double val = pow(nx * nx + ny * ny - 1, 3) - nx * nx * pow(ny, 3);
      
      if (val < 0) {
        int px = cx + x;
        int py = cy + y;
        if (px >= 0 && px < image.width && py >= 0 && py < image.height) {
          image.setPixel(px, py, color);
        }
      }
    }
  }
}

void drawVibeWave(img.Image image, int cx, int cy, int radius, img.Color color, double opacity, {bool flipX = false}) {
  // Draw arc-like wave to represent "vibes" emanating from the heart
  const strokeWidth = 8;
  final alphaColor = img.ColorRgba8(
    color.r.toInt(), 
    color.g.toInt(), 
    color.b.toInt(), 
    (255 * opacity).toInt(),
  );
  
  // Draw a curved arc
  for (double angle = -0.7; angle <= 0.7; angle += 0.015) {
    int x = cx + (flipX ? -1 : 1) * (radius * cos(angle + pi / 2)).toInt();
    int y = cy + (radius * sin(angle + pi / 2)).toInt();
    
    // Draw thick circular point for smooth line
    for (int dx = -strokeWidth ~/ 2; dx <= strokeWidth ~/ 2; dx++) {
      for (int dy = -strokeWidth ~/ 2; dy <= strokeWidth ~/ 2; dy++) {
        if (dx * dx + dy * dy <= (strokeWidth ~/ 2) * (strokeWidth ~/ 2)) {
          int px = x + dx;
          int py = y + dy;
          if (px >= 0 && px < image.width && py >= 0 && py < image.height) {
            image.setPixel(px, py, alphaColor);
          }
        }
      }
    }
  }
}

void drawText(img.Image image, String text, int cx, int cy, img.Color color, int fontSize) {
  // Simple pixel-art style text rendering for "VibeU"
  final letterPatterns = <String, List<List<int>>>{
    'V': [
      [1,0,0,0,1],
      [1,0,0,0,1],
      [0,1,0,1,0],
      [0,1,0,1,0],
      [0,0,1,0,0],
    ],
    'i': [
      [0,1,0],
      [0,0,0],
      [0,1,0],
      [0,1,0],
      [0,1,0],
    ],
    'b': [
      [1,0,0],
      [1,0,0],
      [1,1,0],
      [1,0,1],
      [1,1,0],
    ],
    'e': [
      [1,1,1],
      [1,0,0],
      [1,1,0],
      [1,0,0],
      [1,1,1],
    ],
    'U': [
      [1,0,0,0,1],
      [1,0,0,0,1],
      [1,0,0,0,1],
      [1,0,0,0,1],
      [0,1,1,1,0],
    ],
  };
  
  final scale = fontSize ~/ 5;
  const spacing = 2;
  
  // Calculate total width
  int totalWidth = 0;
  for (var char in text.split('')) {
    final pattern = letterPatterns[char];
    if (pattern != null) {
      totalWidth += pattern[0].length * scale + spacing * scale;
    }
  }
  totalWidth -= spacing * scale;
  
  int currentX = cx - totalWidth ~/ 2;
  
  for (var char in text.split('')) {
    final pattern = letterPatterns[char];
    if (pattern != null) {
      for (int row = 0; row < pattern.length; row++) {
        for (int col = 0; col < pattern[row].length; col++) {
          if (pattern[row][col] == 1) {
            // Draw scaled pixel block
            for (int sy = 0; sy < scale; sy++) {
              for (int sx = 0; sx < scale; sx++) {
                int px = currentX + col * scale + sx;
                int py = cy + row * scale + sy - (pattern.length * scale ~/ 2);
                if (px >= 0 && px < image.width && py >= 0 && py < image.height) {
                  image.setPixel(px, py, color);
                }
              }
            }
          }
        }
      }
      currentX += pattern[0].length * scale + spacing * scale;
    }
  }
}
