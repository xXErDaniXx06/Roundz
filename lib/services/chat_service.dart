import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Generate consistent Chat Room ID
  String getChatRoomId(String uid1, String uid2) {
    List<String> ids = [uid1, uid2];
    ids.sort(); // Ensure alphabetical order so "A-B" is same as "B-A"
    return ids.join('_');
  }

  // Send Message
  Future<void> sendMessage(
      String senderId, String receiverId, String message) async {
    if (message.trim().isEmpty) return;

    final String chatRoomId = getChatRoomId(senderId, receiverId);
    final Timestamp timestamp = Timestamp.now();

    // Message Data
    Map<String, dynamic> messageData = {
      'senderId': senderId,
      'receiverId': receiverId,
      'message': message,
      'timestamp': timestamp,
    };

    // 1. Add message to subcollection
    await _db
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .add(messageData);

    // 2. Update Chat Metadata (for recent chats list, optional but good practice)
    await _db.collection('chats').doc(chatRoomId).set({
      'participants': [senderId, receiverId],
      'lastMessage': message,
      'timestamp': timestamp,
    }, SetOptions(merge: true));
  }

  // Get Messages Stream
  Stream<QuerySnapshot> getMessages(String uid1, String uid2) {
    String chatRoomId = getChatRoomId(uid1, uid2);
    return _db
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }
}
