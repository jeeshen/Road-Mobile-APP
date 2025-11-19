import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../models/user.dart';
import '../services/friend_service.dart';
import 'add_friend_screen.dart';
import 'friend_home_screen.dart';

class FriendsScreen extends StatefulWidget {
  final User currentUser;
  final VoidCallback? onLogout;

  const FriendsScreen({super.key, required this.currentUser, this.onLogout});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final FriendService _friendService = FriendService();
  String _searchQuery = '';
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _navigateToAddFriend() {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => AddFriendScreen(currentUser: widget.currentUser),
      ),
    );
  }

  void _navigateToFriendHome(Map<String, dynamic> friend) {
    final friendId = friend['friendId']?.toString() ?? '';
    if (friendId.isEmpty) return;
    final friendName = friend['friendName']?.toString() ?? 'Friend';

    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => FriendHomeScreen(
          currentUser: widget.currentUser,
          friendId: friendId,
          friendName: friendName,
        ),
      ),
    );
  }

  void _navigateToHome() {
    Navigator.of(context).pop();
  }

  Future<void> _copyOwnUserId() async {
    await Clipboard.setData(ClipboardData(text: widget.currentUser.id));
    HapticFeedback.selectionClick();
  }

  void _logout() {
    widget.onLogout?.call();
    Navigator.of(context).pop();
  }

  Future<void> _removeFriend(String friendId) async {
    try {
      await _friendService.removeFriend(widget.currentUser.id, friendId);
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text(e.toString().replaceAll('Exception: ', '')),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> friends) {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = friends.where((friend) {
      if (query.isEmpty) return true;
      final name = (friend['friendName'] ?? '').toString().toLowerCase();
      final id = (friend['friendId'] ?? '').toString().toLowerCase();
      return name.contains(query) || id.contains(query);
    }).toList();
    return filtered;
  }

  void _showFriendActions(Map<String, dynamic> friend) {
    final friendName = friend['friendName']?.toString() ?? 'Unknown';
    final friendId = friend['friendId']?.toString() ?? '';
    if (friendId.isEmpty) return;

    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(friendName),
        message: Text('User ID: $friendId'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _navigateToFriendHome(friend);
            },
            child: const Text('View Forum Activity'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              Clipboard.setData(ClipboardData(text: friendId));
              HapticFeedback.selectionClick();
            },
            child: const Text('Copy User ID'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _removeFriend(friendId);
            },
            child: const Text('Remove Friend'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            CupertinoColors.systemBlue.withOpacity(0.9),
            CupertinoColors.systemIndigo,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemBlue.withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: CupertinoColors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    widget.currentUser.name.isNotEmpty
                        ? widget.currentUser.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.currentUser.name,
                      style: const TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'User ID: ${widget.currentUser.id}',
                      style: TextStyle(
                        color: CupertinoColors.white.withOpacity(0.8),
                        fontSize: 14,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                color: CupertinoColors.white.withOpacity(0.2),
                onPressed: _copyOwnUserId,
                child: const Icon(
                  CupertinoIcons.doc_on_doc,
                  color: CupertinoColors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  color: CupertinoColors.white,
                  onPressed: _navigateToAddFriend,
                  child: const Text(
                    'Add Friend',
                    style: TextStyle(color: CupertinoColors.black),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CupertinoButton(
                  color: CupertinoColors.systemRed.withOpacity(0.2),
                  onPressed: _logout,
                  child: const Text(
                    'Logout',
                    style: TextStyle(color: CupertinoColors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: CupertinoColors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  CupertinoIcons.person_2,
                  size: 64,
                  color: CupertinoColors.inactiveGray.withOpacity(0.8),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No friends yet',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Share your 6-digit ID so others can follow your updates.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: CupertinoColors.secondaryLabel),
                ),
                const SizedBox(height: 20),
                CupertinoButton.filled(
                  onPressed: _navigateToAddFriend,
                  child: const Text('Add Friend'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendTile(Map<String, dynamic> friend) {
    final friendName = friend['friendName']?.toString() ?? 'Unknown';
    final friendId = friend['friendId']?.toString() ?? '-';
    final initials = friendName.isNotEmpty ? friendName[0].toUpperCase() : '?';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _navigateToFriendHome(friend),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: [
                    CupertinoColors.systemBlue.withOpacity(0.9),
                    CupertinoColors.activeBlue,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: CupertinoColors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friendName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey5,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'ID • $friendId',
                      style: const TextStyle(
                        fontSize: 13,
                        fontFamily: 'monospace',
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minSize: 0,
              onPressed: () => _showFriendActions(friend),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  CupertinoIcons.ellipsis,
                  color: CupertinoColors.systemGrey,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightChip({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: CupertinoColors.systemGrey),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsRow(int total, int visible) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          _buildInsightChip(
            icon: CupertinoIcons.person_2_fill,
            value: '$visible shown',
            label: _searchQuery.isEmpty ? 'All friends' : 'Filtered results',
          ),
          const SizedBox(width: 14),
          _buildInsightChip(
            icon: CupertinoIcons.person_badge_plus,
            value: '$total total',
            label: 'Synced contacts',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: CupertinoScrollbar(
        controller: _scrollController,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            CupertinoSliverNavigationBar(
              largeTitle: const Text('Friends'),
              leading: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _navigateToHome,
                child: const Icon(CupertinoIcons.home),
              ),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _navigateToAddFriend,
                child: const Icon(CupertinoIcons.add),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverToBoxAdapter(child: _buildProfileCard()),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                child: Column(
                  children: [
                    CupertinoSearchTextField(
                      placeholder: 'Search by name or user ID',
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _friendService.getFriendsStream(widget.currentUser.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CupertinoActivityIndicator()),
                    );
                  }

                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Column(
                        children: [
                          Icon(
                            CupertinoIcons.exclamationmark_circle,
                            size: 42,
                            color: CupertinoColors.systemRed.withOpacity(0.7),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Error: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: CupertinoColors.systemRed,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final friends = snapshot.data ?? [];
                  if (friends.isEmpty) {
                    return _buildEmptyState();
                  }

                  final filteredFriends = _applyFilters(friends);

                  if (filteredFriends.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 48,
                      ),
                      child: Column(
                        children: const [
                          Icon(
                            CupertinoIcons.search,
                            size: 48,
                            color: CupertinoColors.secondaryLabel,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No matches found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Try a different name or user ID.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: CupertinoColors.secondaryLabel,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildInsightsRow(friends.length, filteredFriends.length),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Connections',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: CupertinoColors.secondaryLabel,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...filteredFriends.map(
                              (friend) => Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: _buildFriendTile(friend),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
          ],
        ),
      ),
    );
  }
}
