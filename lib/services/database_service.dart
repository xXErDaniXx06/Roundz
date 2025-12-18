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
        'annual_stats': {
          'year': DateTime.now().year,
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

  // Increment Stat (Global + Annual with Reset)
  Future<void> incrementStat(String uid, String statName) async {
    final docRef = _users.doc(uid);
    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;

        final data = snapshot.data() as Map<String, dynamic>;
        final currentYear = DateTime.now().year;

        // Check/Init Annual Stats
        var annualStats = data['annual_stats'] as Map<String, dynamic>? ??
            {'year': currentYear, 'parties': 0, 'cubatas': 0, 'chupitos': 0};

        final savedYear = annualStats['year'] ?? currentYear;

        if (savedYear != currentYear) {
          // New Year: Reset annual stats
          annualStats = {
            'year': currentYear,
            'parties': 0,
            'cubatas': 0,
            'chupitos': 0,
          };
        }

        // Increment Global

        // Note: We can use FieldValue.increment for simple fields, but since we are in a transaction reading data,
        // we can just calculate the new value to be safe or mix logic.
        // For simplicity in transaction, we update the whole map or specific fields.
        // Let's use direct map updates to ensure consistency with the read snapshot.

        // However, mixing FieldValue.increment with explicit set in transaction is tricky if partial.
        // Simplest: Calculate new values.

        // 1. Global
        // We do strictly want to increment, so we can use the `update` command inside transaction.

        transaction.update(docRef, {
          'stats.$statName': FieldValue.increment(1),
          // We must write the ENTIRE annual_stats map if it was reset, OR just update the field if year is same.
          // To be safe and handle the reset atomicly:
          'annual_stats': {
            ...annualStats,
            statName: (annualStats[statName] ?? 0) + 1,
          }
        });
      });
    } catch (e) {
      debugPrint('Error updating stat: $e');
    }
  }

  // Decrement Stat (Global + Annual with Reset, prevent negative)
  Future<void> decrementStat(String uid, String statName) async {
    final docRef = _users.doc(uid);
    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;

        final data = snapshot.data() as Map<String, dynamic>;
        final currentYear = DateTime.now().year;

        // Global Check
        final stats = data['stats'] as Map<String, dynamic>? ?? {};
        final currentGlobal = stats[statName] ?? 0;

        // Annual Check
        var annualStats = data['annual_stats'] as Map<String, dynamic>? ??
            {'year': currentYear, 'parties': 0, 'cubatas': 0, 'chupitos': 0};
        final savedYear = annualStats['year'] ?? currentYear;

        if (savedYear != currentYear) {
          // Reset on new year (even on decrement? Yes, to synchronize)
          annualStats = {
            'year': currentYear,
            'parties': 0,
            'cubatas': 0,
            'chupitos': 0,
          };
        }

        final currentAnnual = annualStats[statName] ?? 0;

        // Only decrement if > 0
        if (currentGlobal > 0 || currentAnnual > 0) {
          // If Annual was just reset, it is 0, so we can't decrement it.
          // But Global might be > 0.
          // Requirement: "buttons ... of the two counters".
          // Implies we probably want to decrement them together?
          // Or does the user mean separate actions?
          // Request: "separate the buttons ... FROM the two counters".
          // Implicitly: ONE set of buttons affects BOTH.

          // Logic:
          // Global should decrement if > 0.
          // Annual should decrement if > 0.

          transaction.update(docRef, {
            if (currentGlobal > 0) 'stats.$statName': FieldValue.increment(-1),
            'annual_stats': {
              ...annualStats,
              statName: (currentAnnual > 0) ? currentAnnual - 1 : 0,
            }
          });
        }
      });
    } catch (e) {
      debugPrint('Error decrementing stat: $e');
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

  // Get Friends Data
  Future<List<Map<String, dynamic>>> getFriends(String uid) async {
    try {
      final userDoc = await _users.doc(uid).get();
      if (!userDoc.exists) return [];

      final data = userDoc.data() as Map<String, dynamic>;
      final List<dynamic> friendsUids = data['friends'] ?? [];

      if (friendsUids.isEmpty) return [];

      // Fetch all friend documents
      // Note: "whereIn" is limited to 10 items. For simplicity/robustness with small friend lists:
      // We can do individual fetches or chunked query.
      // For now, let's assuming <10 friends or do Future.wait.
      // Future.wait is consistent for any number (up to reasonably limits).

      List<Future<DocumentSnapshot>> futures =
          friendsUids.map((fUid) => _users.doc(fUid as String).get()).toList();

      final snapshots = await Future.wait(futures);

      return snapshots
          .where((doc) => doc.exists)
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      debugPrint("Error fetching friends: $e");
      return [];
    }
  }

  // Check if username is already taken
  Future<bool> isUsernameTaken(String username) async {
    final querySnapshot =
        await _users.where('username', isEqualTo: username).limit(1).get();

    return querySnapshot.docs.isNotEmpty;
  }
}
