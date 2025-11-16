# Quick Start Guide

Get the Traffic Safety Community App running in **5 minutes**!

## Prerequisites

- ✅ Flutter SDK installed (>=3.10.0)
- ✅ Firebase account (free tier works)
- ✅ Android Studio / Xcode (for mobile)
- ✅ Chrome (for web testing)

## Step 1: Install Dependencies (1 minute)

```bash
cd "C:\Users\htbac\OneDrive\Desktop\Road Mobile"
flutter pub get
```

## Step 2: Firebase Setup (3 minutes)

### Quick Firebase Setup

1. **Create Firebase Project**
   - Go to https://console.firebase.google.com/
   - Click "Add project"
   - Name: `roadmobile-app`
   - Disable Analytics (optional)
   - Click "Create"

2. **Enable Firestore**
   - Click "Firestore Database"
   - Click "Create database"
   - Choose "Test mode"
   - Location: `asia-southeast1`
   - Click "Enable"

3. **Enable Storage**
   - Click "Storage"
   - Click "Get started"
   - Start in test mode
   - Click "Done"

4. **Configure Flutter App**
   ```bash
   npm install -g firebase-tools
   dart pub global activate flutterfire_cli
   firebase login
   flutterfire configure
   ```
   - Select your project
   - Choose platforms (Android, iOS, Web, Windows)
   - This auto-generates `lib/firebase_options.dart`

## Step 3: Run the App (1 minute)

### For Android
```bash
flutter run
```

### For Web (fastest for testing)
```bash
flutter run -d chrome
```

### For iOS
```bash
flutter run -d ios
```

### For Windows
```bash
flutter run -d windows
```

## First Launch

1. **App opens** → Home screen with map
2. **Districts initialize** automatically (20+ locations)
3. **Tap any marker** or list item → Enter forum
4. **Tap +** → Create your first post
5. **Done!** 🎉

## Test the Features

### 1. Create a Post
- Open any district forum
- Tap the "+" button
- Select category: "Traffic Jam"
- Title: "Heavy traffic on Federal Highway"
- Content: "Avoid this route, very slow moving"
- Add photos (optional)
- Tap "Post"

### 2. View Posts
- See your post appear instantly
- Real-time updates (no refresh needed)
- Tap post to see full details

### 3. Add Comments
- Open any post
- Scroll to bottom
- Type comment: "Thanks for the update!"
- Tap send button
- Comment appears instantly

### 4. Explore Map
- Go back to home screen
- Pan/zoom the map
- Tap different district markers
- Each has its own forum

## Troubleshooting

### "No Firebase App created"
**Fix:** Run `flutterfire configure` again

### "Permission denied" errors
**Fix:** Check Firebase Rules are in test mode:
```javascript
allow read, write: if true;
```

### Map not loading
**Fix:** Check internet connection (OpenStreetMap requires internet)

### Images not uploading
**Fix:** 
- Verify Storage is enabled in Firebase
- Check file size < 10MB
- Ensure permissions in AndroidManifest.xml

## Quick Commands

```bash
# Install dependencies
flutter pub get

# Run on connected device
flutter run

# Run on specific device
flutter devices                    # List devices
flutter run -d chrome             # Run on Chrome
flutter run -d <device-id>        # Run on specific device

# Clean build
flutter clean
flutter pub get
flutter run

# Check for issues
flutter doctor

# Update Firebase config
flutterfire configure

# Build APK (Android)
flutter build apk

# Build IPA (iOS)
flutter build ios

# Build web
flutter build web
```

## Project Structure (Quick Overview)

```
lib/
├── main.dart                      # App entry point
├── firebase_options.dart          # Firebase config (auto-generated)
├── models/                        # Data structures
│   ├── district.dart             # District model
│   ├── post.dart                 # Post model
│   ├── comment.dart              # Comment model
│   └── post_category.dart        # Category enum
├── screens/                       # UI pages
│   ├── home_screen.dart          # Map + district list
│   ├── forum_screen.dart         # Post feed
│   ├── create_post_screen.dart   # Create post
│   └── post_detail_screen.dart   # Post + comments
└── services/
    └── firebase_service.dart      # Database operations
```

## Adding More Districts

Edit `lib/services/firebase_service.dart`:

```dart
District(
  id: 'your_district',
  name: 'Your District Name',
  latitude: 3.0000,  // Your coordinates
  longitude: 101.0000,
  state: 'Your State',
)
```

Run the app → Districts auto-initialize!

## Next Steps

1. ✅ **Read FEATURES.md** - See all implemented features
2. ✅ **Read SETUP_GUIDE.md** - Detailed Firebase setup
3. ✅ **Customize** - Add more districts, categories, features
4. ✅ **Deploy** - Build and publish your app

## Common Customizations

### Change App Name
- `pubspec.yaml`: Update `name`
- `android/app/src/main/AndroidManifest.xml`: Update `android:label`
- `ios/Runner/Info.plist`: Update `CFBundleDisplayName`

### Change Theme Color
Edit `lib/main.dart`:
```dart
theme: CupertinoThemeData(
  primaryColor: CupertinoColors.systemRed, // Your color
),
```

### Add New Category
Edit `lib/models/post_category.dart`:
```dart
enum PostCategory {
  accident,
  trafficJam,
  // Add yours here
  flood,
}
```

### Change Map Center
Edit `lib/screens/home_screen.dart`:
```dart
initialCenter: const LatLng(3.1390, 101.6869), // Your coordinates
initialZoom: 10.0, // Your zoom level
```

## Production Deployment

### Android (Google Play)
```bash
flutter build appbundle
# Upload to Play Console
```

### iOS (App Store)
```bash
flutter build ios
# Open Xcode → Archive → Upload
```

### Web (Hosting)
```bash
flutter build web
firebase deploy --only hosting
```

## Resources

- **Flutter Docs**: https://flutter.dev/docs
- **Firebase Docs**: https://firebase.google.com/docs
- **Flutter Map**: https://docs.fleaflet.dev/
- **Project README**: `README.md`
- **Features List**: `FEATURES.md`
- **Setup Guide**: `SETUP_GUIDE.md`

## Support

Stuck? Check:
1. Firebase Console → Logs
2. Flutter DevTools → Console
3. `flutter doctor` for setup issues
4. Firebase Rules are in test mode
5. Internet connection is active

## Success! 🎉

You now have a fully functional:
- ✅ Real-time traffic community app
- ✅ Interactive Malaysia map
- ✅ 20+ district forums
- ✅ Post and comment system
- ✅ Image upload capability
- ✅ Clean iOS-style UI

**Start posting and help your community! 🚗🇲🇾**




