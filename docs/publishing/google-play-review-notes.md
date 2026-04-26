# Google Play Review Notes

## App Summary

QUIT is a self-control and focus app. The user chooses which apps and websites to block, and QUIT shows a blocking screen when the user tries to open blocked content.

## Accessibility Declaration Summary

QUIT uses Android Accessibility Service as a core feature to detect supported browser website visits and certain foreground transitions needed to block user-selected apps and websites in real time.

The Accessibility Service is not used for advertising, profiling, or selling user data. It is used only to provide the app's core blocking functionality that the user intentionally enables.

## Why Accessibility Is Needed

- detect supported browser URL or domain changes for website blocking
- detect transitions needed to trigger the blocking screen with low delay
- support the app's core blocking workflow selected by the user

## Why Usage Access Is Needed

- detect foreground app usage
- support app blocking and time-based tracking

## Why Overlay Permission Is Needed

- display the blocking screen above blocked apps and blocked websites

## User Control

- the user chooses which apps and websites to block
- the user manually grants the required permissions
- the user can disable permissions at any time in Android settings
- the user can edit or remove blocked apps and blocked websites in the app

## Privacy Summary

- the app works primarily on-device
- blocked apps, blocked websites, and app state are stored locally
- the app uses Google AdMob for advertising

## Reviewer Test Flow

1. Install and open QUIT.
2. Grant Usage Access, Accessibility Service, and Display Over Other Apps when prompted.
3. Add one or more apps to the blocked list.
4. Add one or more websites to the blocked list.
5. Open a blocked app or browse to a blocked website in a supported browser.
6. Confirm that QUIT shows the blocking screen.

## Supported Browser Note

Website blocking depends on accessibility-readable address bars in supported browsers and may vary by browser and browser version.
