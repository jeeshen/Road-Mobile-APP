import 'package:flutter/cupertino.dart';

enum PostCategory {
  accident,
  trafficJam,
  roadblock,
  roadClosure,
  pothole,
  weather,
  construction,
  other
}

extension PostCategoryExtension on PostCategory {
  String get displayName {
    switch (this) {
      case PostCategory.accident:
        return 'Road Accident';
      case PostCategory.trafficJam:
        return 'Traffic Jam';
      case PostCategory.roadblock:
        return 'Roadblock';
      case PostCategory.roadClosure:
        return 'Road Closure';
      case PostCategory.pothole:
        return 'Pothole';
      case PostCategory.weather:
        return 'Weather';
      case PostCategory.construction:
        return 'Construction';
      case PostCategory.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case PostCategory.accident:
        return CupertinoIcons.exclamationmark_triangle_fill;
      case PostCategory.trafficJam:
        return CupertinoIcons.car_fill;
      case PostCategory.roadblock:
        return CupertinoIcons.hand_raised_fill;
      case PostCategory.roadClosure:
        return CupertinoIcons.xmark_octagon_fill;
      case PostCategory.pothole:
        return CupertinoIcons.decrease_indent;
      case PostCategory.weather:
        return CupertinoIcons.cloud_rain_fill;
      case PostCategory.construction:
        return CupertinoIcons.hammer_fill;
      case PostCategory.other:
        return CupertinoIcons.info_circle_fill;
    }
  }

  Color get color {
    switch (this) {
      case PostCategory.accident:
        return const Color(0xFFFF3B30);
      case PostCategory.trafficJam:
        return const Color(0xFFFF9500);
      case PostCategory.roadblock:
        return const Color(0xFFFF2D55);
      case PostCategory.roadClosure:
        return const Color(0xFFAF52DE);
      case PostCategory.pothole:
        return const Color(0xFF5AC8FA);
      case PostCategory.weather:
        return const Color(0xFF007AFF);
      case PostCategory.construction:
        return const Color(0xFFFFCC00);
      case PostCategory.other:
        return const Color(0xFF8E8E93);
    }
  }

  String toJson() => name;

  static PostCategory fromJson(String json) {
    return PostCategory.values.firstWhere(
      (e) => e.name == json,
      orElse: () => PostCategory.other,
    );
  }
}




