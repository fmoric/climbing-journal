import 'package:cloud_firestore/cloud_firestore.dart' show GeoPoint;
import 'package:flutter/material.dart';

import '../data/journal_repository.dart';
import '../data/photo_store.dart';
import '../domain/geo.dart';
import '../domain/location_service.dart';
import '../domain/stats.dart';
import '../models/ascent.dart';
import '../models/climb_route.dart';
import '../models/crag.dart';
import '../models/enums.dart';
import '../models/sector.dart';
import 'add_route_screen.dart';
import 'climbing_mode_screen.dart';
import 'quick_log_sheet.dart';
import 'theme.dart';
import 'widgets.dart';

/// Crag screen: nearest crag, sectors, routes; tap a route to log it,
/// or Start to open climbing mode with its photos.
class LogTab extends StatefulWidget {
  const LogTab({super.key, required this.repo, required this.photos});

  final JournalRepository repo;
  final PhotoStore photos;

  @override
  State<LogTab> createState() => _LogTabState();
}

class _LogTabState extends State<LogTab> {
  late final Stream<List<Crag>> _crags = widget.repo.watchCrags();
  late final Stream<List<Ascent>> _ascents = widget.repo.watchMyAscents();

  String? _cragId;
  String _cragHow = '';
  String? _sectorId;
  Stream<List<Sector>>? _sectors;
  Stream<List<ClimbRoute>>? _routes;
  bool _located = false;

  void _selectCrag(Crag crag, String how) {
    setState(() {
      _cragId = crag.id;
      _cragHow = how;
      _sectorId = null;
      _sectors = widget.repo.watchSectors(crag.id);
      _routes = widget.repo.watchRoutes(crag.id);
    });
  }

  /// FR-2: propose the nearest crag once crags are known.
  Future<void> _locate(List<Crag> crags) async {
    if (_located) return;
    _located = true;
    if (widget.repo.isDemo) {
      if (crags.isNotEmpty) _selectCrag(crags.first, 'Demo · GPS off');
      return;
    }
    final pos = await const LocationService().current();
    if (!mounted || _cragId != null) return;
    final match = pos == null ? null : nearestCrag(crags, pos.lat, pos.lng);
    if (match != null) {
      _selectCrag(
          match.crag, 'GPS match · ${formatDistance(match.distance)} away');
    } else if (crags.isNotEmpty) {
      _selectCrag(crags.first, 'No crag nearby · chosen from list');
    }
  }

  Future<void> _changeCrag(List<Crag> crags) async {
    if (crags.isEmpty) {
      // Nothing to choose from yet: go straight to adding one.
      final crag = await _newCrag();
      if (crag != null) _selectCrag(crag, 'Just added');
      return;
    }
    final picked = await showModalBottomSheet<Crag>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.ground,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          for (final c in crags)
            ListTile(
              leading: Icon(c.type == CragType.gym
                  ? Icons.fitness_center
                  : Icons.terrain),
              title: Text(c.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: c.type == CragType.outdoor && c.location == null
                  ? const Text('No location saved')
                  : null,
              selected: c.id == _cragId,
              onTap: () => Navigator.pop(context, c),
              trailing: widget.repo.isDemo || c.type == CragType.gym
                  ? null
                  : IconButton(
                      tooltip: 'Save my current location for ${c.name}',
                      icon: const Icon(Icons.my_location),
                      onPressed: () async {
                        final ok = await _saveLocation(c);
                        if (ok && context.mounted) {
                          Navigator.pop(context, c);
                        }
                      },
                    ),
            ),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Add crag or gym'),
            onTap: () async {
              final crag = await _newCrag();
              if (context.mounted) Navigator.pop(context, crag);
            },
          ),
        ],
      ),
    );
    if (picked != null) _selectCrag(picked, 'Chosen manually');
  }

  /// Stores the phone's position on the crag, so GPS finds it next time.
  Future<bool> _saveLocation(Crag crag) async {
    final messenger = ScaffoldMessenger.of(context);
    final pos = await const LocationService().current();
    if (pos == null) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Location unavailable. Check that GPS is on.')));
      return false;
    }
    widget.repo.updateCrag(Crag(
      id: crag.id,
      name: crag.name,
      type: crag.type,
      location: GeoPoint(pos.lat, pos.lng),
    ));
    messenger.showSnackBar(
        SnackBar(content: Text('Location saved for ${crag.name}.')));
    return true;
  }

  Future<Crag?> _newCrag() async {
    final name = TextEditingController();
    var type = CragType.outdoor;
    var here = !widget.repo.isDemo;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('New crag'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              SegmentedButton<CragType>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: CragType.outdoor, label: Text('Outdoor')),
                  ButtonSegment(value: CragType.gym, label: Text('Gym')),
                ],
                selected: {type},
                onSelectionChanged: (s) => setLocal(() => type = s.first),
              ),
              if (type == CragType.outdoor && !widget.repo.isDemo)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: here,
                  onChanged: (v) => setLocal(() => here = v ?? false),
                  title: const Text("I'm at this crag now"),
                  subtitle: const Text('Saves the location for GPS'),
                ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Add')),
          ],
        ),
      ),
    );
    final text = name.text.trim();
    name.dispose();
    if (ok != true || text.isEmpty) return null;
    GeoPoint? location;
    if (here && type == CragType.outdoor) {
      final pos = await const LocationService().current();
      if (pos != null) location = GeoPoint(pos.lat, pos.lng);
    }
    final crag = Crag(
        id: widget.repo.newId(), name: text, type: type, location: location);
    widget.repo.createCrag(crag);
    return crag;
  }

  Future<void> _addRoute(Crag crag, List<Sector> sectors,
      List<ClimbRoute> routes) async {
    final route = await Navigator.of(context).push<ClimbRoute>(
      MaterialPageRoute(
        builder: (_) => AddRouteScreen(
          repo: widget.repo,
          cragId: crag.id,
          cragName: crag.name,
          sectors: sectors,
          existing: routes,
          sectorId: _sectorId,
        ),
      ),
    );
    if (route != null && mounted) {
      await _log(route, crag, sectors);
    }
  }

  String _subtitle(ClimbRoute r, Crag crag, List<Sector> sectors) {
    final sector = sectors.where((s) => s.id == r.sectorId).firstOrNull;
    return [
      crag.name,
      if (sector != null) sector.name,
      disciplineLabel(r.discipline),
    ].join(' · ');
  }

  Future<void> _log(ClimbRoute r, Crag crag, List<Sector> sectors) =>
      showQuickLog(context,
          repo: widget.repo, route: r, subtitle: _subtitle(r, crag, sectors));

  Future<void> _start(ClimbRoute r, Crag crag, List<Sector> sectors) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ClimbingModeScreen(
          repo: widget.repo,
          photos: widget.photos,
          route: r,
          subtitle: _subtitle(r, crag, sectors),
        ),
      ));

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Crag>>(
      stream: _crags,
      builder: (context, snap) {
        if (snap.hasError) {
          return _Message('Cannot load crags: ${snap.error}');
        }
        final crags = snap.data;
        if (crags == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_cragId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _locate(crags));
        }
        final crag = crags.where((c) => c.id == _cragId).firstOrNull;
        if (crag == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (crags.isEmpty) ...[
                    const Text('Your logbook is empty',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    const Text(
                      'Add the crag or gym you climb at. Everything stays on '
                      'this phone; export a backup from History.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.quiet),
                    ),
                    const SizedBox(height: 20),
                  ],
                  FilledButton.icon(
                    onPressed: () => _changeCrag(crags),
                    icon: const Icon(Icons.terrain),
                    label: Text(crags.isEmpty
                        ? 'Add a crag or gym'
                        : 'Choose or add a crag'),
                  ),
                ],
              ),
            ),
          );
        }
        return _buildCrag(crag, crags);
      },
    );
  }

  Widget _buildCrag(Crag crag, List<Crag> crags) {
    return StreamBuilder<List<Sector>>(
      stream: _sectors,
      builder: (context, sectorSnap) {
        final sectors = sectorSnap.data ?? const <Sector>[];
        return StreamBuilder<List<ClimbRoute>>(
          stream: _routes,
          builder: (context, routeSnap) {
            final routes = routeSnap.data ?? const <ClimbRoute>[];
            final shown = _sectorId == null
                ? routes
                : routes.where((r) => r.sectorId == _sectorId).toList();
            return Scaffold(
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () => _addRoute(crag, sectors, routes),
                icon: const Icon(Icons.add),
                label: const Text('Add route',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              body: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _CragHeader(
                      crag: crag,
                      how: _cragHow,
                      onChange: () => _changeCrag(crags),
                    ),
                  ),
                  if (sectors.isNotEmpty)
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 56,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 6),
                          children: [
                            _chip('All', _sectorId == null,
                                () => setState(() => _sectorId = null)),
                            for (final s in sectors)
                              _chip(s.name, _sectorId == s.id,
                                  () => setState(() => _sectorId = s.id)),
                          ],
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
                      child: Row(
                        children: [
                          Text('Routes',
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w700)),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text('Tap a route to log it',
                                textAlign: TextAlign.right,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 13, color: AppColors.quiet)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (shown.isEmpty)
                    const SliverToBoxAdapter(
                      child: _Message(
                          'No routes here yet. Add the first one.'),
                    ),
                  StreamBuilder<List<Ascent>>(
                    stream: _ascents,
                    builder: (context, ascentSnap) {
                      final best = _bestStyles(ascentSnap.data ?? const []);
                      return SliverPadding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
                        sliver: SliverList.separated(
                          itemCount: shown.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 6),
                          itemBuilder: (context, i) => _RouteTile(
                            route: shown[i],
                            best: best[shown[i].id],
                            onTap: () => _log(shown[i], crag, sectors),
                            onStart: () => _start(shown[i], crag, sectors),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// The best style logged per route, for the badge in the list.
  Map<String, AscentStyle> _bestStyles(List<Ascent> ascents) {
    const order = [
      AscentStyle.onsight,
      AscentStyle.flash,
      AscentStyle.redpoint,
    ];
    final out = <String, AscentStyle>{};
    for (final a in ascents) {
      if (!isSend(a.style)) continue;
      final prev = out[a.routeId];
      if (prev == null || order.indexOf(a.style) < order.indexOf(prev)) {
        out[a.routeId] = a.style;
      }
    }
    return out;
  }

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

class _CragHeader extends StatelessWidget {
  const _CragHeader({
    required this.crag,
    required this.how,
    required this.onChange,
  });

  final Crag crag;
  final String how;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Logging at'),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.accentTint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      crag.type == CragType.gym
                          ? Icons.fitness_center
                          : Icons.terrain,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(crag.name,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w800)),
                        Text(how,
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.quiet)),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: onChange,
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(44, 44)),
                    child: const Text('Change'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteTile extends StatelessWidget {
  const _RouteTile({
    required this.route,
    required this.best,
    required this.onTap,
    required this.onStart,
  });

  final ClimbRoute route;
  final AscentStyle? best;
  final VoidCallback onTap;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final meta = [
      disciplineLabel(route.discipline),
      if (route.isMultiPitch) '${route.pitches} pitches',
      if (route.photoIds.length == 1) '1 photo',
      if (route.photoIds.length > 1) '${route.photoIds.length} photos',
    ].join(' · ');
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              GradeBadge(route.grade),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(route.name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    Text(meta,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.quiet)),
                  ],
                ),
              ),
              if (best != null) StylePill(best!),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Start: show photo while climbing',
                onPressed: onStart,
                icon: Icon(
                  route.photoIds.isEmpty
                      ? Icons.play_circle_outline
                      : Icons.play_circle_fill,
                  color: AppColors.accent,
                  size: 32,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.quiet)),
    );
  }
}
