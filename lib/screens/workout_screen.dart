import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/theme.dart';
import '../db/db_helper.dart';
import 'workout_log_screen.dart';
import 'stopwatch_session_screen.dart';
import 'rope_skipping_screen.dart';
import 'emom_setup_screen.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  List<Map<String, dynamic>> _sessions = [];

  // 0 = Gym, 1 = Home
  int _mode = 0;

  // ---------- GYM groups ----------
  static const Map<String, IconData> gymGroupIcons = {
    'Chest': Icons.shield_rounded,
    'Back': Icons.accessibility_new_rounded,
    'Triceps': Icons.fitness_center_rounded,
    'Biceps': Icons.sports_martial_arts_rounded,
    'Shoulders': Icons.expand_rounded,
    'Legs': Icons.directions_run_rounded,
  };

  static const Map<String, Color> gymGroupColors = {
    'Chest': AppTheme.coral,
    'Back': AppTheme.lavender,
    'Triceps': AppTheme.peach,
    'Biceps': AppTheme.limeAccent,
    'Shoulders': Color(0xFF7BCDFF),
    'Legs': AppTheme.success,
  };

  // ---------- HOME categories ----------
  static const Map<String, IconData> homeIcons = {
    'Pushups': Icons.airline_seat_flat_rounded,
    'Pullups': Icons.arrow_upward_rounded,
    'Squats': Icons.airline_seat_legroom_normal_rounded,
    'Abs': Icons.bolt_rounded,
    'Planks': Icons.dehaze_rounded,
    'Rope Skipping': Icons.cyclone_rounded,
  };

  static const Map<String, Color> homeColors = {
    'Pushups': AppTheme.coral,
    'Pullups': AppTheme.lavender,
    'Squats': AppTheme.success,
    'Abs': AppTheme.peach,
    'Planks': Color(0xFF7BCDFF),
    'Rope Skipping': AppTheme.limeAccent,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await DBHelper.instance.getAllSessions();
    setState(() => _sessions = s);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.limeAccent,
          backgroundColor: AppTheme.surface,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Workout',
                style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1),
              ),
              const SizedBox(height: 4),
              Text(
                _mode == 0
                    ? 'Pick what you trained today'
                    : 'Train anywhere, no gear needed',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
              ),
              const SizedBox(height: 20),

              _ModeToggle(
                mode: _mode,
                onChange: (m) => setState(() => _mode = m),
              ),
              const SizedBox(height: 20),

              if (_mode == 0) _buildGymSection() else _buildHomeSection(),

              const SizedBox(height: 28),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Workout history',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
              if (_sessions.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppTheme.cardDark,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.fitness_center_rounded,
                          color: AppTheme.textMuted, size: 40),
                      SizedBox(height: 12),
                      Text('No workouts logged yet',
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text('Pick something above to start',
                          style: TextStyle(
                              color: AppTheme.textMuted, fontSize: 12)),
                    ],
                  ),
                )
              else
                ..._sessions.map((s) => _SessionTile(
                      session: s,
                      onTap: () => _viewSession(s),
                      onDelete: () => _confirmDelete(s),
                    )),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- GYM ----------
  Widget _buildGymSection() {
    return Column(
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: gymGroupIcons.keys
              .map((g) => _CategoryCard(
                    name: g,
                    icon: gymGroupIcons[g]!,
                    color: gymGroupColors[g]!,
                    onTap: () => _startGymSession([g]),
                  ))
              .toList(),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => _showMultiGroupPicker(),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding:
                const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.limeAccent, width: 1.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: const [
                Icon(Icons.add_circle_outline_rounded,
                    color: AppTheme.limeAccent, size: 22),
                SizedBox(width: 10),
                Text(
                  'Train multiple groups',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                ),
                Spacer(),
                Icon(Icons.arrow_forward_rounded,
                    color: AppTheme.limeAccent, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------- HOME ----------
  Widget _buildHomeSection() {
    return Column(
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: homeIcons.keys
              .map((g) => _CategoryCard(
                    name: g,
                    icon: homeIcons[g]!,
                    color: homeColors[g]!,
                    onTap: () => _startHomeCategory(g),
                  ))
              .toList(),
        ),
        const SizedBox(height: 12),
        // EMOM wide card
        InkWell(
          onTap: _startEmom,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(
                vertical: 18, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.limeAccent.withOpacity(0.18),
                  AppTheme.warning.withOpacity(0.12),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: AppTheme.limeAccent, width: 1.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.limeAccent.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.flash_on_rounded,
                      color: AppTheme.limeAccent, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'EMOM',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 16),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Every minute on the minute',
                        style: TextStyle(
                            color: AppTheme.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded,
                    color: AppTheme.limeAccent, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------- ROUTING ----------
  Future<void> _startGymSession(List<String> groups) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            WorkoutLogScreen(muscleGroups: groups, workoutType: 'gym'),
      ),
    );
    if (result == true) _load();
  }

  Future<void> _startHomeCategory(String category) async {
    // Stopwatch flow
    if (category == 'Planks') {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const StopwatchSessionScreen(
            category: 'Planks',
            workoutType: 'plank',
          ),
        ),
      );
      if (result == true) _load();
      return;
    }
    if (category == 'Rope Skipping') {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const RopeSkippingScreen(),
        ),
      );
      if (result == true) _load();
      return;
    }
    // Bodyweight reps flow (Pushups, Pullups, Squats, Abs)
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutLogScreen(
          muscleGroups: [category],
          bodyweight: true,
          workoutType: 'home',
        ),
      ),
    );
    if (result == true) _load();
  }

  Future<void> _startEmom() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const EmomSetupScreen()),
    );
    if (result == true) _load();
  }

  Future<void> _showMultiGroupPicker() async {
    final selected = <String>{};
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
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
                  const SizedBox(height: 20),
                  const Text('Select muscle groups',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 16),
                  ...gymGroupIcons.keys.map((g) {
                    final isSel = selected.contains(g);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () => setSheet(() {
                          if (isSel) {
                            selected.remove(g);
                          } else {
                            selected.add(g);
                          }
                        }),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSel
                                ? AppTheme.limeAccent.withOpacity(0.18)
                                : AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSel
                                  ? AppTheme.limeAccent
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(gymGroupIcons[g],
                                  color: gymGroupColors[g], size: 22),
                              const SizedBox(width: 14),
                              Text(g,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600)),
                              const Spacer(),
                              if (isSel)
                                const Icon(Icons.check_circle_rounded,
                                    color: AppTheme.limeAccent),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: selected.isEmpty
                          ? null
                          : () async {
                              Navigator.pop(ctx);
                              await _startGymSession(selected.toList());
                            },
                      style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18))),
                      child: Text('Start (${selected.length})',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  // ---------- HISTORY VIEWER ----------
  Future<void> _viewSession(Map<String, dynamic> session) async {
    final sets =
        await DBHelper.instance.getSetsForSession(session['id'] as int);
    if (!mounted) return;

    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final s in sets) {
      final name = s['exercise_name'] as String;
      grouped.putIfAbsent(name, () => []).add(s);
    }

    final workoutType = (session['workout_type'] as String?) ?? 'gym';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) {
        final date = DateTime.tryParse(session['date'] as String);
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (ctx, scroll) => SingleChildScrollView(
            controller: scroll,
            padding: const EdgeInsets.all(24),
            child: Column(
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
                const SizedBox(height: 20),
                Text(
                  date != null
                      ? DateFormat('EEEE, MMM d, y').format(date)
                      : 'Workout',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: _typeColor(workoutType).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(workoutType.toUpperCase(),
                          style: TextStyle(
                              color: _typeColor(workoutType),
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                              letterSpacing: 1)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        session['muscle_groups'] as String? ?? '',
                        style: const TextStyle(
                            color: AppTheme.lavender,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (grouped.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                        child: Text('No sets recorded',
                            style: TextStyle(color: AppTheme.textMuted))),
                  ),
                ...grouped.entries.map((entry) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardDark,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.key,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 10),
                        ...entry.value.asMap().entries.map((e) {
                          final set = e.value;
                          final duration =
                              (set['duration_seconds'] as int?) ?? 0;
                          final reps = set['reps'] as int;
                          final weight =
                              (set['weight'] as num?)?.toDouble() ?? 0;
                          final hasReps = reps > 0;
                          final hasDuration = duration > 0;
                          // Left side: reps if present, else duration if present, else reps (0)
                          final leftText = hasReps
                              ? '$reps reps'
                              : (hasDuration
                                  ? _fmtDuration(duration)
                                  : '0 reps');
                          // Right side: duration if both present, else label
                          final rightText = (hasReps && hasDuration)
                              ? _fmtDuration(duration)
                              : (hasDuration
                                  ? 'time'
                                  : (weight == 0
                                      ? 'BW'
                                      : '${weight == weight.toInt() ? weight.toStringAsFixed(0) : weight.toStringAsFixed(1)} kg'));
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceLight,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${e.key + 1}',
                                    style: const TextStyle(
                                        color: AppTheme.limeAccent,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  leftText,
                                  style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 14),
                                ),
                                const Spacer(),
                                Text(
                                  rightText,
                                  style: const TextStyle(
                                      color: AppTheme.limeAccent,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }),
                if (session['note'] != null &&
                    (session['note'] as String).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.notes_rounded,
                            color: AppTheme.textMuted, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(session['note'] as String,
                                style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13))),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'home':
        return AppTheme.success;
      case 'plank':
      case 'skipping':
        return const Color(0xFF7BCDFF);
      case 'emom':
        return AppTheme.warning;
      default:
        return AppTheme.limeAccent;
    }
  }

  String _fmtDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h}h ${m.toString().padLeft(2, '0')}m ${s.toString().padLeft(2, '0')}s';
    }
    if (m > 0) {
      return '${m}m ${s.toString().padLeft(2, '0')}s';
    }
    return '${s}s';
  }

  Future<void> _confirmDelete(Map<String, dynamic> session) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete workout?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
            'This will remove all sets logged in this session.',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppTheme.textMuted))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(
                      color: AppTheme.error, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok == true) {
      await DBHelper.instance.deleteSession(session['id'] as int);
      _load();
    }
  }
}

// ---------- Mode toggle (Gym / Home pill) ----------
class _ModeToggle extends StatelessWidget {
  final int mode;
  final ValueChanged<int> onChange;
  const _ModeToggle({required this.mode, required this.onChange});

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
          _seg(0, 'Gym', Icons.fitness_center_rounded),
          _seg(1, 'Home', Icons.home_rounded),
        ],
      ),
    );
  }

  Expanded _seg(int idx, String label, IconData icon) {
    final selected = mode == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChange(idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppTheme.limeAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: selected ? Colors.black : AppTheme.textSecondary),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.black : AppTheme.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CategoryCard(
      {required this.name,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.arrow_forward_rounded,
                      size: 14, color: AppTheme.textPrimary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final Map<String, dynamic> session;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _SessionTile(
      {required this.session, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(session['date'] as String);
    final groups = session['muscle_groups'] as String? ?? '';
    final type = (session['workout_type'] as String?) ?? 'gym';

    IconData icon;
    Color iconColor;
    switch (type) {
      case 'home':
        icon = Icons.home_rounded;
        iconColor = AppTheme.success;
        break;
      case 'plank':
        icon = Icons.timer_rounded;
        iconColor = const Color(0xFF7BCDFF);
        break;
      case 'skipping':
        icon = Icons.cyclone_rounded;
        iconColor = AppTheme.limeAccent;
        break;
      case 'emom':
        icon = Icons.flash_on_rounded;
        iconColor = AppTheme.warning;
        break;
      default:
        icon = Icons.fitness_center_rounded;
        iconColor = AppTheme.limeAccent;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      date != null
                          ? DateFormat('EEE, MMM d').format(date)
                          : '—',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(groups,
                        style: const TextStyle(
                            color: AppTheme.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onDelete,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.delete_outline,
                      color: AppTheme.textMuted, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
