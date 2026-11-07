import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../theme/app_palette.dart';

class LoadingStateWidget extends StatelessWidget {
  final String? message;
  const LoadingStateWidget({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // The Lottie loader stays; it just sits on a soft framed tile.
          Container(
            width: 168,
            height: 168,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.palette.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: context.palette.hairline),
            ),
            child: Lottie.asset(
              'assets/animations/loading.json',
              width: 130,
              height: 130,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  const CircularProgressIndicator(),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
