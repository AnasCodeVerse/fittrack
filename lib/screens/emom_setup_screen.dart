import 'dart:convert';
import 'package:flutter/material.dart';
import '../utils/theme.dart';
import '../db/db_helper.dart';
import 'emom_run_screen.dart';

/// EMOM setup. User configures exercises + reps + total minutes,
/// optionally saves as template, then launches the run screen.
class EmomSetupScreen extends StatefulWidget {
  const EmomSetupScreen({super.key});

  @override
  State<EmomSetupScreen> createState() => _EmomSetupScreenState();
}

class _EmomSetupScreenState extends State<EmomSetupScreen> {
  int _totalMinutes = 10;
  final List<_EmomItem> _items = [];
  List<Map<String, dynamic>> _allExercises = [];
  List<Map<String, dynamic>> _templates = [];

  bool _saveAsTemplate = false;
  final TextEditingController _templateNameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _templateNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final ex = await DBHelper.instance.getAllExercises();
    final tpls = await DBHelper.instance.getAllEmomTemplates();
    setState(() {
      _allExercises = ex;
      _templates = tpls;
    });
  }

  void _loadTemplate(Map<String, dynamic> tpl) {
    final config = jsonDecode(tpl['config'] as String) as List;
    final items = <_EmomItem>[];
    for (final c in config) {
      final exId = c['exercise_id'] as int;
      final ex = _allExercises.firstWhere(
        (e) => e['id'] == exId,
        orElse: () => <String, dynamic>{},
      );
      if (ex.isEmpty) continue;
      items.add(_EmomItem(
        exerciseId: exId,
        exerciseName: ex['name'] as String,
        reps: c['reps'] as int,
      ));
    }
    setState(() {
      _items.clear();
      _items.addAll(items);
      _totalMinutes = tpl['total_minutes'] as int;
    });
  }

  Future<void> _deleteTemplate(int id) async {
    await DBHelper.instance.deleteEmomTemplate(id);
    _load();
  }

  Future<void> _pickExercise() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) {
        // Group exercises by muscle_group for nicer browsing
        final Map<String, List<Map<String, dynamic>>> grouped = {};
        for (final e in _allExercises) {
          grouped.putIfAbsent(e['muscle_group'] as String, () => []).add(e);
        }
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (ctx, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.all(20),
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
              const Text('Pick an exercise',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              ...grouped.entries.map((g) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 6),
                        child: Text(g.key,
                            style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                letterSpacing: 1)),
                      ),
                      ...g.value.map((e) => InkWell(
                            onTap: () => Navigator.pop(ctx, e),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppTheme.cardDark,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(e['name'] as String,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14)),
                            ),
                          )),
                    ],
                  )),
            ],
          ),
        );
      },
    );

    if (result == null) return;
    final reps = await _askReps();
    if (reps == null) return;
    setState(() {
      _items.add(_EmomItem(
        exerciseId: result['id'] as int,
        exerciseName: result['name'] as String,
        reps: reps,
      ));
    });
  }

  Future<int?> _askReps() async {
    final ctrl = TextEditingController(text: '10');
    return await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reps per minute',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700),
          decoration: const InputDecoration(hintText: '10'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppTheme.textMuted))),
          TextButton(
              onPressed: () {
                final r = int.tryParse(ctrl.text.trim()) ?? 0;
                if (r > 0) Navigator.pop(ctx, r);
              },
              child: const Text('Add',
                  style: TextStyle(
                      color: AppTheme.limeAccent,
                      fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }

  Future<void> _start() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Add at least one exercise'),
            backgroundColor: AppTheme.surfaceLight),
      );
      return;
    }
    if (_saveAsTemplate) {
      final name = _templateNameCtrl.text.trim();
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Give the template a name'),
              backgroundColor: AppTheme.surfaceLight),
        );
        return;
      }
      await DBHelper.instance.insertEmomTemplate(
        name: name,
        totalMinutes: _totalMinutes,
        config: _items
            .map((i) =>
                {'exercise_id': i.exerciseId, 'reps': i.reps})
            .toList(),
      );
    }

    if (!mounted) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EmomRunScreen(
          totalMinutes: _totalMinutes,
          items: _items
              .map((i) => EmomRunItem(
                  exerciseId: i.exerciseId,
                  exerciseName: i.exerciseName,
                  reps: i.reps))
              .toList(),
        ),
      ),
    );
    if (result == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('EMOM Setup'),
        actions: [
          TextButton(
              onPressed: _start,
              child: const Text('Start',
                  style: TextStyle(
                      color: AppTheme.limeAccent,
                      fontWeight: FontWeight.w800,
                      fontSize: 15))),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Templates
            if (_templates.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 8),
                child: Text('Your templates',
                    style: TextStyle(
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        letterSpacing: 1)),
              ),
              SizedBox(
                height: 90,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _templates
                      .map((t) => _TemplateCard(
                            template: t,
                            onTap: () => _loadTemplate(t),
                            onDelete: () => _deleteTemplate(t['id'] as int),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Total minutes
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text('Total minutes',
                  style: TextStyle(
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 1)),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  _stepperBtn(Icons.remove, () {
                    if (_totalMinutes > 1) {
                      setState(() => _totalMinutes--);
                    }
                  }),
                  Expanded(
                    child: Center(
                      child: Text('$_totalMinutes min',
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.limeAccent)),
                    ),
                  ),
                  _stepperBtn(Icons.add, () {
                    if (_totalMinutes < 60) {
                      setState(() => _totalMinutes++);
                    }
                  }),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Exercises
            Row(
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Text('Exercises per minute',
                      style: TextStyle(
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          letterSpacing: 1)),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _pickExercise,
                  icon: const Icon(Icons.add,
                      size: 16, color: AppTheme.limeAccent),
                  label: const Text('Add',
                      style: TextStyle(
                          color: AppTheme.limeAccent,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (_items.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: AppTheme.divider, width: 1),
                ),
                child: const Center(
                  child: Text('No exercises added yet',
                      style: TextStyle(color: AppTheme.textMuted)),
                ),
              )
            else
              ..._items.asMap().entries.map((e) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.cardDark,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                              color: AppTheme.limeAccent.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(8)),
                          alignment: Alignment.center,
                          child: Text('${e.key + 1}',
                              style: const TextStyle(
                                  color: AppTheme.limeAccent,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(e.value.exerciseName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                        ),
                        Text('${e.value.reps} reps',
                            style: const TextStyle(
                                color: AppTheme.limeAccent,
                                fontWeight: FontWeight.w700,
                                fontSize: 14)),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () => setState(() => _items.removeAt(e.key)),
                          child: const Icon(Icons.close_rounded,
                              color: AppTheme.textMuted, size: 18),
                        ),
                      ],
                    ),
                  )),

            const SizedBox(height: 20),

            // Save as template
            InkWell(
              onTap: () =>
                  setState(() => _saveAsTemplate = !_saveAsTemplate),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      _saveAsTemplate
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      color: _saveAsTemplate
                          ? AppTheme.limeAccent
                          : AppTheme.textMuted,
                    ),
                    const SizedBox(width: 12),
                    const Text('Save as template',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                  ],
                ),
              ),
            ),
            if (_saveAsTemplate) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _templateNameCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                    hintText: 'Template name (e.g. Pushups + Squats 15)'),
              ),
            ],
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _stepperBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppTheme.textPrimary, size: 22),
      ),
    );
  }
}

class _EmomItem {
  final int exerciseId;
  final String exerciseName;
  final int reps;
  _EmomItem(
      {required this.exerciseId,
      required this.exerciseName,
      required this.reps});
}

class _TemplateCard extends StatelessWidget {
  final Map<String, dynamic> template;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _TemplateCard(
      {required this.template,
      required this.onTap,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final config = jsonDecode(template['config'] as String) as List;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        onTap: onTap,
        onLongPress: onDelete,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: AppTheme.limeAccent.withOpacity(0.4), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                template['name'] as String,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: AppTheme.limeAccent.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text('${template['total_minutes']} min',
                        style: const TextStyle(
                            color: AppTheme.limeAccent,
                            fontWeight: FontWeight.w700,
                            fontSize: 10)),
                  ),
                  const SizedBox(width: 6),
                  Text('${config.length} ex',
                      style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
