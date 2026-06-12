import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../utils/theme.dart';
import '../db/db_helper.dart';

class EmomRunItem {
  final int exerciseId;
  final String exerciseName;
  final int reps;
  EmomRunItem(
      {required this.exerciseId,
      required this.exerciseName,
      required this.reps});
}

class EmomRunScreen extends StatefulWidget {
  final int totalMinutes;
  final List<EmomRunItem> items;

  const EmomRunScreen({
    super.key,
    required this.totalMinutes,
    required this.items,
  });

  @override
  State<EmomRunScreen> createState() => _EmomRunScreenState();
}

class _EmomRunScreenState extends State<EmomRunScreen> {
  Timer? _ticker;
  bool _started = false; // before first tap of Start
  bool _paused = false;
  int _currentMinute = 0; // 0-indexed
  int _secondsIntoMinute = 0;

  // Tracks if the user tapped Done for each minute
  late final List<bool> _minuteCompleted;

  // Audio
  final AudioPlayer _tickPlayer = AudioPlayer();
  final AudioPlayer _goPlayer = AudioPlayer();
  bool _audioReady = false;

  @override
  void initState() {
    super.initState();
    _minuteCompleted = List<bool>.filled(widget.totalMinutes, false);
    _setupAudio();
  }

  Future<void> _setupAudio() async {
    try {
      await _tickPlayer.setReleaseMode(ReleaseMode.stop);
      await _goPlayer.setReleaseMode(ReleaseMode.stop);
      await _tickPlayer.setSource(AssetSource('sounds/tick.wav'));
      await _goPlayer.setSource(AssetSource('sounds/go.wav'));
      // Play through media volume so loud enough at the gym
      await _tickPlayer.setVolume(1.0);
      await _goPlayer.setVolume(1.0);
      if (mounted) setState(() => _audioReady = true);
    } catch (e) {
      // If asset is missing or audio fails, fall back to haptic only
      debugPrint('Audio setup failed: $e');
    }
  }

  Future<void> _playTick() async {
    if (!_audioReady) return;
    try {
      await _tickPlayer.seek(Duration.zero);
      await _tickPlayer.resume();
    } catch (_) {}
  }

  Future<void> _playGo() async {
    if (!_audioReady) return;
    try {
      await _goPlayer.seek(Duration.zero);
      await _goPlayer.resume();
    } catch (_) {}
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _tickPlayer.dispose();
    _goPlayer.dispose();
    super.dispose();
  }

  void _begin() {
    setState(() {
      _started = true;
      _paused = false;
      _currentMinute = 0;
      _secondsIntoMinute = 0;
    });
    _cueMinuteStart();
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) => _tick());
  }

  void _tick() {
    if (_paused) return;
    setState(() => _secondsIntoMinute++);

    // Countdown warning in last 5 seconds: tick sound + haptic
    final secondsLeft = 60 - _secondsIntoMinute;
    if (secondsLeft >= 1 && secondsLeft <= 5) {
      _playTick();
      if (secondsLeft <= 2) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.lightImpact();
      }
    }

    if (_secondsIntoMinute >= 60) {
      // Minute over — advance
      _advanceMinute();
    }
  }

  void _advanceMinute() {
    if (_currentMinute >= widget.totalMinutes - 1) {
      // Finished
      _ticker?.cancel();
      _finishAndSave();
      return;
    }
    setState(() {
      _currentMinute++;
      _secondsIntoMinute = 0;
    });
    _cueMinuteStart();
  }

  /// Strong haptic pulse + audible beep at the start of each minute.
  void _cueMinuteStart() {
    _playGo();
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) HapticFeedback.heavyImpact();
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) HapticFeedback.heavyImpact();
    });
  }

  void _markDone() {
    if (!_started || _paused) return;
    HapticFeedback.mediumImpact();
    setState(() => _minuteCompleted[_currentMinute] = true);
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
  }

  Future<void> _quitEarly() async {
    _paused = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('End EMOM early?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
            'Done $_completedCount of ${widget.totalMinutes} minutes. Save progress?',
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep going',
                  style: TextStyle(color: AppTheme.textMuted))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('End & save',
                  style: TextStyle(
                      color: AppTheme.limeAccent,
                      fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (ok == true) {
      _ticker?.cancel();
      await _finishAndSave();
    } else {
      setState(() => _paused = false);
    }
  }

  int get _completedCount =>
      _minuteCompleted.where((c) => c).length;

  Future<void> _finishAndSave() async {
    final done = _completedCount;
    final sessionId = await DBHelper.instance.insertSession({
      'date': DateTime.now().toIso8601String(),
      'muscle_groups': 'EMOM',
      'note':
          'EMOM ${widget.totalMinutes}min · Completed $done/${widget.totalMinutes}',
      'workout_type': 'emom',
    });

    // One set per exercise, reps = prescribed × completed minutes.
    for (final item in widget.items) {
      final totalReps = item.reps * done;
      if (totalReps > 0) {
        await DBHelper.instance.insertSet({
          'session_id': sessionId,
          'exercise_id': item.exerciseId,
          'set_number': 1,
          'reps': totalReps,
          'weight': 0,
          'duration_seconds': 0,
        });
      }
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_started) return _buildIntro();
    final secondsLeftInMinute = 60 - _secondsIntoMinute;
    final progress = _secondsIntoMinute / 60.0;
    final currentDone = _minuteCompleted[_currentMinute];
    final inCountdown =
        secondsLeftInMinute >= 1 && secondsLeftInMinute <= 5;

    return WillPopScope(
      onWillPop: () async {
        await _quitEarly();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close, color: AppTheme.textPrimary),
            onPressed: _quitEarly,
          ),
          title: const Text('EMOM'),
          actions: [
            IconButton(
              icon: Icon(
                _paused
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded,
                color: AppTheme.limeAccent,
              ),
              onPressed: _togglePause,
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              children: [
                // Minute counter
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardDark,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.flash_on_rounded,
                          color: AppTheme.limeAccent),
                      const SizedBox(width: 10),
                      Text(
                        'Minute ${_currentMinute + 1} of ${widget.totalMinutes}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.limeAccent.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$_completedCount done',
                          style: const TextStyle(
                              color: AppTheme.limeAccent,
                              fontWeight: FontWeight.w800,
                              fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Time remaining circle
                Expanded(
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 220,
                          height: 220,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: inCountdown ? 12 : 8,
                            backgroundColor: AppTheme.divider,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              inCountdown
                                  ? AppTheme.warning
                                  : (currentDone
                                      ? AppTheme.success
                                      : AppTheme.limeAccent),
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${secondsLeftInMinute}s',
                              style: TextStyle(
                                  fontSize: inCountdown ? 80 : 64,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -2,
                                  color: inCountdown
                                      ? AppTheme.warning
                                      : AppTheme.textPrimary),
                            ),
                            Text(
                              inCountdown
                                  ? 'GET READY'
                                  : (currentDone ? 'RESTING' : 'GO'),
                              style: TextStyle(
                                  color: inCountdown
                                      ? AppTheme.warning
                                      : (currentDone
                                          ? AppTheme.success
                                          : AppTheme.limeAccent),
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2,
                                  fontSize: 14),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Exercise list for this minute
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.cardDark,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: widget.items
                        .map((it) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.fitness_center_rounded,
                                      size: 16, color: AppTheme.limeAccent),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(it.exerciseName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15)),
                                  ),
                                  Text('${it.reps} reps',
                                      style: const TextStyle(
                                          color: AppTheme.limeAccent,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15)),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 14),

                // Done button
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: ElevatedButton(
                    onPressed: (_paused || currentDone) ? null : _markDone,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: currentDone
                          ? AppTheme.success
                          : AppTheme.limeAccent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Text(
                      currentDone ? '✓ DONE — Rest till next minute' : 'DONE',
                      style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntro() {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('EMOM'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.flash_on_rounded,
                            color: AppTheme.limeAccent),
                        const SizedBox(width: 8),
                        Text('${widget.totalMinutes}-minute EMOM',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 18)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...widget.items.map((it) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(it.exerciseName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15)),
                              ),
                              Text('${it.reps} reps',
                                  style: const TextStyle(
                                      color: AppTheme.limeAccent,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15)),
                            ],
                          ),
                        )),
                    const SizedBox(height: 12),
                    const Divider(color: AppTheme.divider),
                    const SizedBox(height: 8),
                    const Text(
                      'Every minute on the minute, do all listed exercises. '
                      'Rest the remaining seconds. Phone will vibrate each minute.',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          height: 1.4),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 64,
                child: ElevatedButton.icon(
                  onPressed: _begin,
                  style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20))),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Start EMOM',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          letterSpacing: 0.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
