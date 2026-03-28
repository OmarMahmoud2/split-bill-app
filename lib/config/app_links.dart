import 'dart:io';

class AppLinks {
  // 1. Android Package Name (Application ID)
  // Found in android/app/build.gradle
  static const String androidPackageName = 'net.omarmali.splitapp';

  // 2. Apple App ID
  // Found in App Store Connect > App Information > Apple ID
  static const String appleAppId = '6757280494';
  // 3. Store URLs
  static String get playStoreUrl =>
      'https://play.google.com/store/apps/details?id=$androidPackageName';

  static String get appStoreUrl => 'https://apps.apple.com/app/id$appleAppId';

  static String get storeUrl => Platform.isIOS ? appStoreUrl : playStoreUrl;

  // 4. Support Email
  static const String supportEmail = 'omar.mahmoud1@yahoo.com';

  // 5. Share Text
  static String get shareText =>
      'Check out this awesome Split Bill app! 💸\n\n'
      'App Store: $appStoreUrl\n'
      'Play Store: $playStoreUrl';
}
