import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/database_service.dart';
import '../profile/profile_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final DatabaseService _db = DatabaseService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _myFriends = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchFriends();
  }

  Future<void> _fetchFriends() async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;

    // Fetch full friend objects to allow local search fallback
    try {
      final friends = await _db.getFriends(myUid);
      if (mounted) {
        setState(() {
          _myFriends = friends;
        });
      }
    } catch (e) {
      debugPrint("Error fetching friends: $e");
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _handleSearch();
    });
  }

  Future<void> _handleSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isLoading = false;
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // 1. Local Search (Friends) - Case insensitive partial match
    final lowerQuery = query.toLowerCase();
    final localMatches = _myFriends.where((friend) {
      final username = (friend['username'] ?? '').toString().toLowerCase();
      return username
          .contains(lowerQuery); // Contains check is broader than prefix
    }).toList();

    // 2. Remote Search (Firestore)
    List<Map<String, dynamic>> remoteResults = [];
    try {
      remoteResults = await _db.searchUsers(query);
    } catch (e) {
      debugPrint("Remote search failed: $e");
    }

    // 3. Merge Results (Dedup based on UID)
    final Map<String, Map<String, dynamic>> mergedMap = {};

    // Add local friend matches first (priority)
    for (var user in localMatches) {
      mergedMap[user['uid']] = user;
    }

    // Add remote matches if not present
    for (var user in remoteResults) {
      if (!mergedMap.containsKey(user['uid'])) {
        mergedMap[user['uid']] = user;
      }
    }

    // Remove myself
    final myUid = _auth.currentUser?.uid;
    if (myUid != null) {
      mergedMap.remove(myUid);
    }

    if (mounted) {
      setState(() {
        _searchResults = mergedMap.values.toList();
        _isLoading = false;
      });
    }
  }

  Future<void> _sendRequest(String targetUid) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;

    await _db.sendFriendRequest(myUid, targetUid);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request sent!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search users...',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
            border: InputBorder.none,
          ),
          onChanged: _onSearchChanged,
          onSubmitted: (_) => _handleSearch(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _handleSearch,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final user = _searchResults[index];
                final uid = user['uid'];
                final isFriend = _myFriends.any((f) => f['uid'] == uid);

                final photoUrl = user['photoUrl'];

                return ListTile(
                  leading: CircleAvatar(
                    foregroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                        ? NetworkImage(photoUrl)
                        : null,
                    backgroundColor:
                        Colors.grey[800], // Dark background for avatar
                    child: const Icon(Icons.person, color: Colors.white70),
                  ),
                  title: Text(user['username'] ?? 'Unknown',
                      style: const TextStyle(color: Colors.white)),
                  trailing: IconButton(
                    icon: Icon(isFriend ? Icons.visibility : Icons.person_add,
                        color: Colors.white70),
                    tooltip: isFriend ? "View Profile" : "Send request",
                    onPressed: () {
                      if (isFriend) {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => ProfilePage(userId: uid)));
                      } else {
                        _sendRequest(uid);
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}
