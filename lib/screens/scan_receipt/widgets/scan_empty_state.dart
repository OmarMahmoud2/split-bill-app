import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class ScanEmptyState extends StatelessWidget {
  final File? image;
  final VoidCallback onSnapAndSave;
  final VoidCallback onAnalyze;
  final VoidCallback onPickImage;

  const ScanEmptyState({
    super.key,
    required this.image,
    required this.onSnapAndSave,
    required this.onAnalyze,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (image == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: ElevatedButton.icon(
                onPressed: onSnapAndSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue.shade700,
                  elevation: 4,
                  shadowColor: Colors.blue.withValues(alpha: 0.2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                icon: const Icon(Icons.flash_on_rounded, color: Colors.amber),
                label: const Text(
                  "Snap Now & Split Later",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          const SizedBox(height: 25),
          GestureDetector(
            onTap: () {
              if (image != null) {
                onAnalyze();
              } else {
                onPickImage();
              }
            },
            child: Container(
              width: 300,
              height: 420,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (image != null) ...[
                      Expanded(
                        child: Image.file(
                          image!,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(24),
                        color: Colors.white,
                        width: double.infinity,
                        child: Column(
                          children: [
                            Text(
                              "Receipt Ready!",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "Tap to Analyze Results",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      const Spacer(),
                      Lottie.asset(
                        'assets/animations/scan.json',
                        height: 120,
                        repeat: false,
                        errorBuilder: (c, e, s) => const Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 80,
                          color: Color(0xFF00B365),
                        ),
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        "Tap to Scan",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          "Point your camera at the receipt for magic processing",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[600],
                            height: 1.5,
                          ),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
