import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/database_service.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = FirebaseAuth.instance;
    final db = DatabaseService();
    final colorScheme = Theme.of(context).colorScheme;

    final currentUser = auth.currentUser;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text("Please login")));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: db.getFriendRequests(currentUser.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading requests"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final requests = snapshot.data?.docs ?? [];

          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none,
                      size: 64,
                      color: colorScheme.onSurfaceVariant.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text("No new notifications",
                      style: TextStyle(color: colorScheme.onSurfaceVariant)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              final requesterUid = request['fromUid'];
              final requesterName = request['fromName'];

              return ListTile(
                title: Text("$requesterName sent you a friend request"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => db.acceptFriendRequest(
                          currentUser.uid, request.id, requesterUid),
                      icon: const Icon(Icons.check_circle,
                          color: Colors.green, size: 32),
                      tooltip: "Accept",
                    ),
                    IconButton(
                      onPressed: () =>
                          db.declineFriendRequest(currentUser.uid, request.id),
                      icon:
                          const Icon(Icons.cancel, color: Colors.red, size: 32),
                      tooltip: "Decline",
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
