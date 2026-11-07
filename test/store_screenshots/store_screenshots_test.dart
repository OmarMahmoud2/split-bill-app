@Tags(['store'])
@TestOn('mac-os')
library;

// ignore_for_file: invalid_use_of_visible_for_testing_member
// Renders the raw store screenshots (no framing) for every store locale into
// build/store_raw/<locale>/<n>-<slug>.png. Framing: tool/store/frame_screenshots.py.
//
// Run: flutter test --run-skipped --tags store --concurrency=1 test/store_screenshots
// Only some locales: STORE_LOCALES=en-US,ja flutter test --tags store ...
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/foundation.dart';
// ignore: depend_on_referenced_packages
import 'package:intl/intl.dart' show NumberFormat;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_bill_app/bill_summary_confirm_screen.dart';
import 'package:split_bill_app/data/ledger_repository.dart';
import 'package:split_bill_app/data/models.dart';
import 'package:split_bill_app/domain/money.dart';
import 'package:split_bill_app/guest_bill_screen.dart';
import 'package:split_bill_app/payments/payments.dart';
import 'package:split_bill_app/screens/settle/settle_up_screen.dart';
import 'package:split_bill_app/services/bill_intelligence_service.dart';
import 'package:split_bill_app/split_bill_screen.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/home/home_dashboard.dart';
import 'package:split_bill_app/widgets/home/ledger_session.dart';
import 'package:split_bill_app/widgets/receipt_result_view.dart';
import 'package:split_bill_app/widgets/voice_command_overlay.dart';

import '../bill_flow/voice/voice_command_overlay_test.dart'
    show FakeAssign, FakeRecorder, FakeSpeechEngine;
import '../ledger_screens/fake_repo.dart' show FakeLedgerRepository;
import '../screens/guest_bill/guest_bill_screen_test.dart' show FakeRepo;

// ---------------------------------------------------------------- locales

/// Store profile: caption locale -> app language + currency.
class Profile {
  const Profile(this.key, this.lang, this.currency);
  final String key;
  final String lang;
  final String currency;
}

const profiles = <Profile>[
  Profile('en-US', 'en', 'USD'),
  Profile('en-CA', 'en', 'CAD'),
  Profile('en-GB', 'en', 'GBP'),
  Profile('en-AU', 'en', 'AUD'),
  Profile('de', 'de', 'EUR'),
  Profile('nl', 'nl', 'EUR'),
  Profile('sv', 'sv', 'SEK'),
  Profile('da', 'da', 'DKK'),
  Profile('no', 'nb', 'NOK'),
  Profile('fr-FR', 'fr', 'EUR'),
  Profile('fr-CA', 'fr', 'CAD'),
  Profile('es-ES', 'es', 'EUR'),
  Profile('es-MX', 'es', 'MXN'),
  Profile('it', 'it', 'EUR'),
  Profile('pt-BR', 'pt', 'BRL'),
  Profile('pt-PT', 'pt', 'EUR'),
  Profile('pl', 'pl', 'PLN'),
  Profile('ru', 'ru', 'RUB'),
  Profile('tr', 'tr', 'TRY'),
  Profile('ar-SA', 'ar', 'SAR'),
  Profile('ar', 'ar', 'EGP'),
  Profile('hi', 'hi', 'INR'),
  Profile('ur', 'ur', 'PKR'),
  Profile('id', 'id', 'IDR'),
  Profile('ja', 'ja', 'JPY'),
  Profile('ko', 'ko', 'KRW'),
  Profile('th', 'th', 'THB'),
  Profile('vi', 'vi', 'VND'),
  Profile('zh-Hans', 'zh', 'CNY'),
  Profile('zh-Hant', 'zh', 'TWD'),
];

/// Rough "USD to local" factor so the demo prices look natural.
const _factor = <String, num>{
  'USD': 1, 'CAD': 1.4, 'GBP': 0.8, 'AUD': 1.5, 'EUR': 0.9, 'SEK': 10,
  'DKK': 7, 'NOK': 10, 'MXN': 18, 'BRL': 5, 'PLN': 4, 'RUB': 90, 'TRY': 40,
  'SAR': 3.75, 'EGP': 50, 'INR': 85, 'PKR': 280, 'IDR': 16000, 'JPY': 150,
  'KRW': 1400, 'THB': 35, 'VND': 25000, 'CNY': 7, 'TWD': 30,
};

/// Local-currency amount (major units) for a USD-ish [usd], rounded to a
/// shop-like step.
double _local(String cur, double usd) {
  final v = usd * (_factor[cur] ?? 1);
  if (v >= 5000) return (v / 1000).round() * 1000.0;
  if (v >= 500) return (v / 50).round() * 50.0;
  if (v >= 100) return (v / 5).round() * 5.0;
  if (v >= 20) return v.roundToDouble();
  return (v * 2).round() / 2;
}

int _minor(String cur, double usd) => toMinorUnits(_local(cur, usd), cur);

double _round(String cur, double v) => fromMinorUnits(toMinorUnits(v, cur), cur);

// ----------------------------------------------------------------- fonts

Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  var any = false;
  for (final f in files) {
    if (!File(f).existsSync()) continue;
    any = true;
    loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  if (any) await loader.load();
}

const _sys = '/System/Library/Fonts';
const _sup = '/System/Library/Fonts/Supplemental';

const _fallbackFamilies = [
  'StoreSans', 'StoreArabic', 'StoreJa', 'StoreHans', 'StoreKo', 'StoreThai',
  'StoreDeva', 'StoreUnicode',
];

/// System font that replaces Inter/Plus Jakarta for a script, so even text
/// with its own TextStyle (no theme fallback) renders real glyphs.
/// One process renders one script (see tool/store/run_store_screenshots.sh).
List<String>? _scriptFont(Profile p) => switch (p.lang) {
  'ar' => ['$_sup/Tahoma.ttf', '$_sup/Tahoma Bold.ttf'],
  'ur' => ['$_sup/Arial Unicode.ttf'],
  'ja' => ['$_sys/ヒラギノ角ゴシック W4.ttc', '$_sys/ヒラギノ角ゴシック W6.ttc'],
  'zh' when p.key == 'zh-Hant' => ['$_sys/STHeiti Light.ttc', '$_sys/STHeiti Medium.ttc'],
  'zh' => ['$_sys/Hiragino Sans GB.ttc'],
  'ko' => ['$_sys/AppleSDGothicNeo.ttc'],
  'th' => ['$_sup/Tahoma.ttf', '$_sup/Tahoma Bold.ttf'],
  'hi' => ['$_sys/Kohinoor.ttc'],
  _ => null,
};

Future<void> _loadFonts(Profile first) async {
  final script = _scriptFont(first);
  if (script != null) {
    await _font('Inter', script);
    await _font('PlusJakartaSans', script);
  } else {
    await _loadLatin();
  }
  await _loadCommon();
}

Future<void> _loadLatin() async {
  const inter = 'assets/fonts/Inter';
  await _font('Inter', [
    '$inter/Inter-Regular.ttf', '$inter/Inter-Medium.ttf',
    '$inter/Inter-SemiBold.ttf', '$inter/Inter-Bold.ttf',
  ]);
  const jak = 'assets/fonts/PlusJakartaSans';
  await _font('PlusJakartaSans', [
    '$jak/PlusJakartaSans-SemiBold.ttf', '$jak/PlusJakartaSans-Bold.ttf',
    '$jak/PlusJakartaSans-ExtraBold.ttf',
  ]);
}

Future<void> _loadCommon() async {
  await _font('IBMPlexMono', [
    'assets/fonts/IBMPlexMono/IBMPlexMono-Regular.ttf',
    'assets/fonts/IBMPlexMono/IBMPlexMono-Medium.ttf',
  ]);
  // Phosphor icon fonts straight from the package.
  final cfg = jsonDecode(File('.dart_tool/package_config.json').readAsStringSync())
      as Map<String, dynamic>;
  final pkg = (cfg['packages'] as List).cast<Map>().firstWhere(
    (p) => p['name'] == 'phosphor_flutter',
  );
  final rootUri = Uri.parse(pkg['rootUri'] as String);
  final root = rootUri.isAbsolute
      ? rootUri.toFilePath()
      : Directory('.dart_tool').absolute.uri.resolveUri(rootUri).toFilePath();
  for (final e in {
    'PhosphorRegular': 'Phosphor.ttf', 'PhosphorFill': 'Phosphor-Fill.ttf',
    'PhosphorDuotone': 'Phosphor-Duotone.ttf', 'PhosphorBold': 'Phosphor-Bold.ttf',
    'PhosphorLight': 'Phosphor-Light.ttf', 'PhosphorThin': 'Phosphor-Thin.ttf',
  }.entries) {
    await _font('packages/phosphor_flutter/${e.key}', ['$root/lib/fonts/${e.value}']);
  }
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.path;
  await _font('MaterialIcons', [
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ]);
  // macOS system fonts as per-script fallbacks.
  await _font('StoreSans', ['$_sys/SFNS.ttf']);
  await _font('StoreArabic', ['$_sys/SFArabic.ttf']);
  await _font('StoreJa', ['$_sys/ヒラギノ角ゴシック W4.ttc']);
  await _font('StoreHans', ['$_sys/Hiragino Sans GB.ttc']);
  await _font('StoreKo', ['$_sys/AppleSDGothicNeo.ttc']);
  await _font('StoreThai', ['$_sys/ThonburiUI.ttc']);
  await _font('StoreDeva', ['$_sys/Kohinoor.ttc']);
  await _font('StoreUnicode', ['$_sup/Arial Unicode.ttf']);
}

/// Per-language order so the right script font wins (ja before zh, etc).
List<String> _fallbackFor(String lang) {
  final first = switch (lang) {
    'ar' || 'ur' => 'StoreArabic',
    'ja' => 'StoreJa',
    'zh' => 'StoreHans',
    'ko' => 'StoreKo',
    'th' => 'StoreThai',
    'hi' => 'StoreDeva',
    _ => 'StoreSans',
  };
  return [first, ..._fallbackFamilies.where((f) => f != first)];
}

ButtonStyle? _btn(ButtonStyle? b, List<String> fb) {
  final t = b?.textStyle?.resolve(const {});
  return t == null
      ? b
      : b!.copyWith(textStyle: WidgetStatePropertyAll(t.copyWith(fontFamilyFallback: fb)));
}

ThemeData _withFallback(ThemeData t, List<String> fb) => t.copyWith(
  textTheme: t.textTheme.apply(fontFamilyFallback: fb),
  primaryTextTheme: t.primaryTextTheme.apply(fontFamilyFallback: fb),
  filledButtonTheme: FilledButtonThemeData(style: _btn(t.filledButtonTheme.style, fb)),
  outlinedButtonTheme: OutlinedButtonThemeData(style: _btn(t.outlinedButtonTheme.style, fb)),
  textButtonTheme: TextButtonThemeData(style: _btn(t.textButtonTheme.style, fb)),
  elevatedButtonTheme: ElevatedButtonThemeData(style: _btn(t.elevatedButtonTheme.style, fb)),
);

// ------------------------------------------------------------ translations

class _Translations extends AssetLoader {
  const _Translations();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(
            File('assets/translations/${locale.languageCode}.json')
                .readAsStringSync(),
          )
          as Map<String, dynamic>;
}

// ------------------------------------------------------------- demo data

const _names = {
  'maya': 'Maya', 'leo': 'Leo', 'sara': 'Sara', 'omar': 'Omar', 'yuki': 'Yuki', 'ana': 'Ana',
};
const _ids = ['maya', 'leo', 'sara', 'omar', 'yuki', 'ana'];
const _store = 'Dinner at Lumen';

/// Item (name, usd, assignees). ar/ja/zh get local item names.
List<(String, double, List<String>)> _items(String lang) {
  final n = switch (lang) {
    'ar' => ['بوراتا', 'سباغيتي بالمحار', 'بيتزا مارغريتا', 'باستا الكمأة', 'تيراميسو', 'مياه غازية'],
    'ja' => ['ブッラータ', 'ボンゴレ', 'マルゲリータ', 'トリュフパスタ', 'ティラミス', '炭酸水'],
    'zh' => ['布拉塔奶酪', '蛤蜊意面', '玛格丽特披萨', '松露意面', '提拉米苏', '气泡水'],
    _ => ['Burrata', 'Spaghetti vongole', 'Margherita pizza', 'Truffle pasta', 'Tiramisu', 'Sparkling water'],
  };
  return [
    (n[0], 14, ['maya', 'ana']),
    (n[1], 22, ['omar']),
    (n[2], 18, ['sara', 'maya']),
    (n[3], 24, ['leo']),
    (n[4], 9, ['yuki', 'ana']),
    (n[5], 6, ['leo', 'sara', 'omar', 'yuki', 'ana', 'maya']),
  ];
}

Map<String, dynamic> _receipt(Profile p) {
  final items = _items(p.lang);
  final cur = p.currency;
  final sub = items.fold<double>(0, (a, i) => a + _local(cur, i.$2));
  return {
    'restaurant_name': _store,
    'storeName': _store,
    'currency_code': cur,
    'items': [
      for (final i in items) {'name': i.$1, 'price': _local(cur, i.$2), 'qty': 1},
    ],
    'tax': _round(cur, sub * 0.08),
    'service_charge': _round(cur, sub * 0.10),
  };
}

String _transcript(String lang) => switch (lang) {
  'ar' => 'ليو أخذ الباستا، وأنا وسارة تقاسمنا البيتزا',
  'ja' => 'レオはパスタ、サラと私はピザをシェアしました',
  'zh' => '利奥吃了意面，我和莎拉分了披萨',
  'de' => 'Leo hatte die Pasta, Sara und ich haben uns die Pizza geteilt',
  'fr' => 'Leo a pris les pâtes, Sara et moi avons partagé la pizza',
  'es' => 'Leo pidió la pasta, Sara y yo compartimos la pizza',
  'it' => 'Leo ha preso la pasta, io e Sara abbiamo diviso la pizza',
  'pt' => 'O Leo pediu a massa, eu e a Sara dividimos a pizza',
  'nl' => 'Leo had de pasta, Sara en ik deelden de pizza',
  'pl' => 'Leo zjadł makaron, a ja z Sarą podzieliliśmy pizzę',
  'ru' => 'Лео взял пасту, мы с Сарой поделили пиццу',
  'tr' => 'Leo makarnayı aldı, Sara ile pizzayı paylaştık',
  'sv' => 'Leo tog pastan, Sara och jag delade pizzan',
  'da' => 'Leo fik pastaen, Sara og jeg delte pizzaen',
  'nb' => 'Leo tok pastaen, Sara og jeg delte pizzaen',
  'id' => 'Leo makan pasta, aku dan Sara berbagi pizza',
  'vi' => 'Leo ăn mì Ý, tôi và Sara chia nhau bánh pizza',
  'ko' => '레오는 파스타, 사라와 나는 피자를 나눠 먹었어요',
  'th' => 'ลีโอกินพาสต้า ฉันกับซาร่าแบ่งพิซซ่ากัน',
  'hi' => 'लियो ने पास्ता लिया, सारा और मैंने पिज़्ज़ा बाँटा',
  'ur' => 'لیو نے پاستا لیا، سارہ اور میں نے پیزا بانٹا',
  _ => 'Leo had the pasta, Sara and I shared the pizza',
};

List<Map<String, dynamic>> _people() => [
  for (final id in _ids)
    {'id': id, 'name': _names[id], 'isHost': id == 'maya', 'isGuest': id == 'leo'},
];

// ------------------------------------------------------------- harness

// Taller than a 19.5:9 phone so the breakdown list, the settle rows and the
// home bill are fully visible; the status bar is drawn in frame_screenshots.py.
const _w = 440.0, _h = 1080.0;

class _Shot {
  _Shot(this.tester, this.p);
  final WidgetTester tester;
  final Profile p;
  GlobalKey key = GlobalKey();
  int _n = 0;

  Future<void> pump(Widget home, {bool dark = false}) async {
    // A fresh key, or the previous screen's subtree (routes, overlays) is reused.
    key = GlobalKey();
    final fb = _fallbackFor(p.lang);
    final app = Builder(
      builder: (context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: context.locale,
        supportedLocales: context.supportedLocales,
        localizationsDelegates: context.localizationDelegates,
        theme: _withFallback(AppTheme.lightTheme, fb),
        darkTheme: _withFallback(AppTheme.darkTheme, fb),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: DefaultTextStyle.merge(
            style: TextStyle(fontFamilyFallback: fb),
            child: AppLocaleTypography(child: child!),
          ),
        ),
        home: home,
      ),
    );
    await tester.pumpWidget(
      EasyLocalization(
        key: ValueKey('${p.key}${_n++}'),
        supportedLocales: [Locale(p.lang)],
        startLocale: Locale(p.lang),
        saveLocale: false,
        path: 'assets/translations',
        assetLoader: const _Translations(),
        child: RepaintBoundary(key: key, child: app),
      ),
    );
    await settle();
  }

  Future<void> settle() async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    final e = tester.takeException();
    if (e != null) throw StateError('${p.key}: exception while rendering: $e');
  }

  Future<void> save(String name) async {
    await tester.runAsync(() async {
      final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 3);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      final f = File('build/store_raw/${p.key}/$name.png');
      f.createSync(recursive: true);
      f.writeAsBytesSync(data!.buffer.asUint8List());
    });
  }
}

// ------------------------------------------------------------------ main

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final only = (Platform.environment['STORE_LOCALES'] ?? '')
      .split(',')
      .where((s) => s.isNotEmpty)
      .toSet();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    // Only so Firebase.instance getters do not throw; no network is used.
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    await EasyLocalization.ensureInitialized();
    final sel = profiles.where((p) => only.isEmpty || only.contains(p.key)).toList();
    await _loadFonts(sel.first);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });

  for (final p in profiles.where((p) => only.isEmpty || only.contains(p.key))) {
    testWidgets('store screens ${p.key}', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.physicalSize = const Size(_w * 3, _h * 3);
      tester.view.devicePixelRatio = 3;
      tester.view.padding = const FakeViewPadding(top: 62 * 3, bottom: 34 * 3);
      tester.view.viewPadding = const FakeViewPadding(top: 62 * 3, bottom: 34 * 3);
      addTearDown(tester.view.reset);
      LedgerMe.debugOverride = const LedgerMe(uid: 'maya', name: 'Maya');
      addTearDown(() => LedgerMe.debugOverride = null);

      final s = _Shot(tester, p);
      final cur = p.currency;
      final receipt = _receipt(p);
      String fmt(num v) => fromMinorUnits(toMinorUnits(v.toDouble(), cur), cur)
          .toStringAsFixed(currencyDecimals(cur));

      // 1 scan review
      final owned = <TextEditingController>[];
      TextEditingController c(String t) {
        final x = TextEditingController(text: t);
        owned.add(x);
        return x;
      }
      await s.pump(
        Scaffold(
          body: ReceiptResultView(
            receiptData: receipt,
            itemControllers: [
              for (final i in receipt['items'] as List)
                {
                  'name': c(i['name'] as String),
                  'qty': c('1'),
                  'price': c(fmt(i['price'] as num)),
                },
            ],
            currencyCode: cur,
            restaurantController: c(_store),
            taxController: c(fmt(receipt['tax'] as num)),
            serviceController: c(fmt(receipt['service_charge'] as num)),
            discountController: c(''),
            tipController: c(''),
            deliveryController: c(''),
            onSave: () {},
            onAddItem: (_, _, _) {},
            onUpdateItem: (_, _, _, _) {},
            onDeleteItem: (_) {},
            selectedDate: DateTime(2026, 11, 6),
            onDateChanged: (_) {},
            bottom: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {},
                  child: Builder(builder: (_) => Text('bf_scan_review_cta'.tr())),
                ),
              ),
            ),
          ),
        ),
      );
      await s.save('1-scan');

      // 2 assign + voice overlay
      final engine = FakeSpeechEngine(
        ids: [
          for (final l in ['en', 'ar', 'ur', 'hi', 'ja', 'ko', 'th', 'vi', 'zh', 'de', 'fr', 'es', 'it', 'nl', 'pt', 'pl', 'ru', 'tr', 'sv', 'da', 'nb', 'id'])
            '${l}_XX',
        ],
      );
      await s.pump(
        SplitBillScreen(
          receiptData: receipt,
          initialParticipants: [
            for (final id in _ids)
              {
                'type': id == 'maya' ? 'host' : (id == 'leo' ? 'guest' : 'friend'),
                'data': {'id': id, 'name': _names[id]},
              },
          ],
          initialAssignments: const {
            '0': ['maya', 'ana'],
            '1': ['omar'],
          },
        ),
      );
      final nav = Navigator.of(tester.element(find.byType(SplitBillScreen)));
      unawaited(
        nav.push<Object?>(
          PageRouteBuilder<Object?>(
            opaque: false,
            pageBuilder: (_, _, _) => VoiceCommandOverlay(
              receiptData: receipt,
              participants: _people(),
              speechEngine: engine,
              recorder: FakeRecorder(),
              assignService: FakeAssign([
                VoiceAssignResult(
                  assignments: {
                    for (var i = 0; i < 6; i++) '$i': _items(p.lang)[i].$3,
                  },
                ),
              ]),
              currentUserId: () => 'maya',
              pointsGate: (_) async => true,
              initialLanguage: p.lang,
              openSettings: () async {},
            ),
          ),
        ),
      );
      await s.settle();
      final lang = find.byKey(ValueKey('bf_voice_lang_${p.lang}'));
      if (lang.evaluate().isNotEmpty) {
        await tester.tap(lang);
        await s.settle();
      }
      engine.say(_transcript(p.lang));
      await s.settle();
      await tester.tap(find.byKey(const ValueKey('bf_voice_done')));
      await s.settle();
      await s.save('2-voice');

      // 3 breakdown
      await s.pump(
        BillSummaryConfirmScreen(
          receiptData: receipt,
          participants: _people(),
          itemAssignments: {
            for (var i = 0; i < 6; i++) i: _items(p.lang)[i].$3,
          },
          quantityAssignments: const {},
          taxAmount: (receipt['tax'] as num).toDouble(),
          serviceChargeAmount: (receipt['service_charge'] as num).toDouble(),
          tipAmount: 0,
          debugSave: (_) async => 'demo',
        ),
      );
      await s.save('3-breakdown');

      // 4 guest page
      final repo = FakeRepo();
      await s.pump(
        GuestBillScreen(
          billId: 'demo',
          initialParticipantId: 'leo',
          repository: repo,
          launcher: PaymentLauncher(
            canOpen: (_) async => true,
            open: (_) async => true,
            copy: (_) async {},
          ),
        ),
      );
      repo.controller.add(_guestBill(p));
      await s.settle();
      await s.save('4-guest');

      // 5 settle up
      LedgerRepository.instance = _settleRepo(p);
      await s.pump(const SettleUpScreen.group(groupId: 'g1'));
      await s.save('5-settle');

      // callout strings (translations are loaded by now)
      // Strings for the callouts that tool/store/frame_screenshots.py draws.
      final money = NumberFormat.simpleCurrency(
        locale: p.lang, name: cur, decimalDigits: currencyDecimals(cur));
      // intl has no Arabic riyal symbol; direction marks are re-added when drawn.
      String m(int minor) => money
          .format(fromMinorUnits(minor, cur))
          .replaceAll('Riyal', 'ر.س')
          .replaceAll(RegExp('[‎‏]'), '');
      final gb = _guestBill(p);
      final leo = (gb['participants'] as List).firstWhere((x) => x['id'] == 'leo') as Map;
      final meta = <String, String>{
        // Same sum the scan screen shows (rounded per line), not the per-person total.
        'total': m(
          [
            ...(receipt['items'] as List).map((i) => i['price'] as num),
            receipt['tax'] as num,
            receipt['service_charge'] as num,
          ].fold<int>(0, (a, v) => a + toMinorUnits(v.toDouble(), cur)),
        ),
        'total_label': 'receipt_total'.tr(),
        'transcript': _transcript(p.lang),
        'owe': 'fx_you_owe'.tr(namedArgs: {'amount': m(leo['shareMinor'] as int)}),
        'leo': '${_names['leo']}  ${m(leo['shareMinor'] as int)}',
        'settle': 'settle_n_payments_settle'.tr(namedArgs: {'count': '5'}),
        'paid': '${'status_paid'.tr()}  ${m(_minor(cur, 24) + _minor(cur, 20))}',
        'name': 'Yuki',
      };

      // 6 home (light) and 7 home (dark)
      final homeRepo = _homeRepo(p);
      LedgerRepository.instance = homeRepo;
      Widget home() => HomeDashboard(
        stream: watchHomeLedger(homeRepo, 'maya', fallbackCurrency: cur),
        actions: HomeActions(
          onNew: () {}, onQuickIou: () {}, onStartGroup: () {},
          onOpenGroups: () {}, onOpenActivity: () {}, onOpenProfile: () {},
          onOpenNotifications: () {},
        ),
        onRetry: () {},
      );
      await s.pump(home());
      await s.save('6-home');
      meta['owed_label'] = 'home_owed_overall'.tr();
      meta['owed'] = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .firstWhere((t) => t.startsWith('+'), orElse: () => '');
      await s.pump(home(), dark: true);
      await s.save('7-home-dark');
      File('build/store_raw/${p.key}/meta.json')
          .writeAsStringSync(jsonEncode(meta));
      for (final o in owned) {
        o.dispose();
      }
      debugDefaultTargetPlatformOverride = null;
    });
  }
}

// ------------------------------------------------- guest + ledger fixtures

Map<String, dynamic> _guestBill(Profile p) {
  final cur = p.currency;
  final items = _items(p.lang);
  final minor = [for (final i in items) _minor(cur, i.$2)];
  final sub = minor.fold<int>(0, (a, b) => a + b);
  final tax = (sub * 0.08).round(), service = (sub * 0.10).round();
  final shares = <String, int>{for (final id in _ids) id: 0};
  for (var i = 0; i < items.length; i++) {
    final who = items[i].$3;
    final each = minor[i] ~/ who.length;
    var left = minor[i] - each * who.length;
    for (final w in who) {
      shares[w] = shares[w]! + each + (left-- > 0 ? 1 : 0);
    }
  }
  for (final id in _ids) {
    shares[id] = shares[id]! + ((tax + service) * shares[id]! / sub).round();
  }
  final total = shares.values.fold<int>(0, (a, b) => a + b);
  double major(int m) => fromMinorUnits(m, cur);
  return {
    'storeName': _store,
    'hostId': 'maya',
    'hostName': 'Maya',
    'currencyCode': cur,
    'currency': cur,
    'total': major(total),
    'totalMinor': total,
    'charges': {'taxAmount': major(tax), 'serviceCharge': major(service)},
    'items': [
      for (var i = 0; i < items.length; i++)
        {
          'name': items[i].$1,
          'price': major(minor[i]),
          'priceMinor': minor[i],
          'qty': 1,
          'assignedTo': items[i].$3,
        },
    ],
    'participants': [
      for (final id in _ids)
        {
          'id': id,
          'name': _names[id],
          'share': major(shares[id]!),
          'shareMinor': shares[id],
          'status': id == 'leo' ? 'PENDING' : 'PAID',
        },
    ],
    'paymentMethods': {'PayPal': 'maya@example.com'},
  };
}

BillRecord _bill(
  Profile p,
  String id,
  String title,
  String host,
  Map<String, double> usdShares, {
  Set<String> paid = const {},
  String? groupId,
  DateTime? date,
}) {
  final cur = p.currency;
  final m = {for (final e in usdShares.entries) e.key: _minor(cur, e.value)};
  return BillRecord(
    id: id,
    hostId: host,
    hostName: _names[host],
    title: title,
    currency: cur,
    totalMinor: m.values.fold(0, (a, b) => a + b),
    groupId: groupId,
    date: date ?? DateTime(2026, 11, 6),
    participants: [
      for (final e in m.entries)
        BillShare(
          id: e.key,
          name: _names[e.key]!,
          shareMinor: e.value,
          status: e.key == host || paid.contains(e.key) ? 'PAID' : 'PENDING',
        ),
    ],
  );
}

FakeLedgerRepository _settleRepo(Profile p) {
  final g = LedgerGroup(
    id: 'g1',
    name: 'Lisbon weekend',
    createdBy: 'maya',
    type: GroupType.trip,
    currency: p.currency,
    members: [for (final id in _ids) GroupMember(id: id, name: _names[id]!)],
  );
  return FakeLedgerRepository(
    groups: [g],
    groupBills: {
      'g1': [
        _bill(p, 'b1', 'Dinner at Lumen', 'maya', {'maya': 20, 'leo': 31, 'sara': 28, 'omar': 22, 'yuki': 24, 'ana': 18}, groupId: 'g1'),
        _bill(p, 'b2', 'Tram passes', 'leo', {'maya': 12, 'leo': 12, 'sara': 12, 'omar': 12, 'yuki': 12, 'ana': 12}, groupId: 'g1'),
        _bill(p, 'b3', 'Pastéis de nata', 'sara', {'maya': 8, 'sara': 8, 'yuki': 8}, groupId: 'g1'),
        _bill(p, 'b4', 'Rooftop drinks', 'omar', {'leo': 26, 'omar': 26, 'yuki': 26, 'sara': 26}, groupId: 'g1'),
      ],
    },
  );
}

FakeLedgerRepository _homeRepo(Profile p) {
  final g = LedgerGroup(
    id: 'g1',
    name: 'Lisbon weekend',
    createdBy: 'maya',
    type: GroupType.trip,
    currency: p.currency,
    members: [for (final id in _ids) GroupMember(id: id, name: _names[id]!)],
  );
  return FakeLedgerRepository(
    groups: [g],
    groupBills: {
      'g1': [
        _bill(p, 'b1', 'Dinner at Lumen', 'maya', {'maya': 20, 'leo': 31, 'sara': 28, 'omar': 22, 'yuki': 24, 'ana': 18}, groupId: 'g1', paid: {'sara'}),
        _bill(p, 'b2', 'Tram passes', 'leo', {'maya': 12, 'leo': 12, 'sara': 12}, groupId: 'g1'),
      ],
    },
    recentBills: [
      _bill(p, 'r1', 'Brunch at Fig & Olive', 'maya', {'maya': 18, 'ana': 22, 'yuki': 20}, date: DateTime(2026, 11, 3), paid: {'ana'}),
      _bill(p, 'r2', 'Cinema night', 'omar', {'maya': 11, 'omar': 11, 'leo': 11}, date: DateTime(2026, 11, 1)),
      _bill(p, 'r3', 'Groceries', 'maya', {'maya': 30, 'sara': 30}, date: DateTime(2026, 10, 28), paid: {'sara'}),
    ],
  );
}
