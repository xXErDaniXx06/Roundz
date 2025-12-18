import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import 'group_leaderboard_page.dart';

class RankingPage extends StatefulWidget {
  const RankingPage({super.key});

  @override
  State<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends State<RankingPage> {
  // Sorting state
  String _sortBy = 'parties'; // 'parties', 'cubatas', 'chupitos'
  bool _isDescending = true;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseService _db = DatabaseService();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ranking'),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Global"),
              Tab(text: "My Groups"),
            ],
          ),
          actions: [
            // Sort Criteria Dropdown/Menu
            PopupMenuButton<String>(
              icon: const Icon(Icons.filter_list),
              onSelected: (value) {
                setState(() {
                  _sortBy = value;
                });
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                    value: 'parties', child: Text('Sort by Parties')),
                const PopupMenuItem(
                    value: 'cubatas', child: Text('Sort by Cubatas')),
                const PopupMenuItem(
                    value: 'chupitos', child: Text('Sort by Chupitos')),
              ],
            ),
            // Sort Order Toggle
            IconButton(
              icon: Icon(
                  _isDescending ? Icons.arrow_downward : Icons.arrow_upward),
              onPressed: () {
                setState(() {
                  _isDescending = !_isDescending;
                });
              },
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildGlobalRanking(colorScheme),
            _buildGroupsList(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalRanking(ColorScheme colorScheme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'Global Ranking by ${_sortBy.toUpperCase()} (${_isDescending ? "High to Low" : "Low to High"})',
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .orderBy('stats.$_sortBy', descending: _isDescending)
                .limit(50)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Error loading ranking'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return const Center(child: Text('No users found'));
              }

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final username = data['username'] ?? 'Unknown';
                  final stats = data['stats'] as Map<String, dynamic>? ?? {};
                  final value = stats[_sortBy] ?? 0;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getRankColor(index),
                      foregroundColor: Colors.white,
                      child: Text('${index + 1}'),
                    ),
                    title: Text(username,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: Text(
                      '$value ${_sortBy.toUpperCase()}',
                      style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGroupsList(ColorScheme colorScheme) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.getGroups(_auth.currentUser!.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text("Error loading groups"));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final groups = snapshot.data?.docs ?? [];
        if (groups.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.group_off,
                    size: 60,
                    color: colorScheme.onSurfaceVariant.withOpacity(0.5)),
                const SizedBox(height: 16),
                Text("No groups found",
                    style: TextStyle(color: colorScheme.onSurfaceVariant)),
                const SizedBox(height: 8),
                const Text("Create a group in Chat to see rankings here.",
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final data = groups[index].data() as Map<String, dynamic>;
            final String groupName = data['name'] ?? 'Group';
            final String groupId = groups[index].id;

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: colorScheme.secondaryContainer,
                child: Icon(Icons.leaderboard,
                    color: colorScheme.onSecondaryContainer),
              ),
              title: Text(groupName,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text("Tap to view group leaderboard"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GroupLeaderboardPage(
                      groupId: groupId,
                      groupName: groupName,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Color _getRankColor(int index) {
    if (index == 0) return Colors.amber; // Gold
    if (index == 1) return Colors.grey.shade400; // Silver
    if (index == 2) return Colors.brown.shade400; // Bronze
    return Colors.white10;
  }
}
