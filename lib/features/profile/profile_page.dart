import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final DatabaseService db = DatabaseService();
    final AuthService auth = AuthService();

    if (user == null) {
      return const Center(child: Text("Not logged in"));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Roundz'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await auth.signOut();
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: db.getUserStream(user.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>?;

          if (data == null) {
            return const Center(child: Text("No profile data"));
          }

          final stats = data['stats'] as Map<String, dynamic>? ?? {};
          final int parties = stats['parties'] ?? 0;
          final int cubatas = stats['cubatas'] ?? 0;
          final int chupitos = stats['chupitos'] ?? 0;
          final int friendsCount = data['friendsCount'] ?? 0;
          final String username = data['username'] ?? 'User';

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white10,
                        child:
                            Icon(Icons.person, size: 50, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        username,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '$friendsCount Friends',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Stats Grid
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.85,
                    children: [
                      _StatCard(
                        label: 'FIESTAS',
                        value: parties,
                        onIncrement: () =>
                            db.incrementStat(user.uid, 'parties'),
                      ),
                      _StatCard(
                        label: 'CUBATAS',
                        value: cubatas,
                        onIncrement: () =>
                            db.incrementStat(user.uid, 'cubatas'),
                      ),
                      _StatCard(
                        label: 'CHUPITOS',
                        value: chupitos,
                        onIncrement: () =>
                            db.incrementStat(user.uid, 'chupitos'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback onIncrement;

  const _StatCard({
    required this.label,
    required this.value,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w200, // Minimalist font weight
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          IconButton(
            onPressed: onIncrement,
            icon: const Icon(Icons.add_circle_outline,
                size: 32, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
