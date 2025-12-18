import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/chat_service.dart';
import '../../services/database_service.dart';

class ChatRoomPage extends StatefulWidget {
  final String receiverUserEmail; // Name/Title
  final String receiverUserID; // For DM: UserID. For Group: '' or irrelevant
  final String receiverUserPhotoUrl;
  final String?
      chatId; // If provided, uses this ID (Group). If null, calculates DM ID.
  final bool isGroup;

  const ChatRoomPage({
    super.key,
    required this.receiverUserEmail,
    required this.receiverUserID,
    required this.receiverUserPhotoUrl,
    this.chatId,
    this.isGroup = false,
  });

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScrollController _scrollController = ScrollController();

  late String currentChatId;

  @override
  void initState() {
    super.initState();
    if (widget.chatId != null) {
      currentChatId = widget.chatId!;
    } else {
      currentChatId = _chatService.getChatRoomId(
          _auth.currentUser!.uid, widget.receiverUserID);
    }
  }

  void sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      await _chatService.sendMessage(
        currentChatId,
        _auth.currentUser!.uid,
        _messageController.text,
        isGroup: widget.isGroup,
      );
      _messageController.clear();
      _scrollDown();
    }
  }

  void _scrollDown() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: widget.receiverUserPhotoUrl.isNotEmpty
                  ? NetworkImage(widget.receiverUserPhotoUrl)
                  : null,
              child: widget.receiverUserPhotoUrl.isEmpty
                  ? Icon(widget.isGroup ? Icons.group : Icons.person)
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              widget.receiverUserEmail,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: Colors.transparent, // Seamless look
        scrolledUnderElevation: 0,
        actions: [
          if (widget.isGroup)
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: () {
                _showInviteDialog();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: _buildMessageList(),
          ),

          // Input
          _buildMessageInput(),
        ],
      ),
    );
  }

  void _showInviteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Invite Friend"),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: DatabaseService().getFriends(_auth.currentUser!.uid),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final friends = snapshot.data!;
              if (friends.isEmpty) return const Text("No friends to invite");

              return ListView.builder(
                shrinkWrap: true,
                itemCount: friends.length,
                itemBuilder: (context, index) {
                  final friend = friends[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: friend['photoUrl'] != null &&
                              friend['photoUrl'].isNotEmpty
                          ? NetworkImage(friend['photoUrl'])
                          : null,
                      child: friend['photoUrl'] == null ||
                              friend['photoUrl'].isEmpty
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Text(friend['username'] ?? 'User'),
                    trailing: const Icon(Icons.send),
                    onTap: () async {
                      await DatabaseService().sendGroupInvite(
                          currentChatId,
                          widget
                              .receiverUserEmail, // Group Name (passed as title)
                          _auth.currentUser!.uid,
                          friend['uid']);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Invite sent!")));
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"))
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return StreamBuilder(
      stream: _chatService.getMessages(currentChatId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading messages'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Auto scroll on new message
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollDown());

        return ListView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children:
              snapshot.data!.docs.map((doc) => _buildMessageItem(doc)).toList(),
        );
      },
    );
  }

  Widget _buildMessageItem(DocumentSnapshot document) {
    Map<String, dynamic> data = document.data() as Map<String, dynamic>;
    final colorScheme = Theme.of(context).colorScheme;

    // Is current user?
    bool isCurrentUser = (data['senderId'] == _auth.currentUser!.uid);

    var alignment =
        isCurrentUser ? Alignment.centerRight : Alignment.centerLeft;

    // Modern Colors
    var bubbleColor = isCurrentUser
        ? colorScheme.primary
        : colorScheme.surfaceContainerHighest;
    var textColor =
        isCurrentUser ? colorScheme.onPrimary : colorScheme.onSurface;

    // Rounded Corners logic
    BorderRadius borderRadius = isCurrentUser
        ? const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          );

    return Container(
      alignment: alignment,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: borderRadius,
        ),
        child: Text(
          data['message'],
          style: TextStyle(color: textColor, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Message...',
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: sendMessage,
              icon: Icon(Icons.arrow_upward, color: colorScheme.onPrimary),
            ),
          )
        ],
      ),
    );
  }
}
