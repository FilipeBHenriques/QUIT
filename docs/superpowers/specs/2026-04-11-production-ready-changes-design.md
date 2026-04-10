# Production-Ready Changes — Design Spec
_2026-04-11_

## Scope

Four categories of change to make the app production-ready for Google Play Store:

1. Replace "Unblock App" button with "I Will Do Something Else" (home navigation)
2. Bonus refill interval: 1 minute → 1 hour
3. Fix Android application ID and remove iOS artifacts
4. Polish: remove debug print statements, fix app description

---

## 1. Blocked Screen — Button Change

**File:** `lib/screens/blocked_screen.dart`

**Condition:** The "NORMAL BLOCK" branch (`!_isTotalBlock && !_isTimeLimitExceeded && !_isBonusCooldown`) — shown when an app is permanently blocked (daily limit = 0 min).

**Change:**
- Remove the `_ActionButton(label: 'UNBLOCK APP', onPressed: _launchUnblockedApp, filled: true)` button.
- Replace with `_ActionButton(label: 'I WILL DO SOMETHING ELSE', onPressed: _closeActivity, filled: true, icon: Icons.home_outlined)`.
- `_launchUnblockedApp` method is removed as it is now unused.

**Result:** Tapping the button calls `_closeActivity()` → `navigationChannel.invokeMethod('goHome')` → sends user to Android home screen.

---

## 2. Bonus Refill Interval

**File:** `lib/usage_timer.dart` line 26

**Change:** `Duration(hours: 0, minutes: 1, seconds: 0)` → `Duration(hours: 1)`

This value is written to SharedPreferences as `bonus_refill_interval_seconds` and read by `MonitoringService.kt`. No native-side change needed.

---

## 3. Android Application ID

**File:** `android/app/build.gradle.kts`

**Change:** `applicationId = "com.example.quit"` → `applicationId = "com.filipebhenriques.quit"` (or another unique reverse-domain ID the developer chooses — placeholder used here; must be confirmed).

Also update `namespace = "com.example.quit"` to match.

**Note:** Changing the application ID requires updating all Kotlin source files that reference the old package name via `import com.example.quit.*`. After renaming, the directory structure under `android/app/src/main/kotlin/` should also reflect the new package.

---

## 4. Remove iOS Dependency

**File:** `pubspec.yaml`

**Change:** Remove `screen_time_api_ios: ^0.0.4` from dependencies. This is an iOS-only package unused in the Android build.

---

## 5. Release Signing

**File:** `android/app/build.gradle.kts`

**Change:** Replace `signingConfig = signingConfigs.getByName("debug")` with a proper release signing config referencing a keystore file. The keystore file and credentials are outside this spec — the developer must generate/provide them.

---

## 6. Cleanup

**Files:** `lib/usage_timer.dart`, `pubspec.yaml`

- Remove 4 `print()` calls from `usage_timer.dart` (lines 75, 81–83, 141, 165).
- Update `pubspec.yaml` description from `"A new Flutter project."` to `"QUIT - App Blocker"`.

---

## Out of Scope (listed for future work)

- `_blockingMode` toggle in `apps_tab.dart` has no effect (not wired to MonitoringService).
- `MonitoringService.kt` contains many `Log.d()` debug lines.
- Release signing keystore setup (developer action required outside code).
