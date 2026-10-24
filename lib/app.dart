import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'config.dart';
import 'data/demo_journal_repository.dart';
import 'data/firestore_journal_repository.dart';
import 'screens/sign_in_screen.dart';
import 'ui/home_shell.dart';
import 'ui/theme.dart';

class ClimbingJournalApp extends StatelessWidget {
  const ClimbingJournalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Climbing Journal',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: kDemo ? const _DemoHome() : const _AuthGate(),
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

/// Auth state is cached on the device, so a signed-in user reaches the
/// app without signal.
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
