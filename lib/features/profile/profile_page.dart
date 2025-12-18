import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../notifications/notifications_page.dart';
import '../settings/settings_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    // ... (existing variables)
    final user = FirebaseAuth.instance.currentUser;
    final DatabaseService db = DatabaseService();
    final AuthService auth = AuthService();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (user == null) {
      return const Center(child: Text("Not logged in"));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Roundz'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const NotificationsPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Cerrar Sesión"),
                  content: const Text("¿Estás seguro de que quieres salir?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancelar"),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await auth.signOut();
                      },
                      child: const Text("Cerrar Sesión"),
                    ),
                  ],
                ),
              );
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

          final List<dynamic> friendsList =
              data['friends'] as List<dynamic>? ?? [];
          final int friendsCount =
              friendsList.length; // Use list length for accuracy
          final String username = data['username'] ?? 'User';
          final String photoUrl = data['photoUrl'] ?? '';

          return CustomScrollView(
            slivers: [
              // Profile Header & Control Panel
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor:
                                  colorScheme.surfaceContainerHighest,
                              backgroundImage: photoUrl.isNotEmpty
                                  ? NetworkImage(photoUrl)
                                  : null,
                              child: photoUrl.isEmpty
                                  ? Icon(Icons.person,
                                      size: 50,
                                      color: colorScheme.onSurfaceVariant)
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              username,
                              style: textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              '$friendsCount Friends',
                              style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant),
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
                            onIncrement: () =>
                                db.incrementStat(user.uid, 'parties'),
                            onDecrement: () =>
                                db.decrementStat(user.uid, 'parties'),
                          ),
                          _ControlKey(
                            label: "CUBATA",
                            onIncrement: () =>
                                db.incrementStat(user.uid, 'cubatas'),
                            onDecrement: () =>
                                db.decrementStat(user.uid, 'cubatas'),
                          ),
                          _ControlKey(
                            label: "CHUPITO",
                            onIncrement: () =>
                                db.incrementStat(user.uid, 'chupitos'),
                            onDecrement: () =>
                                db.decrementStat(user.uid, 'chupitos'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // Stats Grid
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.7,
                  ),
                  delegate: SliverChildListDelegate([
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
                  ]),
                ),
              ),
              // Extra space at bottom
              const SliverToBoxAdapter(
                child: SizedBox(height: 32),
              ),
            ],
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
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton.filled(
              onPressed: onDecrement,
              icon: const Icon(Icons.remove, size: 18),
              style: IconButton.styleFrom(
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  foregroundColor: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: onIncrement,
              icon: const Icon(Icons.add, size: 18),
              style: IconButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title,
              style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 10,
                  letterSpacing: 1.2)),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('$annual',
                style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 32,
                    fontWeight: FontWeight.w300)),
          ),
          Text('THIS YEAR',
              style: TextStyle(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                  fontSize: 8)),
          Divider(
              color: colorScheme.outlineVariant.withOpacity(0.2),
              indent: 20,
              endIndent: 20,
              height: 16),
          Text('$total',
              style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.8),
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          Text('TOTAL',
              style: TextStyle(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                  fontSize: 8)),
          const Spacer(),
        ],
      ),
    );
  }
}
