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
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showCreateGroupDialog(context),
          child: const Icon(Icons.group_add),
        ),
      ),
    );
  }

  void _showCreateGroupDialog(BuildContext context) {
    final TextEditingController groupNameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Create Group"),
        content: TextField(
          controller: groupNameController,
          decoration: const InputDecoration(hintText: "Group Name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (groupNameController.text.trim().isNotEmpty) {
                await _db.createGroup(
                    groupNameController.text.trim(), _auth.currentUser!.uid);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text("Create"),
          ),
        ],
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
                  final photoUrl = data['photoUrl'] as String?;

                  // Rank specific styling
                  Color? rankColor;
                  double scale = 1.0;

                  if (index == 0) {
                    rankColor = const Color(0xFFFFD700); // Gold
                    scale = 1.1;
                  } else if (index == 1) {
                    rankColor = const Color(0xFFC0C0C0); // Silver
                    scale = 1.05;
                  } else if (index == 2) {
                    rankColor = const Color(0xFFCD7F32); // Bronze
                  }

                  return Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: index < 3
                          ? colorScheme.surfaceContainerHighest.withOpacity(0.3)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: index < 3
                          ? Border.all(
                              color: rankColor!.withOpacity(0.3), width: 1)
                          : null,
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      leading: SizedBox(
                        width: 50 * scale,
                        height: 50 * scale,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: rankColor != null
                                    ? Border.all(color: rankColor, width: 2)
                                    : null,
                                boxShadow: rankColor != null
                                    ? [
                                        BoxShadow(
                                            color: rankColor.withOpacity(0.3),
                                            blurRadius: 8,
                                            spreadRadius: 1)
                                      ]
                                    : null,
                              ),
                              child: CircleAvatar(
                                radius: 25 * scale,
                                foregroundImage:
                                    (photoUrl != null && photoUrl.isNotEmpty)
                                        ? NetworkImage(photoUrl)
                                        : null,
                                backgroundColor:
                                    colorScheme.surfaceContainerHighest,
                                child: const Icon(Icons.person,
                                    color: Colors.grey),
                              ),
                            ),
                            // Rank Number Badge for ALL, simpler/cleaner than medals
                            Positioned(
                              bottom: -4,
                              right: -4,
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: rankColor ??
                                      colorScheme.surfaceContainerHighest,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: colorScheme.surface, width: 2),
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      color: rankColor != null
                                          ? Colors.white
                                          : colorScheme.onSurface,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                      title: Text(username,
                          style: TextStyle(
                            fontWeight:
                                index < 3 ? FontWeight.w900 : FontWeight.normal,
                            fontSize: index < 3 ? 18 : 16,
                          )),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color:
                                colorScheme.primaryContainer.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          '$value',
                          style: TextStyle(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                      ),
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

  // Helper functions or other page methods...
}
