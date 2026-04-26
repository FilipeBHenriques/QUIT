# Google Play Data Safety Worksheet

Last updated: 2026-04-26

This is a draft worksheet for Play Console. Final answers must match the release build, current SDK behavior, and your AdMob configuration.

## Likely Data Categories Involved

### Data used by the app's core features

- App activity
  - foreground app detection
  - blocking and usage tracking behavior
- Web browsing
  - blocked website or domain detection in supported browsers
- App info and performance
  - possible diagnostics or crash information

### Data likely involved through AdMob

- Device or other identifiers
- Advertising or diagnostics-related data

## App Data Stored Locally

The app appears to store these items locally on-device:

- blocked apps
- blocked websites
- timing preferences
- in-app stats and progress data

## First-Pass Submission Guidance

These are working assumptions, not final legal answers:

- Does the app collect data
  - likely `Yes`, especially because AdMob may collect identifiers or diagnostics
- Is any data shared
  - likely `Yes`, at least through AdMob or service-provider advertising flows
- Is all data encrypted in transit
  - confirm against the final release behavior and SDK behavior
- Can users request deletion
  - local app data can be removed by clearing app storage or uninstalling the app

## What To Verify Before Submission

- your exact AdMob ad settings
- whether you use personalized ads
- whether you add a consent flow
- the current Google Mobile Ads SDK disclosure expectations
- the exact data categories shown in Play Console at submission time

## Important Note

Do not paste this file into Play Console without checking it against the live release app and current Google documentation.
