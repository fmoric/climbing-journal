import 'package:flutter/material.dart';

import '../data/journal_repository.dart';
import '../domain/stats.dart';
import '../models/ascent.dart';
import '../models/climb_route.dart';
import '../models/crag.dart';
import '../models/enums.dart';
import '../report/yearly_report.dart';
import 'theme.dart';
import 'widgets.dart';

/// History (FR-6): year, discipline filter, grade pyramid, ascent list,
/// and the yearly PDF report (FR-9).
class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key, required this.repo, required this.climber});

  final JournalRepository repo;
  final String climber;

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  late final Stream<List<Ascent>> _ascents = widget.repo.watchMyAscents();
  late final Stream<List<ClimbRoute>> _routes = widget.repo.watchAllRoutes();
  late final Stream<List<Crag>> _crags = widget.repo.watchCrags();

  int _year = DateTime.now().year;
  Discipline? _discipline;
  bool _exporting = false;

  Future<void> _export(List<Ascent> ascents, Map<String, ClimbRoute> routes,
      Map<String, Crag> crags) async {
    setState(() => _exporting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final summary = summarizeYear(_year, ascents, routes);
      final bytes = await buildYearlyReport(
        summary: summary,
        routes: routes,
        crags: crags,
        climber: widget.climber,
      );
      await shareYearlyReport(bytes, _year);
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Could not create the report: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _confirmDelete(Ascent a, ClimbRoute? r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this ascent?'),
        content: Text(
            '${r?.name ?? 'Route'} · ${styleLabel(a.style)} · ${formatDate(a.date)}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) widget.repo.deleteAscent(a.id);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Ascent>>(
      stream: _ascents,
      builder: (context, aSnap) => StreamBuilder<List<ClimbRoute>>(
        stream: _routes,
        builder: (context, rSnap) => StreamBuilder<List<Crag>>(
          stream: _crags,
          builder: (context, cSnap) {
            if (aSnap.hasError) {
              return Center(child: Text('Cannot load history: ${aSnap.error}'));
            }
            final ascents = aSnap.data;
            if (ascents == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final routes = {for (final r in rSnap.data ?? <ClimbRoute>[]) r.id: r};
            final crags = {for (final c in cSnap.data ?? <Crag>[]) c.id: c};
            return _build(ascents, routes, crags);
          },
        ),
      ),
    );
  }

  Widget _build(List<Ascent> all, Map<String, ClimbRoute> routes,
      Map<String, Crag> crags) {
    final years = yearsWithAscents(all);
    if (!years.contains(_year)) years.insert(0, _year);
    years.sort((a, b) => b.compareTo(a));

    final summary = summarizeYear(_year, all, routes);
    final inYear = summary.ascents.reversed.where((a) {
      if (_discipline == null) return true;
      return routes[a.routeId]?.discipline == _discipline;
    }).toList();

    final pyramidDiscipline = _discipline ??
        (summary.pyramids.keys.isEmpty ? null : summary.pyramids.keys.first);
    final rows = pyramidDiscipline == null
        ? const <PyramidRow>[]
        : summary.pyramids[pyramidDiscipline] ?? const <PyramidRow>[];

    // Group by day, newest first.
    final groups = <String, List<Ascent>>{};
    for (final a in inYear) {
      groups.putIfAbsent(formatDate(a.date), () => []).add(a);
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text('History',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5)),
                ),
                DropdownButton<int>(
                  value: _year,
                  underline: const SizedBox.shrink(),
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink),
                  items: [
                    for (final y in years)
                      DropdownMenuItem(value: y, child: Text('$y')),
                  ],
                  onChanged: (y) => setState(() => _year = y ?? _year),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: FilledButton.tonalIcon(
              onPressed: _exporting
                  ? null
                  : () => _export(all, routes, crags),
              icon: _exporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.picture_as_pdf_outlined),
              label: Text('Download $_year report (PDF)'),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48)),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              children: [
                _chip('All', _discipline == null,
                    () => setState(() => _discipline = null)),
                for (final d in Discipline.values)
                  _chip(disciplineLabel(d), _discipline == d,
                      () => setState(() => _discipline = d)),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Row(
              children: [
                _stat('${summary.ascents.length}', 'ascents'),
                _stat('${summary.sends}', 'sends'),
                _stat('${summary.days}', 'days'),
              ],
            ),
          ),
        ),
        if (pyramidDiscipline != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: _PyramidCard(
                  discipline: pyramidDiscipline, rows: rows),
            ),
          ),
        if (inYear.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('No ascents in $_year yet.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.quiet)),
            ),
          ),
        for (final entry in groups.entries) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
              child: SectionLabel(
                  '${entry.key} · ${crags[entry.value.first.cragId]?.name ?? ''}'),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList.separated(
              itemCount: entry.value.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, i) {
                final a = entry.value[i];
                final r = routes[a.routeId];
                return _AscentTile(
                  ascent: a,
                  route: r,
                  onLongPress: () => _confirmDelete(a, r),
                );
              },
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Widget _stat(String value, String label) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            Text(label,
                style: const TextStyle(fontSize: 13, color: AppColors.quiet)),
          ],
        ),
      );

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.ink,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          color: selected ? AppColors.ground : AppColors.ink,
        ),
        shape: const StadiumBorder(side: BorderSide(color: AppColors.line)),
      ),
    );
  }
}

class _PyramidCard extends StatelessWidget {
  const _PyramidCard({required this.discipline, required this.rows});

  final Discipline discipline;
  final List<PyramidRow> rows;

  @override
  Widget build(BuildContext context) {
    final max = rows.fold<int>(0, (m, r) => r.count > m ? r.count : m);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Grade pyramid · ${disciplineLabel(discipline)}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const Text('Sends only',
                style: TextStyle(fontSize: 12, color: AppColors.quiet)),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              const Text('No sends yet.',
                  style: TextStyle(color: AppColors.quiet)),
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text(r.grade,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Align(
                        alignment: Alignment.center,
                        child: FractionallySizedBox(
                          widthFactor: r.count / max,
                          child: Container(
                            height: 22,
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 28,
                      child: Text('${r.count}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.quiet)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AscentTile extends StatelessWidget {
  const _AscentTile({
    required this.ascent,
    required this.route,
    required this.onLongPress,
  });

  final Ascent ascent;
  final ClimbRoute? route;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final r = route;
    final meta = [
      if (r != null) disciplineLabel(r.discipline),
      '${ascent.attempts} ${ascent.attempts == 1 ? 'attempt' : 'attempts'}',
      if (ascent.visibility == AscentVisibility.circle) 'shared',
    ].join(' · ');
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              GradeBadge(r?.grade ?? '?', size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r?.name ?? 'Deleted route',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    Text(meta,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.quiet)),
                    if (ascent.notes.isNotEmpty)
                      Text(ascent.notes,
                          style: const TextStyle(
                              fontSize: 13, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
              StylePill(ascent.style),
            ],
          ),
        ),
      ),
    );
  }
}
