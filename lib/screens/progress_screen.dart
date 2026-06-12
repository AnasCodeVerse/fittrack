import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../utils/theme.dart';
import '../db/db_helper.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<Map<String, dynamic>> _prs = [];
  List<Map<String, dynamic>> _bodyWeights = [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    final allEx = await DBHelper.instance.getAllExercises();
    final List<Map<String, dynamic>> prs = [];
    for (final ex in allEx) {
      final pr = await DBHelper.instance.getMaxWeightForExercise(ex['id'] as int);
      if (pr != null) {
        prs.add({
          'name': ex['name'],
          'group': ex['muscle_group'],
          'weight': pr['weight'],
          'reps': pr['reps'],
          'date': pr['date'],
          'exercise_id': ex['id'],
        });
      }
    }
    prs.sort((a, b) => (b['weight'] as num).compareTo(a['weight'] as num));
    final bw = await DBHelper.instance.getAllBodyWeight();
    setState(() {
      _prs = prs;
      _bodyWeights = bw;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Progress',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1),
                ),
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
                  Tab(text: 'Personal Records'),
                  Tab(text: 'Body Weight'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _buildPRTab(),
                  _buildBodyWeightTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPRTab() {
    if (_prs.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 60),
          const Icon(Icons.emoji_events_outlined, color: AppTheme.textMuted, size: 50),
          const SizedBox(height: 12),
          const Center(child: Text('No PRs yet', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600))),
          const SizedBox(height: 4),
          const Center(child: Text('Log workouts to see your records', style: TextStyle(color: AppTheme.textMuted, fontSize: 12))),
        ],
      );
    }
    return RefreshIndicator(
      color: AppTheme.limeAccent,
      backgroundColor: AppTheme.surface,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          ..._prs.map((pr) => _PRTile(pr: pr, onTap: () => _showProgressChart(pr))),
        ],
      ),
    );
  }

  Widget _buildBodyWeightTab() {
    final spots = <FlSpot>[];
    final sortedAsc = [..._bodyWeights]..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    for (int i = 0; i < sortedAsc.length; i++) {
      spots.add(FlSpot(i.toDouble(), (sortedAsc[i]['weight'] as num).toDouble()));
    }

    final latest = _bodyWeights.isNotEmpty ? (_bodyWeights.first['weight'] as num).toDouble() : null;
    final oldest = _bodyWeights.isNotEmpty ? (_bodyWeights.last['weight'] as num).toDouble() : null;
    final delta = (latest != null && oldest != null) ? latest - oldest : null;

    return RefreshIndicator(
      color: AppTheme.limeAccent,
      backgroundColor: AppTheme.surface,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          // Add button
          ElevatedButton.icon(
            onPressed: _addBodyWeight,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Log Weight'),
          ),
          const SizedBox(height: 16),
          if (latest != null) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Current weight', style: TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        latest.toStringAsFixed(1),
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 44, fontWeight: FontWeight.w800, letterSpacing: -1.5),
                      ),
                      const SizedBox(width: 6),
                      const Text('kg', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      if (delta != null && delta != 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: (delta > 0 ? AppTheme.coral : AppTheme.success).withOpacity(0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                delta > 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                                color: delta > 0 ? AppTheme.coral : AppTheme.success,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)} kg',
                                style: TextStyle(
                                  color: delta > 0 ? AppTheme.coral : AppTheme.success,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (spots.length > 1)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text('Trend', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 200,
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (_) => const FlLine(color: AppTheme.divider, strokeWidth: 0.5, dashArray: [4, 4]),
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 36,
                                getTitlesWidget: (v, _) => Text(v.toStringAsFixed(0), style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                              ),
                            ),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: spots,
                              isCurved: true,
                              color: AppTheme.coral,
                              barWidth: 3,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                                  radius: 4,
                                  color: AppTheme.coral,
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
                                    AppTheme.coral.withOpacity(0.3),
                                    AppTheme.coral.withOpacity(0.0),
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
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
            ..._bodyWeights.map((bw) {
              final d = DateTime.tryParse(bw['date'] as String);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        d != null ? DateFormat('EEE, MMM d, y').format(d) : '—',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      '${(bw['weight'] as num).toStringAsFixed(1)} kg',
                      style: const TextStyle(color: AppTheme.coral, fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () async {
                        await DBHelper.instance.deleteBodyWeight(bw['id'] as int);
                        _load();
                      },
                      child: const Icon(Icons.delete_outline, color: AppTheme.textMuted, size: 18),
                    ),
                  ],
                ),
              );
            }),
          ] else
            Container(
              margin: const EdgeInsets.only(top: 24),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                children: [
                  Icon(Icons.monitor_weight_outlined, color: AppTheme.textMuted, size: 40),
                  SizedBox(height: 12),
                  Text('No weight logged yet', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _addBodyWeight() async {
    final weight = TextEditingController();
    DateTime selectedDate = DateTime.now();

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
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
                    decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 18),
                const Text('Log Body Weight', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 24),
                TextField(
                  controller: weight,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(
                    hintText: '0.0',
                    suffixText: 'kg',
                    suffixStyle: TextStyle(color: AppTheme.textMuted, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
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
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, color: AppTheme.textMuted, size: 18),
                        const SizedBox(width: 10),
                        Text(DateFormat('EEE, MMM d, y').format(selectedDate), style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () async {
                      final w = double.tryParse(weight.text.trim());
                      if (w == null || w <= 0) return;
                      await DBHelper.instance.insertBodyWeight({
                        'date': selectedDate.toIso8601String(),
                        'weight': w,
                      });
                      if (mounted) Navigator.pop(ctx);
                      _load();
                    },
                    style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                    child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showProgressChart(Map<String, dynamic> pr) async {
    final progress = await DBHelper.instance.getProgressForExercise(pr['exercise_id'] as int);
    if (!mounted) return;

    final spots = <FlSpot>[];
    for (int i = 0; i < progress.length; i++) {
      spots.add(FlSpot(i.toDouble(), (progress[i]['max_weight'] as num).toDouble()));
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        minChildSize: 0.4,
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
                  decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 20),
              Text(pr['name'] as String, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
              const SizedBox(height: 4),
              Text(pr['group'] as String, style: const TextStyle(color: AppTheme.lavender, fontWeight: FontWeight.w600)),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.limeAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events_rounded, color: AppTheme.limeAccent, size: 32),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Personal Record', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '${(pr['weight'] as num).toStringAsFixed(1)}',
                              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(width: 6),
                            const Text('kg', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 12),
                            Text('× ${pr['reps']}', style: const TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (spots.length > 1) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text('Max weight per session', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                  decoration: BoxDecoration(color: AppTheme.cardDark, borderRadius: BorderRadius.circular(20)),
                  child: SizedBox(
                    height: 200,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (_) => const FlLine(color: AppTheme.divider, strokeWidth: 0.5, dashArray: [4, 4]),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 36,
                              getTitlesWidget: (v, _) => Text(v.toStringAsFixed(0), style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                            ),
                          ),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            color: AppTheme.limeAccent,
                            barWidth: 3,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (s, p, b, i) => FlDotCirclePainter(
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
                                colors: [AppTheme.limeAccent.withOpacity(0.3), AppTheme.limeAccent.withOpacity(0)],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ] else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text('Log more sessions to see progress', style: TextStyle(color: AppTheme.textMuted))),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PRTile extends StatelessWidget {
  final Map<String, dynamic> pr;
  final VoidCallback onTap;
  const _PRTile({required this.pr, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(pr['date'] as String);
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
                  color: AppTheme.limeAccent.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.emoji_events_rounded, color: AppTheme.limeAccent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pr['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                      '${pr['group']} • ${date != null ? DateFormat('MMM d').format(date) : '—'}',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${(pr['weight'] as num).toStringAsFixed(1)}',
                        style: const TextStyle(color: AppTheme.limeAccent, fontWeight: FontWeight.w800, fontSize: 18),
                      ),
                      const SizedBox(width: 3),
                      const Text('kg', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  Text('× ${pr['reps']} reps', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
