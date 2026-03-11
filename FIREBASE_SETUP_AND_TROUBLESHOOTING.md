# Firebase Setup & Troubleshooting – HumSafar

This guide explains why the app can work on the **emulator** but fail on a **physical Android device** or **iOS**, and how to fix it. It is not about “testing vs production” as a separate environment; it’s about **Firestore database existence**, **Security Rules**, and **app configuration** (Android SHA-1, iOS plist).

---

## 1. What’s going on?

- **Emulator**: Uses the same debug build and (usually) the same Firebase config as your dev machine. If Firestore is in test mode or rules are loose, it works.
- **Physical Android**: Same app can get **permission-denied** from Firestore if rules are in production mode, or **not-found** if the database was never created. Different signing (e.g. release or another PC’s debug key) can also cause Auth/Firebase to reject the app if the SHA-1 isn’t registered.
- **iOS**: The error **“No Firebase App '[DEFAULT]' has been created”** means Firebase was never initialized. The most common cause is **GoogleService-Info.plist** not being included in the Xcode project, so it’s not copied into the app and the SDK can’t find the config. That has been fixed in this project by adding the plist to the Runner target.

---

## 2. Fix checklist

### Step 1: Create Firestore (if you haven’t)

1. Open [Firebase Console](https://console.firebase.google.com/) → project **HumSafar** (`humsafar-eb7f9`).
2. In the left sidebar, open **Build → Firestore Database**.
3. If you see **“Create database”** (or no database at all):
   - Click **Create database**.
   - Choose a **location** (e.g. `us-central1`). You can’t change it later.
   - When asked **“Start in production mode or test mode?”**:
     - **Test mode**: Anyone can read/write for 30 days. Use this to get the app working first.
     - **Production mode**: All reads/writes are denied until you add rules. Use this only when you’re ready to lock down access.
4. Click **Enable**. Wait until the database is created. You should see the Firestore **Data** and **Rules** tabs.

If you had already created the database in **production mode** and never added rules, that explains “Failed to save user data” on the device: Firestore is rejecting the write. Either switch to test mode temporarily (see Step 2) or add proper rules (Step 3).

---

### Step 2: Set Firestore rules (test mode to get unblocked)

1. In Firebase Console → **Firestore Database** → **Rules**.
2. You’ll see something like:

   **If you’re in production mode** (and that’s why writes fail), you can temporarily use **test mode** to confirm the rest of the setup:

   ```text
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /{document=**} {
         allow read, write: if request.time < timestamp.date(2025, 4, 11);
       }
     }
   }
   ```

   That allows read/write until the date you set (e.g. 30 days from now). **Use only for development.** For real users you must replace this with proper rules (Step 3).

3. Click **Publish**.

After this, signup on a physical Android device should be able to write to `users` (and you’ll see the “Failed to save user data” go away if the only issue was rules).

---

### Step 3: Production Firestore rules (for real use)

For HumSafar you want only authenticated users to read/write their own data and appropriate shared data. Example (adjust to your exact collections and fields):

```text
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && request.auth.uid == userId;
      allow update, delete: if request.auth != null && request.auth.uid == userId;
    }
    // Add rules for posts, journeys, chats, etc. as needed.
  }
}
```

Replace or extend the `match` blocks for your other collections, then **Publish**.

---

### Step 4: Android – Add SHA-1 so physical devices are accepted

Firebase does **not** have an “accept all devices” option. It only accepts requests from builds signed with a certificate whose **SHA-1** (and optionally SHA-256) is registered in your Firebase Android app. To support all devices and networks you use, add **every** signing key you use (debug on this PC, debug on another PC, release, etc.).

**Get your debug SHA-1 (same build you install on the phone):**

- **Option A – Gradle (recommended):**
  1. Open a terminal in your **project root** (the folder that contains the `android` folder and `pubspec.yaml`).
  2. Run:
     ```bash
     cd android
     .\gradlew.bat signingReport
     ```
     (On macOS/Linux use `./gradlew signingReport` instead.)
  3. Wait for the build to finish. Scroll the output until you see a section like:
     ```
     Variant: debug
     Config: debug
     Store: C:\Users\YourName\.android\debug.keystore
     Alias: AndroidDebugKey
     ...
     SHA1: AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD
     SHA-256: ...
     ```
  4. Copy the **entire SHA1 line** (the value after `SHA1:`, e.g. `AA:BB:CC:DD:...`). That is what you paste into Firebase as the fingerprint.

- **Option B – Android Studio:** Open the **Android** view → **Gradle** → **humsafar_app** → **app** → **Tasks** → **android** → double‑click **signingReport**. Copy the **SHA1** for the `debug` variant.

- **Option C – keytool (debug keystore):**  
  Default debug keystore location:
  - **Windows:** `%USERPROFILE%\.android\debug.keystore`  
  - **macOS/Linux:** `~/.android/debug.keystore`  
  Run (replace path for your OS):
  ```bash
  keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
  ```
  Copy the **SHA1** from the output.

**Add the SHA-1 in Firebase:**

1. Go to [Firebase Console](https://console.firebase.google.com/) → your project **HumSafar**.
2. Click the **gear** → **Project settings**.
3. Under **Your apps**, select your **Android** app (`com.example.humsafar_app`).
4. Click **Add fingerprint**, paste the **SHA-1**, then add **SHA-256** from the same `signingReport` or keytool output if you want.
5. Click **Save** (no need to re-download `google-services.json` for SHA-1 only, but if you add a new app or change package name you must download it).

**Use the new config and rebuild:**

6. In Project settings, click **Download google-services.json** and replace `android/app/google-services.json` in your project.
7. Clean and run on the device:
   ```bash
   flutter clean && flutter pub get && flutter run
   ```

After this, that build (e.g. debug from this PC) will be accepted by Firebase on any device or network. For another machine or release builds, repeat with that keystore’s SHA-1 and add it as another fingerprint.

---

### Step 5: iOS – GoogleService-Info.plist in Xcode

The iOS error **“No Firebase App '[DEFAULT]' has been created”** was caused by **GoogleService-Info.plist** not being part of the Xcode project, so it wasn’t included in the app bundle. That has been fixed in this repo: the plist is now added to the **Runner** target’s **Copy Bundle Resources**.

You should:

1. **Clean and rebuild iOS:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```
   (with an iOS device or simulator selected).

2. If you ever regenerate the iOS app or add a new target, ensure **GoogleService-Info.plist** is in the **Runner** group and in **Runner → Build Phases → Copy Bundle Resources**.

3. In Firebase Console → **Project settings** → **Your apps** → **iOS** app, confirm the **Bundle ID** is exactly **com.example.humsafarApp** (same as in Xcode).

---

### Step 6: Ensure Firebase APIs are enabled

1. Firebase Console → **Build → Authentication** → ensure **Sign-in method** “Email/Password” is **Enabled**.
2. **Firestore** – already covered above (database created and rules set).
3. Optional: [Google Cloud Console](https://console.cloud.google.com/) → select project **humsafar-eb7f9** → **APIs & Services → Enabled APIs**. You should see **Cloud Firestore API** and **Firebase Authentication** (or similar) enabled.

---

## 3. “Testing” vs “production” in Firebase

- **Firestore**: When you **create** the database, you choose “test mode” (permissive rules for 30 days) or “production mode” (deny all until you add rules). There is no separate “testing project” unless you create a second Firebase project. Your single project **HumSafar** has one Firestore database; its **Rules** tab is what makes it “test” (permissive) or “production” (strict).
- **Auth**: Same project, same Auth; no “testing vs production” toggle. Emulator and device both talk to the same Auth and Firestore.

So: if you had chosen **production** when creating Firestore and never added rules, the emulator might have worked earlier under different rules or a mistake, but the device would get **permission-denied** when writing. Fix by creating the database (if missing), then either using test rules temporarily (Step 2) or proper rules (Step 3).

---

## 4. Summary

| Symptom | Likely cause | What to do |
|--------|----------------|------------|
| “Failed to save user data” on physical Android | Firestore rules deny write, or database missing | Create Firestore; set test or production rules (Steps 1–3). |
| Same on emulator works | Emulator uses same app; rules or DB were different before | Same as above; ensure one Firestore DB and one set of rules. |
| “No Firebase App '[DEFAULT]' has been created” on iOS | Plist not in app bundle | Already fixed in this project (plist in Runner). Do Step 5 (clean/rebuild, check Bundle ID). |
| Auth or Firebase “invalid” on device only | Wrong or missing SHA-1 for that build | Add SHA-1 and update google-services.json (Step 4). |

After completing the steps that apply to your case, run the app again on the **physical Android** and **iOS** device. The app code has also been updated so that Firestore errors (e.g. permission-denied, not-found) show clearer messages that point you to Security Rules and database creation in Firebase Console.

---

## Appendix: Corrected Firestore rules (users + posts fix)

Your existing rules already allow signup (the `users` block has `allow read, write: if true`), so **permission-denied on signup is unlikely** if these rules are actually deployed. If you still see "Failed to save user data" on a physical device, focus on **Android SHA-1** (Step 4 in the checklist) and ensure the rules below are what’s in the console.

Two fixes you should apply:

1. **Users**: Remove `allow read, write: if true` (anyone could read/change any user). Use auth-based rules only. Signup still works because the app creates the Auth user first, then writes the `users` doc while authenticated.
2. **Posts**: Your app stores the post owner as `userId`, not `driverId`. Rules that use `resource.data.driverId` will fail for update/delete. Use `resource.data.userId` so drivers can update/delete their own posts.

Use this **users** block and the **posts** block below; keep the rest of your rules as-is.

**Replace your `match /users/{userId}` section** (both blocks) with this single block:

```text
match /users/{userId} {
  allow read: if request.auth != null;
  allow create: if request.auth != null && request.auth.uid == userId;
  allow update, delete: if request.auth != null && request.auth.uid == userId;
}
```

**Replace your `match /posts/{postId}` section** – change `driverId` to `userId` and combine the two update cases:

```text
match /posts/{postId} {
  allow read: if request.auth != null;
  allow create: if request.auth != null;
  allow delete: if request.auth != null && request.auth.uid == resource.data.userId;
  allow update: if request.auth != null && (
    request.auth.uid == resource.data.userId
    || request.resource.data.diff(resource.data).affectedKeys().hasOnly(['seatsAvailable'])
  );
}
```

Then in Firebase Console → Firestore → **Rules** → **Publish**. After that, if signup still fails on device, the cause is likely **SHA-1** (add the device build’s SHA-1 in Project settings → Android app) or **network/timeout** on that device.
