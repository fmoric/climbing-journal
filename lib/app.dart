import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'data/journal_repository.dart';
import 'screens/crags_screen.dart';
import 'screens/sign_in_screen.dart';

class ClimbingJournalApp extends StatelessWidget {
  const ClimbingJournalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Climbing Journal',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      // Auth state is cached on the device, so a signed-in user
      // reaches the app without signal.
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final user = snapshot.data;
          if (user == null) return const SignInScreen();
          return CragsScreen(
            repo: JournalRepository(
              db: FirebaseFirestore.instance,
              uid: user.uid,
              onWriteError: (e, _) => debugPrint('Write rejected: $e'),
            ),
          );
        },
      ),
    );
  }
}
