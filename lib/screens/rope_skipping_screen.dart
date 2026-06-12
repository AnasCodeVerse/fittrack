import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/theme.dart';
import '../db/db_helper.dart';

/// Rope Skipping screen with two modes:
///   - Stopwatch: just duration
///   - Audio Counter: uses mic to detect rope ticks, counts reps + duration
class RopeSkippingScreen extends StatefulWidget {
  const RopeSkippingScreen({super.key});

  @override
  State<RopeSkippingScreen> createState() => _RopeSkippingScreenState();
}

class _RopeSkippingScreenState extends State<RopeSkippingScreen> {
  static const _prefsKeyThreshold = 'rope_audio_threshold_db';
  static const _prefsKeyAmbient = 'rope_audio_ambient_db';

  // 0 = stopwatch, 1 = audio counter
  int _mode = 0;

  // Shared timer state
  Timer? _ticker;
  int _elapsed = 0;
  bool _running = false;

  // Audio state
  NoiseMeter? _noiseMeter;
  StreamSubscription<NoiseReading>? _noiseSub;
  int _count = 0;
  double _currentDb = 0;
  double _peakDbThisSecond = 0;
  final List<double> _rollingDb = [];
  int _lastPeakMs = 0;
  bool _pulse = false;

  // Calibration / config
  double _thresholdDelta = 0; // dB above baseline that counts as a jump
  double _calibAmbient = 35;
  bool _calibrated = false;
  bool _permissionGranted = false;
  bool _permissionChecked = false;

  // Calibration UI state
  bool _calibrating = false;
  int _calibPhase = 0; // 0=ambient, 1=jumps
  int _calibCountdown = 0;
  final List<double> _calibAmbientReadings = [];
  final List<double> _calibPeakReadings = [];
  int _calibPeaksDetected = 0;
  int _calibLastPeakMs = 0;

  Map<String, dynamic>? _exercise;

  @override
  void initState() {
    super.initState();
    _loadExercise();
    _loadCalibration();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _noiseSub?.cancel();
    super.dispose();
  }

  Future<void> _loadExercise() async {
    final ex = await DBHelper.instance
        .getExerciseByName('Rope Skipping', 'Rope Skipping');
    setState(() => _exercise = ex);
  }

  Future<void> _loadCalibration() async {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getDouble(_prefsKeyThreshold);
    final a = prefs.getDouble(_prefsKeyAmbient);
    if (t != null && t > 0) {
      setState(() {
        _thresholdDelta = t;
        _calibAmbient = a ?? 35;
        _calibrated = true;
      });
    }
  }

  Future<void> _saveCalibration(double threshold, double ambient) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefsKeyThreshold, threshold);
    await prefs.setDouble(_prefsKeyAmbient, ambient);
    setState(() {
      _thresholdDelta = threshold;
      _calibAmbient = ambient;
      _calibrated = true;
    });
  }

  Future<bool> _ensurePermission() async {
    final status = await Permission.microphone.request();
    setState(() {
      _permissionGranted = status.isGranted;
      _permissionChecked = true;
    });
    return status.isGranted;
  }

  // ---------- STOPWATCH ----------
  void _toggleStopwatch() {
    if (_running) {
      _ticker?.cancel();
      setState(() => _running = false);
    } else {
      HapticFeedback.lightImpact();
      setState(() => _running = true);
      _ticker = Timer.periodic(
          const Duration(seconds: 1), (_) => setState(() => _elapsed++));
    }
  }

  void _resetAll() {
    _ticker?.cancel();
    _stopAudio();
    setState(() {
      _elapsed = 0;
      _running = false;
      _count = 0;
      _currentDb = 0;
      _rollingDb.clear();
    });
  }

  // ---------- AUDIO COUNTER ----------
  Future<void> _toggleAudio() async {
    if (_running) {
      await _stopAudio();
    } else {
      await _startAudio();
    }
  }

  Future<void> _startAudio() async {
    if (!_permissionGranted) {
      final ok = await _ensurePermission();
      if (!ok) return;
    }
    if (!_calibrated) {
      // Should not happen — UI gates this
      return;
    }
    _noiseMeter ??= NoiseMeter();
    setState(() {
      _running = true;
      _rollingDb.clear();
      _lastPeakMs = 0;
    });
    HapticFeedback.lightImpact();

    _ticker = Timer.periodic(
        const Duration(seconds: 1), (_) => setState(() => _elapsed++));

    try {
      _noiseSub = _noiseMeter!.noise.listen(
        _onCountReading,
        onError: (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('Mic error: $e'),
                  backgroundColor: AppTheme.surfaceLight),
            );
          }
          _stopAudio();
        },
        cancelOnError: true,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Could not start mic: $e'),
            backgroundColor: AppTheme.surfaceLight),
      );
      _stopAudio();
    }
  }

  Future<void> _stopAudio() async {
    _ticker?.cancel();
    await _noiseSub?.cancel();
    _noiseSub = null;
    if (mounted) setState(() => _running = false);
  }

  void _onCountReading(NoiseReading reading) {
    final db = reading.maxDecibel;
    if (db.isNaN || db.isInfinite) return;

    // Rolling window: last ~3s of readings for baseline (assume ~10 Hz updates)
    _rollingDb.add(db);
    if (_rollingDb.length > 30) _rollingDb.removeAt(0);

    // Use median of recent readings as adaptive baseline.
    final sorted = List<double>.from(_rollingDb)..sort();
    final baseline = sorted.isEmpty
        ? _calibAmbient
        : sorted[sorted.length ~/ 2];

    final now = DateTime.now().millisecondsSinceEpoch;
    final isPeak = db > baseline + _thresholdDelta;
    final debounceOk = (now - _lastPeakMs) > 200; // max ~5 jumps/sec

    if (mounted) {
      setState(() {
        _currentDb = db;
      });
    }

    if (isPeak && debounceOk) {
      _lastPeakMs = now;
      if (mounted) {
        setState(() {
          _count++;
          _pulse = true;
        });
        Future.delayed(const Duration(milliseconds: 120), () {
          if (mounted) setState(() => _pulse = false);
        });
      }
    }
  }

  // ---------- CALIBRATION ----------
  Future<void> _startCalibration() async {
    if (!_permissionGranted) {
      final ok = await _ensurePermission();
      if (!ok) return;
    }
    setState(() {
      _calibrating = true;
      _calibPhase = 0;
      _calibCountdown = 3;
      _calibAmbientReadings.clear();
      _calibPeakReadings.clear();
      _calibPeaksDetected = 0;
      _calibLastPeakMs = 0;
    });

    _noiseMeter ??= NoiseMeter();
    try {
      _noiseSub = _noiseMeter!.noise.listen(
        _onCalibReading,
        onError: (_) => _cancelCalibration(),
        cancelOnError: true,
      );
    } catch (e) {
      _cancelCalibration();
      return;
    }

    // Phase 0: ambient for 3 seconds
    for (int i = 3; i >= 1; i--) {
      if (!mounted || !_calibrating) return;
      setState(() => _calibCountdown = i);
      await Future.delayed(const Duration(seconds: 1));
    }
    if (!mounted || !_calibrating) return;

    // Phase 1: do 10 jumps
    setState(() {
      _calibPhase = 1;
      _calibCountdown = 0;
    });
    // Time out the jump phase at 25 seconds
    final timeout =
        Future.delayed(const Duration(seconds: 25), _finishCalibration);
    // _finishCalibration is also called when 10 peaks reached.
    await timeout;
  }

  void _onCalibReading(NoiseReading reading) {
    final db = reading.maxDecibel;
    if (db.isNaN || db.isInfinite) return;
    if (!mounted) return;
    setState(() => _currentDb = db);

    if (_calibPhase == 0) {
      _calibAmbientReadings.add(db);
    } else {
      // Detect peaks with conservative threshold based on ambient so far
      final ambient = _calibAmbientReadings.isEmpty
          ? 35.0
          : (_calibAmbientReadings.reduce((a, b) => a + b) /
              _calibAmbientReadings.length);
      final now = DateTime.now().millisecondsSinceEpoch;
      if (db > ambient + 6 && (now - _calibLastPeakMs) > 200) {
        _calibLastPeakMs = now;
        _calibPeakReadings.add(db);
        _calibPeaksDetected++;
        setState(() {});
        // If we've got plenty, finish early
        if (_calibPeaksDetected >= 12) {
          _finishCalibration();
        }
      }
    }
  }

  void _cancelCalibration() {
    _noiseSub?.cancel();
    if (mounted) setState(() => _calibrating = false);
  }

  Future<void> _finishCalibration() async {
    if (!_calibrating) return;
    await _noiseSub?.cancel();
    _noiseSub = null;

    if (_calibPeakReadings.length < 5) {
      if (mounted) {
        setState(() => _calibrating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Couldn\'t hear enough jumps. Try moving the phone closer.'),
            backgroundColor: AppTheme.surfaceLight,
          ),
        );
      }
      return;
    }

    final ambient = _calibAmbientReadings.reduce((a, b) => a + b) /
        _calibAmbientReadings.length;
    final peakAvg = _calibPeakReadings.reduce((a, b) => a + b) /
        _calibPeakReadings.length;
    // Threshold = a chunk below the average peak height so we still catch quieter jumps.
    final threshold = ((peakAvg - ambient) * 0.55).clamp(4.0, 30.0);

    await _saveCalibration(threshold, ambient);
    if (mounted) {
      setState(() => _calibrating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Calibrated! Detected ${_calibPeakReadings.length} jumps · threshold ${threshold.toStringAsFixed(1)} dB'),
          backgroundColor: AppTheme.surfaceLight,
        ),
      );
    }
  }

  // ---------- SAVE ----------
  Future<void> _save() async {
    if (_mode == 0 && _elapsed < 1) {
      _snack('Timer hasn\'t started yet');
      return;
    }
    if (_mode == 1 && _count < 1 && _elapsed < 1) {
      _snack('Nothing to save yet');
      return;
    }
    await _stopAudio();
    _ticker?.cancel();

    // For audio mode, let the user edit the count first
    int finalCount = _count;
    if (_mode == 1) {
      final edited = await _showEditCountDialog(_count, _elapsed);
      if (edited == null) {
        // User cancelled — restart timer/listener? Keep it stopped, they can resume.
        return;
      }
      finalCount = edited;
    } else {
      // Stopwatch save confirmation
      final ok = await _confirmSave(_elapsed, 0);
      if (ok != true) return;
    }

    if (_exercise == null) {
      _snack('Exercise not found in DB');
      return;
    }
    final sessionId = await DBHelper.instance.insertSession({
      'date': DateTime.now().toIso8601String(),
      'muscle_groups': 'Rope Skipping',
      'note': _mode == 1 ? 'Audio counted' : '',
      'workout_type': 'skipping',
    });
    await DBHelper.instance.insertSet({
      'session_id': sessionId,
      'exercise_id': _exercise!['id'],
      'set_number': 1,
      'reps': finalCount,
      'weight': 0,
      'duration_seconds': _elapsed,
    });

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<int?> _showEditCountDialog(int count, int duration) async {
    final ctrl = TextEditingController(text: count.toString());
    return await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Save skips',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Duration: ${_fmtDuration(duration)}',
                style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            const Text('Count (fix if off):',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w800),
              decoration: const InputDecoration(hintText: '0'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppTheme.textMuted))),
          TextButton(
              onPressed: () {
                final n = int.tryParse(ctrl.text.trim()) ?? 0;
                if (n >= 0) Navigator.pop(ctx, n);
              },
              child: const Text('Save',
                  style: TextStyle(
                      color: AppTheme.limeAccent,
                      fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }

  Future<bool?> _confirmSave(int duration, int count) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Save session?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Duration: ${_fmtDuration(duration)}',
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppTheme.textMuted))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save',
                  style: TextStyle(
                      color: AppTheme.limeAccent,
                      fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.surfaceLight),
    );
  }

  String _fmtDuration(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) {
      return '${h}h ${m.toString().padLeft(2, '0')}m ${sec.toString().padLeft(2, '0')}s';
    }
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  // ---------- BUILD ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Rope Skipping'),
        actions: [
          if (_mode == 1 && _calibrated && !_calibrating && !_running)
            IconButton(
              icon: const Icon(Icons.tune_rounded,
                  color: AppTheme.textSecondary),
              tooltip: 'Recalibrate',
              onPressed: _startCalibration,
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Mode toggle
              _ModePill(
                mode: _mode,
                onChange: (m) {
                  if (_running || _calibrating) return;
                  _resetAll();
                  setState(() => _mode = m);
                },
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _calibrating
                    ? _buildCalibrationUI()
                    : (_mode == 0
                        ? _buildStopwatchUI()
                        : _buildAudioUI()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- STOPWATCH UI ----------
  Widget _buildStopwatchUI() {
    return Column(
      children: [
        const Spacer(),
        Center(
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.cardDark,
              border: Border.all(
                color: _running ? AppTheme.limeAccent : AppTheme.divider,
                width: 3,
              ),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _fmtDuration(_elapsed),
                  style: TextStyle(
                    fontSize: _elapsed >= 3600 ? 40 : 52,
                    fontWeight: FontWeight.w800,
                    color: _running
                        ? AppTheme.limeAccent
                        : AppTheme.textPrimary,
                    letterSpacing: -1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _running ? 'RUNNING' : (_elapsed > 0 ? 'PAUSED' : 'READY'),
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        _buildControls(onToggle: _toggleStopwatch),
      ],
    );
  }

  // ---------- AUDIO UI ----------
  Widget _buildAudioUI() {
    if (!_permissionChecked && !_permissionGranted) {
      return _buildPermissionPrompt();
    }
    if (_permissionChecked && !_permissionGranted) {
      return _buildPermissionDenied();
    }
    if (!_calibrated) {
      return _buildCalibrationPrompt();
    }

    final pulseScale = _pulse ? 1.06 : 1.0;
    return Column(
      children: [
        // Live dB readout
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.mic_rounded,
                  color: AppTheme.limeAccent, size: 16),
              const SizedBox(width: 8),
              Text(
                'Mic: ${_currentDb.isFinite ? _currentDb.toStringAsFixed(0) : "—"} dB',
                style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12),
              ),
              const Spacer(),
              Text(
                _running ? _fmtDuration(_elapsed) : 'Ready',
                style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12),
              ),
            ],
          ),
        ),
        const Spacer(),
        Center(
          child: AnimatedScale(
            scale: pulseScale,
            duration: const Duration(milliseconds: 80),
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.cardDark,
                border: Border.all(
                  color: _pulse
                      ? AppTheme.success
                      : (_running
                          ? AppTheme.limeAccent
                          : AppTheme.divider),
                  width: 3,
                ),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$_count',
                    style: TextStyle(
                      fontSize: _count >= 1000 ? 84 : 100,
                      fontWeight: FontWeight.w900,
                      color: _running
                          ? AppTheme.limeAccent
                          : AppTheme.textPrimary,
                      letterSpacing: -3,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('skips',
                      style: TextStyle(
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: 2)),
                ],
              ),
            ),
          ),
        ),
        const Spacer(),
        if (!_running && _elapsed == 0 && _count == 0)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Place phone on the ground within 2-3m, mic side up',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppTheme.textMuted, fontSize: 12),
            ),
          ),
        _buildControls(onToggle: _toggleAudio),
      ],
    );
  }

  Widget _buildPermissionPrompt() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mic_rounded,
                color: AppTheme.limeAccent, size: 36),
            const SizedBox(height: 12),
            const Text('Microphone access needed',
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 6),
            const Text(
              'Audio counter listens for the rope tick to count jumps.\nMic data is processed live and never recorded.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _ensurePermission,
                style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16))),
                child: const Text('Grant microphone access',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionDenied() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mic_off_rounded,
                color: AppTheme.error, size: 36),
            const SizedBox(height: 12),
            const Text('Permission denied',
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 6),
            const Text(
              'Enable microphone access in your phone settings to use the audio counter.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: openAppSettings,
                style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16))),
                child: const Text('Open settings',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 14)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _ensurePermission,
              child: const Text('Retry',
                  style: TextStyle(
                      color: AppTheme.limeAccent,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalibrationPrompt() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.tune_rounded,
                color: AppTheme.limeAccent, size: 36),
            const SizedBox(height: 12),
            const Text('One-time calibration',
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 6),
            const Text(
              'The app needs to learn what your rope sounds like in your usual spot. '
              'Place the phone where you\'ll skip, then tap Start.\n\n'
              'It will listen for 3 seconds of silence, then ask you to do about 10 jumps.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _startCalibration,
                style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16))),
                child: const Text('Start calibration',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalibrationUI() {
    String title;
    String subtitle;
    Widget centerWidget;
    if (_calibPhase == 0) {
      title = 'Listening to ambient...';
      subtitle = 'Don\'t skip yet — just stand still';
      centerWidget = Text(
        '$_calibCountdown',
        style: const TextStyle(
            fontSize: 120,
            fontWeight: FontWeight.w900,
            color: AppTheme.limeAccent,
            letterSpacing: -4),
      );
    } else {
      title = 'Do 10 jumps now';
      subtitle = 'Detected $_calibPeaksDetected so far';
      centerWidget = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$_calibPeaksDetected',
            style: const TextStyle(
                fontSize: 100,
                fontWeight: FontWeight.w900,
                color: AppTheme.limeAccent,
                letterSpacing: -3),
          ),
          const Text('/ 10',
              style: TextStyle(
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w700,
                  fontSize: 18)),
        ],
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.mic_rounded,
                  color: AppTheme.limeAccent, size: 16),
              const SizedBox(width: 8),
              Text(
                'Mic: ${_currentDb.isFinite ? _currentDb.toStringAsFixed(0) : "—"} dB',
                style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 18)),
        const SizedBox(height: 4),
        Text(subtitle,
            style: const TextStyle(
                color: AppTheme.textMuted, fontSize: 13)),
        const Spacer(),
        Center(child: centerWidget),
        const Spacer(),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 60,
                child: OutlinedButton(
                  onPressed: () {
                    _cancelCalibration();
                  },
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                    side: const BorderSide(color: AppTheme.divider),
                  ),
                  child: const Text('Cancel',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ),
            if (_calibPhase == 1) ...[
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _finishCalibration,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                    ),
                    child: const Text('Done',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildControls({required VoidCallback onToggle}) {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: SizedBox(
            height: 60,
            child: OutlinedButton(
              onPressed: (_elapsed > 0 || _count > 0) ? _resetAll : null,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                side: const BorderSide(color: AppTheme.divider),
              ),
              child: const Icon(Icons.refresh_rounded,
                  color: AppTheme.textSecondary),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 60,
            child: ElevatedButton.icon(
              onPressed: onToggle,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
              ),
              icon: Icon(_running
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded),
              label: Text(_running ? 'Pause' : 'Start',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 1,
          child: SizedBox(
            height: 60,
            child: OutlinedButton(
              onPressed:
                  (_elapsed > 0 || _count > 0) ? _save : null,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                side: const BorderSide(color: AppTheme.limeAccent),
              ),
              child: const Icon(Icons.check_rounded,
                  color: AppTheme.limeAccent),
            ),
          ),
        ),
      ],
    );
  }
}

class _ModePill extends StatelessWidget {
  final int mode;
  final ValueChanged<int> onChange;
  const _ModePill({required this.mode, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _seg(0, 'Stopwatch', Icons.timer_rounded),
          _seg(1, 'Audio counter', Icons.mic_rounded),
        ],
      ),
    );
  }

  Expanded _seg(int idx, String label, IconData icon) {
    final sel = mode == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChange(idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: sel ? AppTheme.limeAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: sel ? Colors.black : AppTheme.textSecondary),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      color: sel ? Colors.black : AppTheme.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
