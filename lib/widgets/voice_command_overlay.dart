import 'dart:ui';
import 'dart:async';
import 'package:easy_localization/easy_localization.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:split_bill_app/services/voice_service.dart';
import 'package:split_bill_app/services/bill_intelligence_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:split_bill_app/config/supported_preferences.dart';
import 'package:split_bill_app/screens/scan_receipt/widgets/no_points_dialog.dart';
import 'package:split_bill_app/helpers/rewarded_ad_helper.dart';
import 'package:split_bill_app/providers/app_settings_provider.dart';

class VoiceCommandOverlay extends StatefulWidget {
  final Map<String, dynamic> receiptData;
  final List<Map<String, dynamic>> participants;

  const VoiceCommandOverlay({
    super.key,
    required this.receiptData,
    required this.participants,
  });

  @override
  State<VoiceCommandOverlay> createState() => _VoiceCommandOverlayState();
}

class _VoiceCommandOverlayState extends State<VoiceCommandOverlay>
    with SingleTickerProviderStateMixin {
  static const Map<String, String> _languageFlags = {
    'ar': '🇪🇬',
    'en': '🇺🇸',
    'fr': '🇫🇷',
    'de': '🇩🇪',
    'ru': '🇷🇺',
    'id': '🇮🇩',
    'ur': '🇵🇰',
    'hi': '🇮🇳',
    'pl': '🇵🇱',
    'es': '🇪🇸',
    'it': '🇮🇹',
    'pt': '🇵🇹',
    'zh': '🇨🇳',
    'ko': '🇰🇷',
    'ja': '🇯🇵',
  };

  final VoiceService _voiceService = VoiceService();
  final BillIntelligenceService _aiService = BillIntelligenceService();

  // Animation
  late AnimationController _pulseController;

  // State
  bool _isListening = false;
  bool _isProcessingTranscript = false; // Processing Audio -> Text
  bool _isProcessingAssignment = false; // Processing Text -> Assignment
  bool _isSuccess = false;
  bool _hasError = false;
  bool _isLanguageSelectionStep =
      true; // New State: Start with Language Selection
  bool _languageInitialized = false;

  // Transcript Logic
  String? _transcript;
  String _statusText = "Tap to Speak";
  String _subStatusText = "Try: \"Split the appetizers between me and John\"";
  String _selectedLanguage = 'en';

  int _recordDuration = 0;

  // Stopwatch
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_languageInitialized) return;

    final localeCode = context.read<AppSettingsProvider>().locale.languageCode;
    if (supportedLocaleOptions.any((option) => option.code == localeCode)) {
      _selectedLanguage = localeCode;
    }
    _languageInitialized = true;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _voiceService.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_isListening) {
      await _stopAndTranscribe();
    } else {
      if (_transcript != null && !_isSuccess) {
        // If we have a transcript but user taps mic again -> Retry
        _retryRecording();
      } else {
        bool canProceed = await _checkPoints();
        if (canProceed) {
          await _startRecording();
        }
      }
    }
  }

  Future<bool> _checkPoints() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      final isPremium = data?['isPremium'] ?? false;
      final points = data?['points'] ?? 0;

      if (isPremium) return true;

      if (points <= 0) {
        if (mounted) {
          await NoPointsDialog.show(context, onWatchAd: _watchAdForPoint);
        }
        return false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _deductPoint() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if ((doc.data()?['isPremium'] ?? false) == false) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'points': FieldValue.increment(-1)});
      }
    } catch (_) {}
  }

  Future<void> _watchAdForPoint() async {
    if (!RewardedAdHelper.isReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ad_is_still_loading_please_try_again_in_a_moment').tr(),
          backgroundColor: Colors.blue,
        ),
      );
      return;
    }

    await RewardedAdHelper.showAdAndReward(
      onRewardEarned: () async {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('plus_1_point_earned').tr(),
              backgroundColor: Colors.green,
            ),
          );
        }
      },
      onAdFailed: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ad_failed_to_load_please_try_again').tr(),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }

  Future<void> _startRecording() async {
    try {
      HapticFeedback.mediumImpact();
      await _voiceService.startRecording();
      _stopwatch.reset();
      _stopwatch.start();
      setState(() {
        _isListening = true;
        _isSuccess = false;
        _statusText = 'listening'.tr();
        _subStatusText = 'say_your_command'.tr();
        _transcript = null;
      });

      // Update timer
      _startTimer();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            'error_with_details'.tr(
              namedArgs: {'error': _messageFromError(e)},
            ),
          ),
        ),
      );
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _recordDuration = _stopwatch.elapsed.inSeconds;
        });
      }
    });
  }

  Future<void> _stopAndTranscribe() async {
    _stopwatch.stop();
    _timer?.cancel();

    setState(() {
      _isListening = false;
      _isProcessingTranscript = true;
      _statusText = 'thinking'.tr();
      _subStatusText = 'analyzing_audio'.tr();
    });

    try {
      final path = await _voiceService.stopRecording();
      if (path != null) {
        final text = await _voiceService.transcribeAudio(
          path,
          language: _selectedLanguage,
        );
        if (mounted) {
          setState(() {
            _transcript = text;
            _isProcessingTranscript = false;
            _statusText = "Did you say?";
            // The transcript is shown in the special UI, so subtext can be simpler or hidden
            _subStatusText = "";
          });
        }
      } else {
        setState(() {
          _isProcessingTranscript = false;
          _statusText = "Error";
          _subStatusText = "No audio recorded";
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessingTranscript = false;
        _statusText = "Error";
        _subStatusText = _messageFromError(
          e,
          fallback: "Could not understand audio",
        );
      });
      debugPrint("Voice Error: $e");
    }
  }

  void _retryRecording() {
    _startRecording();
  }

  Future<void> _confirmAssignment() async {
    if (_transcript == null) return;

    setState(() {
      _isProcessingAssignment = true;
      _hasError = false; // Reset error state
      _statusText = "Assigning Items...";
      _subStatusText = "Applying your command...";
    });

    Map<String, List<String>>? assignments;

    try {
      // 1. Perform API Call logic safely
      assignments = await _aiService.assignItemsByVoice(
        receiptItems: (widget.receiptData['items'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
        participants: widget.participants,
        transcript: _transcript!,
      );

      // 2. Update State on Success
      if (mounted) {
        setState(() {
          _isProcessingAssignment = false;
          _isSuccess = true;
          _statusText = "Done!";
          _subStatusText = "Assignments updated";
        });
        HapticFeedback.lightImpact();
        await _deductPoint(); // Deduct point on success
      }
    } catch (e) {
      // 3. Handle API Errors Only
      if (mounted) {
        setState(() {
          _isProcessingAssignment = false;
          _hasError = true;
          _statusText = "Failed to Assign";
          _subStatusText = _messageFromError(
            e,
            fallback: "Please try again.",
          );
        });
      }
      return; // Exit early, do not attempt navigation
    }

    // 4. Navigation (Isolated from try-catch)
    // Wait briefly for the user to see "Done!"
    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted) {
      try {
        Navigator.pop(context, assignments);
      } catch (e) {
        debugPrint("Navigation pop failed (likely already closed): $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isProcessing = _isProcessingTranscript || _isProcessingAssignment;
    bool showConfirmation =
        _transcript != null && !isProcessing && !_isSuccess && !_isListening;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Minimal Blur
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: Container(
                color: Colors.black.withValues(
                  alpha: 0.01,
                ), // Almost clear as requested
              ),
            ),
          ),

          // Dismiss area
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                // Prevent dismissal if success (auto-closing) or processing
                if (!isProcessing &&
                    !showConfirmation &&
                    !_isListening &&
                    !_isSuccess) {
                  Navigator.pop(context);
                }
              },
              behavior: HitTestBehavior.translucent,
              child: Container(),
            ),
          ),

          // Close Button
          Positioned(
            top: 50,
            left: 20,
            child: GestureDetector(
              onTap: () {
                if (!_isSuccess) Navigator.of(context).maybePop();
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.black87,
                  size: 24,
                ),
              ),
            ),
          ),

          // Removed Positioned Language Selector (Now handled in Main Content)

          // Main Content
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 50),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _isLanguageSelectionStep
                      ? _buildLanguageSelectionView()
                      : Column(
                          key: const ValueKey("RecordingUI"),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (showConfirmation)
                              _buildConfirmationUI()
                            else
                              _buildStatusUI(),

                            const SizedBox(height: 40),

                            // The Orb
                            if (showConfirmation)
                              const SizedBox(height: 100)
                            else
                              _buildOrb(isProcessing),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusUI() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      key: ValueKey(_statusText),
      child: Column(
        children: [
          Text(
            _statusText,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.black45,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _isListening ? _formatDuration(_recordDuration) : _subStatusText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationUI() {
    return Column(
      children: [
        // Transcript Box
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Text('you_said',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ).tr(),
              const SizedBox(height: 8),
              Text(
                _transcript!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        if (_hasError)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                _subStatusText, // "Please try again"
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

        const SizedBox(height: 30),

        // Actions
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Retry Button
            _buildActionButton(
              icon: Icons.refresh_rounded,
              color: Colors.white,
              bgColor: Colors.grey.withValues(alpha: 0.8),
              onTap: _retryRecording,
              label: "Re-record",
            ),
            const SizedBox(width: 40),
            // Confirm Button
            _buildActionButton(
              icon: Icons.check_rounded,
              color: Colors.white,
              bgColor: const Color(0xFF00B365),
              onTap: _confirmAssignment,
              size: 70,
              label: "Confirm",
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
    double size = 60,
    String? label,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: size * 0.5),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              shadows: [Shadow(blurRadius: 2, color: Colors.black)],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLanguageSelectionView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('select_language',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ).tr(),
        const SizedBox(height: 8),
        Text('choose_the_language_you_will_speak',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ).tr(),
        const SizedBox(height: 32),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: supportedLocaleOptions
              .map(_buildLanguageCard)
              .toList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildLanguageCard(LocaleOption option) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        setState(() {
          _selectedLanguage = option.code;
          _isLanguageSelectionStep = false;
        });
      },
      child: Container(
        width: 118,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          children: [
            Text(
              _languageFlags[option.code] ?? '🌐',
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(height: 8),
            Text(
              option.nativeName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            if (option.nativeName != option.englishName) ...[
              const SizedBox(height: 4),
              Text(
                option.englishName,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrb(bool isProcessing) {
    return GestureDetector(
      onTap: _toggleRecording,
      child: SizedBox(
        height: 100,
        width: 100,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Pulse Ring
            if (_isListening || isProcessing)
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 100 + (_pulseController.value * 40),
                    height: 100 + (_pulseController.value * 40),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _getOrbColor().withValues(
                        alpha: 0.3 - (_pulseController.value * 0.3),
                      ),
                    ),
                  );
                },
              ),
            // Main Orb
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _getOrbGradient(),
                ),
                boxShadow: [
                  BoxShadow(
                    color: _getOrbColor().withValues(alpha: 0.6),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: isProcessing
                    ? const SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : Icon(
                        _isSuccess
                            ? Icons.check_rounded
                            : (_isListening
                                  ? Icons.graphic_eq_rounded
                                  : Icons.mic_rounded),
                        color: Colors.white,
                        size: 40,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getOrbColor() {
    if (_isSuccess) return Colors.greenAccent;
    if (_isProcessingAssignment || _isProcessingTranscript) {
      return Colors.purpleAccent;
    }
    if (_isListening) return Colors.redAccent;
    return Colors.blueAccent;
  }

  List<Color> _getOrbGradient() {
    if (_isSuccess) return [Colors.green.shade400, Colors.green.shade600];
    if (_isProcessingAssignment || _isProcessingTranscript) {
      return [Colors.purple.shade400, Colors.deepPurple.shade600];
    }
    if (_isListening) return [const Color(0xFFFF5252), const Color(0xFFD50000)];
    return [const Color(0xFF448AFF), const Color(0xFF2979FF)]; // Idle Blue
  }

  String _messageFromError(Object error, {String fallback = 'Something went wrong'}) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    if (message.isEmpty) {
      return fallback;
    }
    return message;
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }
}
