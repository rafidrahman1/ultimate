# Play Store release checklist

Build: `flutter build appbundle --release` -> `build/app/outputs/bundle/release/app-release.aab`
(signed via `android/key.properties`; back up `~/.android-keys/personal-release.jks` and its passwords, losing it blocks updates unless Play App Signing is enrolled).

Before every upload bump `version:` in `pubspec.yaml` (`1.0.0+2`: the number after `+` is the versionCode and must increase).

## Play Console
- App id `com.powern.motohealth` is permanent once published.
- Enrol in Play App Signing (the .aab is your upload key).
- Privacy policy URL: host `docs/privacy-policy.md` publicly (GitHub Pages / gist) and paste the link.
- Data safety form: no data collected by the developer. Mention that the optional AI feature sends user-chosen content to a third-party provider the user configures with their own key.
- Content rating questionnaire, target audience (18+ / not for children), ads: none.
- Store listing: short description (80 chars), full description (README "What it does"), 512x512 icon, 1024x500 feature graphic, 2-8 phone screenshots.
- New personal developer accounts must run a closed test with 12+ testers for 14 days before production access.
