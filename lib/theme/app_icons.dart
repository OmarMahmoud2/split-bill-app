import 'package:flutter/widgets.dart';

/// One semantic map of the app's icons onto Phosphor
/// (docs/2.0/PREMIUM_POLISH.md, "Icons"): regular weight for UI, `*Fill` for
/// the selected nav tab, `*Duo` for feature tiles.
///
/// Use `Icon(AppIcons.add)`. Duotone entries are [AppDuoGlyph]s: draw them
/// with [AppDuoIcon].
///
/// Only the glyph fonts of `phosphor_flutter` are used (its Dart API does not
/// compile with the current Flutter SDK: it extends the final `IconData`), so
/// the code points below were copied from the package. Like the package, the
/// icons mirror in right-to-left locales.
class AppIcons {
  AppIcons._();

  static const _pkg = 'phosphor_flutter';

  // ---- navigation
  static const IconData home = IconData(
    0xe2c2,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // house
  static const IconData homeFill = IconData(
    0xe2c2,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // house
  static const IconData activity = IconData(
    0xe000,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // pulse
  static const IconData activityFill = IconData(
    0xe000,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // pulse
  static const IconData groups = IconData(
    0xe68e,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // usersThree
  static const IconData groupsFill = IconData(
    0xe68e,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // usersThree
  static const IconData you = IconData(
    0xe4c2,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // user
  static const IconData youFill = IconData(
    0xe4c2,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // user

  // ---- actions
  static const IconData add = IconData(
    0xe3d4,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // plus
  static const IconData remove = IconData(
    0xe32a,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // minus
  static const IconData removeCircle = IconData(
    0xe32c,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // minusCircle
  static const IconData close = IconData(
    0xe4f6,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // x
  static const IconData cancel = IconData(
    0xe4f8,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // xCircle
  static const IconData back = IconData(
    0xe058,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // arrowLeft
  static const IconData forward = IconData(
    0xe06c,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // arrowRight
  static const IconData chevronRight = IconData(
    0xe13a,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // caretRight
  static const IconData chevronLeft = IconData(
    0xe138,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // caretLeft
  static const IconData chevronDown = IconData(
    0xe136,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // caretDown
  static const IconData check = IconData(
    0xe182,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // check
  static const IconData share = IconData(
    0xe408,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // shareNetwork
  static const IconData copy = IconData(
    0xe1ca,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // copy
  static const IconData edit = IconData(
    0xe3b4,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // pencilSimple
  static const IconData delete = IconData(
    0xe4a6,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // trash
  static const IconData undo = IconData(
    0xe038,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // arrowCounterClockwise
  static const IconData refresh = IconData(
    0xe094,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // arrowsClockwise
  static const IconData more = IconData(
    0xe1fe,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // dotsThree
  static const IconData search = IconData(
    0xe30c,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // magnifyingGlass
  static const IconData filter = IconData(
    0xe434,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // slidersHorizontal
  static const IconData swap = IconData(
    0xe0a0,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // arrowsLeftRight
  static const IconData openExternal = IconData(
    0xe5de,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // arrowSquareOut
  static const IconData link = IconData(
    0xe2e2,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // link
  static const IconData download = IconData(
    0xe20c,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // downloadSimple
  static const IconData upload = IconData(
    0xe4c0,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // uploadSimple
  static const IconData export = IconData(
    0xeaf0,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // export
  static const IconData play = IconData(
    0xe3d0,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // play
  static const IconData playCircle = IconData(
    0xe3d2,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // playCircle
  static const IconData tap = IconData(
    0xec90,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // handTap
  static const IconData toggle = IconData(
    0xe674,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // toggleLeft

  // ---- input and capture
  static const IconData scan = IconData(
    0xebb6,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // scan
  static const AppDuoGlyph scanDuo = AppDuoGlyph(
    IconData(
      0xebb7,
      fontFamily: 'PhosphorDuotone',
      fontPackage: _pkg,
      matchTextDirection: true,
    ),
    IconData(
      0xebb6,
      fontFamily: 'PhosphorDuotone',
      fontPackage: _pkg,
      matchTextDirection: true,
    ),
  ); // scan
  static const AppDuoGlyph messageDuo = AppDuoGlyph(
    IconData(
      0xe16d,
      fontFamily: 'PhosphorDuotone',
      fontPackage: _pkg,
      matchTextDirection: true,
    ),
    IconData(
      0xe16c,
      fontFamily: 'PhosphorDuotone',
      fontPackage: _pkg,
      matchTextDirection: true,
    ),
  ); // chatCircleDots
  static const AppDuoGlyph linkDuo = AppDuoGlyph(
    IconData(
      0xe2e3,
      fontFamily: 'PhosphorDuotone',
      fontPackage: _pkg,
      matchTextDirection: true,
    ),
    IconData(
      0xe2e2,
      fontFamily: 'PhosphorDuotone',
      fontPackage: _pkg,
      matchTextDirection: true,
    ),
  ); // link
  static const AppDuoGlyph qrDuo = AppDuoGlyph(
    IconData(
      0xe3e7,
      fontFamily: 'PhosphorDuotone',
      fontPackage: _pkg,
      matchTextDirection: true,
    ),
    IconData(
      0xe3e6,
      fontFamily: 'PhosphorDuotone',
      fontPackage: _pkg,
      matchTextDirection: true,
    ),
  ); // qrCode
  static const AppDuoGlyph sendDuo = AppDuoGlyph(
    IconData(
      0xe399,
      fontFamily: 'PhosphorDuotone',
      fontPackage: _pkg,
      matchTextDirection: true,
    ),
    IconData(
      0xe398,
      fontFamily: 'PhosphorDuotone',
      fontPackage: _pkg,
      matchTextDirection: true,
    ),
  ); // paperPlaneTilt
  static const IconData qr = IconData(
    0xe3e6,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // qrCode
  static const IconData keyboard = IconData(
    0xe2d8,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // keyboard
  static const IconData mic = IconData(
    0xe326,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // microphone
  static const IconData micOff = IconData(
    0xe328,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // microphoneSlash
  static const IconData voice = IconData(
    0xe802,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // waveform
  static const IconData camera = IconData(
    0xe10e,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // camera
  static const IconData cameraOff = IconData(
    0xe110,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // cameraSlash
  static const IconData videoOff = IconData(
    0xe4dc,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // videoCameraSlash
  static const IconData earOff = IconData(
    0xe70e,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // earSlash
  static const IconData gallery = IconData(
    0xe2ca,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // image
  static const IconData brokenImage = IconData(
    0xe7a8,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // imageBroken
  static const IconData eye = IconData(
    0xe220,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // eye
  static const IconData eyeOff = IconData(
    0xe224,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // eyeSlash

  // ---- people
  static const IconData people = IconData(
    0xe4d6,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // users
  static const IconData personAdd = IconData(
    0xe4d0,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // userPlus
  static const IconData personRemove = IconData(
    0xe4ce,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // userMinus
  static const IconData personSearch = IconData(
    0xe6fc,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // userFocus
  static const IconData contacts = IconData(
    0xe6f8,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // addressBook
  static const IconData phone = IconData(
    0xe3b8,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // phone
  static const IconData mail = IconData(
    0xe218,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // envelopeSimple

  // ---- money
  static const IconData wallet = IconData(
    0xe68a,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // wallet
  static const AppDuoGlyph walletDuo = AppDuoGlyph(
    IconData(
      0xe68b,
      fontFamily: 'PhosphorDuotone',
      fontPackage: _pkg,
      matchTextDirection: true,
    ),
    IconData(
      0xe68a,
      fontFamily: 'PhosphorDuotone',
      fontPackage: _pkg,
      matchTextDirection: true,
    ),
  ); // wallet
  static const IconData receipt = IconData(
    0xe3ec,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // receipt
  static const AppDuoGlyph receiptDuo = AppDuoGlyph(
    IconData(
      0xe3f1,
      fontFamily: 'PhosphorDuotone',
      fontPackage: _pkg,
      matchTextDirection: true,
    ),
    IconData(
      0xe3ec,
      fontFamily: 'PhosphorDuotone',
      fontPackage: _pkg,
      matchTextDirection: true,
    ),
  ); // receipt
  static const IconData iou = IconData(
    0xea8c,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // handCoins
  static const IconData money = IconData(
    0xe588,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // money
  static const IconData cash = IconData(
    0xe588,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // money
  static const IconData card = IconData(
    0xe1d2,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // creditCard
  static const IconData bank = IconData(
    0xe0b4,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // bank
  static const IconData coins = IconData(
    0xe78e,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // coins
  static const IconData currency = IconData(
    0xe54c,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // currencyCircleDollar
  static const IconData split = IconData(
    0xe27e,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // gitFork
  static const IconData roulette = IconData(
    0xe1ee,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // diceFive
  static const IconData chart = IconData(
    0xe156,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // chartLineUp
  static const IconData insights = IconData(
    0xe150,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // chartBar
  static const IconData pieChart = IconData(
    0xeaa6,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // chartDonut

  // ---- status
  static const IconData info = IconData(
    0xe2ce,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // info
  static const IconData help = IconData(
    0xe3e8,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // question
  static const IconData warning = IconData(
    0xe4e0,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // warning
  static const IconData error = IconData(
    0xe4e2,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // warningCircle
  static const IconData success = IconData(
    0xe184,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // checkCircle
  static const IconData successFill = IconData(
    0xe184,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // checkCircle
  static const IconData block = IconData(
    0xe3de,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // prohibit
  static const IconData lock = IconData(
    0xe2fa,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // lock
  static const IconData clock = IconData(
    0xe19a,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // clock
  static const IconData hourglass = IconData(
    0xe2b2,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // hourglass
  static const IconData calendar = IconData(
    0xe10a,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // calendarBlank
  static const IconData wifiOff = IconData(
    0xe4f2,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // wifiSlash
  static const IconData cloudOff = IconData(
    0xe1b6,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // cloudSlash
  static const IconData inbox = IconData(
    0xe4aa,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // tray
  static const IconData bolt = IconData(
    0xe2de,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // lightning
  static const IconData rocket = IconData(
    0xe3fe,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // rocketLaunch
  static const IconData trip = IconData(
    0xe504,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // airplaneTakeoff

  // ---- brand and account
  static const IconData bell = IconData(
    0xe0ce,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // bell
  static const AppDuoGlyph bellDuo = AppDuoGlyph(
    IconData(
      0xe0cf,
      fontFamily: 'PhosphorDuotone',
      fontPackage: _pkg,
      matchTextDirection: true,
    ),
    IconData(
      0xe0ce,
      fontFamily: 'PhosphorDuotone',
      fontPackage: _pkg,
      matchTextDirection: true,
    ),
  ); // bell
  static const IconData settings = IconData(
    0xe270,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // gear
  static const IconData language = IconData(
    0xe4a2,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // translate
  static const IconData appearance = IconData(
    0xe6c8,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // palette
  static const IconData logout = IconData(
    0xe42a,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // signOut
  static const IconData star = IconData(
    0xe46a,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // star
  static const IconData heart = IconData(
    0xe2a8,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // heart
  static const IconData heartFill = IconData(
    0xe2a8,
    fontFamily: 'PhosphorFill',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // heart
  static const IconData crown = IconData(
    0xe616,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // crownSimple
  static const IconData sparkle = IconData(
    0xe6a2,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // sparkle
  static const IconData sun = IconData(
    0xe472,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // sun
  static const IconData moon = IconData(
    0xe330,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // moon
  static const IconData apple = IconData(
    0xe516,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // appleLogo
  static const IconData android = IconData(
    0xe008,
    fontFamily: 'PhosphorRegular',
    fontPackage: _pkg,
    matchTextDirection: true,
  ); // androidLogo
}

/// A duotone icon: the main [primary] glyph plus a faint [secondary] layer.
class AppDuoGlyph {
  const AppDuoGlyph(this.primary, this.secondary);
  final IconData primary;
  final IconData secondary;
}

/// Draws an [AppDuoGlyph]: the secondary layer at 20% opacity under the
/// primary layer, both in the icon colour.
class AppDuoIcon extends StatelessWidget {
  const AppDuoIcon(this.glyph, {super.key, this.size, this.color});

  final AppDuoGlyph glyph;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final base =
        color ?? IconTheme.of(context).color ?? const Color(0xFF000000);
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(glyph.secondary, size: size, color: base.withValues(alpha: 0.2)),
        Icon(glyph.primary, size: size, color: base),
      ],
    );
  }
}
