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
  Future<void> sendMessage(String chatId, String senderId, String message,
      {bool isGroup = false}) async {
    if (message.trim().isEmpty) return;

    final Timestamp timestamp = Timestamp.now();

    // Message Data
    Map<String, dynamic> messageData = {
      'senderId': senderId,
      'message': message,
      'timestamp': timestamp,
    };

    // 1. Add message to subcollection
    await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(messageData);

    // 2. Update Chat Metadata (recent message)
    await _db.collection('chats').doc(chatId).set({
      'recentMessage': message,
      'recentMessageSender': senderId,
      'recentMessageTime': timestamp,
      if (!isGroup)
        'participants': chatId.split('_'), // Only for DM logic if needed
    }, SetOptions(merge: true));
  }

  // Get Messages Stream
  Stream<QuerySnapshot> getMessages(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }
}
