import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import 'chat_room_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseService _db = DatabaseService();

  void _showCreateGroupDialog() {
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Messages'),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Friends"),
              Tab(text: "Groups"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Friends List
            _buildFriendsList(colorScheme),

            // Tab 2: Groups List
            _buildGroupsList(colorScheme),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showCreateGroupDialog,
          child: const Icon(Icons.group_add),
        ),
      ),
    );
  }

  Widget _buildFriendsList(ColorScheme colorScheme) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _db.getFriends(_auth.currentUser!.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading friends'));
        }

        final friends = snapshot.data ?? [];

        if (friends.isEmpty) {
          return Center(
            child: Text("No friends yet",
                style: TextStyle(color: colorScheme.onSurfaceVariant)),
          );
        }

        return ListView.builder(
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final friend = friends[index];
            final String username = friend['username'] ?? 'User';
            final String photoUrl = friend['photoUrl'] ?? '';
            final String uid = friend['uid'];

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: colorScheme.surfaceContainerHighest,
                backgroundImage:
                    photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                child: photoUrl.isEmpty ? const Icon(Icons.person) : null,
              ),
              title: Text(username,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle:
                  const Text("Tap to chat", style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatRoomPage(
                      receiverUserEmail: username,
                      receiverUserID: uid,
                      receiverUserPhotoUrl: photoUrl,
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
          return const Center(child: Text("No groups joined"));
        }

        return ListView.builder(
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final data = groups[index].data() as Map<String, dynamic>;
            final String groupName = data['name'] ?? 'Group';
            final String groupId = groups[index].id;

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(Icons.group, color: colorScheme.onPrimaryContainer),
              ),
              title: Text(groupName,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(data['recentMessage'] ?? ''),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatRoomPage(
                      receiverUserEmail: groupName,
                      receiverUserID: '', // Not used for groups
                      receiverUserPhotoUrl: '', // Could be group icon
                      chatId: groupId,
                      isGroup: true,
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
}
