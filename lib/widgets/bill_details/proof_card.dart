import 'dart:convert';
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/theme/theme.dart';

/// Decodes a `data:image/...;base64,` (or bare base64) proof, or null.
Uint8List? decodeProofImage(Object? raw) {
  if (raw is! String || raw.trim().isEmpty) return null;
  try {
    final body = raw.contains(',') ? raw.split(',').last : raw;
    return base64Decode(body.trim());
  } on FormatException {
    return null;
  }
}

/// "Ali sent proof · InstaPay · 2 min ago" with a thumbnail and Confirm.
/// Without an image it reads "Ali says they paid".
class ProofCard extends StatelessWidget {
  const ProofCard({
    super.key,
    required this.name,
    required this.onConfirm,
    this.image,
    this.detail,
    this.onViewProof,
    this.onReject,
    this.busy = false,
  });

  final String name;
  final Uint8List? image;

  /// "InstaPay · 2 min ago".
  final String? detail;
  final VoidCallback onConfirm;
  final VoidCallback? onViewProof;

  /// Host rejects the proof: clears it and sets the share back to unpaid.
  final VoidCallback? onReject;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final title = image != null
        ? 'bf_bill_proof_sent'.tr(namedArgs: {'name': name})
        : 'bf_bill_proof_says_paid'.tr(namedArgs: {'name': name});
    final thumb = Container(
      width: 56,
      height: 72,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.hairline,
        borderRadius: BorderRadius.circular(8),
      ),
      child: image == null
          ? Icon(Icons.receipt_long_rounded, color: p.textSecondary)
          : Image.memory(
              image!,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) =>
                  Icon(Icons.broken_image_outlined, color: p.textSecondary),
            ),
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: p.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (image != null && onViewProof != null)
                Semantics(
                  button: true,
                  label: 'bf_bill_proof_view'.tr(namedArgs: {'name': name}),
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: onViewProof,
                    borderRadius: BorderRadius.circular(8),
                    child: thumb,
                  ),
                )
              else
                ExcludeSemantics(child: thumb),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.titleSmall.copyWith(
                        color: p.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (detail != null && detail!.isNotEmpty)
                      Text(
                        detail!,
                        style: AppTypography.bodySmall.copyWith(
                          color: p.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              SizedBox(
                height: 44,
                child: Center(
                  child: Material(
                    color: p.accent,
                    shape: const StadiumBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: busy ? null : onConfirm,
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        child: busy
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: p.onAccent,
                                ),
                              )
                            : Text(
                                'bf_bill_proof_confirm'.tr(),
                                style: AppTypography.labelMedium.copyWith(
                                  color: p.onAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (onReject != null)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: busy ? null : onReject,
                style: TextButton.styleFrom(
                  foregroundColor: p.owe,
                  minimumSize: const Size(0, 44),
                  textStyle: AppTypography.labelMedium,
                ),
                child: Text('bf_bill_proof_reject'.tr()),
              ),
            ),
        ],
      ),
    );
  }
}
