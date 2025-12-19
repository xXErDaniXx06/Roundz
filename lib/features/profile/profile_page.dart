import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../notifications/notifications_page.dart';
import '../settings/settings_page.dart';
import 'party_session_page.dart';

class ProfilePage extends StatefulWidget {
  final String? userId; // Optional: If provided, view this user's profile

  const ProfilePage({super.key, this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final DatabaseService db = DatabaseService();
  final AuthService auth = AuthService();
  // We can't use 'user' directly for data fetching if viewing a friend.
  late String targetUid;
  late bool isCurrentUser;

  @override
  void initState() {
    super.initState();
    final currentUser = FirebaseAuth.instance.currentUser;
    if (widget.userId != null && widget.userId != currentUser?.uid) {
      targetUid = widget.userId!;
      isCurrentUser = false;
    } else {
      targetUid = currentUser!.uid;
      isCurrentUser = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // App Bar Area (Stats)
          SliverAppBar(
            expandedHeight: 460.0,
            floating: false,
            pinned: true,
            backgroundColor: colorScheme.surface,
            leading: !isCurrentUser
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
            flexibleSpace: FlexibleSpaceBar(
              background: StreamBuilder<DocumentSnapshot>(
                  stream: db.getUserStream(targetUid),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(child: Icon(Icons.error));
                    }
                    final data =
                        snapshot.data?.data() as Map<String, dynamic>? ?? {};
                    final stats = data['stats'] as Map<String, dynamic>? ?? {};

                    return _buildGlobalStatsHeader(
                        context,
                        stats,
                        data['username'] ?? 'User',
                        data['photoUrl'] // Pass photoUrl
                        );
                  }),
            ),
            actions: [
              // Only show actions for current user
              if (isCurrentUser) ...[
                IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const NotificationsPage())),
                ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SettingsPage())),
                ),
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () => _showLogoutDialog(context),
                ),
              ]
            ],
          ),

          // Title for Parties List
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Text(
                isCurrentUser ? "Your Parties" : "Parties History",
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // Parties List
          StreamBuilder<QuerySnapshot>(
            stream: db.getParties(targetUid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(
                    child: Center(
                        child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator())));
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return SliverToBoxAdapter(
                  child: Center(
                    child: Column(
                      children: [
                        const SizedBox(height: 40),
                        Icon(Icons.celebration,
                            size: 60,
                            color:
                                colorScheme.onSurfaceVariant.withOpacity(0.3)),
                        const SizedBox(height: 10),
                        Text("No parties yet",
                            style:
                                TextStyle(color: colorScheme.onSurfaceVariant)),
                        if (isCurrentUser) ...[
                          const SizedBox(height: 5),
                          const Text("Tap the + button to start one!",
                              style: TextStyle(color: Colors.grey)),
                        ]
                      ],
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final partyData =
                        docs[index].data() as Map<String, dynamic>;
                    final partyId = docs[index].id;
                    final Timestamp? ts = partyData['timestamp'];
                    final dateStr = ts != null
                        ? "${ts.toDate().day}/${ts.toDate().month}/${ts.toDate().year}"
                        : "";
                    final photoUrl = partyData['photoUrl'] as String?;

                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => PartySessionPage(
                                        partyId: partyId,
                                        partyName: partyData['name'] ?? 'Party',
                                        isReadOnly:
                                            !isCurrentUser, // READ ONLY IF NOT ME
                                        ownerUid: targetUid, // PASS OWNER ID
                                      )));
                        },
                        child: Ink(
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withOpacity(0.3),
                            borderRadius: BorderRadius.circular(16),
                            image: photoUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(photoUrl),
                                    fit: BoxFit.cover,
                                    opacity: 0.3)
                                : null,
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            leading: CircleAvatar(
                              backgroundColor:
                                  colorScheme.primaryContainer.withOpacity(0.9),
                              child: Icon(Icons.celebration,
                                  color: colorScheme.onPrimaryContainer),
                            ),
                            title: Text(partyData['name'] ?? 'Unnamed Party',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(dateStr),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.local_drink,
                                    size: 16, color: Colors.lightBlue),
                                const SizedBox(width: 4),
                                Text("${partyData['cubatas'] ?? 0}"),
                                const SizedBox(width: 12),
                                const Icon(Icons.local_bar,
                                    size: 16, color: Colors.deepOrange),
                                const SizedBox(width: 4),
                                Text("${partyData['chupitos'] ?? 0}"),
                                const SizedBox(width: 12),
                                const Icon(Icons.sports_bar,
                                    size: 16, color: Colors.amber),
                                const SizedBox(width: 4),
                                Text("${partyData['cervezas'] ?? 0}"),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_ios, size: 14),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: docs.length,
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
      floatingActionButton: isCurrentUser
          ? FloatingActionButton.extended(
              onPressed: () => _showCreatePartyDialog(context),
              label: const Text("New Party"),
              icon: const Icon(Icons.add),
            )
          : null, // No create button for friends
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await auth.signOut();
              },
              child: const Text("Log Out")),
        ],
      ),
    );
  }

  void _showCreatePartyDialog(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final TextEditingController controller = TextEditingController();
    File? selectedImage;
    bool isUploading = false;
    final ImagePicker picker = ImagePicker();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text("New Party"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                      labelText: "Party Name", hintText: "e.g. Saturday Night"),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                // Date Picker
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                        "Date: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}"),
                    TextButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: const Text("Change"),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() => selectedDate = picked);
                        }
                      },
                    )
                  ],
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () async {
                    final XFile? image =
                        await picker.pickImage(source: ImageSource.gallery);
                    if (image != null) {
                      setState(() {
                        selectedImage = File(image.path);
                      });
                    }
                  },
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      image: selectedImage != null
                          ? DecorationImage(
                              image: FileImage(selectedImage!),
                              fit: BoxFit.cover)
                          : null,
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                    child: selectedImage == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                                Icon(Icons.add_photo_alternate,
                                    size: 40, color: Colors.grey),
                                SizedBox(height: 8),
                                Text("Add Cover Photo",
                                    style: TextStyle(color: Colors.grey))
                              ])
                        : null,
                  ),
                ),
                if (isUploading)
                  const Padding(
                    padding: EdgeInsets.only(top: 16.0),
                    child: CircularProgressIndicator(),
                  )
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel")),
              FilledButton(
                  onPressed: isUploading
                      ? null
                      : () async {
                          if (controller.text.isNotEmpty) {
                            setState(() => isUploading = true);
                            String? photoUrl;
                            if (selectedImage != null) {
                              try {
                                photoUrl = await db.uploadPartyImage(
                                    user.uid, selectedImage!);
                              } catch (e) {
                                // Handle error?
                              }
                            }

                            await db.createParty(
                                user.uid, controller.text.trim(),
                                photoUrl: photoUrl, date: selectedDate);
                            if (context.mounted) Navigator.pop(context);
                          }
                        },
                  child: const Text("Start!")),
            ],
          );
        });
      },
    );
  }

  // Re-using the header logic but simplified/cleaned up for Sliver context
  Widget _buildGlobalStatsHeader(BuildContext context,
      Map<String, dynamic> stats, String username, String? photoUrl) {
    final colorScheme = Theme.of(context).colorScheme;
    final parties = stats['parties'] ?? 0;
    final cubatas = stats['cubatas'] ?? 0;
    final chupitos = stats['chupitos'] ?? 0;
    final cervezas = stats['cervezas'] ?? 0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage:
                      photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null
                      ? Text(
                          username.isNotEmpty ? username[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 24))
                      : null,
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(username,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    Text("Total Stats",
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.grey)),
                  ],
                )
              ],
            ),
            const SizedBox(height: 24),
            // Big Party Card
            SizedBox(
              width: double.infinity,
              height: 120, // Reduced height
              child: Card(
                color: colorScheme.primaryContainer,
                child: Stack(
                  children: [
                    Positioned(
                        right: -20,
                        top: -20,
                        child: Icon(Icons.celebration,
                            size: 150,
                            color: colorScheme.onPrimaryContainer
                                .withOpacity(0.1))),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("TOTAL PARTIES",
                              style: TextStyle(
                                  color: colorScheme.onPrimaryContainer
                                      .withOpacity(0.7),
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2)),
                          const Spacer(),
                          Text("$parties",
                              style: TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onPrimaryContainer,
                                  height: 1)),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Drinks Row
            Row(
              children: [
                Expanded(
                    child: _buildSmallStat(context, "CUBATAS", cubatas,
                        Icons.local_drink, Colors.lightBlue)),
                const SizedBox(width: 8),
                Expanded(
                    child: _buildSmallStat(context, "CHUPITOS", chupitos,
                        Icons.local_bar, Colors.deepOrange)),
                const SizedBox(width: 8),
                Expanded(
                    child: _buildSmallStat(context, "CERVEZAS", cervezas,
                        Icons.sports_bar, Colors.amber)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSmallStat(BuildContext context, String label, int value,
      IconData icon, Color color) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(label,
              style:
                  const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          Text("$value",
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
