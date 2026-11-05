/// QR rendering for the guest pay panel. Imported `deferred` so qr_flutter
/// only downloads when a guest actually opens a QR code.
library;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class GuestQrCode extends StatelessWidget {
  const GuestQrCode({
    super.key,
    required this.data,
    required this.foreground,
    required this.background,
    this.size = 200,
  });

  final String data;
  final Color foreground;
  final Color background;
  final double size;

  @override
  Widget build(BuildContext context) {
    return QrImageView(
      data: data,
      size: size,
      backgroundColor: background,
      padding: const EdgeInsets.all(12),
      eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: foreground),
      dataModuleStyle: QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: foreground,
      ),
    );
  }
}
