import 'package:flutter/widgets.dart';

/// Wraps easy_localization's delegate so [Localizations] reloads it each time
/// EasyLocalization rebuilds.
///
/// `context.locale` reads the controller's locale as soon as `setLocale`
/// starts, before the new file has loaded. Any MaterialApp rebuild in that
/// window (a settings provider notify, say) made [Localizations] load the new
/// locale with the old strings, and the stock delegate's `shouldReload` is
/// always false, so the app kept the previous language until a restart.
/// EasyLocalization only rebuilds (and creates a new delegate) once the
/// translations are in, so reloading on a new inner delegate fixes that.
class FreshLocalizationsDelegate extends LocalizationsDelegate<dynamic> {
  const FreshLocalizationsDelegate(this.inner);

  final LocalizationsDelegate<dynamic> inner;

  @override
  Type get type => inner.type;

  @override
  bool isSupported(Locale locale) => inner.isSupported(locale);

  @override
  Future<dynamic> load(Locale locale) => inner.load(locale);

  @override
  bool shouldReload(covariant FreshLocalizationsDelegate old) =>
      !identical(old.inner, inner) || inner.shouldReload(old.inner);
}

/// EasyLocalization's delegates with its own one made reloadable.
List<LocalizationsDelegate<dynamic>> freshDelegates(
  List<LocalizationsDelegate<dynamic>> delegates,
) => [
  if (delegates.isNotEmpty) FreshLocalizationsDelegate(delegates.first),
  ...delegates.skip(1),
];

/// Rebuilds the whole subtree whenever [Localizations] reloads.
///
/// Most labels call `'key'.tr()` without a context, so they never depend on
/// [Localizations]; const screens (the home IndexedStack pages) kept the old
/// language after a switch. [Localizations] notifies only once the new
/// resources have loaded, so marking every element dirty then shows the new
/// language while keeping all widget state (navigation, tab, scroll).
class LocaleRebuilder extends StatefulWidget {
  const LocaleRebuilder({super.key, required this.child});

  final Widget child;

  @override
  State<LocaleRebuilder> createState() => _LocaleRebuilderState();
}

class _LocaleRebuilderState extends State<LocaleRebuilder> {
  bool _first = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribes to the Localizations scope (any reload notifies).
    Localizations.maybeLocaleOf(context);
    if (_first) {
      _first = false;
      return;
    }
    void mark(Element e) {
      e.markNeedsBuild();
      e.visitChildren(mark);
    }

    (context as Element).visitChildren(mark);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
