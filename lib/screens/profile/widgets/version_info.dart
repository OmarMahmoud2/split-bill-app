import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/theme/app_palette.dart';
import 'package:package_info_plus/package_info_plus.dart';

class VersionInfo extends StatelessWidget {
  const VersionInfo({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'made_with'.tr(),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: p.textTertiary,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.favorite, color: p.danger, size: 14),
              const SizedBox(width: 4),
              Text(
                'for_smart_spenders'.tr(),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: p.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final packageInfo = snapshot.data;
              final label = packageInfo == null
                  ? 'app_version_loading'.tr()
                  : 'app_version_build'.tr(
                      namedArgs: {
                        'version': packageInfo.version,
                        'build': packageInfo.buildNumber,
                      },
                    );

              return Text(
                label,
                style: TextStyle(fontSize: 12, color: p.textDisabled),
              );
            },
          ),
        ],
      ),
    );
  }
}
