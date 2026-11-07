import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:split_bill_app/bill_flow/voice/speech_engine.dart';
import 'package:split_bill_app/bill_flow/voice/voice_logic.dart';
import 'package:split_bill_app/config/feature_costs.dart';
import 'package:split_bill_app/config/supported_preferences.dart';
import 'package:split_bill_app/helpers/rewarded_ad_helper.dart';
import 'package:split_bill_app/providers/app_settings_provider.dart';
import 'package:split_bill_app/screens/scan_receipt/widgets/no_points_dialog.dart';
import 'package:split_bill_app/services/bill_intelligence_service.dart';
import 'package:split_bill_app/services/revenue_cat_service.dart';
import 'package:split_bill_app/services/voice_service.dart';
import 'package:split_bill_app/widgets/pal_avatar.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:url_launcher/url_launcher.dart';

/// "Assign by voice" bottom sheet (People board 4, "Voice, understood live").
///
/// Speech is recognised on the device (`speech_to_text`) with a live
/// transcript; only the text goes to `voice/assign/`. When on-device
/// recognition is unavailable it records audio and has the server transcribe
/// it instead.
///
/// Pops, on Done:
/// * `Map<String, List<String>>` item index -> participant ids, when the
///   result has no per-unit splits;
/// * otherwise a map with `'assignments'` (as above) and `'splits'`
///   (`Map<String, Map<String, int>>`, item -> units per participant);
/// * `null` when cancelled or the user chose to assign by tapping.
class VoiceCommandOverlay extends StatefulWidget {
  const VoiceCommandOverlay({
    super.key,
    required this.receiptData,
    required this.participants,
    this.speechEngine,
    this.recorder,
    this.assignService,
    this.currentUserId,
    this.pointsGate,
    this.initialLanguage,
    this.openSettings,
  });

  final Map<String, dynamic> receiptData;
  final List<Map<String, dynamic>> participants;

  /// Seams for tests; real implementations are used when null.
  final SpeechEngine? speechEngine;
  final VoiceRecorder? recorder;
  final BillIntelligenceService? assignService;

  /// Signed-in uid (the host). Defaults to FirebaseAuth.
  final String? Function()? currentUserId;

  /// Premium / points check before listening. Defaults to the Firestore
  /// points check with [NoPointsDialog] and rewarded ads.
  final Future<bool> Function(BuildContext context)? pointsGate;

  /// Speech language code; defaults to the app language.
  final String? initialLanguage;

  /// Opens the system settings for this app.
  final Future<void> Function()? openSettings;

  /// Pushes the sheet over the current route (dim backdrop, no page change).
  static Future<Object?> show(
    BuildContext context, {
    required Map<String, dynamic> receiptData,
    required List<Map<String, dynamic>> participants,
  }) {
    return Navigator.of(context).push<Object?>(
      PageRouteBuilder<Object?>(
        opaque: false,
        barrierDismissible: false,
        transitionDuration: AppMotion.durationFor(context, AppMotion.slow),
        reverseTransitionDuration: AppMotion.durationFor(
          context,
          AppMotion.medium,
        ),
        pageBuilder: (_, _, _) => VoiceCommandOverlay(
          receiptData: receiptData,
          participants: participants,
        ),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  State<VoiceCommandOverlay> createState() => _VoiceCommandOverlayState();
}

enum _Phase {
  language,
  starting,
  listening,
  recording,
  transcribing,
  assigning,
  review,
  permissionDenied,
  error,
}

enum _ErrorKind {
  offline,
  timeout,
  noCredits,
  rateLimited,
  noSpeech,
  noMatch,
  unknown,
}

class _VoiceCommandOverlayState extends State<VoiceCommandOverlay>
    with WidgetsBindingObserver {
  late final SpeechEngine _engine = widget.speechEngine ?? SpeechToTextEngine();
  late final VoiceRecorder _recorder = widget.recorder ?? ServerVoiceRecorder();
  late final BillIntelligenceService _assign =
      widget.assignService ?? BillIntelligenceService();
  late final List<VoiceItemRow> _items = voiceItemsFrom(widget.receiptData);

  _Phase _phase = _Phase.language;
  _ErrorKind _errorKind = _ErrorKind.unknown;
  bool _errorFromAssign = false;

  String _language = 'en';
  bool _languageInitialized = false;

  /// On-device recognition is out (unavailable / no locale): record instead.
  bool _useServer = false;
  bool _engineReady = false;
  String? _localeId;

  String _lastWords = '';
  TranscriptSplit _split = const TranscriptSplit('', '');
  String? _transcript;
  String _source = 'on_device';
  VoiceAssignResult? _result;

  double _level = 0;
  final SoundLevelNormalizer _speechLevels = SoundLevelNormalizer();
  final SoundLevelNormalizer _recordLevels = SoundLevelNormalizer.dbfs();
  StreamSubscription<double>? _levelSub;
  Timer? _stopSafety;
  Timer? _recordLimit;
  bool _stopping = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_languageInitialized) return;
    _languageInitialized = true;
    var code = widget.initialLanguage;
    if (code == null) {
      try {
        code = context.read<AppSettingsProvider>().locale.languageCode;
      } on ProviderNotFoundException {
        code = Localizations.maybeLocaleOf(context)?.languageCode;
      }
    }
    if (supportedLocaleOptions.any((o) => o.code == code)) _language = code!;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from Settings with the microphone turned on: try again.
    if (state == AppLifecycleState.resumed &&
        _phase == _Phase.permissionDenied) {
      _recheckPermission();
    }
  }

  Future<void> _recheckPermission() async {
    final granted = await _engine.hasPermission();
    if (granted && mounted && _phase == _Phase.permissionDenied) {
      _engineReady = false;
      _startCapture();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopSafety?.cancel();
    _recordLimit?.cancel();
    _levelSub?.cancel();
    if (_phase == _Phase.listening) _engine.cancel();
    if (_phase == _Phase.recording) _recorder.cancel();
    _recorder.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ flow

  Future<void> _selectLanguage(String code) async {
    AppHaptics.selection();
    setState(() => _language = code);
    final gate = widget.pointsGate ?? _defaultPointsGate;
    if (!await gate(context)) return;
    if (!mounted) return;
    _startCapture();
  }

  Future<void> _startCapture() async {
    _stopSafety?.cancel();
    _recordLimit?.cancel();
    setState(() {
      _phase = _Phase.starting;
      _lastWords = '';
      _split = const TranscriptSplit('', '');
      _transcript = null;
      _result = null;
      _level = 0;
      _stopping = false;
    });

    if (!_useServer && !_engineReady) {
      final ok = await _engine.initialize(
        onError: _onSpeechError,
        onStatus: _onSpeechStatus,
      );
      if (!mounted) return;
      if (!ok) {
        if (!await _engine.hasPermission()) {
          _showPermissionDenied();
          return;
        }
        _useServer = true;
      } else {
        _engineReady = true;
        final ids = await _engine.localeIds();
        final system = await _engine.systemLocaleId();
        _localeId = matchSpeechLocale(_language, ids, systemLocaleId: system);
        if (_localeId == null) _useServer = true;
      }
    }
    if (!mounted) return;
    if (_useServer) {
      await _startRecording();
    } else {
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    AppHaptics.light();
    setState(() => _phase = _Phase.listening);
    try {
      await _engine.listen(
        localeId: _localeId!,
        onResult: _onSpeechResult,
        onSoundLevel: (raw) {
          if (!mounted || _phase != _Phase.listening) return;
          setState(() => _level = _speechLevels.normalize(raw));
        },
      );
    } catch (e) {
      debugPrint('Voice listen failed, using server fallback: $e');
      if (!mounted) return;
      _useServer = true;
      await _startRecording();
    }
  }

  void _onSpeechResult(String words, bool isFinal) {
    if (!mounted || _phase != _Phase.listening) return;
    setState(() {
      _split = splitTranscript(_lastWords, words, isFinal: isFinal);
      _lastWords = words;
    });
    if (isFinal) _finishListening();
  }

  void _onSpeechError(String code, bool permanent) {
    if (!mounted || _phase != _Phase.listening) return;
    debugPrint('Speech error: $code (permanent: $permanent)');
    if (code == SpeechErrorCodes.permission) {
      _showPermissionDenied();
      return;
    }
    if (_split.full.trim().isNotEmpty) {
      _finishListening();
      return;
    }
    if (code == SpeechErrorCodes.noMatch ||
        code == SpeechErrorCodes.speechTimeout) {
      _showError(_ErrorKind.noSpeech, fromAssign: false);
      return;
    }
    // On-device recognition can't run here (language pack, service...):
    // keep the old path and record for the server.
    _useServer = true;
    _engine.cancel();
    _startRecording();
  }

  void _onSpeechStatus(String status) {
    if (!mounted || _phase != _Phase.listening) return;
    if (status == 'done') {
      _finishListening();
    } else if (status == 'notListening' && !_stopping) {
      // Stopped on its own (pause or time limit): wait for the final words.
      _armStopSafety();
    }
  }

  Future<void> _stopListening() async {
    _stopping = true;
    _armStopSafety();
    try {
      await _engine.stop();
    } catch (e) {
      debugPrint('Speech stop failed: $e');
      _finishListening();
    }
  }

  void _armStopSafety() {
    _stopSafety?.cancel();
    _stopSafety = Timer(const Duration(milliseconds: 2500), _finishListening);
  }

  void _finishListening() {
    _stopSafety?.cancel();
    if (!mounted || _phase != _Phase.listening) return;
    final text = _split.full.trim();
    if (text.isEmpty) {
      _showError(_ErrorKind.noSpeech, fromAssign: false);
      return;
    }
    setState(() => _split = TranscriptSplit(text, ''));
    _runAssign(text, 'on_device');
  }

  Future<void> _startRecording() async {
    try {
      await _recorder.start();
    } on VoiceCaptureException catch (e) {
      if (!mounted) return;
      if (e.failure == VoiceCaptureFailure.permissionDenied) {
        _showPermissionDenied();
      } else {
        _showError(_ErrorKind.unknown, fromAssign: false);
      }
      return;
    } catch (e) {
      debugPrint('Voice recording failed: $e');
      if (mounted) _showError(_ErrorKind.unknown, fromAssign: false);
      return;
    }
    if (!mounted) return;
    AppHaptics.light();
    setState(() => _phase = _Phase.recording);
    _levelSub?.cancel();
    _levelSub = _recorder.levels().listen((raw) {
      if (!mounted || _phase != _Phase.recording) return;
      setState(() => _level = _recordLevels.normalize(raw));
    }, onError: (_) {});
    _recordLimit = Timer(const Duration(seconds: 60), _finishRecording);
  }

  Future<void> _finishRecording() async {
    if (!mounted || _phase != _Phase.recording) return;
    _recordLimit?.cancel();
    unawaited(_levelSub?.cancel());
    _levelSub = null;
    setState(() {
      _phase = _Phase.transcribing;
      _level = 0;
    });
    try {
      final text = await _recorder.stopAndTranscribe(language: _language);
      if (!mounted) return;
      setState(() => _split = TranscriptSplit(text.trim(), ''));
      await _runAssign(text.trim(), 'server');
    } on VoiceCaptureException catch (e) {
      if (!mounted) return;
      _showError(switch (e.failure) {
        VoiceCaptureFailure.offline => _ErrorKind.offline,
        VoiceCaptureFailure.timeout => _ErrorKind.timeout,
        VoiceCaptureFailure.noSpeech => _ErrorKind.noSpeech,
        VoiceCaptureFailure.permissionDenied ||
        VoiceCaptureFailure.unknown => _ErrorKind.unknown,
      }, fromAssign: false);
    } catch (e) {
      debugPrint('Voice transcription failed: $e');
      if (mounted) _showError(_ErrorKind.unknown, fromAssign: false);
    }
  }

  Future<void> _runAssign(String text, String source) async {
    setState(() {
      _phase = _Phase.assigning;
      _transcript = text;
      _source = source;
      _result = null;
    });
    final uid = (widget.currentUserId ?? _defaultUid)();
    final hostId = resolveHostId(uid, widget.participants);
    try {
      final result = await _assign.assignItemsByVoice(
        receiptItems: [
          for (final e in (widget.receiptData['items'] as List? ?? const []))
            Map<String, dynamic>.from(e as Map),
        ],
        participants: widget.participants,
        transcript: text,
        currentUserId: hostId,
        aliases: buildVoiceAliases(
          participants: widget.participants,
          hostId: hostId,
          languageCode: _language,
        ),
        transcriptSource: source,
      );
      if (!mounted) return;
      if (result.isEmpty) {
        _showError(_ErrorKind.noMatch, fromAssign: false);
        return;
      }
      AppHaptics.selection();
      setState(() {
        _result = result;
        _phase = _Phase.review;
      });
    } on VoiceAssignException catch (e) {
      if (!mounted) return;
      _showError(switch (e.failure) {
        VoiceAssignFailure.offline => _ErrorKind.offline,
        VoiceAssignFailure.timeout => _ErrorKind.timeout,
        VoiceAssignFailure.noCredits => _ErrorKind.noCredits,
        VoiceAssignFailure.rateLimited => _ErrorKind.rateLimited,
        VoiceAssignFailure.unknown => _ErrorKind.unknown,
      }, fromAssign: true);
    } catch (e) {
      debugPrint('Voice assign failed: $e');
      if (mounted) _showError(_ErrorKind.unknown, fromAssign: true);
    }
  }

  void _showPermissionDenied() {
    _stopSafety?.cancel();
    _recordLimit?.cancel();
    _levelSub?.cancel();
    AppHaptics.error();
    setState(() => _phase = _Phase.permissionDenied);
  }

  void _showError(_ErrorKind kind, {required bool fromAssign}) {
    _stopSafety?.cancel();
    _recordLimit?.cancel();
    AppHaptics.error();
    setState(() {
      _phase = _Phase.error;
      _errorKind = kind;
      _errorFromAssign = fromAssign && _transcript != null;
    });
  }

  Future<void> _retry() async {
    if (_errorFromAssign && _transcript != null) {
      if (_errorKind == _ErrorKind.noCredits) {
        final gate = widget.pointsGate ?? _defaultPointsGate;
        if (!await gate(context) || !mounted) return;
      }
      // The service sends a fresh requestId on every attempt.
      await _runAssign(_transcript!, _source);
    } else {
      await _startCapture();
    }
  }

  void _onDone() {
    switch (_phase) {
      case _Phase.listening:
        _stopListening();
      case _Phase.recording:
        _finishRecording();
      case _Phase.review:
        final result = _result;
        if (result == null) return;
        AppHaptics.success();
        Navigator.of(context).pop(voicePopValue(result));
      default:
        break;
    }
  }

  void _cancel() {
    if (_phase == _Phase.listening) _engine.cancel();
    if (_phase == _Phase.recording) _recorder.cancel();
    _phase = _Phase.language; // dispose must not cancel twice
    Navigator.of(context).pop();
  }

  void _assignByTapping() => _cancel();

  Future<void> _openSettings() async {
    if (widget.openSettings != null) return widget.openSettings!();
    var opened = false;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        opened = await launchUrl(Uri.parse('app-settings:'));
      } catch (_) {
        opened = false;
      }
    }
    if (!opened && mounted) {
      AppToast.show(context, message: 'bf_voice_settings_hint'.tr());
    }
  }

  static String? _defaultUid() => FirebaseAuth.instance.currentUser?.uid;

  Future<bool> _defaultPointsGate(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      if (RevenueCatService.isUserActivePremium(data)) return true;
      final points = (data?['points'] as num?)?.toInt() ?? 0;
      if (points >= FeatureCosts.voiceCommandPoints) return true;
      if (context.mounted) {
        await NoPointsDialog.show(
          context,
          requiredPoints: FeatureCosts.voiceCommandPoints,
          onWatchAd: _watchAdForPoint,
          feature: NoPointsFeature.voice,
        );
      }
      return false;
    } catch (e) {
      debugPrint('Voice points check failed: $e');
      if (context.mounted) {
        AppToast.show(
          context,
          message: 'bf_voice_points_check_failed'.tr(),
          type: AppToastType.error,
        );
      }
      return false;
    }
  }

  Future<void> _watchAdForPoint() async {
    if (await RewardedAdHelper.isDailyCapReached()) {
      if (!mounted) return;
      AppToast.show(
        context,
        message: 'ad_daily_cap_reached'.tr(),
        type: AppToastType.info,
      );
      return;
    }
    if (!mounted) return;
    if (!RewardedAdHelper.isReady) {
      AppToast.show(
        context,
        message: 'fetching_an_ad_please_try_again_in_a_moment'.tr(),
        type: AppToastType.info,
      );
      try {
        // Same as the scanner: start the load so the next tap can show it.
        await RewardedAdHelper.loadAd();
      } catch (e) {
        debugPrint('Ad failed to initialize: $e');
      }
      return;
    }
    await RewardedAdHelper.showAdAndReward(
      onRewardEarned: () {
        if (mounted) {
          AppToast.show(
            context,
            message: 'plus_1_point_earned'.tr(),
            type: AppToastType.success,
          );
        }
      },
      onAdFailed: () {
        if (mounted) {
          AppToast.show(
            context,
            message: 'ad_failed_to_load_please_try_again'.tr(),
            type: AppToastType.error,
          );
        }
      },
    );
  }

  // ------------------------------------------------------------------- UI

  bool get _busy =>
      _phase == _Phase.starting ||
      _phase == _Phase.transcribing ||
      _phase == _Phase.assigning;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final media = MediaQuery.of(context);
    final reduce = AppMotion.reduceMotion(context);
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _busy ? null : _cancel,
              child: Semantics(
                label: 'cancel'.tr(),
                button: true,
                child: ColoredBox(color: p.scrim),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: reduce ? 0 : 1, end: 0),
              duration: AppMotion.durationFor(context, AppMotion.slow),
              curve: AppMotion.emphasizedDecelerate,
              builder: (context, t, child) => FractionalTranslation(
                translation: Offset(0, t * 0.25),
                child: Opacity(opacity: 1 - t, child: child),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: media.size.height * 0.9,
                  maxWidth: 600,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: AppRadii.sheetRadius,
                    border: Border(top: BorderSide(color: p.border)),
                  ),
                  child: SafeArea(
                    top: false,
                    minimum: const EdgeInsets.only(bottom: AppSpacing.xxl),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        AppSpacing.xl,
                        10,
                        AppSpacing.xl,
                        AppSpacing.lg,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 36,
                            height: 5,
                            margin: const EdgeInsets.only(bottom: 18),
                            decoration: BoxDecoration(
                              color: p.borderStrong,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          Flexible(
                            child: AnimatedSwitcher(
                              duration: AppMotion.durationFor(
                                context,
                                AppMotion.medium,
                              ),
                              child: KeyedSubtree(
                                key: ValueKey(_contentKey),
                                child: _buildContent(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _contentKey => switch (_phase) {
    _Phase.language => 'language',
    _Phase.permissionDenied => 'permission',
    _Phase.error => 'error-$_errorKind',
    _ => 'live',
  };

  Widget _buildContent() => switch (_phase) {
    _Phase.language => _buildLanguageStep(),
    _Phase.permissionDenied => _buildPermissionDenied(),
    _Phase.error => _buildError(),
    _ => _buildLive(),
  };

  Widget _buildLanguageStep() {
    final p = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'select_language'.tr(),
          textAlign: TextAlign.center,
          style: AppTypography.titleLarge.copyWith(color: p.textPrimary),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'choose_the_language_you_will_speak'.tr(),
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(color: p.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),
        Flexible(
          child: SingleChildScrollView(
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.center,
              children: [
                for (final option in supportedLocaleOptions)
                  _LanguageChip(
                    key: ValueKey('bf_voice_lang_${option.code}'),
                    option: option,
                    selected: option.code == _language,
                    onTap: () => _selectLanguage(option.code),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _PillButton.outline(label: 'cancel'.tr(), onPressed: _cancel),
      ],
    );
  }

  Widget _buildPermissionDenied() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: ErrorState(
          icon: AppIcons.micOff,
          title: 'bf_voice_mic_off_title'.tr(),
          message: 'bf_voice_mic_off_message'.tr(),
          retryLabel: 'bf_voice_open_settings'.tr(),
          onRetry: _openSettings,
          secondaryLabel: 'bf_voice_assign_by_tapping'.tr(),
          onSecondary: _assignByTapping,
        ),
      ),
    );
  }

  Widget _buildError() {
    final (title, message, icon) = switch (_errorKind) {
      _ErrorKind.offline => (
        'feedback_offline_title'.tr(),
        'bf_voice_error_offline'.tr(),
        AppIcons.wifiOff,
      ),
      _ErrorKind.timeout => (
        'bf_voice_error_timeout_title'.tr(),
        'bf_voice_error_timeout'.tr(),
        AppIcons.hourglass,
      ),
      _ErrorKind.noCredits => (
        'bf_voice_error_no_credits_title'.tr(),
        'bf_voice_error_no_credits'.tr(),
        AppIcons.coins,
      ),
      _ErrorKind.rateLimited => (
        'bf_voice_error_busy_title'.tr(),
        'bf_voice_error_busy'.tr(),
        AppIcons.hourglass,
      ),
      _ErrorKind.noSpeech => (
        'bf_voice_error_no_speech_title'.tr(),
        'bf_voice_error_no_speech'.tr(),
        AppIcons.earOff,
      ),
      _ErrorKind.noMatch => (
        'bf_voice_error_no_match_title'.tr(),
        'bf_voice_error_no_match'.tr(),
        AppIcons.help,
      ),
      _ErrorKind.unknown => (
        'bf_voice_error_unknown_title'.tr(),
        'bf_voice_error_unknown'.tr(),
        AppIcons.error,
      ),
    };
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: ErrorState(
          icon: icon,
          title: title,
          message: message,
          retryLabel: 'feedback_try_again'.tr(),
          onRetry: _retry,
          secondaryLabel: 'bf_voice_assign_by_tapping'.tr(),
          onSecondary: _assignByTapping,
        ),
      ),
    );
  }

  Widget _buildLive() {
    final p = context.palette;
    final live = _phase == _Phase.listening || _phase == _Phase.recording;
    final result = _result;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatusPill(
          key: const ValueKey('bf_voice_status'),
          label: switch (_phase) {
            _Phase.review => 'done'.tr(),
            _Phase.listening || _Phase.recording => 'listening'.tr(),
            _ => 'thinking'.tr(),
          },
          live: live,
          done: _phase == _Phase.review,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 56,
          child: _LevelBars(level: _level, live: live),
        ),
        const SizedBox(height: 14),
        Container(
          constraints: const BoxConstraints(minHeight: 96),
          padding: const EdgeInsets.all(16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: p.surfaceVariant,
            borderRadius: AppRadii.cardRadius,
            border: Border.all(color: p.border),
          ),
          child: _buildTranscript(),
        ),
        const SizedBox(height: 16),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ItemCard(
                  items: _items,
                  participants: widget.participants,
                  result: result,
                  heardText: _split.full,
                  phase: _phase,
                ),
                if (result != null && result.ambiguous.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  for (final a in result.ambiguous)
                    if (a.text.trim().isNotEmpty) _AmbiguityNote(text: a.text),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (_phase == _Phase.review)
          Center(
            child: TextButton(
              onPressed: _startCapture,
              style: TextButton.styleFrom(
                foregroundColor: p.textPrimary,
                minimumSize: const Size(44, 44),
              ),
              child: Text('bf_voice_say_again'.tr()),
            ),
          )
        else
          Text(
            (_useServer ? 'bf_voice_server_note' : 'bf_voice_privacy_note')
                .tr(),
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              color: p.textSecondary,
              fontSize: 12,
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: _PillButton.outline(
                label: 'cancel'.tr(),
                onPressed: _cancel,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PillButton.ink(
                key: const ValueKey('bf_voice_done'),
                label: 'done'.tr(),
                loading: _busy,
                onPressed: (live || _phase == _Phase.review) ? _onDone : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTranscript() {
    final p = context.palette;
    final style = AppTypography.bodyLarge.copyWith(
      fontSize: 20,
      height: 1.4,
      fontWeight: FontWeight.w500,
      color: p.textPrimary,
    );
    if (_phase == _Phase.transcribing ||
        (_phase == _Phase.starting && _split.isEmpty)) {
      return Semantics(
        label: 'bf_voice_turning_into_text'.tr(),
        child: const Column(
          children: [
            Skeleton.line(width: 260, height: 20),
            SizedBox(height: AppSpacing.sm),
            Skeleton.line(width: 180, height: 20),
          ],
        ),
      );
    }
    if (_split.isEmpty) {
      return Text(
        _phase == _Phase.recording
            ? 'bf_voice_recording_hint'.tr()
            : 'bf_voice_hint'.tr(),
        key: const ValueKey('bf_voice_transcript_hint'),
        textAlign: TextAlign.center,
        style: style.copyWith(color: p.textSecondary),
      );
    }
    final listening = _phase == _Phase.listening;
    final settled = _split.settled;
    final tail = _split.tail;
    return Semantics(
      liveRegion: true,
      label: _split.full,
      child: ExcludeSemantics(
        child: Text.rich(
          key: const ValueKey('bf_voice_transcript'),
          TextSpan(
            children: [
              TextSpan(text: '“$settled'),
              if (tail.isNotEmpty)
                TextSpan(
                  text: '${settled.isEmpty ? '' : ' '}$tail',
                  style: TextStyle(color: p.textSecondary),
                ),
              TextSpan(
                text: listening ? '…”' : '”',
                style: TextStyle(
                  color: listening ? p.textSecondary : p.textPrimary,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
          style: style,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- pieces

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    super.key,
    required this.label,
    required this.live,
    required this.done,
  });
  final String label;
  final bool live;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: live || done ? p.accentSoft : p.surfaceVariant,
          borderRadius: AppRadii.fullRadius,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              done
                  ? AppIcons.successFill
                  : (live ? AppIcons.mic : AppIcons.hourglass),
              size: 16,
              color: live || done ? p.accent : p.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.labelLarge.copyWith(
                color: live || done ? p.onAccentSoft : p.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
    super.key,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final LocaleOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      label: option.nativeName,
      child: Material(
        color: selected ? p.accentSoft : p.surface,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? p.accent : p.border),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                    child: Text(
                      option.flag,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    option.nativeName,
                    style: AppTypography.labelLarge.copyWith(
                      color: selected ? p.onAccentSoft : p.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Twenty-four mint level bars. They follow the microphone level while [live]; static
/// under reduce motion.
class _LevelBars extends StatefulWidget {
  const _LevelBars({required this.level, required this.live});
  final double level;
  final bool live;

  @override
  State<_LevelBars> createState() => _LevelBarsState();
}

class _LevelBarsState extends State<_LevelBars>
    with SingleTickerProviderStateMixin {
  static const _delays = [
    0.0,
    .1,
    .2,
    .3,
    .15,
    .25,
    .05,
    .35,
    .12,
    .22,
    .32,
    .08,
    .18,
    .28,
    .02,
    .38,
    .14,
    .24,
    .34,
    .06,
    .16,
    .26,
    .36,
    .04,
  ];
  static const _still = [
    .45,
    .7,
    1.0,
    .6,
    .85,
    .5,
    .9,
    .4,
    .55,
    .8,
    .65,
    .95,
    .5,
    .75,
    .4,
    .9,
    .6,
    .85,
    .45,
    .7,
    .55,
    .8,
    .5,
    .65,
  ];
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _LevelBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final animate = widget.live && !AppMotion.reduceMotion(context);
    if (animate && !_wave.isAnimating) {
      _wave.repeat();
    } else if (!animate && _wave.isAnimating) {
      _wave.stop();
    }
  }

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final reduce = AppMotion.reduceMotion(context);
    final color = widget.live ? p.accent : p.borderStrong;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _wave,
        builder: (context, _) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _delays.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Container(
                width: 3,
                height: 52 * _scale(i, reduce),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  double _scale(int i, bool reduce) {
    if (reduce || !widget.live) return widget.live ? _still[i] : .25;
    final wave = 0.5 - 0.5 * math.cos(2 * math.pi * (_wave.value - _delays[i]));
    final amp = 0.3 + 0.7 * widget.level.clamp(0.0, 1.0);
    return (0.25 + 0.75 * wave * amp).clamp(0.25, 1.0);
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.items,
    required this.participants,
    required this.result,
    required this.heardText,
    required this.phase,
  });

  final List<VoiceItemRow> items;
  final List<Map<String, dynamic>> participants;
  final VoiceAssignResult? result;
  final String heardText;
  final _Phase phase;

  String _nameOf(String id) {
    for (final p in participants) {
      if (p['id']?.toString() == id) {
        final first = firstNameOf(p['name']);
        return first.isEmpty ? id : first;
      }
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: p.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) _row(context, items[i], i),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, VoiceItemRow item, int index) {
    final p = context.palette;
    final r = result;
    final people = r == null ? const <String>[] : peopleOnItem(r, item.key);
    final unassigned =
        r != null &&
        (people.isEmpty || r.unassignedItemKeys.contains(item.key));
    final label = item.qty > 1 ? '${item.name} ×${item.qty}' : item.name;

    Widget trailing;
    if (r != null && !unassigned) {
      final units = r.splits[item.key];
      trailing = Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.end,
        children: [
          for (final id in people)
            AvatarHop(
              child: _PersonChip(
                seed: id,
                label: units?[id] != null
                    ? '${_nameOf(id)} ×${units![id]}'
                    : _nameOf(id),
                tint: p.avatarTintFor(id),
              ),
            ),
        ],
      );
    } else if (unassigned) {
      trailing = Text(
        'bf_voice_not_assigned'.tr(),
        style: AppTypography.bodySmall.copyWith(color: p.oweInk, fontSize: 13),
      );
    } else if (phase == _Phase.assigning) {
      trailing = const Skeleton(
        width: 56,
        height: 28,
        borderRadius: AppRadii.fullRadius,
      );
    } else if (phase == _Phase.listening &&
        itemMentioned(item.name, heardText)) {
      trailing = Text(
        'bf_voice_listening'.tr(),
        style: AppTypography.bodySmall.copyWith(
          color: p.textSecondary,
          fontSize: 13,
        ),
      );
    } else {
      trailing = const SizedBox.shrink();
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 50),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: unassigned ? p.oweSoft : null,
        border: index == 0
            ? null
            : Border(top: BorderSide(color: p.borderSubtle)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                color: p.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Flexible(child: trailing),
        ],
      ),
    );
  }
}

class _PersonChip extends StatelessWidget {
  const _PersonChip({
    required this.label,
    required this.tint,
    required this.seed,
  });
  final String label;
  final Color tint;
  final String seed;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      height: 30,
      padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 10, 0),
      decoration: BoxDecoration(
        color: p.accentSoft,
        borderRadius: AppRadii.fullRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PalAvatar(seed: seed, name: label, size: 22),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelMedium.copyWith(
                color: p.onAccentSoft,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmbiguityNote extends StatelessWidget {
  const _AmbiguityNote({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(AppIcons.info, size: 16, color: p.owe),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodySmall.copyWith(
                color: p.oweInk,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton.ink({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  }) : outlined = false;

  const _PillButton.outline({required this.label, required this.onPressed})
    : outlined = true,
      loading = false;

  final String label;
  final VoidCallback? onPressed;
  final bool outlined;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Text(
      label,
      style: AppTypography.labelLarge.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
    if (outlined) {
      return SizedBox(
        height: 52,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            shape: const StadiumBorder(),
            backgroundColor: p.surface,
            foregroundColor: p.textPrimary,
            side: BorderSide(color: p.borderStrong),
          ),
          child: text,
        ),
      );
    }
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          backgroundColor: p.inverseSurface,
          foregroundColor: p.onInverseSurface,
          disabledBackgroundColor: loading ? p.inverseSurface : p.surfaceMuted,
          disabledForegroundColor: loading
              ? p.onInverseSurface
              : p.textDisabled,
        ),
        child: loading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: p.onInverseSurface,
                ),
              )
            : text,
      ),
    );
  }
}
