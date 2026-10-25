import 'package:flutter/material.dart';

import '../data/journal_repository.dart';
import '../data/photo_store.dart';
import 'history_tab.dart';
import 'log_tab.dart';
import 'widgets.dart';

/// Two tabs: Log (crag and routes) and History.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.repo,
    required this.photos,
    this.climber,
    this.onSignOut,
  });

  final JournalRepository repo;
  final PhotoStore photos;

  /// Name printed on the yearly report. Null in local mode, where the
  /// app asks for it once and stores it on the device.
  final String? climber;
  final VoidCallback? onSignOut;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (widget.repo.isDemo) const DemoBanner(),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: [
                  LogTab(repo: widget.repo, photos: widget.photos),
                  HistoryTab(repo: widget.repo, climber: widget.climber),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.terrain), label: 'Log'),
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'History'),
        ],
      ),
    );
  }
}
