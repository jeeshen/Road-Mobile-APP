import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../models/user.dart';
import '../services/friend_service.dart';

class AddFriendScreen extends StatefulWidget {
  final User currentUser;

  const AddFriendScreen({super.key, required this.currentUser});

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final FriendService _friendService = FriendService();
  final TextEditingController _userIdController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _addFriend() async {
    final friendId = _userIdController.text.trim();

    if (friendId.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a user ID';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await _friendService.addFriend(widget.currentUser.id, friendId);
      setState(() {
        _successMessage = 'Friend added successfully!';
        _isLoading = false;
        _userIdController.clear();
      });

      // Clear success message after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _successMessage = null;
          });
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
        _successMessage = null;
      });
    }
  }

  Future<void> _copyUserId() async {
    await Clipboard.setData(ClipboardData(text: widget.currentUser.id));
    if (!mounted) return;
    setState(() {
      _successMessage = 'User ID copied to clipboard!';
      _errorMessage = null;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _successMessage == 'User ID copied to clipboard!') {
        setState(() {
          _successMessage = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Add Friend'),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Friend by User ID',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter the user ID of the person you want to add as a friend.',
                style: TextStyle(
                  fontSize: 14,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
              const SizedBox(height: 32),
              CupertinoTextField(
                controller: _userIdController,
                placeholder: 'User ID',
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: CupertinoColors.systemRed,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
              if (_successMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _successMessage!,
                    style: const TextStyle(
                      color: CupertinoColors.systemGreen,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: _isLoading ? null : _addFriend,
                  child: _isLoading
                      ? const CupertinoActivityIndicator()
                      : const Text('Add Friend'),
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          CupertinoIcons.info,
                          size: 20,
                          color: CupertinoColors.systemBlue,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Your User ID',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.currentUser.id,
                            style: const TextStyle(
                              fontSize: 13,
                              fontFamily: 'monospace',
                              color: CupertinoColors.label,
                            ),
                          ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          minSize: 32,
                          onPressed: _copyUserId,
                          child: const Icon(
                            CupertinoIcons.doc_on_doc,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Share this ID with others so they can add you as a friend.',
                      style: TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

