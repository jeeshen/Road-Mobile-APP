import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DebugScreen extends StatelessWidget {
  const DebugScreen({super.key});

  Future<Map<String, dynamic>> _getDebugInfo() async {
    final firestore = FirebaseFirestore.instance;
    
    try {
      // Get all posts
      final postsSnapshot = await firestore.collection('posts').get();
      
      // Get all districts
      final districtsSnapshot = await firestore.collection('districts').get();
      
      // Get all comments
      final commentsSnapshot = await firestore.collection('comments').get();
      
      return {
        'totalPosts': postsSnapshot.docs.length,
        'totalDistricts': districtsSnapshot.docs.length,
        'totalComments': commentsSnapshot.docs.length,
        'posts': postsSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'districtId': data['districtId'] ?? 'N/A',
            'title': data['title'] ?? 'N/A',
            'username': data['username'] ?? 'N/A',
            'createdAt': data['createdAt']?.toString() ?? 'N/A',
          };
        }).toList(),
        'districts': districtsSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'] ?? 'N/A',
          };
        }).toList(),
      };
    } catch (e) {
      return {
        'error': e.toString(),
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Debug Info'),
      ),
      child: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _getDebugInfo(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CupertinoActivityIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: CupertinoColors.systemRed),
                  ),
                ),
              );
            }

            final data = snapshot.data!;

            if (data.containsKey('error')) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        CupertinoIcons.exclamationmark_triangle,
                        size: 60,
                        color: CupertinoColors.systemRed,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Firestore Error',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data['error'],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Firestore is not enabled!\n\n'
                        '1. Go to Firebase Console\n'
                        '2. Enable Firestore Database\n'
                        '3. Set rules to test mode',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildInfoCard(
                  'Total Posts',
                  '${data['totalPosts']}',
                  CupertinoIcons.doc_text,
                ),
                const SizedBox(height: 12),
                _buildInfoCard(
                  'Total Districts',
                  '${data['totalDistricts']}',
                  CupertinoIcons.location,
                ),
                const SizedBox(height: 12),
                _buildInfoCard(
                  'Total Comments',
                  '${data['totalComments']}',
                  CupertinoIcons.chat_bubble,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Posts in Database:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (data['posts'].isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No posts in database',
                      style: TextStyle(color: CupertinoColors.systemGrey),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  ...List.generate(data['posts'].length, (index) {
                    final post = data['posts'][index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post['title'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'District: ${post['districtId']}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                          Text(
                            'By: ${post['username']}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 24),
                const Text(
                  'Districts in Database:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (data['districts'].isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No districts in database',
                      style: TextStyle(color: CupertinoColors.systemGrey),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(data['districts'].length, (index) {
                      final district = data['districts'][index];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemBlue,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          district['name'],
                          style: const TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 12,
                          ),
                        ),
                      );
                    }),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBlue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: CupertinoColors.white, size: 32),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 14,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


