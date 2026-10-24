import 'package:flutter/material.dart';

import '../data/journal_repository.dart';
import '../domain/grades.dart';
import '../domain/similarity.dart';
import '../domain/stats.dart';
import '../models/climb_route.dart';
import '../models/enums.dart';
import '../models/sector.dart';
import 'theme.dart';
import 'widgets.dart';

/// Add-route form (FR-3) with duplicate suggestion (FR-4).
///
/// Pops with the route to log: either the new route or an existing one
/// the user picked from the suggestion.
class AddRouteScreen extends StatefulWidget {
  const AddRouteScreen({
    super.key,
    required this.repo,
    required this.cragId,
    required this.cragName,
    required this.sectors,
    required this.existing,
    this.sectorId,
  });

  final JournalRepository repo;
  final String cragId;
  final String cragName;
  final List<Sector> sectors;

  /// Routes already at this crag, for the duplicate check.
  final List<ClimbRoute> existing;
  final String? sectorId;

  @override
  State<AddRouteScreen> createState() => _AddRouteScreenState();
}

class _AddRouteScreenState extends State<AddRouteScreen> {
  final _name = TextEditingController();
  Discipline _discipline = Discipline.sport;
  GradeSystem _system = GradeSystem.french;
  String? _grade;
  int _pitches = 1;
  String? _sectorId;
  String? _dismissedFor;

  @override
  void initState() {
    super.initState();
    _sectorId = widget.sectorId;
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  List<GradeSystem> get _systems => _discipline == Discipline.boulder
      ? const [GradeSystem.font, GradeSystem.vScale]
      : const [GradeSystem.french, GradeSystem.uiaa, GradeSystem.yds];

  void _setDiscipline(Discipline d) {
    setState(() {
      _discipline = d;
      if (!_systems.contains(_system)) {
        _system = Grades.defaultFor(d);
        _grade = null;
      }
      if (d != Discipline.trad) _pitches = 1;
    });
  }

  List<ClimbRoute> get _suggestions {
    final text = _name.text.trim();
    if (text.isEmpty || _dismissedFor == text) return const [];
    // Same sector first, then the rest of the crag.
    final matches = similarRoutes(text, widget.existing);
    matches.sort((a, b) {
      final sa = a.sectorId == _sectorId ? 0 : 1;
      final sb = b.sectorId == _sectorId ? 0 : 1;
      return sa.compareTo(sb);
    });
    return matches.take(2).toList();
  }

  bool get _canSave => _name.text.trim().isNotEmpty && _grade != null;

  void _save() {
    final repo = widget.repo;
    final route = ClimbRoute(
      id: repo.newId(),
      cragId: widget.cragId,
      sectorId: _sectorId,
      name: _name.text.trim(),
      discipline: _discipline,
      grade: _grade!,
      gradeSystem: _system,
      pitches: _pitches,
    );
    repo.createRoute(route);
    Navigator.of(context).pop(route);
  }

  String? _sectorName(String? id) {
    for (final s in widget.sectors) {
      if (s.id == id) return s.name;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _suggestions;
    final sectorName = _sectorName(_sectorId);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('New route'),
            Text(
              sectorName == null
                  ? widget.cragName
                  : '${widget.cragName} · $sectorName',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.quiet),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Name'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 16),
            _DuplicateCard(
              sectorName: sectorName,
              routes: suggestions,
              onUse: (r) => Navigator.of(context).pop(r),
              onDismiss: () =>
                  setState(() => _dismissedFor = _name.text.trim()),
            ),
          ],
          const SizedBox(height: 20),
          const SectionLabel('Discipline'),
          const SizedBox(height: 8),
          SegmentedButton<Discipline>(
            showSelectedIcon: false,
            segments: [
              for (final d in Discipline.values)
                ButtonSegment(value: d, label: Text(disciplineLabel(d))),
            ],
            selected: {_discipline},
            onSelectionChanged: (s) => _setDiscipline(s.first),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('grade-${_system.name}'),
                  initialValue: _grade,
                  decoration: const InputDecoration(labelText: 'Grade'),
                  items: [
                    for (final g in Grades.scale(_system))
                      DropdownMenuItem(value: g, child: Text(g)),
                  ],
                  onChanged: (g) => setState(() => _grade = g),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<GradeSystem>(
                  key: ValueKey('system-${_discipline.name}'),
                  initialValue: _system,
                  decoration: const InputDecoration(labelText: 'System'),
                  items: [
                    for (final s in _systems)
                      DropdownMenuItem(
                          value: s, child: Text(Grades.systemLabel(s))),
                  ],
                  onChanged: (s) {
                    if (s == null) return;
                    setState(() {
                      // Keep the chosen difficulty when switching systems.
                      _grade = _grade == null
                          ? null
                          : Grades.convert(_grade!, _system, s);
                      _system = s;
                    });
                  },
                ),
              ),
            ],
          ),
          if (widget.sectors.isNotEmpty) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: _sectorId,
              decoration: const InputDecoration(labelText: 'Sector'),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('No sector')),
                for (final s in widget.sectors)
                  DropdownMenuItem<String?>(value: s.id, child: Text(s.name)),
              ],
              onChanged: (v) => setState(() => _sectorId = v),
            ),
          ],
          if (_discipline == Discipline.trad) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text('Pitches',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                IconButton.outlined(
                  tooltip: 'Fewer pitches',
                  onPressed:
                      _pitches > 1 ? () => setState(() => _pitches--) : null,
                  icon: const Icon(Icons.remove),
                ),
                SizedBox(
                  width: 40,
                  child: Text('$_pitches',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800)),
                ),
                IconButton.outlined(
                  tooltip: 'More pitches',
                  onPressed: () => setState(() => _pitches++),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          const Text('Name, discipline and grade are enough. Add details later.',
              style: TextStyle(fontSize: 13, color: AppColors.quiet)),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _canSave ? _save : null,
            child: const Text('Save and log ascent'),
          ),
        ],
      ),
    );
  }
}

class _DuplicateCard extends StatelessWidget {
  const _DuplicateCard({
    required this.sectorName,
    required this.routes,
    required this.onUse,
    required this.onDismiss,
  });

  final String? sectorName;
  final List<ClimbRoute> routes;
  final ValueChanged<ClimbRoute> onUse;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warnBg,
        border: Border.all(color: AppColors.warnLine),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            sectorName == null ? 'Already here?' : 'Already in $sectorName?',
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.warnInk),
          ),
          const Text('A similar route exists. Log that one instead?',
              style: TextStyle(fontSize: 13, color: AppColors.warnInk)),
          const SizedBox(height: 10),
          for (final r in routes) ...[
            Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onUse(r),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      GradeBadge(r.grade, size: 38),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(r.name,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                      const Text('Use this',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          OutlinedButton(
            onPressed: onDismiss,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              foregroundColor: AppColors.warnInk,
            ),
            child: const Text("It's a new route"),
          ),
        ],
      ),
    );
  }
}
