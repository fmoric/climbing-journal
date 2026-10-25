import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'config.dart';
import 'data/demo_journal_repository.dart';
import 'data/firestore_journal_repository.dart';
import 'data/local_database.dart';
import 'data/local_journal_repository.dart';
import 'screens/sign_in_screen.dart';
import 'ui/home_shell.dart';
import 'ui/theme.dart';

class ClimbingJournalApp extends StatelessWidget {
  const ClimbingJournalApp({super.key});

  @override
  Widget build(BuildContext context) {
    final Widget home;
    if (kDemo) {
      home = const _DemoHome();
    } else if (kCloud) {
      home = const _AuthGate();
    } else {
      home = const _LocalHome();
    }
    return MaterialApp(
      title: 'Climbing Journal',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: home,
    );
  }
}

/// Local mode: opens the on-device database, then the app.
class _LocalHome extends StatefulWidget {
  const _LocalHome();

  @override
  State<_LocalHome> createState() => _LocalHomeState();
}

class _LocalHomeState extends State<_LocalHome> {
  late final Future<LocalJournalRepository> _repo = openLocalDatabase().then(
    (db) => LocalJournalRepository(
      db,
      onWriteError: (e, _) => debugPrint('Local write failed: $e'),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LocalJournalRepository>(
      future: _repo,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not open the logbook: ${snap.error}',
                    textAlign: TextAlign.center),
              ),
            ),
          );
        }
        final repo = snap.data;
        if (repo == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return HomeShell(repo: repo);
      },
    );
  }
}

class _DemoHome extends StatefulWidget {
  const _DemoHome();

  @override
  State<_DemoHome> createState() => _DemoHomeState();
}

class _DemoHomeState extends State<_DemoHome> {
  final _repo = DemoJournalRepository.seeded();

  @override
  Widget build(BuildContext context) =>
      HomeShell(repo: _repo, climber: 'Demo climber');
}

/// Cloud mode (M2). Auth state is cached on the device, so a signed-in
/// user reaches the app without signal.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        if (user == null) return const SignInScreen();
        return HomeShell(
          key: ValueKey(user.uid),
          repo: FirestoreJournalRepository(
            db: FirebaseFirestore.instance,
            uid: user.uid,
            onWriteError: (e, _) => debugPrint('Write rejected: $e'),
          ),
          climber: user.displayName ?? user.email ?? 'Climber',
          onSignOut: () => FirebaseAuth.instance.signOut(),
        );
      },
    );
  }
}
