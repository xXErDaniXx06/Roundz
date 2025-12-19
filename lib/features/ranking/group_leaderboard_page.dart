import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
                    final photoUrl = user['photoUrl'] as String?;

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
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: index < 3
                            ? colorScheme.surfaceContainerHighest
                                .withOpacity(0.3)
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
                              // Rank Number Badge
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
                              fontWeight: index < 3
                                  ? FontWeight.w900
                                  : FontWeight.normal,
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
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
