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
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _userIdController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildHeroCard() {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 24),
      constraints: const BoxConstraints(minHeight: 220),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          colors: [
            CupertinoColors.activeBlue,
            CupertinoColors.systemIndigo.withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemBlue.withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: CupertinoColors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              CupertinoIcons.person_badge_plus,
              color: CupertinoColors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Add Friend by User ID',
            style: TextStyle(
              color: CupertinoColors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Enter the 6-digit code your friend shares with you. '
            'Requests sync instantly across all devices.',
            style: TextStyle(
              color: CupertinoColors.white.withOpacity(0.85),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    final message = _errorMessage ?? _successMessage;
    final isError = _errorMessage != null;
    final color = isError
        ? CupertinoColors.systemRed
        : CupertinoColors.systemGreen;
    final icon = isError
        ? CupertinoIcons.exclamationmark_circle_fill
        : CupertinoIcons.check_mark_circled_solid;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: message == null
          ? const SizedBox.shrink()
          : Container(
              key: ValueKey(message),
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(
                        color: color,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildUserIdSection() {
    return CupertinoListSection.insetGrouped(
      margin: EdgeInsets.zero,
      header: const Text('Share your ID'),
      children: [
        CupertinoListTile(
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: CupertinoColors.systemBlue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              CupertinoIcons.person_fill,
              color: CupertinoColors.systemBlue,
            ),
          ),
          title: const Text('Your User ID'),
          subtitle: Text(
            widget.currentUser.id,
            style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
          ),
          trailing: CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            onPressed: _copyUserId,
            child: const Icon(CupertinoIcons.doc_on_doc),
          ),
        ),
        const CupertinoListTile(
          leading: Icon(CupertinoIcons.info, color: CupertinoColors.systemGrey),
          title: Text('Need to be discovered?'),
          subtitle: Text('Share this code so friends can find you instantly.'),
        ),
      ],
    );
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
    if (friendId.length != 6 || int.tryParse(friendId) == null) {
      setState(() {
        _errorMessage = 'Please enter a valid 6-digit user ID';
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
      FocusScope.of(context).unfocus();
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
      navigationBar: const CupertinoNavigationBar(middle: Text('Add Friend')),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return CupertinoScrollbar(
              controller: _scrollController,
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeroCard(),
                      const SizedBox(height: 24),
                      _buildStatusBanner(),
                      CupertinoFormSection.insetGrouped(
                        margin: EdgeInsets.zero,
                        header: const Text('Friend ID'),
                        children: [
                          CupertinoTextFormFieldRow(
                            controller: _userIdController,
                            placeholder: '6-digit User ID',
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            prefix: const Icon(
                              CupertinoIcons.number,
                              color: CupertinoColors.systemGrey,
                            ),
                            onFieldSubmitted: (_) => _addFriend(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoButton.filled(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          onPressed: _isLoading ? null : _addFriend,
                          child: _isLoading
                              ? const CupertinoActivityIndicator()
                              : const Text('Send Friend Request'),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildUserIdSection(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
