import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/database_service.dart';

class PartySessionPage extends StatefulWidget {
  final String partyId;
  final String partyName;
  final bool isReadOnly;
  final String? ownerUid;

  const PartySessionPage({
    super.key,
    required this.partyId,
    required this.partyName,
    this.isReadOnly = false,
    this.ownerUid,
  });

  @override
  State<PartySessionPage> createState() => _PartySessionPageState();
}

class _PartySessionPageState extends State<PartySessionPage> {
  final DatabaseService _db = DatabaseService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  Future<void> _changeCoverPhoto() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      final File file = File(image.path);
      final String url =
          await _db.uploadPartyImage(_auth.currentUser!.uid, file);
      await _db.updatePartyPhoto(_auth.currentUser!.uid, widget.partyId, url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Cover updated properly! 📸")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error uploading image: $e")));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // We need to fetch from the owner's UID if it is read only?
    // WARNING: `getPartyStream` uses `_auth.currentUser!.uid`.
    // IF we are viewing a friend, we need THEIR UID.
    // BUT the page doesn't receive the Owner UID currently, relying on Auth.
    // The previous implementation assumed "My Profile".
    // Wait, if I am viewing a friend, I can't just access `_users.doc(auth.uid)`.
    // I MUST pass the Owner ID to this page if I am viewing someone else's party.
    // However, the current refactor only adds `isReadOnly`.
    // I will assume for now that `DatabaseService` methods might need adjustment OR
    // simply that I need the Owner UID.
    // Actually, `getPartyStream` takes `uid`. So I need `ownerUid`.

    // NOTE: For now, I will assume the caller passes the correct context,
    // BUT `_auth.currentUser!.uid` is hardcoded in the StreamBuilder below.
    // I should probably fix this now.
    // Let's add `ownerUid` to the constructor as well? Or just use `partyId` if global?
    // Parties are subcollections of users. So yes, I need `ownerUid`.
    // I'll update the plan implicitly: Add `ownerUid` to constructor.
    // For backward compatibility, if ownerUid is null, use current user.

    // Wait, the User Request is just "procede". I should make it robust.
    // I will add `ownerUid` to the constructor.
    return _buildPage();
  }

  // Splitting build to handle the logic cleanly
  Widget _buildPage() {
    // For now, I'll stick to the strict replacement requested but be aware of the data source issue.
    // To fix the data source, I need `ownerUid`.
    // I'll add `ownerUid` to the widget.
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        // Use widget.ownerUid if available, else auth.uid
        stream: _db.getPartyStream(
            widget.ownerUid ?? _auth.currentUser!.uid, widget.partyId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint(snapshot.error.toString());
            return const Center(child: Text("Error loading party"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Party not found"));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final cubatas = data['cubatas'] ?? 0;
          final chupitos = data['chupitos'] ?? 0;
          final cervezas = data['cervezas'] ?? 0;
          final photoUrl = data['photoUrl'] as String?;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 250.0,
                pinned: true,
                stretch: true,
                leading: Center(
                  child: CircleAvatar(
                    backgroundColor: Colors.black45,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Back',
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(data['name'] ?? widget.partyName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 4)
                          ])),
                  centerTitle: true,
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (photoUrl != null)
                        Image.network(
                          photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(color: Colors.grey),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                              gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.purple.shade800,
                              Colors.blue.shade900
                            ],
                          )),
                          child: const Center(
                              child: Icon(Icons.celebration,
                                  size: 80, color: Colors.white24)),
                        ),
                      Container(color: Colors.black26),

                      // Edit Cover Photo Button - Only if NOT Read Only
                      if (!widget.isReadOnly)
                        Positioned(
                          right: 16,
                          bottom: 16,
                          child: InkWell(
                            onTap: _changeCoverPhoto,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(20)),
                              child: _isUploading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.add_a_photo,
                                      color: Colors.white, size: 20),
                            ),
                          ),
                        )
                    ],
                  ),
                ),
                actions: [
                  // Edit Info Button - Only if NOT Read Only
                  if (!widget.isReadOnly)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: CircleAvatar(
                        backgroundColor: Colors.black45,
                        child: IconButton(
                          icon: const Icon(Icons.edit, color: Colors.white),
                          onPressed: () {
                            final Timestamp? ts = data['timestamp'];
                            final currentName =
                                data['name'] ?? widget.partyName;
                            final currentDate =
                                ts != null ? ts.toDate() : DateTime.now();
                            _showEditDialog(context, currentName, currentDate);
                          },
                          tooltip: 'Edit Party',
                        ),
                      ),
                    )
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      _buildCounterCard(context, "Cubatas", cubatas,
                          Icons.local_drink, Colors.lightBlue, 'cubatas'),
                      const SizedBox(height: 24),
                      _buildCounterCard(context, "Chupitos", chupitos,
                          Icons.local_bar, Colors.deepOrange, 'chupitos'),
                      const SizedBox(height: 24),
                      _buildCounterCard(context, "Cervezas", cervezas,
                          Icons.sports_bar, Colors.amber, 'cervezas'),
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCounterCard(BuildContext context, String label, int count,
      IconData icon, Color color, String statKey) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 32),
                    const SizedBox(width: 12),
                    Text(
                      label,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Text(
                  '$count',
                  style: TextStyle(
                      fontSize: 32, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
            // Actions Row - Only if NOT Read Only
            if (!widget.isReadOnly) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(Icons.remove, color, () {
                    _db.updatePartyStats(
                        _auth.currentUser!.uid, widget.partyId, statKey, -1);
                  }),
                  _buildActionButton(Icons.add, color, () {
                    _db.updatePartyStats(
                        _auth.currentUser!.uid, widget.partyId, statKey, 1);
                  }),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onTap) {
    return FilledButton.tonal(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(20),
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
      ),
      child: Icon(icon, size: 32),
    );
  }

  void _showEditDialog(
      BuildContext context, String currentName, DateTime currentDate) {
    final TextEditingController nameController =
        TextEditingController(text: currentName);
    DateTime selectedDate = currentDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          title: const Text("Edit Party"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Party Name"),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                      "Date: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}"),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() => selectedDate = picked);
                      }
                    },
                    child: const Text("Change"),
                  )
                ],
              )
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel")),
            FilledButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  await _db.updatePartyDetails(
                      _auth.currentUser!.uid, widget.partyId,
                      name: nameController.text.trim(), date: selectedDate);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text("Save"),
            )
          ],
        );
      }),
    );
  }
}
