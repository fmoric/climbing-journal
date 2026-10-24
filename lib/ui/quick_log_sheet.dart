import 'package:flutter/material.dart';

import '../data/journal_repository.dart';
import '../domain/stats.dart';
import '../models/ascent.dart';
import '../models/climb_route.dart';
import '../models/enums.dart';
import 'theme.dart';
import 'widgets.dart';

/// Opens the quick-log sheet (FR-1): style, attempts, date, save.
Future<void> showQuickLog(
  BuildContext context, {
  required JournalRepository repo,
  required ClimbRoute route,
  required String subtitle,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.ground,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) =>
        QuickLogSheet(repo: repo, route: route, subtitle: subtitle),
  );
}

class QuickLogSheet extends StatefulWidget {
  const QuickLogSheet({
    super.key,
    required this.repo,
    required this.route,
    required this.subtitle,
  });

  final JournalRepository repo;
  final ClimbRoute route;
  final String subtitle;

  @override
  State<QuickLogSheet> createState() => _QuickLogSheetState();
}

class _QuickLogSheetState extends State<QuickLogSheet> {
  AscentStyle _style = AscentStyle.redpoint;
  int _attempts = 1;
  DateTime _date = DateTime.now();
  bool _share = false;
  final _notes = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  bool get _isToday {
    final n = DateTime.now();
    return _date.year == n.year && _date.month == n.month && _date.day == n.day;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    final repo = widget.repo;
    repo.createAscent(Ascent(
      id: repo.newId(),
      userId: repo.uid,
      routeId: widget.route.id,
      cragId: widget.route.cragId,
      date: DateTime(_date.year, _date.month, _date.day),
      style: _style,
      attempts: _attempts,
      notes: _notes.text.trim(),
      visibility: _share ? AscentVisibility.circle : AscentVisibility.private,
    ));
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(
      content: Text('Logged ${widget.route.name} · ${styleLabel(_style)}'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.route;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFC9C4BA),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            Row(
              children: [
                GradeBadge(r.grade, size: 48),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.name,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w800)),
                      Text(widget.subtitle,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.quiet)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const SectionLabel('Style'),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.4,
              children: [
                for (final s in AscentStyle.values)
                  _StyleButton(
                    label: styleLabel(s),
                    selected: s == _style,
                    onTap: () => setState(() => _style = s),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Attempts',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.quiet)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton.outlined(
                                tooltip: 'Fewer attempts',
                                onPressed: _attempts > 1
                                    ? () => setState(() => _attempts--)
                                    : null,
                                icon: const Icon(Icons.remove),
                              ),
                              Text('$_attempts',
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800)),
                              IconButton.outlined(
                                tooltip: 'More attempts',
                                onPressed: () => setState(() => _attempts++),
                                icon: const Icon(Icons.add),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _pickDate,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Date',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.quiet)),
                            SizedBox(
                              height: 48,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _isToday ? 'Today' : formatDate(_date),
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Beta, conditions, how it felt',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Share with the circle',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              value: _share,
              onChanged: (v) => setState(() => _share = v),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _save,
              child: Text('Save · ${styleLabel(_style)}'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StyleButton extends StatelessWidget {
  const _StyleButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.accent : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
              color: selected ? AppColors.accent : AppColors.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
