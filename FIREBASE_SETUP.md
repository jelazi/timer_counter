# Firebase Setup Guide

This guide explains how to configure Firebase for real-time synchronization between desktop and mobile devices.

## Prerequisites

- [Firebase CLI](https://firebase.google.com/docs/cli) installed
- [FlutterFire CLI](https://firebase.flutter.dev/docs/cli/) installed
- A Firebase project created in [Firebase Console](https://console.firebase.google.com/)

## 1. Install FlutterFire CLI

```bash
dart pub global activate flutterfire_cli
```

## 2. Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **Add project**
3. Enter a project name (e.g., `timer-counter`)
4. (Optional) Enable Google Analytics
5. Click **Create project**

## 3. Enable Firebase Services

### Authentication
1. In Firebase Console, go to **Authentication** → **Sign-in method**
2. Enable **Email/Password** provider
3. Click **Save**

### Cloud Firestore
1. Go to **Firestore Database** → **Create database**
2. Choose **Start in test mode** (or production mode with rules below)
3. Select a region close to you
4. Click **Enable**

### Firestore Security Rules (Recommended)

Replace the default rules with:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only read/write their own data
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## 4. Configure FlutterFire

Run from the project root:

```bash
flutterfire configure --project=YOUR_FIREBASE_PROJECT_ID
```

This will:
- Create/update `lib/firebase_options.dart` with platform-specific configuration
- Add `google-services.json` for Android
- Add `GoogleService-Info.plist` for iOS
- Configure macOS if selected

Select the platforms you want to support (Android, iOS, macOS).

## 5. Build & Run

### Android
```bash
flutter run -d android
```

### iOS
```bash
cd ios && pod install && cd ..
flutter run -d ios
```

### macOS (Desktop)
```bash
flutter run -d macos
```

## 6. Usage

1. Open the app on any device
2. Go to **Settings** → **Cloud Sync**
3. Click **Sign In** and enter your email/password (or **Sign Up** for a new account)
4. Once signed in, real-time sync starts automatically
5. All changes (timers, projects, tasks, time entries) are synced across all devices in real-time
6. Use **Upload to Cloud** / **Download from Cloud** buttons for manual bulk sync

## Data Structure

Data is stored under `users/{userId}/` in Firestore:

```
users/
  {userId}/
    categories/     → CategoryModel documents
    projects/       → ProjectModel documents
    tasks/          → TaskModel documents
    time_entries/   → TimeEntryModel documents
    running_timers/ → RunningTimerModel documents (live running timers)
    monthly_targets/→ MonthlyHoursTargetModel documents
```

## Troubleshooting

### "Firebase not available" in Settings
- Make sure you ran `flutterfire configure` and `lib/firebase_options.dart` was generated
- Rebuild the app after configuration

### Authentication errors
- Verify Email/Password sign-in is enabled in Firebase Console
- Check that the Firebase project ID matches your configuration

### Sync not working
- Ensure Firestore is enabled in your Firebase project
- Check Firestore security rules allow authenticated access
- Verify your internet connection

### Build errors on iOS
- Run `cd ios && pod install --repo-update`
- Ensure minimum iOS deployment target is 13.0

### Build errors on Android
- Ensure `minSdk` is at least 23 in `android/app/build.gradle.kts`
