import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/journal_repository.dart';
import '../models/crag.dart';
import '../models/enums.dart';

/// Smoke-test screen for M1-01/02: proves auth, rules and offline writes.
/// Replaced by the real logging flow in M1-04 onwards.
class CragsScreen extends StatelessWidget {
  const CragsScreen({super.key, required this.repo});

  final JournalRepository repo;

  Future<void> _addCrag(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New crag'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    repo.createCrag(Crag(id: repo.newId(), name: name.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crags'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<List<Crag>>(
        stream: repo.watchCrags(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            // Most likely cause: no /members document for this account.
            return Center(child: Text('Cannot load crags: ${snapshot.error}'));
          }
          final crags = snapshot.data;
          if (crags == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (crags.isEmpty) {
            return const Center(child: Text('No crags yet. Add one.'));
          }
          return ListView.builder(
            itemCount: crags.length,
            itemBuilder: (context, i) {
              final crag = crags[i];
              return ListTile(
                leading: Icon(crag.type == CragType.gym
                    ? Icons.fitness_center
                    : Icons.terrain),
                title: Text(crag.name),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add crag',
        onPressed: () => _addCrag(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
