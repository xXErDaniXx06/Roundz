import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class RankingPage extends StatefulWidget {
  const RankingPage({super.key});

  @override
  State<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends State<RankingPage> {
  // Sorting state
  String _sortBy = 'parties'; // 'parties', 'cubatas', 'chupitos'
  bool _isDescending = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Global Ranking'),
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
      body: StreamBuilder<QuerySnapshot>(
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

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Ranking by ${_sortBy.toUpperCase()} (${_isDescending ? "High to Low" : "Low to High"})',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
              Expanded(
                child: ListView.builder(
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
                          style: const TextStyle(color: Colors.white)),
                      trailing: Text(
                        '$value ${_sortBy.toUpperCase()}',
                        style: const TextStyle(
                            color: Colors.white70, fontWeight: FontWeight.bold),
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
