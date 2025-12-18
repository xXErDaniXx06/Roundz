import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/database_service.dart';

class GroupLeaderboardPage extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupLeaderboardPage({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupLeaderboardPage> createState() => _GroupLeaderboardPageState();
}

class _GroupLeaderboardPageState extends State<GroupLeaderboardPage> {
  String _sortBy = 'parties';
  bool _isDescending = true;
  final DatabaseService _db = DatabaseService();

  Future<List<Map<String, dynamic>>> _fetchGroupMembersRanking() async {
    // 1. Get Group Members list
    final groupDoc = await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.groupId)
        .get();

    if (!groupDoc.exists) return [];

    final List<dynamic> memberUids = groupDoc.data()?['members'] ?? [];

    if (memberUids.isEmpty) return [];

    // 2. Fetch User Data for each member
    // Using Future.wait for parallel execution
    List<Future<DocumentSnapshot>> futures = memberUids
        .map((uid) =>
            FirebaseFirestore.instance.collection('users').doc(uid).get())
        .toList();

    final userSnapshots = await Future.wait(futures);

    // 3. Map to Data
    List<Map<String, dynamic>> users = userSnapshots
        .where((doc) => doc.exists)
        .map((doc) => doc.data() as Map<String, dynamic>)
        .toList();

    // 4. Sort (Client-Side)
    users.sort((a, b) {
      final statsA = a['stats'] as Map<String, dynamic>? ?? {};
      final statsB = b['stats'] as Map<String, dynamic>? ?? {};

      final valA = statsA[_sortBy] as num? ?? 0;
      final valB = statsB[_sortBy] as num? ?? 0;

      if (_isDescending) {
        return valB.compareTo(valA);
      } else {
        return valA.compareTo(valB);
      }
    });

    return users;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.groupName} Ranking'),
        actions: [
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
          IconButton(
            icon:
                Icon(_isDescending ? Icons.arrow_downward : Icons.arrow_upward),
            onPressed: () {
              setState(() {
                _isDescending = !_isDescending;
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        // Re-fetch when sort changes
        future: _fetchGroupMembersRanking(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          final users = snapshot.data ?? [];

          if (users.isEmpty) {
            return const Center(child: Text("No members found"));
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Group Ranking by ${_sortBy.toUpperCase()}',
                  style: TextStyle(
                      color: colorScheme.onSurfaceVariant, fontSize: 12),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final username = user['username'] ?? 'Unknown';
                    final stats = user['stats'] as Map<String, dynamic>? ?? {};
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
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _getRankColor(int index) {
    if (index == 0) return Colors.amber; // Gold
    if (index == 1) return Colors.grey.shade400; // Silver
    if (index == 2) return Colors.brown.shade400; // Bronze
    return Colors.white10;
  }
}
