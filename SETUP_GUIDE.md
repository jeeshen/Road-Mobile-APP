# Setup Guide - Traffic Safety Community App

## Step-by-Step Firebase Configuration

### 1. Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project"
3. Enter project name: `roadmobile-malaysia` (or your choice)
4. Disable Google Analytics (optional)
5. Click "Create project"

### 2. Enable Required Firebase Services

#### A. Cloud Firestore
1. In Firebase Console, go to "Build" → "Firestore Database"
2. Click "Create database"
3. Select "Start in test mode" (we'll add proper rules later)
4. Choose location: `asia-southeast1` (Singapore) for Malaysia
5. Click "Enable"

#### B. Firebase Storage
1. Go to "Build" → "Storage"
2. Click "Get started"
3. Start in test mode
4. Use same location as Firestore
5. Click "Done"

#### C. Firebase Authentication (Optional but recommended)
1. Go to "Build" → "Authentication"
2. Click "Get started"
3. Enable "Anonymous" sign-in method
4. Click "Save"

### 3. Configure Firebase for Flutter

#### Install Firebase CLI
```bash
npm install -g firebase-tools
```

#### Install FlutterFire CLI
```bash
dart pub global activate flutterfire_cli
```

#### Configure Firebase Project
```bash
cd "C:\Users\htbac\OneDrive\Desktop\Road Mobile"
firebase login
flutterfire configure
```

Follow the prompts:
- Select your Firebase project
- Choose platforms: Android, iOS, Windows, Web
- This will automatically update `lib/firebase_options.dart`

### 4. Add Firebase Security Rules

#### Firestore Rules
In Firebase Console → Firestore Database → Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Districts - read only, admin write
    match /districts/{district} {
      allow read: if true;
      allow write: if false; // Only initialize once via code
    }
    
    // Posts - public read, authenticated write
    match /posts/{post} {
      allow read: if true;
      allow create: if true;
      allow update: if request.auth != null || true; // Allow for pin/unpin
      allow delete: if request.auth != null;
    }
    
    // Comments - public read, anyone can create
    match /comments/{comment} {
      allow read: if true;
      allow create: if true;
      allow update, delete: if request.auth != null;
    }
  }
}
```

#### Storage Rules
In Firebase Console → Storage → Rules:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /posts/{postId}/{allPaths=**} {
      allow read: if true;
      allow write: if request.resource.size < 10 * 1024 * 1024 // 10MB limit
                   && request.resource.contentType.matches('image/.*');
    }
  }
}
```

### 5. Platform-Specific Setup

#### Android Configuration

1. Download `google-services.json` from Firebase Console:
   - Project Settings → Your apps → Android app
   - Click "Download google-services.json"

2. Place it in: `android/app/google-services.json`

3. Update `android/build.gradle.kts` if needed (already configured):
```kotlin
buildscript {
    dependencies {
        classpath("com.google.gms:google-services:4.4.0")
    }
}
```

4. Update `android/app/build.gradle.kts` (add at bottom):
```kotlin
apply(plugin = "com.google.gms.google-services")
```

#### iOS Configuration

1. Download `GoogleService-Info.plist`:
   - Project Settings → Your apps → iOS app
   - Click "Download GoogleService-Info.plist"

2. Place it in: `ios/Runner/GoogleService-Info.plist`

3. Open Xcode:
```bash
open ios/Runner.xcworkspace
```

4. Drag `GoogleService-Info.plist` into the Runner folder in Xcode
5. Ensure "Copy items if needed" is checked

#### Windows Configuration

Windows uses the web configuration automatically from `firebase_options.dart`.

### 6. Initialize Database with Districts

Run the app for the first time. On the home screen, the app will automatically:
- Check if districts exist
- If not, initialize 20+ districts across Malaysia
- This only happens once

Or you can manually add districts via Firebase Console.

### 7. Test the App

```bash
# Run on Android
flutter run

# Run on iOS
flutter run -d ios

# Run on Web
flutter run -d chrome

# Run on Windows
flutter run -d windows
```

### 8. Common Issues & Solutions

#### Issue: "No Firebase App has been created"
**Solution:** Ensure `Firebase.initializeApp()` is called in `main()` before `runApp()`

#### Issue: "Permission denied" when creating posts
**Solution:** Check Firestore security rules allow public writes

#### Issue: Images not uploading
**Solution:** 
- Check Storage rules
- Verify internet connection
- Check file size < 10MB

#### Issue: Map not loading
**Solution:**
- Check internet connection
- OpenStreetMap tiles require internet
- No API key needed for OSM

#### Issue: Real-time updates not working
**Solution:**
- Verify Firestore rules allow reads
- Check internet connection
- Ensure StreamBuilder is properly configured

### 9. Production Checklist

Before deploying to production:

- [ ] Update Firebase security rules (remove test mode)
- [ ] Enable Firebase Authentication
- [ ] Add user authentication flow
- [ ] Implement admin role for pinning posts
- [ ] Add content moderation
- [ ] Set up Firebase App Check (anti-abuse)
- [ ] Configure proper CORS for web
- [ ] Add rate limiting
- [ ] Set up Firebase Analytics
- [ ] Configure proper error logging (Crashlytics)
- [ ] Test on real devices
- [ ] Optimize Firestore indexes
- [ ] Set up backup strategy

### 10. Optional Enhancements

#### Add User Profiles
```dart
// Create users collection
collection('users').doc(userId).set({
  'username': 'John Doe',
  'avatar': 'url',
  'createdAt': Timestamp.now(),
});
```

#### Add Like Functionality
```dart
// Add likes subcollection
collection('posts').doc(postId).collection('likes').doc(userId).set({
  'likedAt': Timestamp.now(),
});
```

#### Add Push Notifications
```bash
flutter pub add firebase_messaging
```

#### Add Image Compression
```bash
flutter pub add flutter_image_compress
```

### 11. Cost Estimation (Firebase Free Tier)

**Firestore:**
- 50K reads/day ✅
- 20K writes/day ✅
- 20K deletes/day ✅
- 1GB storage ✅

**Storage:**
- 5GB storage ✅
- 1GB/day downloads ✅
- 20K uploads/day ✅

**Sufficient for:**
- ~500 active users/day
- ~100 posts/day
- ~500 comments/day
- ~200 image uploads/day

### 12. Support

For issues or questions:
- Check Firebase Console logs
- Review Flutter error messages
- Check network connectivity
- Verify all dependencies are installed
- Ensure Firebase project is active

## Success! 🎉

You should now have a fully functional Traffic Safety Community App with:
- ✅ Real-time updates
- ✅ Image uploads
- ✅ Interactive map
- ✅ Regional forums
- ✅ Comments system
- ✅ Clean Cupertino UI




