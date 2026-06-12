import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/theme.dart';
import '../db/db_helper.dart';

class WorkoutLogScreen extends StatefulWidget {
  final List<String> muscleGroups;
  // When true, hides weight input — sets are saved with weight=0
  final bool bodyweight;
  // 'gym' | 'home' — stored on the session
  final String workoutType;

  const WorkoutLogScreen({
    super.key,
    required this.muscleGroups,
    this.bodyweight = false,
    this.workoutType = 'gym',
  });

  @override
  State<WorkoutLogScreen> createState() => _WorkoutLogScreenState();
}

class _WorkoutLogScreenState extends State<WorkoutLogScreen> {
  // Map of exerciseId -> list of (reps, weight)
  final Map<int, _ExerciseLog> _logged = {};
  List<Map<String, dynamic>> _availableExercises = [];
  final TextEditingController _noteCtrl = TextEditingController();

  // Rest timer
  Timer? _timer;
  int _restSeconds = 90;
  int _remaining = 0;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExercises() async {
    final List<Map<String, dynamic>> all = [];
    for (final g in widget.muscleGroups) {
      final ex = await DBHelper.instance.getExercisesByGroup(g);
      all.addAll(ex);
    }
    setState(() => _availableExercises = all);
  }

  void _startTimer(int seconds) {
    _timer?.cancel();
    setState(() {
      _restSeconds = seconds;
      _remaining = seconds;
      _running = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining <= 1) {
        t.cancel();
        setState(() {
          _running = false;
          _remaining = 0;
        });
      } else {
        setState(() => _remaining--);
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _running = false;
      _remaining = 0;
    });
  }

  Future<void> _addSet(Map<String, dynamic> exercise) async {
    final reps = TextEditingController();
    final weight = TextEditingController();

    final log = _logged[exercise['id'] as int];
    if (log != null && log.sets.isNotEmpty) {
      final last = log.sets.last;
      reps.text = last.reps.toString();
      if (!widget.bodyweight) {
        weight.text = last.weight % 1 == 0
            ? last.weight.toStringAsFixed(0)
            : last.weight.toStringAsFixed(1);
      }
    }

    final result = await showModalBottomSheet<_SetEntry>(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppTheme.divider,
                      borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 18),
              Text(exercise['name'] as String,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5)),
              const SizedBox(height: 4),
              Text(
                'Set ${(_logged[exercise['id'] as int]?.sets.length ?? 0) + 1}',
                style: const TextStyle(
                    color: AppTheme.limeAccent, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              widget.bodyweight
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 6, bottom: 6),
                          child: Text('Reps',
                              style: TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                        TextField(
                          controller: reps,
                          keyboardType: TextInputType.number,
                          autofocus: true,
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.w700),
                          decoration: const InputDecoration(hintText: '0'),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(left: 6, bottom: 6),
                                child: Text('Reps',
                                    style: TextStyle(
                                        color: AppTheme.textMuted,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                              ),
                              TextField(
                                controller: reps,
                                keyboardType: TextInputType.number,
                                autofocus: true,
                                style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700),
                                decoration:
                                    const InputDecoration(hintText: '0'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(left: 6, bottom: 6),
                                child: Text('Weight (kg)',
                                    style: TextStyle(
                                        color: AppTheme.textMuted,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                              ),
                              TextField(
                                controller: weight,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700),
                                decoration:
                                    const InputDecoration(hintText: '0'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    final r = int.tryParse(reps.text.trim()) ?? 0;
                    final w = widget.bodyweight
                        ? 0.0
                        : (double.tryParse(weight.text.trim()) ?? 0);
                    if (r > 0) {
                      Navigator.pop(ctx, _SetEntry(reps: r, weight: w));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18))),
                  child: const Text('Add Set',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _logged
            .putIfAbsent(
                exercise['id'] as int, () => _ExerciseLog(exercise: exercise))
            .sets
            .add(result);
      });
      // Auto-start rest timer
      _startTimer(_restSeconds);
    }
  }

  void _removeSet(int exerciseId, int setIndex) {
    setState(() {
      _logged[exerciseId]?.sets.removeAt(setIndex);
      if (_logged[exerciseId]?.sets.isEmpty ?? false) {
        _logged.remove(exerciseId);
      }
    });
  }

  Future<void> _save() async {
    if (_logged.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Add at least one set first'),
            backgroundColor: AppTheme.surfaceLight),
      );
      return;
    }
    final sessionId = await DBHelper.instance.insertSession({
      'date': DateTime.now().toIso8601String(),
      'muscle_groups': widget.muscleGroups.join(', '),
      'note': _noteCtrl.text.trim(),
      'workout_type': widget.workoutType,
    });
    for (final entry in _logged.entries) {
      for (int i = 0; i < entry.value.sets.length; i++) {
        await DBHelper.instance.insertSet({
          'session_id': sessionId,
          'exercise_id': entry.key,
          'set_number': i + 1,
          'reps': entry.value.sets[i].reps,
          'weight': entry.value.sets[i].weight,
          'duration_seconds': 0,
        });
      }
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _addCustomExercise() async {
    final name = TextEditingController();
    String selectedGroup = widget.muscleGroups.first;

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppTheme.divider,
                        borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 18),
                const Text('Add Custom Exercise',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5)),
                const SizedBox(height: 20),
                TextField(
                  controller: name,
                  autofocus: true,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(hintText: 'Exercise name'),
                ),
                const SizedBox(height: 14),
                if (widget.muscleGroups.length > 1) ...[
                  const Padding(
                    padding: EdgeInsets.only(left: 6, bottom: 6),
                    child: Text('Muscle group',
                        style: TextStyle(
                            color: AppTheme.textMuted, fontSize: 12)),
                  ),
                  Wrap(
                    spacing: 8,
                    children: widget.muscleGroups.map((g) {
                      final sel = selectedGroup == g;
                      return ChoiceChip(
                        label: Text(g),
                        selected: sel,
                        onSelected: (_) => setSheet(() => selectedGroup = g),
                        backgroundColor: AppTheme.surfaceLight,
                        selectedColor: AppTheme.limeAccent,
                        labelStyle: TextStyle(
                            color: sel ? Colors.black : AppTheme.textPrimary,
                            fontWeight: FontWeight.w600),
                        side: BorderSide.none,
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () async {
                      final n = name.text.trim();
                      if (n.isEmpty) return;
                      await DBHelper.instance.insertExercise(n, selectedGroup);
                      if (mounted) Navigator.pop(ctx);
                      _loadExercises();
                    },
                    style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18))),
                    child: const Text('Add Exercise',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.muscleGroups.join(' + ')),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save',
                style: TextStyle(
                    color: AppTheme.limeAccent,
                    fontWeight: FontWeight.w800,
                    fontSize: 15)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_running || _remaining > 0)
              Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.limeAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.limeAccent, width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_rounded, color: AppTheme.limeAccent),
                    const SizedBox(width: 12),
                    const Text('Rest',
                        style: TextStyle(color: AppTheme.textSecondary)),
                    const Spacer(),
                    Text(
                      '${(_remaining ~/ 60).toString().padLeft(2, '0')}:${(_remaining % 60).toString().padLeft(2, '0')}',
                      style: const TextStyle(
                          color: AppTheme.limeAccent,
                          fontWeight: FontWeight.w800,
                          fontSize: 22),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _stopTimer,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.close,
                            size: 16, color: AppTheme.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _restChip(60, '1 min'),
                  _restChip(90, '1:30'),
                  _restChip(120, '2 min'),
                  _restChip(180, '3 min'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                children: [
                  if (_logged.isNotEmpty) ...[
                    const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: Text("Today's sets",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                    ..._logged.entries.map((e) => _LoggedExerciseCard(
                          log: e.value,
                          bodyweight: widget.bodyweight,
                          onAddMore: () => _addSet(e.value.exercise),
                          onRemoveSet: (i) => _removeSet(e.key, i),
                        )),
                    const SizedBox(height: 16),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text('Exercises',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                      TextButton.icon(
                        onPressed: _addCustomExercise,
                        icon: const Icon(Icons.add,
                            size: 16, color: AppTheme.limeAccent),
                        label: const Text('Custom',
                            style: TextStyle(
                                color: AppTheme.limeAccent,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  ..._availableExercises
                      .where((e) => !_logged.containsKey(e['id']))
                      .map((e) => _ExerciseTile(
                            exercise: e,
                            onTap: () => _addSet(e),
                          )),
                  if (_availableExercises
                      .where((e) => !_logged.containsKey(e['id']))
                      .isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          _availableExercises.isEmpty
                              ? 'Loading...'
                              : 'All exercises added',
                          style: const TextStyle(color: AppTheme.textMuted),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _noteCtrl,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'Workout notes (optional)',
                      prefixIcon:
                          Icon(Icons.notes_rounded, color: AppTheme.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _restChip(int seconds, String label) {
    final selected = _restSeconds == seconds && !_running;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => _startTimer(seconds),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppTheme.limeAccent : AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Row(
            children: [
              Icon(Icons.timer_outlined,
                  size: 14,
                  color: selected ? Colors.black : AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                    color: selected ? Colors.black : AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseLog {
  final Map<String, dynamic> exercise;
  final List<_SetEntry> sets = [];
  _ExerciseLog({required this.exercise});
}

class _SetEntry {
  final int reps;
  final double weight;
  _SetEntry({required this.reps, required this.weight});
}

class _LoggedExerciseCard extends StatelessWidget {
  final _ExerciseLog log;
  final bool bodyweight;
  final VoidCallback onAddMore;
  final ValueChanged<int> onRemoveSet;

  const _LoggedExerciseCard({
    required this.log,
    required this.bodyweight,
    required this.onAddMore,
    required this.onRemoveSet,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: AppTheme.limeAccent.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(log.exercise['name'] as String,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.limeAccent.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${log.sets.length} ${log.sets.length == 1 ? 'set' : 'sets'}',
                  style: const TextStyle(
                      color: AppTheme.limeAccent,
                      fontWeight: FontWeight.w700,
                      fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...log.sets.asMap().entries.map((e) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(8)),
                    alignment: Alignment.center,
                    child: Text('${e.key + 1}',
                        style: const TextStyle(
                            color: AppTheme.limeAccent,
                            fontWeight: FontWeight.w700,
                            fontSize: 11)),
                  ),
                  const SizedBox(width: 12),
                  Text('${e.value.reps} reps',
                      style: const TextStyle(
                          color: AppTheme.textPrimary, fontSize: 14)),
                  const Spacer(),
                  Text(
                    bodyweight
                        ? 'BW'
                        : '${e.value.weight % 1 == 0 ? e.value.weight.toStringAsFixed(0) : e.value.weight.toStringAsFixed(1)} kg',
                    style: const TextStyle(
                        color: AppTheme.limeAccent,
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => onRemoveSet(e.key),
                    child: const Icon(Icons.close_rounded,
                        color: AppTheme.textMuted, size: 16),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onAddMore,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 16, color: AppTheme.limeAccent),
                  SizedBox(width: 6),
                  Text('Add Set',
                      style: TextStyle(
                          color: AppTheme.limeAccent,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  final Map<String, dynamic> exercise;
  final VoidCallback onTap;
  const _ExerciseTile({required this.exercise, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exercise['name'] as String,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(exercise['muscle_group'] as String,
                        style: const TextStyle(
                            color: AppTheme.textMuted, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.limeAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add,
                    color: AppTheme.limeAccent, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
