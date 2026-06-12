import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../utils/theme.dart';
import '../db/db_helper.dart';

class SleepScreen extends StatefulWidget {
  const SleepScreen({super.key});

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<Map<String, dynamic>> _entries = [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    final entries = await DBHelper.instance.getAllSleep();
    setState(() => _entries = entries);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Sleep',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddDialog(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Log'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: TabBar(
                controller: _tab,
                indicator: BoxDecoration(
                  color: AppTheme.limeAccent,
                  borderRadius: BorderRadius.circular(14),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.all(4),
                labelColor: Colors.black,
                unselectedLabelColor: AppTheme.textSecondary,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Week'),
                  Tab(text: 'Month'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _buildPeriodView(7),
                  _buildPeriodView(30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodView(int days) {
    final now = DateTime.now();
    final cutoff = now.subtract(Duration(days: days));
    final filtered = _entries.where((e) {
      final d = DateTime.tryParse(e['date'] as String);
      return d != null && d.isAfter(cutoff);
    }).toList();

    final avgMinutes = filtered.isEmpty
        ? 0.0
        : filtered.map((e) => e['duration_minutes'] as int).reduce((a, b) => a + b) / filtered.length;
    final avgHours = avgMinutes / 60.0;
    final totalHours = filtered.isEmpty
        ? 0.0
        : filtered.map((e) => e['duration_minutes'] as int).reduce((a, b) => a + b) / 60.0;

    // Build chart data
    final List<FlSpot> spots = [];
    final sortedAsc = [...filtered]..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    for (int i = 0; i < sortedAsc.length; i++) {
      final mins = sortedAsc[i]['duration_minutes'] as int;
      spots.add(FlSpot(i.toDouble(), mins / 60.0));
    }

    return RefreshIndicator(
      color: AppTheme.limeAccent,
      backgroundColor: AppTheme.surface,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        children: [
          Row(
            children: [
              Expanded(
                child: _SleepStatCard(
                  label: 'Average',
                  value: avgHours > 0 ? avgHours.toStringAsFixed(1) : '—',
                  unit: avgHours > 0 ? 'hrs' : '',
                  color: AppTheme.lavender,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SleepStatCard(
                  label: 'Entries',
                  value: '${filtered.length}',
                  unit: '',
                  color: AppTheme.peach,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SleepStatCard(
                  label: 'Total',
                  value: totalHours > 0 ? totalHours.toStringAsFixed(0) : '—',
                  unit: totalHours > 0 ? 'hrs' : '',
                  color: AppTheme.coral,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (spots.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text('Sleep trend', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 180,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 2,
                          getDrawingHorizontalLine: (_) => const FlLine(color: AppTheme.divider, strokeWidth: 0.5, dashArray: [4, 4]),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 2,
                              reservedSize: 30,
                              getTitlesWidget: (v, _) => Text('${v.toInt()}h', style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                            ),
                          ),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        minY: 0,
                        maxY: 12,
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            color: AppTheme.limeAccent,
                            barWidth: 3,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                                radius: 4,
                                color: AppTheme.limeAccent,
                                strokeWidth: 2,
                                strokeColor: AppTheme.background,
                              ),
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppTheme.limeAccent.withOpacity(0.3),
                                  AppTheme.limeAccent.withOpacity(0.0),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Recent entries',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                children: [
                  Icon(Icons.bedtime_outlined, color: AppTheme.textMuted, size: 40),
                  SizedBox(height: 12),
                  Text('No sleep entries yet', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text('Tap "Log" to add your first entry', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                ],
              ),
            )
          else
            ...filtered.map((e) => _SleepEntryTile(
                  entry: e,
                  onDelete: () async {
                    await DBHelper.instance.deleteSleep(e['id'] as int);
                    _load();
                  },
                )),
        ],
      ),
    );
  }

  void _showAddDialog() async {
    DateTime selectedDate = DateTime.now();
    TimeOfDay sleepTime = const TimeOfDay(hour: 23, minute: 0);
    TimeOfDay wakeTime = const TimeOfDay(hour: 7, minute: 0);
    final noteController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Log Sleep', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                  const SizedBox(height: 24),
                  // Date picker
                  _PickerTile(
                    icon: Icons.calendar_today_rounded,
                    label: 'Date',
                    value: DateFormat('EEE, MMM d').format(selectedDate),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        builder: (ctx, child) => Theme(
                          data: Theme.of(ctx).copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: AppTheme.limeAccent,
                              onPrimary: Colors.black,
                              surface: AppTheme.surface,
                              onSurface: AppTheme.textPrimary,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) setSheet(() => selectedDate = picked);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _PickerTile(
                          icon: Icons.bedtime_rounded,
                          label: 'Sleep',
                          value: sleepTime.format(ctx),
                          onTap: () async {
                            final t = await showTimePicker(
                              context: ctx,
                              initialTime: sleepTime,
                              builder: (ctx, child) => Theme(
                                data: Theme.of(ctx).copyWith(
                                  colorScheme: const ColorScheme.dark(
                                    primary: AppTheme.limeAccent,
                                    onPrimary: Colors.black,
                                    surface: AppTheme.surface,
                                    onSurface: AppTheme.textPrimary,
                                  ),
                                ),
                                child: child!,
                              ),
                            );
                            if (t != null) setSheet(() => sleepTime = t);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PickerTile(
                          icon: Icons.wb_sunny_rounded,
                          label: 'Wake',
                          value: wakeTime.format(ctx),
                          onTap: () async {
                            final t = await showTimePicker(
                              context: ctx,
                              initialTime: wakeTime,
                              builder: (ctx, child) => Theme(
                                data: Theme.of(ctx).copyWith(
                                  colorScheme: const ColorScheme.dark(
                                    primary: AppTheme.limeAccent,
                                    onPrimary: Colors.black,
                                    surface: AppTheme.surface,
                                    onSurface: AppTheme.textPrimary,
                                  ),
                                ),
                                child: child!,
                              ),
                            );
                            if (t != null) setSheet(() => wakeTime = t);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Notes (optional)',
                      prefixIcon: Icon(Icons.notes_rounded, color: AppTheme.textMuted),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Live duration display
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.limeAccent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_rounded, color: AppTheme.limeAccent),
                        const SizedBox(width: 12),
                        const Text('Duration', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                        const Spacer(),
                        Text(
                          _formatDuration(_calcDuration(sleepTime, wakeTime)),
                          style: const TextStyle(color: AppTheme.limeAccent, fontWeight: FontWeight.w800, fontSize: 18),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () async {
                        final mins = _calcDuration(sleepTime, wakeTime);
                        await DBHelper.instance.insertSleep({
                          'date': selectedDate.toIso8601String(),
                          'sleep_time': '${sleepTime.hour}:${sleepTime.minute}',
                          'wake_time': '${wakeTime.hour}:${wakeTime.minute}',
                          'duration_minutes': mins,
                          'note': noteController.text.trim(),
                        });
                        if (mounted) Navigator.pop(ctx);
                        _load();
                      },
                      style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                      child: const Text('Save Entry', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
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

  int _calcDuration(TimeOfDay sleep, TimeOfDay wake) {
    int sleepMin = sleep.hour * 60 + sleep.minute;
    int wakeMin = wake.hour * 60 + wake.minute;
    if (wakeMin <= sleepMin) wakeMin += 24 * 60;
    return wakeMin - sleepMin;
  }

  String _formatDuration(int mins) {
    final h = mins ~/ 60;
    final m = mins % 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }
}

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  const _PickerTile({required this.icon, required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.textMuted, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SleepStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  const _SleepStatCard({required this.label, required this.value, required this.unit, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 3),
                Text(unit, style: TextStyle(color: color.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SleepEntryTile extends StatelessWidget {
  final Map<String, dynamic> entry;
  final VoidCallback onDelete;
  const _SleepEntryTile({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(entry['date'] as String);
    final mins = entry['duration_minutes'] as int;
    final h = mins ~/ 60;
    final m = mins % 60;
    final note = entry['note'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
              color: AppTheme.lavender.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.bedtime_rounded, color: AppTheme.lavender, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date != null ? DateFormat('EEE, MMM d').format(date) : '—',
                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry['sleep_time']} → ${entry['wake_time']}',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
                if (note != null && note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(note, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${h}h ${m.toString().padLeft(2, '0')}m',
                style: const TextStyle(color: AppTheme.limeAccent, fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: onDelete,
                child: const Icon(Icons.delete_outline, color: AppTheme.textMuted, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
