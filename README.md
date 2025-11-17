# Traffic Safety Community Navigation App

A regional-style transportation forum app for Malaysia with real-time traffic updates, community-driven posts, and interactive map integration.

## Features

✅ **Regional Forums**: Auto-generated forums for each district (Sungai Besi, Bukit Jalil, KLCC, Petaling Jaya, etc.)

✅ **Interactive Map**: Real-time map showing all districts in Malaysia with clickable markers

✅ **Post Categories**:
- Road Accidents 🚨
- Traffic Jams 🚗
- Roadblocks ✋
- Road Closures 🚫
- Potholes 🕳️
- Weather ⛈️
- Construction 🔨
- Other ℹ️

✅ **Community Features**:
- Create posts with photos
- Real-time comments
- Pin important posts
- Anonymous or named posting
- Real-time updates via Firestore

✅ **Clean Cupertino UI**: iOS-style minimalist design

## Upcoming Friend Features

- [ ] Friend home page
- [ ] Friend's post in every forum

## Setup Instructions

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Configure Firebase

You need to set up a Firebase project and configure it for your app:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project (or use existing)
3. Enable the following services:
   - **Cloud Firestore** (Database)
   - **Firebase Storage** (For image/video uploads)
   - **Firebase Authentication** (Optional, for user accounts)

4. Install Firebase CLI:
```bash
npm install -g firebase-tools
```

5. Login to Firebase:
```bash
firebase login
```

6. Install FlutterFire CLI:
```bash
dart pub global activate flutterfire_cli
```

7. Configure Firebase for your Flutter app:
```bash
flutterfire configure
```

This will automatically generate the `lib/firebase_options.dart` file with your Firebase credentials.

### 3. Firebase Security Rules

Set up Firestore security rules in Firebase Console:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Districts - read only
    match /districts/{district} {
      allow read: if true;
      allow write: if false;
    }
    
    // Posts - anyone can read and create
    match /posts/{post} {
      allow read: if true;
      allow create: if true;
      allow update: if true;
      allow delete: if false;
    }
    
    // Comments - anyone can read and create
    match /comments/{comment} {
      allow read: if true;
      allow create: if true;
      allow update: if false;
      allow delete: if false;
    }
  }
}
```

Set up Storage security rules:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /posts/{allPaths=**} {
      allow read: if true;
      allow write: if true;
    }
  }
}
```

### 4. Run the App

```bash
# For Android
flutter run

# For iOS
flutter run

# For Web
flutter run -d chrome

# For Windows
flutter run -d windows
```

## Project Structure

```
lib/
├── models/
│   ├── comment.dart          # Comment data model
│   ├── district.dart         # District data model
│   ├── post.dart            # Post data model
│   └── post_category.dart   # Category enum with icons & colors
├── screens/
│   ├── home_screen.dart           # Map view + district list
│   ├── forum_screen.dart          # Post feed for a district
│   ├── post_detail_screen.dart    # Single post with comments
│   └── create_post_screen.dart    # Create new post
├── services/
│   └── firebase_service.dart      # Firebase CRUD operations
├── firebase_options.dart          # Firebase configuration
└── main.dart                      # App entry point
```

## How It Works

### 1. Home Screen
- Shows an interactive map of Malaysia with district markers
- Displays a scrollable list of all available regional forums
- Tap any marker or list item to enter that district's forum

### 2. Forum Screen
- Real-time stream of posts for the selected district
- Posts are ordered by: Pinned posts first → Most recent
- Each post shows category badge, title, preview, media thumbnail, and comment count
- Tap "+" to create a new post

### 3. Create Post Screen
- Select category from 8 predefined types
- Add title and detailed description
- Upload multiple photos
- Optional username (defaults to "Anonymous")
- Media uploads to Firebase Storage automatically

### 4. Post Detail Screen
- Full post content with all images
- Real-time comment section
- Add comments with optional username
- Timestamps use "timeago" format (e.g., "2 hours ago")

### 5. Real-time Updates
- All data syncs in real-time via Firestore streams
- New posts and comments appear instantly
- No manual refresh needed

## Firebase Collections

### `districts`
```json
{
  "id": "bukit_jalil",
  "name": "Bukit Jalil",
  "latitude": 3.0643,
  "longitude": 101.6995,
  "state": "Kuala Lumpur"
}
```

### `posts`
```json
{
  "id": "uuid",
  "districtId": "bukit_jalil",
  "userId": "demo_user",
  "username": "John Doe",
  "title": "Heavy traffic on C180",
  "content": "Accident causing major delays...",
  "category": "trafficJam",
  "mediaUrls": ["https://..."],
  "createdAt": "Timestamp",
  "isPinned": false,
  "commentCount": 5,
  "likeCount": 0
}
```

### `comments`
```json
{
  "id": "uuid",
  "postId": "post_uuid",
  "userId": "demo_user",
  "username": "Jane Doe",
  "content": "Thanks for the update!",
  "createdAt": "Timestamp"
}
```

## Customization

### Add More Districts
Edit `lib/services/firebase_service.dart` → `_getMalaysiaDistricts()` method:

```dart
District(
  id: 'new_district',
  name: 'New District Name',
  latitude: 3.0000,
  longitude: 101.0000,
  state: 'State Name',
)
```

### Modify Categories
Edit `lib/models/post_category.dart` to add/remove categories with custom icons and colors.

### Change Theme
Edit `lib/main.dart` → `CupertinoApp` theme:

```dart
theme: CupertinoThemeData(
  brightness: Brightness.dark, // Dark mode
  primaryColor: CupertinoColors.systemRed,
),
```

## Admin Features (Optional)

To pin/unpin posts, you can add admin functionality:

```dart
await _firebaseService.updatePostPinStatus(postId, true);
```

Implement admin authentication to restrict this feature.

## Requirements

- Flutter SDK >=3.10.0
- Dart SDK >=3.10.0
- Firebase project
- Internet connection for real-time features

## Packages Used

- `firebase_core` - Firebase initialization
- `cloud_firestore` - Real-time database
- `firebase_storage` - Media storage
- `firebase_auth` - User authentication
- `flutter_map` - Interactive maps
- `latlong2` - Coordinate handling
- `image_picker` - Photo selection
- `cached_network_image` - Image caching
- `timeago` - Relative timestamps
- `uuid` - Unique ID generation

## License

This project is open source and available under the MIT License.
