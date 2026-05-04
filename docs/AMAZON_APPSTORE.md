# Amazon Appstore Submission Guide

## Prerequisites

- Amazon Developer account: https://developer.amazon.com
- Release APK (see `scripts/build-apk-release.ps1`)
- App assets (icons, screenshots)

## Required Assets

### Icons
| Size | File | Purpose |
|------|------|---------|
| 512x512 | `icon-512.png` | App icon (Google Play / Amazon) |
| 1280x720 | `banner-1280x720.png` | Fire TV banner |
| 48x48 to 192x192 | `mipmap-*/ic_launcher.png` | App launcher icons |

### Screenshots
- Minimum 3 screenshots
- Resolution: 1920x1080 (Fire TV)
- Show the app in action (streaming, settings, connection)

## Submission Checklist

- [ ] APK is signed with release keystore (not debug)
- [ ] `AndroidManifest.xml` includes `LEANBACK_LAUNCHER` category
- [ ] App supports D-Pad navigation (no touch required)
- [ ] No unnecessary permissions in manifest
- [ ] App title and description in English and Spanish
- [ ] Privacy policy URL (can be GitHub repo README)

## Manifest Requirements

```xml
<manifest>
    <uses-feature android:name="android.software.leanback" android:required="true" />
    <uses-feature android:name="android.hardware.touchscreen" android:required="false" />
    
    <application
        android:banner="@drawable/banner"
        android:label="Emiscreen">
        
        <activity android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LEANBACK_LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
```

## Category

- **Primary**: Apps & Games
- **Secondary**: Utilities or Productivity

## Testing on Fire TV

Before submission, test on real Fire TV hardware:
1. D-Pad navigation works throughout the app
2. App launches from home screen
3. No crashes on orientation changes
4. Proper handling of back button

## Approval Timeline

Amazon Appstore review typically takes 3-5 business days.
