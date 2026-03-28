import 'package:flutter/material.dart';

class VersionInfo extends StatelessWidget {
  final String version;

  const VersionInfo({super.key, this.version = "1.1.0"});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const Text(
            "Made with ❤️ for smart spenders",
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Version $version",
            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}
