import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/post.dart';
import '../models/district.dart';
import '../models/post_category.dart';

class ChatGPTService {
  final String apiKey;
  final String baseUrl = 'https://api.openai.com/v1/chat/completions';

  ChatGPTService({required this.apiKey});

  Future<String> generateTrafficSummary(
    District district,
    List<Post> posts,
  ) async {
    if (posts.isEmpty) {
      return 'No recent traffic incidents reported in ${district.name}.';
    }

    // Group posts by category
    final Map<String, List<Post>> postsByCategory = {};
    for (var post in posts) {
      final category = post.category.displayName;
      if (!postsByCategory.containsKey(category)) {
        postsByCategory[category] = [];
      }
      postsByCategory[category]!.add(post);
    }

    try {
      // Build prompt
      final prompt = _buildPrompt(district, postsByCategory);

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are a traffic safety assistant for Malaysia. Provide concise, helpful traffic summaries.',
            },
            {'role': 'user', 'content': prompt},
          ],
          'max_tokens': 300,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'].trim();
      } else {
        print('ChatGPT API error: ${response.statusCode} - ${response.body}');
        return _generateFallbackSummary(district, postsByCategory);
      }
    } catch (e) {
      print('Error calling ChatGPT API: $e');
      return _generateFallbackSummary(district, postsByCategory);
    }
  }

  String _buildPrompt(
    District district,
    Map<String, List<Post>> postsByCategory,
  ) {
    final buffer = StringBuffer();
    buffer.writeln(
      'Generate a brief traffic safety summary for ${district.name}, ${district.state}, Malaysia.',
    );
    buffer.writeln('\nRecent incidents by category:');

    postsByCategory.forEach((category, categoryPosts) {
      buffer.writeln('\n$category: ${categoryPosts.length} report(s)');
      for (var post in categoryPosts.take(3)) {
        buffer.writeln('- ${post.title}');
      }
    });

    buffer.writeln(
      '\nProvide a concise 2-3 sentence summary highlighting key traffic concerns and patterns. Focus on actionable information for drivers.',
    );

    return buffer.toString();
  }

  String _generateFallbackSummary(
    District district,
    Map<String, List<Post>> postsByCategory,
  ) {
    if (postsByCategory.isEmpty) {
      return 'No recent traffic incidents reported in ${district.name}.';
    }

    final buffer = StringBuffer();
    buffer.writeln('Traffic Summary for ${district.name}:');

    postsByCategory.forEach((category, posts) {
      buffer.writeln('• $category: ${posts.length} report(s)');
    });

    buffer.writeln('\nStay alert and drive safely.');

    return buffer.toString();
  }
}
