import 'package:flutter/cupertino.dart';
import '../models/user.dart';
import '../services/friend_service.dart';
import 'add_friend_screen.dart';

class FriendsScreen extends StatefulWidget {
  final User currentUser;
  final VoidCallback? onLogout;

  const FriendsScreen({super.key, required this.currentUser, this.onLogout});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final FriendService _friendService = FriendService();

  void _navigateToAddFriend() {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => AddFriendScreen(
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  void _navigateToHome() {
    Navigator.of(context).pop();
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

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Friends'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.home),
          onPressed: _navigateToHome,
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.add),
          onPressed: _navigateToAddFriend,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // User Info Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Profile',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        CupertinoIcons.person_fill,
                        size: 20,
                        color: CupertinoColors.systemBlue,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.currentUser.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        CupertinoIcons.number,
                        size: 20,
                        color: CupertinoColors.secondaryLabel,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'User ID: ${widget.currentUser.id}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: CupertinoColors.secondaryLabel,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      color: CupertinoColors.systemRed,
                      onPressed: _logout,
                      child: const Text('Logout'),
                    ),
                  ),
                ],
              ),
            ),
            // Friends List
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _friendService.getFriendsStream(widget.currentUser.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CupertinoActivityIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error: ${snapshot.error}'),
                    );
                  }

                  final friends = snapshot.data ?? [];

                  if (friends.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            CupertinoIcons.person_2,
                            size: 64,
                            color: CupertinoColors.tertiaryLabel,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No friends yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: CupertinoColors.secondaryLabel,
                            ),
                          ),
                          const SizedBox(height: 8),
                          CupertinoButton(
                            onPressed: _navigateToAddFriend,
                            child: const Text('Add Friend'),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: friends.length,
                    itemBuilder: (context, index) {
                      final friend = friends[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemBackground,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: CupertinoListTile(
                          leading: const Icon(
                            CupertinoIcons.person_fill,
                            color: CupertinoColors.systemBlue,
                          ),
                          title: Text(friend['friendName'] ?? 'Unknown'),
                          subtitle: Text(
                            'ID: ${friend['friendId']}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: CupertinoColors.secondaryLabel,
                            ),
                          ),
                          trailing: CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => _removeFriend(friend['friendId']),
                            child: const Icon(
                              CupertinoIcons.delete,
                              color: CupertinoColors.systemRed,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

