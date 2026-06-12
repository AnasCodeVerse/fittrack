import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/theme.dart';
import '../utils/auth_helper.dart';
import '../db/db_helper.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  final void Function(int)? onNavigate;
  const DashboardScreen({super.key, this.onNavigate});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _username = '';
  double _avgSleep = 0;
  int _workoutsThisWeek = 0;
  double? _latestWeight;
  Map<String, dynamic>? _lastWorkout;
  int _streakDays = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final username = await AuthHelper.getUsername();
    final allSleep = await DBHelper.instance.getAllSleep();
    final allSessions = await DBHelper.instance.getAllSessions();
    final allWeights = await DBHelper.instance.getAllBodyWeight();

    // Avg sleep last 7 days
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final recent = allSleep.where((s) {
      final d = DateTime.tryParse(s['date'] as String);
      return d != null && d.isAfter(weekAgo);
    }).toList();
    double avg = 0;
    if (recent.isNotEmpty) {
      avg = recent
              .map((e) => e['duration_minutes'] as int)
              .reduce((a, b) => a + b) /
          recent.length /
          60.0;
    }

    // Workouts this week
    final wkCount = allSessions.where((s) {
      final d = DateTime.tryParse(s['date'] as String);
      return d != null && d.isAfter(weekAgo);
    }).length;

    // Streak (consecutive days with workout up to today)
    int streak = 0;
    final workoutDates = allSessions
        .map((s) => DateTime.tryParse(s['date'] as String))
        .where((d) => d != null)
        .map((d) => DateTime(d!.year, d.month, d.day))
        .toSet();
    var checkDay = DateTime(now.year, now.month, now.day);
    while (workoutDates.contains(checkDay)) {
      streak++;
      checkDay = checkDay.subtract(const Duration(days: 1));
    }

    if (!mounted) return;
    setState(() {
      _username = username;
      _avgSleep = avg;
      _workoutsThisWeek = wkCount;
      _latestWeight = allWeights.isNotEmpty
          ? (allWeights.first['weight'] as num).toDouble()
          : null;
      _lastWorkout = allSessions.isNotEmpty ? allSessions.first : null;
      _streakDays = streak;
    });
  }

  @override
  Widget build(BuildContext context) {
    final greeting = _getGreeting();
    final dateStr = DateFormat('EEEE, MMM d').format(DateTime.now());

    return Scaffold(
      body: RefreshIndicator(
        color: AppTheme.limeAccent,
        backgroundColor: AppTheme.surface,
        onRefresh: _load,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$greeting,',
                        style: const TextStyle(
                            color: AppTheme.textMuted, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _username,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(dateStr,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13)),
                    ],
                  ),
                  GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen()),
                      );
                      _load();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.settings_rounded,
                          color: AppTheme.textPrimary, size: 22),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Streak banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.limeAccent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.local_fire_department_rounded,
                          color: AppTheme.limeAccent, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Workout Streak',
                            style: TextStyle(
                                color: Colors.black87,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '$_streakDays',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _streakDays == 1 ? 'day' : 'days',
                                style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Stats grid
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.bedtime_rounded,
                      label: 'Avg Sleep',
                      value: _avgSleep > 0 ? _avgSleep.toStringAsFixed(1) : '—',
                      unit: _avgSleep > 0 ? 'hrs' : '',
                      color: AppTheme.lavender,
                      bgColor: AppTheme.lavender.withOpacity(0.18),
                      sub: 'last 7 days',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.fitness_center_rounded,
                      label: 'Workouts',
                      value: '$_workoutsThisWeek',
                      unit: '',
                      color: AppTheme.peach,
                      bgColor: AppTheme.peach.withOpacity(0.18),
                      sub: 'this week',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.monitor_weight_rounded,
                      label: 'Body Weight',
                      value: _latestWeight != null
                          ? _latestWeight!.toStringAsFixed(1)
                          : '—',
                      unit: _latestWeight != null ? 'kg' : '',
                      color: AppTheme.coral,
                      bgColor: AppTheme.coral.withOpacity(0.18),
                      sub: 'latest entry',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.calendar_today_rounded,
                      label: 'Last Workout',
                      value: _lastWorkout != null
                          ? _formatLastWorkout(_lastWorkout!['date'] as String)
                          : '—',
                      unit: '',
                      color: AppTheme.limeAccent,
                      bgColor: AppTheme.limeAccent.withOpacity(0.15),
                      sub: _lastWorkout != null
                          ? (_lastWorkout!['muscle_groups'] as String? ?? '')
                          : 'none yet',
                      smallValue: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Quick actions
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Quick Actions',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _QuickActions(onNavigate: widget.onNavigate),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _getGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _formatLastWorkout(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return '—';
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(d.year, d.month, d.day))
        .inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    return DateFormat('MMM d').format(d);
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final String sub;
  final Color color;
  final Color bgColor;
  final bool smallValue;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.sub,
    required this.color,
    required this.bgColor,
    this.smallValue = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: smallValue ? 20 : 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final void Function(int)? onNavigate;
  const _QuickActions({this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionTile(
            label: 'Log Sleep',
            icon: Icons.bedtime_rounded,
            color: AppTheme.lavender,
            onTap: () => onNavigate?.call(1),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionTile(
            label: 'Add Workout',
            icon: Icons.add_rounded,
            color: AppTheme.limeAccent,
            onTap: () => onNavigate?.call(2),
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.divider, width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
