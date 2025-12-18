import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Collection References
  CollectionReference get _users => _db.collection('users');

  // Create or Update User Profile
  Future<void> createUserProfile(User user, String username) async {
    final doc = _users.doc(user.uid);
    final snapshot = await doc.get();

    if (!snapshot.exists) {
      await doc.set({
        'uid': user.uid,
        'email': user.email,
        'username': username,
        'createdAt': FieldValue.serverTimestamp(),
        'friendsCount': 0,
        // Public stats (none for now, but structure ready)
        // Private stats (only visible to friends)
        'stats': {
          'parties': 0,
          'cubatas': 0,
          'chupitos': 0,
        },
        'friends': [], // List of UIDs
      });
    }
  }

  // Get User Data Stream
  Stream<DocumentSnapshot> getUserStream(String uid) {
    return _users.doc(uid).snapshots();
  }

  // Increment Stat (Only for self)
  Future<void> incrementStat(String uid, String statName) async {
    // statName: 'parties', 'cubatas', 'chupitos'
    try {
      await _users.doc(uid).update({
        'stats.$statName': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('Error updating stat: $e');
    }
  }

  // Add Friend (Simplistic: A adds B -> B is in A's friend list)
  // Logic: For B to see A's stats, A must add B (or strict mutual).
  // Request: "Stats visible only to added friends".
  // Interpretation: If I (A) add You (B), then You (B) are my friend.
  // So You (B) can see My (A) stats.
  Future<void> addFriend(String currentUid, String targetUid) async {
    try {
      await _users.doc(currentUid).update({
        'friends': FieldValue.arrayUnion([targetUid]),
        'friendsCount': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('Error adding friend: $e');
    }
  }

  Future<void> removeFriend(String currentUid, String targetUid) async {
    try {
      await _users.doc(currentUid).update({
        'friends': FieldValue.arrayRemove([targetUid]),
        'friendsCount': FieldValue.increment(-1),
      });
    } catch (e) {
      debugPrint('Error removing friend: $e');
    }
  }

  // Search Users
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    // Simple search by username (exact match or startAt for better UX later)
    // Note: Firestore text search is limited. Using simple equality for now.
    // Or >= query and <= query + '\uf8ff' for prefix.
    try {
      final snapshot = await _users
          .where('username', isGreaterThanOrEqualTo: query)
          .where('username', isLessThan: '${query}z')
          .limit(10)
          .get();

      return snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      debugPrint('Error searching users: $e');
      return [];
    }
  }
}
