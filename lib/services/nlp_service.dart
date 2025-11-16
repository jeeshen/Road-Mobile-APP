import '../models/post.dart';
import '../models/post_category.dart';

/// NLP Service for analyzing post content and automatically tagging/classifying
class NLPService {
  // Keywords for different event types
  final Map<String, List<String>> _keywordMap = {
    'accident': [
      'accident',
      'crash',
      'collision',
      'collided',
      'hit',
      'crashed',
      'smashed',
      'wreck',
      'injured',
      'ambulance',
      'hospital',
    ],
    'jam': [
      'jam',
      'traffic',
      'congestion',
      'stuck',
      'slow',
      'heavy traffic',
      'bumper to bumper',
      'gridlock',
      'standstill',
    ],
    'police': [
      'police',
      'cop',
      'officer',
      'roadblock',
      'checkpoint',
      'patrol',
      'enforcement',
      'summon',
      'fine',
    ],
    'rain': [
      'rain',
      'raining',
      'rainy',
      'wet',
      'flood',
      'flooded',
      'water',
      'puddle',
      'slippery',
      'storm',
      'heavy rain',
      'downpour',
    ],
    'closure': [
      'closure',
      'closed',
      'blocked',
      'barricade',
      'detour',
      'diversion',
      'road closed',
      'no entry',
      'blocked road',
    ],
    'pothole': [
      'pothole',
      'hole',
      'damage',
      'bump',
      'rough',
      'uneven',
      'crack',
      'broken road',
    ],
    'construction': [
      'construction',
      'work',
      'repair',
      'maintenance',
      'road work',
      'workers',
      'machinery',
    ],
  };

  /// Analyzes post content and extracts keywords
  /// Returns list of detected keywords/tags
  List<String> analyzeKeywords(String title, String content) {
    final text = '${title.toLowerCase()} ${content.toLowerCase()}';
    final detectedTags = <String>[];

    _keywordMap.forEach((key, keywords) {
      for (final keyword in keywords) {
        if (text.contains(keyword)) {
          if (!detectedTags.contains(key)) {
            detectedTags.add(key);
          }
          break; // Found one keyword for this category, move to next
        }
      }
    });

    return detectedTags;
  }

  /// Automatically classifies/categorizes a post based on content analysis
  PostCategory classifyPost(String title, String content) {
    final text = '${title.toLowerCase()} ${content.toLowerCase()}';
    final scores = <PostCategory, int>{};

    // Accident detection
    if (_containsKeywords(text, _keywordMap['accident']!)) {
      scores[PostCategory.accident] = (scores[PostCategory.accident] ?? 0) + 3;
    }

    // Traffic jam detection
    if (_containsKeywords(text, _keywordMap['jam']!)) {
      scores[PostCategory.trafficJam] = (scores[PostCategory.trafficJam] ?? 0) + 2;
    }

    // Roadblock detection
    if (_containsKeywords(text, _keywordMap['police']!)) {
      scores[PostCategory.roadblock] = (scores[PostCategory.roadblock] ?? 0) + 2;
    }

    // Weather detection
    if (_containsKeywords(text, _keywordMap['rain']!)) {
      scores[PostCategory.weather] = (scores[PostCategory.weather] ?? 0) + 2;
    }

    // Road closure detection
    if (_containsKeywords(text, _keywordMap['closure']!)) {
      scores[PostCategory.roadClosure] = (scores[PostCategory.roadClosure] ?? 0) + 3;
    }

    // Pothole detection
    if (_containsKeywords(text, _keywordMap['pothole']!)) {
      scores[PostCategory.pothole] = (scores[PostCategory.pothole] ?? 0) + 2;
    }

    // Construction detection
    if (_containsKeywords(text, _keywordMap['construction']!)) {
      scores[PostCategory.construction] = (scores[PostCategory.construction] ?? 0) + 2;
    }

    // Return category with highest score, or 'other' if no matches
    if (scores.isEmpty) {
      return PostCategory.other;
    }

    final sortedEntries = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedEntries.first.key;
  }

  /// Determines risk level based on content analysis
  RiskLevel determineRiskLevel(String title, String content, PostCategory category) {
    final text = '${title.toLowerCase()} ${content.toLowerCase()}';
    int riskScore = 0;

    // High-risk keywords
    if (_containsKeywords(text, ['accident', 'crash', 'collision', 'injured', 'hospital', 'ambulance'])) {
      riskScore += 3;
    }

    if (_containsKeywords(text, ['flood', 'flooded', 'water', 'blocked', 'closed'])) {
      riskScore += 2;
    }

    if (_containsKeywords(text, ['police', 'roadblock', 'checkpoint'])) {
      riskScore += 1;
    }

    // Category-based risk
    switch (category) {
      case PostCategory.accident:
        riskScore += 3;
        break;
      case PostCategory.roadClosure:
        riskScore += 2;
        break;
      case PostCategory.trafficJam:
        riskScore += 1;
        break;
      case PostCategory.roadblock:
        riskScore += 1;
        break;
      case PostCategory.weather:
        riskScore += 1;
        break;
      default:
        break;
    }

    // Determine risk level
    if (riskScore >= 5) {
      return RiskLevel.critical;
    } else if (riskScore >= 3) {
      return RiskLevel.high;
    } else if (riskScore >= 2) {
      return RiskLevel.medium;
    } else {
      return RiskLevel.low;
    }
  }

  /// Checks if text contains any of the provided keywords
  bool _containsKeywords(String text, List<String> keywords) {
    for (final keyword in keywords) {
      if (text.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

  /// Analyzes a post and returns enhanced post with auto-tags and risk level
  Post enhancePost(Post post) {
    final autoTags = analyzeKeywords(post.title, post.content);
    final suggestedCategory = classifyPost(post.title, post.content);
    final riskLevel = determineRiskLevel(post.title, post.content, post.category);

    return post.copyWith(
      autoTags: autoTags,
      riskLevel: riskLevel,
      // Optionally update category if it's 'other' and we found a better match
      category: post.category == PostCategory.other ? suggestedCategory : post.category,
    );
  }
}


