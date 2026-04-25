// ignore_for_file: use_build_context_synchronously
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img; // Import image package
import '../../providers/dashboard_provider.dart';

class UserSettingsSection extends StatefulWidget {
  const UserSettingsSection({super.key});

  @override
  State<UserSettingsSection> createState() => _UserSettingsSectionState();
}

class _UserSettingsSectionState extends State<UserSettingsSection> {
  final _nameController = TextEditingController();
  String? _newPhotoBase64;
  bool _isInit = true;
  bool _isProcessingImage = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final user = Provider.of<DashboardProvider>(context).userProfile;
      if (user != null) {
        _nameController.text = user.name;
      }
      _isInit = false;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 500); // MaxWidth helps init resize

    if (pickedFile != null) {
      setState(() => _isProcessingImage = true);
      try {
        final bytes = await pickedFile.readAsBytes();
        
        // Resize & Compress (Pure Dart)
        // 1. Decode
        img.Image? image = img.decodeImage(bytes);
        if (image == null) throw Exception("Could not decode image");

        // 2. Resize (Thumbnail) - Maintain aspect ratio
        img.Image thumbnail = img.copyResize(image, width: 200);

        // 3. Encode to JPG with compression
        List<int> compressedBytes = img.encodeJpg(thumbnail, quality: 70);

        // 4. Base64
        final base64String = base64Encode(compressedBytes);

        if (mounted) {
           setState(() {
             _newPhotoBase64 = base64String;
           });
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error processing image: $e")));
      } finally {
        if (mounted) setState(() => _isProcessingImage = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    final user = provider.userProfile;

    if (user == null) return const Center(child: Text("No User Logged In"));

    // Determine Image Provider
    ImageProvider? imageProvider;
    if (_newPhotoBase64 != null) {
       imageProvider = MemoryImage(base64Decode(_newPhotoBase64!));
    } else if (user.photoBase64 != null && user.photoBase64!.isNotEmpty) {
       imageProvider = MemoryImage(base64Decode(user.photoBase64!));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("User Settings")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
           Center(
             child: Stack(
               children: [
                 CircleAvatar(
                   radius: 60,
                   backgroundColor: Colors.grey.shade200,
                   backgroundImage: imageProvider,
                   child: (imageProvider == null && !_isProcessingImage) 
                       ? const Icon(Icons.person, size: 60, color: Colors.grey)
                       : _isProcessingImage ? const CircularProgressIndicator() : null,
                 ),
                 Positioned(
                   bottom: 0,
                   right: 0,
                   child: InkWell(
                     onTap: _pickImage,
                     child: Container(
                       padding: const EdgeInsets.all(8),
                       decoration: const BoxDecoration(
                         color: Colors.blue,
                         shape: BoxShape.circle,
                       ),
                       child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                     ),
                   ),
                 )
               ],
             ),
           ),
           const SizedBox(height: 24),
           TextField(
             controller: _nameController,
             decoration: const InputDecoration(
               labelText: 'Full Name',
               border: OutlineInputBorder(),
               prefixIcon: Icon(Icons.person),
             ),
           ),
           const SizedBox(height: 20),
           ListTile(
             title: const Text("Email"),
             subtitle: Text(user.email),
             leading: const Icon(Icons.email),
             enabled: false, // Email usually immutable without re-auth
           ),
           ListTile(
             title: const Text("Role"),
             subtitle: Text(user.role),
             leading: const Icon(Icons.security),
             enabled: false,
           ),
           const SizedBox(height: 30),
           ElevatedButton(
             onPressed: _isProcessingImage ? null : () async {
                final newName = _nameController.text.trim();
                await provider.updateUserProfile(
                  name: newName,
                  photoBase64: _newPhotoBase64
                );
                if (mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Updated Successfully")));
                   // Do not pop, let them see the change
                }
             },
             style: ElevatedButton.styleFrom(
               padding: const EdgeInsets.symmetric(vertical: 16),
               textStyle: const TextStyle(fontSize: 18),
             ),
             child: const Text("Save Profile"),
           ),
           
           const Divider(height: 40),
           



        ],
      ),
    );
  }
}

