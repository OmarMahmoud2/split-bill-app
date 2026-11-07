import 'package:flutter/material.dart';
import 'package:simple_icons/simple_icons.dart';
import 'package:split_bill_app/payments/payments.dart';
import 'package:split_bill_app/theme/theme.dart';

class _Glyph {
  const _Glyph(this.icon, this.color);
  final IconData icon;
  final Color color;
}

// Brand glyphs that exist in Simple Icons (CC0). Methods bundled as raster
// logos (PayPal, Venmo, InstaPay) use the raster instead.
const Map<String, _Glyph> _brandGlyphs = {
  'revolut': _Glyph(SimpleIcons.revolut, SimpleIconColors.revolut),
  'wise': _Glyph(SimpleIcons.wise, SimpleIconColors.wise),
  'cash_app': _Glyph(SimpleIcons.cashapp, SimpleIconColors.cashapp),
  'zelle': _Glyph(SimpleIcons.zelle, SimpleIconColors.zelle),
  'apple_cash': _Glyph(SimpleIcons.applepay, SimpleIconColors.applepay),
  'pix': _Glyph(SimpleIcons.pix, SimpleIconColors.pix),
  'monzo': _Glyph(SimpleIcons.monzo, SimpleIconColors.monzo),
  'alipay': _Glyph(SimpleIcons.alipay, SimpleIconColors.alipay),
  'wechat_pay': _Glyph(SimpleIcons.wechat, SimpleIconColors.wechat),
  'lydia': _Glyph(SimpleIcons.lydia, SimpleIconColors.lydia),
  'mercado_pago': _Glyph(SimpleIcons.mercadopago, SimpleIconColors.mercadopago),
  'line_pay': _Glyph(SimpleIcons.line, SimpleIconColors.line),
  'kakaopay': _Glyph(SimpleIcons.kakao, SimpleIconColors.kakao),
  'sepa_qr': _Glyph(SimpleIcons.sepa, SimpleIconColors.sepa),
};

const Map<String, AppDuoGlyph> _genericGlyphs = {
  'bank_transfer': AppIcons.bankDuo,
  'cash': AppIcons.cashDuo,
  'other': AppIcons.linkDuo,
  'e_wallet': AppIcons.walletDuo,
};

/// True when [type] has a brand glyph or bundled logo (not a monogram).
bool paymentMethodHasLogo(PaymentMethodType type) =>
    type.logoAsset != null || _brandGlyphs.containsKey(type.id);

/// The one mark for a payment method everywhere (settings grid, browse sheet,
/// pay sheet, bill details, guest pay): bundled logo, else Simple Icons brand
/// glyph, else duotone icon for generic types, else a brand monogram.
class PaymentMethodMark extends StatelessWidget {
  const PaymentMethodMark({super.key, required this.type, this.size = 40});

  final PaymentMethodType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final glyph = _brandGlyphs[type.id];
    final generic = _genericGlyphs[type.id];
    final Widget tile;
    if (type.logoAsset != null) {
      tile = Image.asset(
        type.logoAsset!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _monogram(),
      );
    } else if (glyph != null) {
      // Light brands (Wise, Kakao) get dark ink; the rest white on the brand.
      final light = glyph.color.computeLuminance() > 0.5;
      tile = ColoredBox(
        color: glyph.color,
        child: Center(
          child: Icon(
            glyph.icon,
            size: size * 0.55,
            color: light ? const Color(0xFF111111) : Colors.white,
          ),
        ),
      );
    } else if (generic != null) {
      final p = context.palette;
      tile = ColoredBox(
        color: p.surfaceVariant,
        child: Center(
          child: AppDuoIcon(generic, size: size * 0.56, color: p.textPrimary),
        ),
      );
    } else {
      tile = _monogram();
    }
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.3),
          child: tile,
        ),
      ),
    );
  }

  Widget _monogram() {
    final brand = Color(type.brandColor);
    final ink = ThemeData.estimateBrightnessForColor(brand) == Brightness.dark
        ? Colors.white
        : Colors.black87;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [brand, Color.lerp(brand, Colors.black, 0.22)!],
        ),
      ),
      child: Text(
        type.initials,
        maxLines: 1,
        style: AppTypography.labelSmall.copyWith(
          color: ink,
          fontSize: size * 0.33,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
