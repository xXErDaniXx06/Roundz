import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

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
        'searchKey': username.toLowerCase(), // For case-insensitive search
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

  // Send Friend Request
  Future<void> sendFriendRequest(String currentUid, String targetUid) async {
    try {
      // 1. Get current user info to store in request (optimization for display)
      final currentUserDoc = await _users.doc(currentUid).get();
      final userData = currentUserDoc.data() as Map<String, dynamic>;

      // 2. Create Request Document in Target's subcollection
      // Path: users/{targetUid}/friend_requests/{currentUid}
      await _users
          .doc(targetUid)
          .collection('friend_requests')
          .doc(currentUid)
          .set({
        'from': currentUid,
        'username': userData['username'] ?? 'Unknown',
        'photoUrl': userData['photoUrl'] ?? '',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error sending friend request: $e');
    }
  }

  // Accept Friend Request (Transaction for consistency)
  Future<void> acceptFriendRequest(
      String currentUid, String requestId, String requesterUid) async {
    final currentRef = _users.doc(currentUid);
    final requesterRef = _users.doc(requesterUid);
    final requestRef =
        _users.doc(currentUid).collection('friend_requests').doc(requestId);

    try {
      await _db.runTransaction((transaction) async {
        final currentSnapshot = await transaction.get(currentRef);
        final requesterSnapshot = await transaction.get(requesterRef);

        if (!currentSnapshot.exists || !requesterSnapshot.exists) {
          throw Exception("User data not found");
        }

        final currentData = currentSnapshot.data() as Map<String, dynamic>;
        final requesterData = requesterSnapshot.data() as Map<String, dynamic>;

        final currentFriends = List<String>.from(currentData['friends'] ?? []);
        final requesterFriends =
            List<String>.from(requesterData['friends'] ?? []);

        // Update Current User (only if not already friends)
        if (!currentFriends.contains(requesterUid)) {
          transaction.update(currentRef, {
            'friends': FieldValue.arrayUnion([requesterUid]),
            'friendsCount': FieldValue.increment(1),
          });
        }

        // Update Requester (only if not already friends)
        if (!requesterFriends.contains(currentUid)) {
          transaction.update(requesterRef, {
            'friends': FieldValue.arrayUnion([currentUid]),
            'friendsCount': FieldValue.increment(1),
          });
        }

        // Always delete the request
        transaction.delete(requestRef);
      });
    } catch (e) {
      debugPrint('Error accepting friend request: $e');
    }
  }

  // Decline/Cancel Friend Request (or Group Invite)
  Future<void> declineFriendRequest(String currentUid, String requestId) async {
    try {
      await _users
          .doc(currentUid)
          .collection('friend_requests')
          .doc(requestId)
          .delete();
    } catch (e) {
      debugPrint('Error declining request: $e');
    }
  }

  // Get Friend Requests Stream
  Stream<QuerySnapshot> getFriendRequests(String uid) {
    return _users
        .doc(uid)
        .collection('friend_requests')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Search Users
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    // Case-insensitive search using 'searchKey'
    final String searchKey = query.toLowerCase();

    try {
      final snapshot = await _users
          .where('searchKey', isGreaterThanOrEqualTo: searchKey)
          .where('searchKey', isLessThan: '$searchKey\uf8ff')
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

  // --- Party & Sessions Logic ---

  // Upload Image to Storage
  Future<String> uploadPartyImage(String uid, File imageFile) async {
    try {
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference ref =
          _storage.ref().child('user_parties').child(uid).child(fileName);

      final UploadTask task = ref.putFile(imageFile);
      final TaskSnapshot snapshot = await task;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint("Error uploading image: $e");
      rethrow;
    }
  }

  // Create a new Party
  Future<String> createParty(String uid, String partyName,
      {String? photoUrl, DateTime? date}) async {
    final partyRef = _users.doc(uid).collection('parties').doc();
    final userRef = _users.doc(uid);
    final partyDate = date ?? DateTime.now();

    await _db.runTransaction((transaction) async {
      // 1. READ: Get User Data First
      final userSnapshot = await transaction.get(userRef);

      // 2. WRITE: Create Party Doc
      transaction.set(partyRef, {
        'name': partyName,
        'photoUrl': photoUrl,
        'timestamp': Timestamp.fromDate(partyDate),
        'cubatas': 0,
        'chupitos': 0,
        'cervezas': 0,
      });

      // 3. WRITE: Update User Stats
      if (userSnapshot.exists) {
        final data = userSnapshot.data() as Map<String, dynamic>;

        final currentYear = DateTime.now().year;
        var annualStats = data['annual_stats'] as Map<String, dynamic>? ??
            {
              'year': currentYear,
              'parties': 0,
              'cubatas': 0,
              'chupitos': 0,
              'cervezas': 0
            };

        if ((annualStats['year'] ?? currentYear) != currentYear) {
          annualStats = {
            'year': currentYear,
            'parties': 0,
            'cubatas': 0,
            'chupitos': 0,
            'cervezas': 0
          };
        }

        transaction.update(userRef, {
          'stats.parties': FieldValue.increment(1),
          'annual_stats': {
            ...annualStats,
            'parties': (annualStats['parties'] ?? 0) + 1
          }
        });
      }
    });
    return partyRef.id;
  }

  // Update Party Photo
  Future<void> updatePartyPhoto(
      String uid, String partyId, String photoUrl) async {
    await _users
        .doc(uid)
        .collection('parties')
        .doc(partyId)
        .update({'photoUrl': photoUrl});
  }

  // Update Party Details (Name, Date)
  Future<void> updatePartyDetails(String uid, String partyId,
      {String? name, DateTime? date}) async {
    final Map<String, dynamic> updates = {};
    if (name != null) updates['name'] = name;
    if (date != null) updates['timestamp'] = Timestamp.fromDate(date);

    if (updates.isNotEmpty) {
      await _users.doc(uid).collection('parties').doc(partyId).update(updates);
    }
  }

  // Get Parties Stream
  Stream<QuerySnapshot> getParties(String uid) {
    return _users
        .doc(uid)
        .collection('parties')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Get Single Party Stream (For live updates inside the page)
  Stream<DocumentSnapshot> getPartyStream(String uid, String partyId) {
    return _users.doc(uid).collection('parties').doc(partyId).snapshots();
  }

  // Update Party Stats (Increment/Decrement Drink)
  Future<void> updatePartyStats(
      String uid, String partyId, String statName, int delta) async {
    final partyRef = _users.doc(uid).collection('parties').doc(partyId);
    final userRef = _users.doc(uid);

    try {
      await _db.runTransaction((transaction) async {
        // 1. READ: Get Party State
        final partySnapshot = await transaction.get(partyRef);
        if (!partySnapshot.exists) return; // Exit if party doesn't exist

        // 2. READ: Get User State (MUST be before any write)
        final userSnapshot = await transaction.get(userRef);

        final currentVal = partySnapshot.get(statName) ?? 0;
        if (currentVal + delta < 0) return; // Prevent negative local

        // 3. WRITE: Update Party
        transaction.update(partyRef, {statName: FieldValue.increment(delta)});

        // 4. WRITE: Update Global User Stats
        if (userSnapshot.exists) {
          final data = userSnapshot.data() as Map<String, dynamic>;
          final currentYear = DateTime.now().year;
          var annualStats = data['annual_stats'] as Map<String, dynamic>? ??
              {
                'year': currentYear,
                'parties': 0,
                'cubatas': 0,
                'chupitos': 0,
                'cervezas': 0
              };

          if ((annualStats['year'] ?? currentYear) != currentYear) {
            annualStats = {
              'year': currentYear,
              'parties': 0,
              'cubatas': 0,
              'chupitos': 0,
              'cervezas': 0
            };
          }

          final globalStatVal = (data['stats']?[statName] ?? 0);
          // Only update global if it won't go negative (or if we don't care about global negative logic as much as local)
          // Assuming we want to keep them in sync, if local allowed it, global generally should too unless they are out of sync.
          if (globalStatVal + delta >= 0) {
            transaction.update(userRef, {
              'stats.$statName': FieldValue.increment(delta),
              'annual_stats': {
                ...annualStats,
                statName:
                    ((annualStats[statName] ?? 0) + delta).clamp(0, 999999)
              }
            });
          }
        }
      });
    } catch (e) {
      debugPrint("Error updating party stats: $e");
    }
  }

  // --- Group Logic ---

  // Create Group
  Future<void> createGroup(String groupName, String creatorUid) async {
    final groupRef = _db.collection('chats').doc();
    await groupRef.set({
      'name': groupName,
      'members': [creatorUid],
      'admin': creatorUid,
      'recentMessage': '',
      'recentMessageSender': '',
      'recentMessageTime': FieldValue.serverTimestamp(),
      'type': 'group',
    });
  }

  // Get User Groups Stream
  Stream<QuerySnapshot> getGroups(String uid) {
    return _db
        .collection('chats')
        .where('members', arrayContains: uid)
        .where('type', isEqualTo: 'group')
        .snapshots();
  }

  // Send Group Invite
  Future<void> sendGroupInvite(String groupId, String groupName,
      String inviterUid, String targetUid) async {
    // Check if already in group (optional, but good UX)
    final groupDoc = await _db.collection('chats').doc(groupId).get();
    if (!groupDoc.exists) return;
    final members = List<String>.from(groupDoc['members'] ?? []);
    if (members.contains(targetUid)) return; // Already a member

    // Fetch inviter info for display
    final inviterDoc = await _users.doc(inviterUid).get();
    final inviterData = inviterDoc.data() as Map<String, dynamic>;

    await _users
        .doc(targetUid)
        .collection('friend_requests') // Re-using collection, new 'type'
        .add({
      'type': 'group_invite',
      'groupId': groupId,
      'groupName': groupName,
      'from': inviterUid,
      'username': inviterData['username'] ?? 'Unknown',
      'photoUrl': inviterData['photoUrl'] ?? '',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Accept Group Invite
  Future<void> acceptGroupInvite(
      String uid, String requestId, String groupId) async {
    try {
      await _db.runTransaction((transaction) async {
        // 1. Add user to group members
        final groupRef = _db.collection('chats').doc(groupId);
        transaction.update(groupRef, {
          'members': FieldValue.arrayUnion([uid])
        });

        // 2. Delete the invite
        final requestRef =
            _users.doc(uid).collection('friend_requests').doc(requestId);
        transaction.delete(requestRef);
      });
    } catch (e) {
      debugPrint("Error accepting group invite: $e");
    }
  }
}
