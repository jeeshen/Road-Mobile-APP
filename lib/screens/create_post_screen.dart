import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/district.dart';
import '../models/post.dart';
import '../models/post_category.dart';
import '../services/firebase_service.dart';

class CreatePostScreen extends StatefulWidget {
  final District district;
  final double? latitude;
  final double? longitude;

  const CreatePostScreen({
    super.key,
    required this.district,
    this.latitude,
    this.longitude,
  });

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _usernameController = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();
  final ImagePicker _picker = ImagePicker();
  
  PostCategory _selectedCategory = PostCategory.other;
  final List<File> _selectedMedia = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _selectedMedia.addAll(pickedFiles.map((xFile) => File(xFile.path)));
      });
    }
  }

  void _removeMedia(int index) {
    setState(() {
      _selectedMedia.removeAt(index);
    });
  }

  Future<void> _createPost() async {
    if (_titleController.text.isEmpty || _contentController.text.isEmpty) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Missing Information'),
          content: const Text('Please fill in title and content'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      print('Creating post for district: ${widget.district.id}');
      
      final post = Post(
        id: const Uuid().v4(),
        districtId: widget.district.id,
        userId: 'demo_user',
        username: _usernameController.text.isEmpty
            ? 'Anonymous'
            : _usernameController.text,
        title: _titleController.text,
        content: _contentController.text,
        category: _selectedCategory,
        mediaUrls: [],
        createdAt: DateTime.now(),
        latitude: widget.latitude,
        longitude: widget.longitude,
      );

      print('Post created with ID: ${post.id}');
      print('Uploading ${_selectedMedia.length} images...');
      
      await _firebaseService.createPost(post, _selectedMedia);
      
      print('Post saved successfully!');

      if (mounted) {
        // Show success message
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Success!'),
            content: const Text('Your post has been created successfully'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Close create post screen
                },
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('Error creating post: $e');
      print('Error type: ${e.runtimeType}');
      
      if (mounted) {
        String errorMessage = 'Failed to create post: $e';
        
        // Provide helpful error messages
        if (e.toString().contains('permission-denied')) {
          errorMessage = 'Permission denied!\n\n'
              'Please enable Firestore in Firebase Console:\n'
              '1. Go to console.firebase.google.com\n'
              '2. Select your project\n'
              '3. Enable Firestore Database\n'
              '4. Set rules to test mode';
        } else if (e.toString().contains('not-found')) {
          errorMessage = 'Firestore database not found!\n'
              'Please create Firestore database in Firebase Console.';
        }
        
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text(errorMessage),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showCategoryPicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => Container(
        height: 250,
        color: CupertinoColors.systemBackground,
        child: Column(
          children: [
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.pop(context),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Text('Done'),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 44,
                onSelectedItemChanged: (index) {
                  setState(() {
                    _selectedCategory = PostCategory.values[index];
                  });
                },
                children: PostCategory.values.map((category) {
                  return Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(category.icon, color: category.color, size: 20),
                        const SizedBox(width: 8),
                        Text(category.displayName),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Create Post'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isLoading ? null : _createPost,
          child: _isLoading
              ? const CupertinoActivityIndicator()
              : const Text('Post'),
        ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Username Section
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CupertinoTextField(
                        controller: _usernameController,
                        placeholder: 'Username (Optional)',
                        padding: const EdgeInsets.all(16),
                        decoration: null,
                        style: const TextStyle(fontSize: 17),
                      ),
                    ),
                  ),
                  // Category Selector
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: GestureDetector(
                        onTap: _showCategoryPicker,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(
                                _selectedCategory.icon,
                                color: _selectedCategory.color,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _selectedCategory.displayName,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              const Spacer(),
                              const Icon(
                                CupertinoIcons.chevron_right,
                                size: 16,
                                color: CupertinoColors.tertiaryLabel,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Title
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CupertinoTextField(
                        controller: _titleController,
                        placeholder: 'Post Title',
                        padding: const EdgeInsets.all(16),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: null,
                      ),
                    ),
                  ),
                  // Content
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CupertinoTextField(
                        controller: _contentController,
                        placeholder: 'Describe the situation...',
                        padding: const EdgeInsets.all(16),
                        maxLines: 8,
                        minLines: 6,
                        decoration: null,
                        style: const TextStyle(fontSize: 17),
                      ),
                    ),
                  ),
                  // Media Section
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: _pickImage,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: CupertinoColors.systemBlue.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      CupertinoIcons.photo,
                                      color: CupertinoColors.systemBlue,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Add Photos',
                                    style: TextStyle(
                                      fontSize: 17,
                                      color: CupertinoColors.systemBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_selectedMedia.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: _selectedMedia.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final file = entry.value;
                                  return Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.file(
                                          file,
                                          width: 100,
                                          height: 100,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        top: 6,
                                        right: 6,
                                        child: GestureDetector(
                                          onTap: () => _removeMedia(index),
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: const BoxDecoration(
                                              color: CupertinoColors.systemRed,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              CupertinoIcons.xmark,
                                              size: 14,
                                              color: CupertinoColors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

