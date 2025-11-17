import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import '../models/district.dart';
import '../models/post.dart';
import '../models/post_category.dart';
import '../models/user.dart';
import '../services/firebase_service.dart';
import '../services/nlp_service.dart';
import '../services/location_service.dart';
import '../services/chatgpt_service.dart';

class CreatePostScreen extends StatefulWidget {
  final District district;
  final double? latitude;
  final double? longitude;
  final bool isRoadDamage;
  final double? roadDamageSeverity;
  final User? currentUser;

  const CreatePostScreen({
    super.key,
    required this.district,
    this.latitude,
    this.longitude,
    this.isRoadDamage = false,
    this.roadDamageSeverity,
    this.currentUser,
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
  final NLPService _nlpService = NLPService();
  final LocationService _locationService = LocationService();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final ChatGPTService? _chatGPTService = ChatGPTService(
    apiKey:
        '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',
  );

  PostCategory _selectedCategory = PostCategory.other;
  final List<File> _selectedMedia = [];
  File? _videoFile;
  File? _audioFile;
  VideoPlayerController? _videoController;
  bool _isLoading = false;
  bool _isRecordingAudio = false;
  bool _isGeneratingContent = false;

  @override
  void initState() {
    super.initState();
    if (widget.currentUser != null) {
      _usernameController.text = widget.currentUser!.name;
    }
    if (widget.isRoadDamage) {
      _generateAIContent();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _usernameController.dispose();
    _videoController?.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _generateAIContent() async {
    final chatGPTService = _chatGPTService;
    if (chatGPTService == null) {
      // Fallback content
      _titleController.text = 'Road Damage Detected';
      _contentController.text =
          'Road damage detected in ${widget.district.name}. Please drive with caution.';
      return;
    }

    setState(() {
      _isGeneratingContent = true;
    });

    try {
      final result = await chatGPTService.generateRoadDamageReport(
        widget.district.name,
        widget.district.state,
        widget.roadDamageSeverity ?? 0.5,
        widget.latitude,
        widget.longitude,
      );

      if (mounted) {
        setState(() {
          _titleController.text = result['title'] ?? 'Road Damage Detected';
          _contentController.text = result['content'] ?? '';
          _selectedCategory = PostCategory.pothole;
          _isGeneratingContent = false;
        });
      }
    } catch (e) {
      print('Error generating AI content: $e');
      if (mounted) {
        setState(() {
          _titleController.text = 'Road Damage Detected';
          _contentController.text =
              'Road damage detected in ${widget.district.name}. Please drive with caution.';
          _selectedCategory = PostCategory.pothole;
          _isGeneratingContent = false;
        });
      }
    }
  }

  // One-tap photo upload
  Future<void> _pickImage() async {
    final pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _selectedMedia.addAll(pickedFiles.map((xFile) => File(xFile.path)));
      });
    }
  }

  // One-tap video upload
  Future<void> _pickVideo() async {
    final pickedVideo = await _picker.pickVideo(source: ImageSource.camera);
    if (pickedVideo != null) {
      setState(() {
        _videoFile = File(pickedVideo.path);
        _videoController = VideoPlayerController.file(_videoFile!)
          ..initialize().then((_) {
            setState(() {});
          });
      });
    }
  }

  // One-tap voice recording
  Future<void> _startVoiceRecording() async {
    if (await _audioRecorder.hasPermission()) {
      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(const RecordConfig(), path: path);
      setState(() {
        _isRecordingAudio = true;
      });
    }
  }

  Future<void> _stopVoiceRecording() async {
    final path = await _audioRecorder.stop();
    if (path != null) {
      setState(() {
        _audioFile = File(path);
        _isRecordingAudio = false;
      });
    }
  }

  void _removeMedia(int index) {
    setState(() {
      _selectedMedia.removeAt(index);
    });
  }

  void _removeVideo() {
    setState(() {
      _videoFile = null;
      _videoController?.dispose();
      _videoController = null;
    });
  }

  void _removeAudio() {
    setState(() {
      _audioFile = null;
    });
  }

  Future<void> _createPost() async {
    // Allow posts with just media (one-tap upload)
    if (_titleController.text.isEmpty &&
        _contentController.text.isEmpty &&
        _selectedMedia.isEmpty &&
        _videoFile == null &&
        _audioFile == null) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Missing Information'),
          content: const Text('Please add some content, media, or description'),
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

      // Get current location if not provided
      double? latitude = widget.latitude;
      double? longitude = widget.longitude;
      if (latitude == null || longitude == null) {
        final position = await _locationService.getCurrentPosition();
        if (position != null) {
          latitude = position.latitude;
          longitude = position.longitude;
        }
      }

      // Auto-generate title if empty
      String title = _titleController.text;
      if (title.isEmpty) {
        if (_selectedMedia.isNotEmpty) {
          title = 'Photo Report';
        } else if (_videoFile != null) {
          title = 'Video Report';
        } else if (_audioFile != null) {
          title = 'Voice Report';
        } else {
          title = 'Road Condition Report';
        }
      }

      // Auto-generate content if empty
      String content = _contentController.text;
      if (content.isEmpty) {
        content = 'Reported via one-tap upload';
      }

      // Create initial post
      final activeUserId = widget.currentUser?.id ?? 'guest_user';
      final hasAccountName =
          widget.currentUser != null && widget.currentUser!.name.isNotEmpty;
      final displayName = hasAccountName
          ? widget.currentUser!.name
          : (_usernameController.text.isEmpty
              ? 'Anonymous'
              : _usernameController.text);

      Post post = Post(
        id: const Uuid().v4(),
        districtId: widget.district.id,
        userId: activeUserId,
        username: displayName,
        title: title,
        content: content,
        category: _selectedCategory,
        mediaUrls: [],
        createdAt: DateTime.now(),
        latitude: latitude,
        longitude: longitude,
        isRoadDamage: widget.isRoadDamage ? true : null,
      );

      // Apply NLP analysis for auto-tagging and risk level
      post = _nlpService.enhancePost(post);

      // Update category if NLP suggests a better one
      if (post.category != _selectedCategory &&
          _selectedCategory == PostCategory.other) {
        // Use NLP-suggested category if user didn't specify
      }

      print('Post created with ID: ${post.id}');
      print('Auto-tags: ${post.autoTags}');
      print('Risk level: ${post.riskLevel?.displayName}');
      print('Uploading ${_selectedMedia.length} images...');

      // Collect all media files
      final allMediaFiles = <File>[..._selectedMedia];
      if (_videoFile != null) allMediaFiles.add(_videoFile!);
      if (_audioFile != null) allMediaFiles.add(_audioFile!);

      await _firebaseService.createPost(post, allMediaFiles);

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
          errorMessage =
              'Permission denied!\n\n'
              'Please enable Firestore in Firebase Console:\n'
              '1. Go to console.firebase.google.com\n'
              '2. Select your project\n'
              '3. Enable Firestore Database\n'
              '4. Set rules to test mode';
        } else if (e.toString().contains('not-found')) {
          errorMessage =
              'Firestore database not found!\n'
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
        middle: Text(widget.isRoadDamage ? 'Review Auto Report' : 'Create Post'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: (_isLoading || _isGeneratingContent) ? null : _createPost,
          child: _isLoading || _isGeneratingContent
              ? const CupertinoActivityIndicator()
              : Text(widget.isRoadDamage ? 'Approve' : 'Post'),
        ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Loading indicator for AI generation
                  if (_isGeneratingContent)
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemBackground,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          CupertinoActivityIndicator(),
                          SizedBox(width: 12),
                          Text(
                            'Generating report content...',
                            style: TextStyle(fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  // Username Section
                  if (!widget.isRoadDamage && widget.currentUser == null)
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
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
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: GestureDetector(
                        onTap: widget.isRoadDamage ? null : _showCategoryPicker,
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
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w400,
                                  color: widget.isRoadDamage
                                      ? CupertinoColors.secondaryLabel
                                      : CupertinoColors.label,
                                ),
                              ),
                              const Spacer(),
                              if (!widget.isRoadDamage)
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
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
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
                        readOnly: widget.isRoadDamage,
                        enabled: !widget.isRoadDamage,
                      ),
                    ),
                  ),
                  // Content
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
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
                        readOnly: widget.isRoadDamage,
                        enabled: !widget.isRoadDamage,
                      ),
                    ),
                  ),
                  // One-Tap Upload Section (hidden for auto-reports)
                  if (!widget.isRoadDamage)
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
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
                              const Text(
                                'One-Tap Upload',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: CupertinoColors.secondaryLabel,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  // Photo Button
                                  Expanded(
                                    child: CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      onPressed: _pickImage,
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: CupertinoColors.systemBlue
                                              .withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Column(
                                          children: [
                                            Icon(
                                              CupertinoIcons.photo,
                                              color: CupertinoColors.systemBlue,
                                              size: 24,
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              'Photo',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: CupertinoColors.systemBlue,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Video Button
                                  Expanded(
                                    child: CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      onPressed: _pickVideo,
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: CupertinoColors.systemPurple
                                              .withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Column(
                                          children: [
                                            Icon(
                                              CupertinoIcons.videocam,
                                              color: CupertinoColors.systemPurple,
                                              size: 24,
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              'Video',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color:
                                                    CupertinoColors.systemPurple,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Voice Button
                                  Expanded(
                                    child: CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      onPressed: _isRecordingAudio
                                          ? _stopVoiceRecording
                                          : _startVoiceRecording,
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: _isRecordingAudio
                                              ? CupertinoColors.systemRed
                                                    .withValues(alpha: 0.2)
                                              : CupertinoColors.systemGreen
                                                    .withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Column(
                                          children: [
                                            Icon(
                                              _isRecordingAudio
                                                  ? CupertinoIcons.stop_circle
                                                  : CupertinoIcons.mic,
                                              color: _isRecordingAudio
                                                  ? CupertinoColors.systemRed
                                                  : CupertinoColors.systemGreen,
                                              size: 24,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _isRecordingAudio
                                                  ? 'Stop'
                                                  : 'Voice',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: _isRecordingAudio
                                                    ? CupertinoColors.systemRed
                                                    : CupertinoColors.systemGreen,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            // Display selected media
                            if (_selectedMedia.isNotEmpty ||
                                _videoFile != null ||
                                _audioFile != null) ...[
                              const SizedBox(height: 16),
                              const Text(
                                'Selected Media',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: CupertinoColors.secondaryLabel,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  // Photos
                                  ..._selectedMedia.asMap().entries.map((
                                    entry,
                                  ) {
                                    final index = entry.key;
                                    final file = entry.value;
                                    return Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
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
                                                color:
                                                    CupertinoColors.systemRed,
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
                                  }),
                                  // Video
                                  if (_videoFile != null)
                                    Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          child:
                                              _videoController != null &&
                                                  _videoController!
                                                      .value
                                                      .isInitialized
                                              ? SizedBox(
                                                  width: 100,
                                                  height: 100,
                                                  child: VideoPlayer(
                                                    _videoController!,
                                                  ),
                                                )
                                              : Container(
                                                  width: 100,
                                                  height: 100,
                                                  color: CupertinoColors
                                                      .systemGrey6,
                                                  child: const Icon(
                                                    CupertinoIcons.videocam,
                                                    size: 30,
                                                  ),
                                                ),
                                        ),
                                        Positioned(
                                          top: 6,
                                          right: 6,
                                          child: GestureDetector(
                                            onTap: _removeVideo,
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: const BoxDecoration(
                                                color:
                                                    CupertinoColors.systemRed,
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
                                    ),
                                  // Audio
                                  if (_audioFile != null)
                                    Stack(
                                      children: [
                                        Container(
                                          width: 100,
                                          height: 100,
                                          decoration: BoxDecoration(
                                            color: CupertinoColors.systemGreen
                                                .withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: const Icon(
                                            CupertinoIcons.mic,
                                            size: 30,
                                            color: CupertinoColors.systemGreen,
                                          ),
                                        ),
                                        Positioned(
                                          top: 6,
                                          right: 6,
                                          child: GestureDetector(
                                            onTap: _removeAudio,
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: const BoxDecoration(
                                                color:
                                                    CupertinoColors.systemRed,
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
                                    ),
                                ],
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
