import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../transaction.dart';
import '../transaction_form.dart';
import '../transaction_model.dart';
import '../utils/micro_interactions.dart';
import '../voice_expense_service.dart';
import 'pill_chip.dart';

bool _voiceFlowActive = false;

Future<void> startVoiceExpenseFlow(BuildContext context) async {
  if (_voiceFlowActive) return;
  _voiceFlowActive = true;
  try {
    final model = Provider.of<TransactionModel>(context, listen: false);
    final draft = await showVoiceRecordingSheet(context);
    if (draft == null || !context.mounted) return;
    await showTransactionForm(
      context,
      draft.type,
      model.addTransaction,
      prefill: draft,
    );
  } finally {
    _voiceFlowActive = false;
  }
}

Future<Transaction?> showVoiceRecordingSheet(BuildContext context) {
  return showModalBottomSheet<Transaction>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    enableDrag: true,
    builder: (_) => const _VoiceRecordingSheet(),
  );
}

enum _VoiceState { recording, processing, error }

enum _ErrorKind { noSpeech, transcribeFailed, parseFailed }

class _VoiceRecordingSheet extends StatefulWidget {
  const _VoiceRecordingSheet();

  @override
  State<_VoiceRecordingSheet> createState() => _VoiceRecordingSheetState();
}

class _VoiceRecordingSheetState extends State<_VoiceRecordingSheet>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const Duration _maxDuration = Duration(seconds: 30);

  final AudioRecorder _recorder = AudioRecorder();
  final VoiceExpenseService _service = VoiceExpenseService();

  late final AnimationController _pulse;
  _VoiceState _state = _VoiceState.recording;
  _ErrorKind _errorKind = _ErrorKind.noSpeech;
  String _errorMessage = '';
  Timer? _timer;
  int _elapsedSeconds = 0;
  String? _audioPath;
  String? _transcript;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulse = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _startRecording());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _pulse.dispose();
    _recorder.stop().catchError((_) => null);
    _recorder.dispose();
    final path = _audioPath;
    if (path != null) {
      final file = File(path);
      file.exists().then((exists) {
        if (exists) file.delete().catchError((_) => file);
      });
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _state == _VoiceState.recording) {
      _stopAndProcess();
    }
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!mounted) return;
    if (!hasPermission) {
      _showError(
        _ErrorKind.noSpeech,
        'Microphone access is off. Enable it in Settings > Budgie.',
      );
      return;
    }
    if (_state != _VoiceState.recording) return;

    final previousPath = _audioPath;
    if (previousPath != null) {
      _audioPath = null;
      final previousFile = File(previousPath);
      if (await previousFile.exists()) {
        await previousFile.delete().catchError((_) => previousFile);
      }
      if (!mounted || _state != _VoiceState.recording) return;
    }

    final tempDir = await getTemporaryDirectory();
    if (!mounted || _state != _VoiceState.recording) return;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '${tempDir.path}/voice_expense_$timestamp.m4a';

    _audioPath = path;
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 32000,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
    if (!mounted || _state != _VoiceState.recording) return;

    MicroInteractions.mediumImpact();
    if (!MediaQuery.disableAnimationsOf(context)) _pulse.repeat();
    setState(() => _elapsedSeconds = 0);

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSeconds++);
      if (_elapsedSeconds >= _maxDuration.inSeconds) {
        _stopAndProcess();
      }
    });
  }

  Future<void> _stopAndProcess() async {
    if (_state != _VoiceState.recording) return;
    setState(() => _state = _VoiceState.processing);

    _timer?.cancel();
    _pulse.stop();
    MicroInteractions.lightImpact();

    await _recorder.stop();
    if (!mounted) return;
    await _transcribeAndParse();
  }

  Future<void> _transcribeAndParse() async {
    final path = _audioPath;
    if (path == null) {
      _showError(_ErrorKind.noSpeech, "Didn't catch anything — try again");
      return;
    }

    try {
      final transcript = await _service.transcribe(File(path));
      if (!mounted) return;
      _transcript = transcript;
      await _parseTranscript(transcript);
    } on VoiceExpenseException catch (error) {
      if (!mounted) return;
      _showError(_ErrorKind.noSpeech, error.message);
    } catch (_) {
      if (!mounted) return;
      _showError(
        _ErrorKind.transcribeFailed,
        'Something went wrong. Try again.',
      );
    }
  }

  Future<void> _parseTranscript(String transcript) async {
    try {
      final transaction = await _service.parse(transcript, DateTime.now());
      if (!mounted) return;
      Navigator.of(context).pop(transaction);
    } on VoiceExpenseException catch (error) {
      if (!mounted) return;
      _showError(_ErrorKind.parseFailed, error.message);
    } catch (_) {
      if (!mounted) return;
      _showError(_ErrorKind.parseFailed, 'Something went wrong. Try again.');
    }
  }

  void _showError(_ErrorKind kind, String message) {
    MicroInteractions.vibrate();
    setState(() {
      _state = _VoiceState.error;
      _errorKind = kind;
      _errorMessage = message;
    });
  }

  Future<void> _retry() async {
    switch (_errorKind) {
      case _ErrorKind.noSpeech:
        _restartRecording();
        break;
      case _ErrorKind.transcribeFailed:
        setState(() => _state = _VoiceState.processing);
        await _transcribeAndParse();
        break;
      case _ErrorKind.parseFailed:
        final transcript = _transcript;
        if (transcript == null) {
          _restartRecording();
          return;
        }
        setState(() => _state = _VoiceState.processing);
        await _parseTranscript(transcript);
        break;
    }
  }

  void _restartRecording() {
    setState(() {
      _state = _VoiceState.recording;
      _elapsedSeconds = 0;
    });
    _startRecording();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final processing = _state == _VoiceState.processing;

    return PopScope(
      canPop: !processing,
      child: GestureDetector(
        onVerticalDragUpdate: processing ? (_) {} : null,
        onVerticalDragEnd: processing ? (_) {} : null,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.getCard(isDark),
              border: Border.all(color: AppColors.getCardBorder(isDark)),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.getTextTertiaryColor(isDark)
                              .withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    _buildContent(isDark),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    switch (_state) {
      case _VoiceState.recording:
        return _buildRecording(isDark);
      case _VoiceState.processing:
        return _buildProcessing(isDark);
      case _VoiceState.error:
        return _buildError(isDark);
    }
  }

  Widget _buildRecording(bool isDark) {
    final accent = AppColors.getAccent(isDark);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'LISTENING',
          style: AppTypography.eyebrow.copyWith(color: accent),
        ),
        const SizedBox(height: 28),
        _buildPulsingMic(isDark, accent, reduceMotion),
        const SizedBox(height: 28),
        Text(
          _formatElapsed(_elapsedSeconds),
          style: AppTypography.numericMedium.copyWith(
            color: AppColors.getTextSecondaryColor(isDark),
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: PillButton(
            label: 'Stop',
            icon: Symbols.stop_rounded,
            color: accent,
            filled: true,
            height: 44,
            onPressed: _stopAndProcess,
          ),
        ),
      ],
    );
  }

  Widget _buildPulsingMic(bool isDark, Color accent, bool reduceMotion) {
    return Semantics(
      label: 'Recording',
      child: SizedBox(
        width: 120,
        height: 120,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final ping = Curves.easeOut.transform(_pulse.value);
            return Stack(
              alignment: Alignment.center,
              children: [
                if (!reduceMotion)
                  IgnorePointer(
                    child: Transform.scale(
                      scale: 1 + 0.7 * ping,
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: accent.withValues(
                              alpha: 0.55 * (1 - ping),
                            ),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                child!,
              ],
            );
          },
          child: Container(
            width: 88,
            height: 88,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
              boxShadow: AppColors.glow(
                accent,
                blurRadius: 32,
                alpha: 0.55,
                isDark: isDark,
              ),
            ),
            child: Icon(
              Symbols.mic_rounded,
              size: 42,
              weight: 500,
              color: AppColors.getOnAccent(isDark),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProcessing(bool isDark) {
    final accent = AppColors.getAccent(isDark);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'THINKING',
          style: AppTypography.eyebrow.copyWith(color: accent),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: 120,
          height: 120,
          child: Center(
            child: SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Making sense of it...',
          style: AppTypography.rowSubtitle.copyWith(
            color: AppColors.getTextSecondaryColor(isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildError(bool isDark) {
    final accent = AppColors.getAccent(isDark);
    final showTranscript =
        _errorKind == _ErrorKind.parseFailed && _transcript != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Symbols.error_rounded,
          size: 48,
          weight: 500,
          color: AppColors.getDanger(isDark),
        ),
        const SizedBox(height: 20),
        Text(
          _errorMessage,
          textAlign: TextAlign.center,
          style: AppTypography.cardTitle.copyWith(
            color: AppColors.getTextColor(isDark),
          ),
        ),
        if (showTranscript) ...[
          const SizedBox(height: 12),
          Text(
            '"${_transcript!}"',
            textAlign: TextAlign.center,
            style: AppTypography.rowSubtitle.copyWith(
              color: AppColors.getTextSecondaryColor(isDark),
            ),
          ),
        ],
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: PillButton(
                label: 'Cancel',
                color: AppColors.getTextSecondaryColor(isDark),
                height: 44,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PillButton(
                label: 'Try again',
                color: accent,
                filled: true,
                height: 44,
                onPressed: _retry,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatElapsed(int seconds) {
    final remaining = math.max(0, _maxDuration.inSeconds - seconds);
    return '0:${remaining.toString().padLeft(2, '0')}';
  }
}
