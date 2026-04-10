# Production-Ready Changes — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the app deployable to Google Play Store: fix the blocked screen UX, correct the bonus interval, remove iOS artifacts, clean debug output, and set a unique application ID.

**Architecture:** Pure in-place edits — no new files, no new abstractions. Five files change in Flutter, three in Android. The app ID rename touches all Kotlin source files and the directory structure.

**Tech Stack:** Flutter/Dart, Kotlin, Android Gradle (build.gradle.kts)

> **APP ID DECISION — CONFIRM BEFORE TASK 5:**
> This plan uses `com.filipebhenriques.quit` as the new application ID (based on git user).
> If you want a different ID (e.g. `com.quitapp.blocker`), set `NEW_PKG=your.id.here` and replace every occurrence of `com.filipebhenriques.quit` in Tasks 5-6 with your chosen ID before running those tasks.

---

## File Map

| File | Change |
|------|--------|
| `lib/screens/blocked_screen.dart` | Replace UNBLOCK APP button; remove `_launchUnblockedApp` method |
| `lib/usage_timer.dart` | `bonusRefillInterval` 1 min → 1 hour; remove 4 `print()` calls |
| `pubspec.yaml` | Remove `screen_time_api_ios`; update description |
| `android/app/build.gradle.kts` | `applicationId` + `namespace` → `com.filipebhenriques.quit`; add release signing config |
| `android/app/src/main/AndroidManifest.xml` | Update WATCHDOG action to new package |
| All 7 `android/app/src/main/kotlin/com/example/quit/*.kt` | Update `package` declaration |
| Directory `android/app/src/main/kotlin/com/example/quit/` | Rename to `.../kotlin/com/filipebhenriques/quit/` |

---

## Task 1: Replace "Unblock App" with "I Will Do Something Else"

**Files:**
- Modify: `lib/screens/blocked_screen.dart`

- [ ] **Step 1: Replace the button and remove the unused method**

In `lib/screens/blocked_screen.dart`, make two edits:

**Edit A** — Remove the `_launchUnblockedApp` method (lines 94–118). Delete the entire method:

```dart
  Future<void> _launchUnblockedApp() async {
    if (_blockedPackageName == null) {
      _closeActivity();
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> blockedApps = prefs.getStringList('blocked_apps') ?? [];
    blockedApps.remove(_blockedPackageName);
    await prefs.setStringList('blocked_apps', blockedApps);

    try {
      await monitoringChannel.invokeMethod('updateBlockedApps', {
        'blockedApps': blockedApps,
      });
    } catch (_) {}

    try {
      await navigationChannel.invokeMethod('launchApp', {
        'packageName': _blockedPackageName,
      });
    } catch (_) {
      _closeActivity();
    }
  }
```

**Edit B** — In the `// ── NORMAL BLOCK ──` section, replace:

```dart
                          _ActionButton(
                            label: 'UNBLOCK APP',
                            onPressed: _launchUnblockedApp,
                            filled: true,
                          ),
```

with:

```dart
                          _ActionButton(
                            label: 'I WILL DO SOMETHING ELSE',
                            onPressed: _closeActivity,
                            filled: true,
                            icon: Icons.home_outlined,
                          ),
```

- [ ] **Step 2: Verify the file compiles**

```bash
cd "c:/Users/USER/Desktop/SelfProjects/QUIT- app blocker gambling/quit"
flutter analyze lib/screens/blocked_screen.dart
```

Expected: no errors. If `_launchUnblockedApp` still appears anywhere in the file, it will warn about unused code — remove it.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/blocked_screen.dart
git commit -m "ux: replace unblock button with go-home on normal block screen"
```

---

## Task 2: Bonus Refill Interval 1 min → 1 hour + Remove print() calls

**Files:**
- Modify: `lib/usage_timer.dart`

- [ ] **Step 1: Change the default bonusRefillInterval**

In `lib/usage_timer.dart` line 26, replace:

```dart
    this.bonusRefillInterval = const Duration(hours: 0, minutes: 1, seconds: 0),
```

with:

```dart
    this.bonusRefillInterval = const Duration(hours: 1),
```

- [ ] **Step 2: Remove the 4 print() calls**

Remove these lines entirely (they appear inside `setDailyLimit` and `resetTimer`):

```dart
      print('✨ Bonus system initialized (never granted)');
```

```dart
    print(
      '⏰ Limit: ${seconds}s, Used: ${usedToday}s, Remaining: ${remainingSeconds}s',
    );
```

```dart
      print('⏰ Daily time ran out - bonus timer started');
```

```dart
    print('⏰ Timer reset: ${dailyLimitSeconds}s available, countdown cleared');
```

- [ ] **Step 3: Verify**

```bash
flutter analyze lib/usage_timer.dart
```

Expected: no errors or warnings.

- [ ] **Step 4: Commit**

```bash
git add lib/usage_timer.dart
git commit -m "fix: bonus refill interval 1 hour; remove debug print calls"
```

---

## Task 3: Remove iOS Dependency + Update App Description

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Remove screen_time_api_ios and update description**

In `pubspec.yaml`:

**Edit A** — Change line 2 (`description`) from:

```yaml
description: "A new Flutter project."
```

to:

```yaml
description: "QUIT - App & Website Blocker"
```

**Edit B** — Remove this line from the `dependencies:` block:

```yaml
  screen_time_api_ios: ^0.0.4
```

- [ ] **Step 2: Re-fetch dependencies**

```bash
flutter pub get
```

Expected: resolves without errors. If `screen_time_api_ios` was referenced anywhere in Dart code, `flutter pub get` will report it — but grep confirms it is not imported anywhere:

```bash
grep -r "screen_time_api_ios" lib/
```

Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: remove ios dependency, update app description"
```

---

## Task 4: Android Application ID Rename

> **Before starting:** Confirm your desired app ID. This plan uses `com.filipebhenriques.quit`.
> If you want something else, replace every occurrence of `com.filipebhenriques.quit` and `com/filipebhenriques/quit` in this task with your chosen values.

**Files:**
- Modify: `android/app/build.gradle.kts`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Rename directory: `android/app/src/main/kotlin/com/example/quit/` → `android/app/src/main/kotlin/com/filipebhenriques/quit/`
- Modify `package` declaration in all 7 `.kt` files

- [ ] **Step 1: Update build.gradle.kts**

In `android/app/build.gradle.kts`, replace:

```kotlin
    namespace = "com.example.quit"
```

with:

```kotlin
    namespace = "com.filipebhenriques.quit"
```

And replace:

```kotlin
        applicationId = "com.example.quit"
```

with:

```kotlin
        applicationId = "com.filipebhenriques.quit"
```

- [ ] **Step 2: Update the WATCHDOG broadcast action in AndroidManifest.xml**

In `android/app/src/main/AndroidManifest.xml`, replace:

```xml
                <action android:name="com.example.quit.WATCHDOG" />
```

with:

```xml
                <action android:name="com.filipebhenriques.quit.WATCHDOG" />
```

- [ ] **Step 3: Rename the Kotlin source directory**

```bash
mkdir -p "c:/Users/USER/Desktop/SelfProjects/QUIT- app blocker gambling/quit/android/app/src/main/kotlin/com/filipebhenriques/quit"
cp "c:/Users/USER/Desktop/SelfProjects/QUIT- app blocker gambling/quit/android/app/src/main/kotlin/com/example/quit/"*.kt \
   "c:/Users/USER/Desktop/SelfProjects/QUIT- app blocker gambling/quit/android/app/src/main/kotlin/com/filipebhenriques/quit/"
rm -rf "c:/Users/USER/Desktop/SelfProjects/QUIT- app blocker gambling/quit/android/app/src/main/kotlin/com/example"
```

- [ ] **Step 4: Update the package declaration in all 7 Kotlin files**

In each of these files, change `package com.example.quit` to `package com.filipebhenriques.quit`:

- `android/app/src/main/kotlin/com/filipebhenriques/quit/BlockingActivity.kt`
- `android/app/src/main/kotlin/com/filipebhenriques/quit/BootReceiver.kt`
- `android/app/src/main/kotlin/com/filipebhenriques/quit/BrowserAccessibilityService.kt`
- `android/app/src/main/kotlin/com/filipebhenriques/quit/MainActivity.kt`
- `android/app/src/main/kotlin/com/filipebhenriques/quit/MonitoringService.kt`
- `android/app/src/main/kotlin/com/filipebhenriques/quit/ServiceWatchdog.kt`
- `android/app/src/main/kotlin/com/filipebhenriques/quit/ServiceWatchdogReceiver.kt`

For each file, the first line changes from:

```kotlin
package com.example.quit
```

to:

```kotlin
package com.filipebhenriques.quit
```

Also update the WATCHDOG action string inside `ServiceWatchdogReceiver.kt` and `ServiceWatchdog.kt` — search both files for `"com.example.quit.WATCHDOG"` and replace with `"com.filipebhenriques.quit.WATCHDOG"`.

- [ ] **Step 5: Verify the build**

```bash
cd "c:/Users/USER/Desktop/SelfProjects/QUIT- app blocker gambling/quit"
flutter build apk --debug 2>&1 | tail -20
```

Expected: `Built build/app/outputs/flutter-apk/app-debug.apk`. If you see `package com.example.quit not found` errors, one of the files still has the old declaration — fix and re-run.

- [ ] **Step 6: Commit**

```bash
git add android/
git commit -m "chore: rename application ID to com.filipebhenriques.quit"
```

---

## Task 5: Release Signing Config

> This task sets up the release signing config in Gradle. You must first generate a keystore file (one-time, outside the repo). Steps below cover both.

**Files:**
- Modify: `android/app/build.gradle.kts`
- Create: `android/key.properties` (gitignored — never commit this)

- [ ] **Step 1: Generate a keystore (one-time, run once, store the file safely)**

```bash
keytool -genkey -v -keystore ~/quit-release.keystore \
  -alias quit -keyalg RSA -keysize 2048 -validity 10000
```

You will be prompted for a password and identity fields. **Save the keystore file and passwords somewhere safe** — losing them means you can never update the app on Play Store.

- [ ] **Step 2: Create android/key.properties**

Create `android/key.properties` (this file must NOT be committed — check `.gitignore`):

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=quit
storeFile=C:/Users/USER/quit-release.keystore
```

Replace `YOUR_STORE_PASSWORD` and `YOUR_KEY_PASSWORD` with the passwords you used in Step 1. Use the actual absolute path to the keystore file.

- [ ] **Step 3: Add key.properties to .gitignore**

Append to `.gitignore` (create it at repo root if it doesn't exist):

```
android/key.properties
*.keystore
```

- [ ] **Step 4: Update build.gradle.kts to load the signing config**

In `android/app/build.gradle.kts`, replace the entire `android { ... }` block with:

```kotlin
android {
    namespace = "com.filipebhenriques.quit"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    val keystorePropertiesFile = rootProject.file("app/key.properties")
    val keystoreProperties = java.util.Properties()
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(keystorePropertiesFile.inputStream())
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    defaultConfig {
        applicationId = "com.filipebhenriques.quit"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

- [ ] **Step 5: Verify release build**

```bash
flutter build apk --release 2>&1 | tail -20
```

Expected: `Built build/app/outputs/flutter-apk/app-release.apk`. If signing fails, double-check the paths and passwords in `key.properties`.

- [ ] **Step 6: Commit (do NOT include key.properties)**

```bash
git add android/app/build.gradle.kts .gitignore
git commit -m "chore: add release signing config"
```

---

## Self-Review

Checked against spec:

| Spec requirement | Covered by |
|---|---|
| Replace UNBLOCK APP → I WILL DO SOMETHING ELSE + goes home | Task 1 |
| Remove `_launchUnblockedApp` method | Task 1 |
| bonusRefillInterval 1 min → 1 hour | Task 2 |
| Remove 4 print() calls | Task 2 |
| Remove screen_time_api_ios | Task 3 |
| Update app description | Task 3 |
| applicationId com.example.quit → unique ID | Task 4 |
| Kotlin package rename + directory | Task 4 |
| AndroidManifest WATCHDOG action | Task 4 |
| Release signing config | Task 5 |

No placeholders, no TBDs. All code shown in full.
