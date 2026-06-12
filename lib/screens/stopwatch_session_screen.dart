import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/theme.dart';
import '../db/db_helper.dart';

/// Stopwatch-based logging used for Rope Skipping and Planks.
/// - For Rope Skipping: pass [category]='Rope Skipping', [defaultExerciseName]='Rope Skipping'.
/// - For Planks: pass [category]='Planks' and leave [defaultExerciseName] null — user picks a variant.
class StopwatchSessionScreen extends StatefulWidget {
  final String category;
  final String workoutType; // 'skipping' | 'plank'
  final String? defaultExerciseName;

  const StopwatchSessionScreen({
    super.key,
    required this.category,
    required this.workoutType,
    this.defaultExerciseName,
  });

  @override
  State<StopwatchSessionScreen> createState() => _StopwatchSessionScreenState();
}

class _StopwatchSessionScreenState extends State<StopwatchSessionScreen> {
  Timer? _ticker;
  int _elapsed = 0; // seconds
  bool _running = false;

  List<Map<String, dynamic>> _variants = [];
  Map<String, dynamic>? _selectedExercise;

  @override
  void initState() {
    super.initState();
    _loadVariants();
  }

  Future<void> _loadVariants() async {
    final list = await DBHelper.instance.getExercisesByGroup(widget.category);
    setState(() {
      _variants = list;
      if (widget.defaultExerciseName != null) {
        _selectedExercise = list.firstWhere(
          (e) => e['name'] == widget.defaultExerciseName,
          orElse: () => list.isNotEmpty ? list.first : <String, dynamic>{},
        );
        if (_selectedExercise!.isEmpty) _selectedExercise = null;
      } else if (list.length == 1) {
        _selectedExercise = list.first;
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _toggle() {
    if (_running) {
      _pause();
    } else {
      _start();
    }
  }

  void _start() {
    HapticFeedback.lightImpact();
    setState(() => _running = true);
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _elapsed++);
    });
  }

  void _pause() {
    HapticFeedback.lightImpact();
    _ticker?.cancel();
    setState(() => _running = false);
  }

  void _reset() {
    _ticker?.cancel();
    setState(() {
      _elapsed = 0;
      _running = false;
    });
  }

  Future<void> _saveAndExit() async {
    if (_elapsed < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Timer hasn\'t started yet'),
            backgroundColor: AppTheme.surfaceLight),
      );
      return;
    }
    if (_selectedExercise == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Pick a ${widget.category.toLowerCase()} variant first'),
            backgroundColor: AppTheme.surfaceLight),
      );
      return;
    }
    _ticker?.cancel();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Save ${_selectedExercise!['name']}?',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Duration: ${_format(_elapsed)}',
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

    if (ok != true) {
      // Resume timer if user cancels
      if (mounted) _start();
      return;
    }

    final sessionId = await DBHelper.instance.insertSession({
      'date': DateTime.now().toIso8601String(),
      'muscle_groups': widget.category,
      'note': '',
      'workout_type': widget.workoutType,
    });
    await DBHelper.instance.insertSet({
      'session_id': sessionId,
      'exercise_id': _selectedExercise!['id'],
      'set_number': 1,
      'reps': 0,
      'weight': 0,
      'duration_seconds': _elapsed,
    });

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  String _format(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final needsPicker = _variants.length > 1;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.category),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (needsPicker) ...[
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 8),
                  child: Text('Variant',
                      style: TextStyle(
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w600,
                          fontSize: 12)),
                ),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _variants.map((v) {
                      final sel = _selectedExercise?['id'] == v['id'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedExercise = v),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: sel
                                  ? AppTheme.limeAccent
                                  : AppTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              v['name'] as String,
                              style: TextStyle(
                                  color: sel
                                      ? Colors.black
                                      : AppTheme.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              const Spacer(),
              // Big timer display
              Center(
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.cardDark,
                    border: Border.all(
                      color: _running
                          ? AppTheme.limeAccent
                          : AppTheme.divider,
                      width: 3,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _format(_elapsed),
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
              // Controls
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: 60,
                      child: OutlinedButton(
                        onPressed: _elapsed > 0 ? _reset : null,
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
                        onPressed: _toggle,
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
                        onPressed: _elapsed > 0 ? _saveAndExit : null,
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
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Tap ✓ to save when done',
                  style:
                      TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
