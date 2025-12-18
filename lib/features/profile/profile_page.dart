import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../settings/settings_page.dart';

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
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
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

          final annualStats =
              data['annual_stats'] as Map<String, dynamic>? ?? {};
          final int partiesYear = annualStats['parties'] ?? 0;
          final int cubatasYear = annualStats['cubatas'] ?? 0;
          final int chupitosYear = annualStats['chupitos'] ?? 0;

          final int friendsCount = data['friendsCount'] ?? 0;
          final String username = data['username'] ?? 'User';
          final String photoUrl = data['photoUrl'] ?? '';

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white10,
                        backgroundImage:
                            photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                        child: photoUrl.isEmpty
                            ? const Icon(Icons.person,
                                size: 50, color: Colors.white)
                            : null,
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

                // Control Panel (Add/Remove)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ControlKey(
                      label: "FIESTA",
                      onIncrement: () => db.incrementStat(user.uid, 'parties'),
                      onDecrement: () => db.decrementStat(user.uid, 'parties'),
                    ),
                    _ControlKey(
                      label: "CUBATA",
                      onIncrement: () => db.incrementStat(user.uid, 'cubatas'),
                      onDecrement: () => db.decrementStat(user.uid, 'cubatas'),
                    ),
                    _ControlKey(
                      label: "CHUPITO",
                      onIncrement: () => db.incrementStat(user.uid, 'chupitos'),
                      onDecrement: () => db.decrementStat(user.uid, 'chupitos'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Stats Display (Annual + Global)
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.7,
                    children: [
                      _DoubleStatCard(
                        title: "FIESTAS",
                        annual: partiesYear,
                        total: parties,
                      ),
                      _DoubleStatCard(
                        title: "CUBATAS",
                        annual: cubatasYear,
                        total: cubatas,
                      ),
                      _DoubleStatCard(
                        title: "CHUPITOS",
                        annual: chupitosYear,
                        total: chupitos,
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

class _ControlKey extends StatelessWidget {
  final String label;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _ControlKey(
      {required this.label,
      required this.onIncrement,
      required this.onDecrement});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton.filled(
              onPressed: onDecrement,
              icon: const Icon(Icons.remove, size: 18),
              style: IconButton.styleFrom(
                  backgroundColor: Colors.white10,
                  foregroundColor: Colors.white),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: onIncrement,
              icon: const Icon(Icons.add, size: 18),
              style: IconButton.styleFrom(
                  backgroundColor: Colors.white, foregroundColor: Colors.black),
            ),
          ],
        )
      ],
    );
  }
}

class _DoubleStatCard extends StatelessWidget {
  final String title;
  final int annual;
  final int total;

  const _DoubleStatCard(
      {required this.title, required this.annual, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white54, fontSize: 10, letterSpacing: 1.2)),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('$annual',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32, // Reduced from 36
                    fontWeight: FontWeight.w300)),
          ),
          const Text('THIS YEAR',
              style: TextStyle(color: Colors.white24, fontSize: 8)),
          const Divider(
              color: Colors.white10, indent: 20, endIndent: 20, height: 16),
          Text('$total',
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const Text('TOTAL',
              style: TextStyle(color: Colors.white24, fontSize: 8)),
          const Spacer(),
        ],
      ),
    );
  }
}
