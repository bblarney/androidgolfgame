# Releasing Birdie Blitz to the Google Play Store

This is the checklist for cutting an Android release. The repo already has the in-project pieces
wired up (app version, icon, boot splash, and a starter `export_presets.cfg`). The steps below are
the ones that need the Godot editor's tooling, a Google account, or your sign-off.

> Launch model: **free, no ads, no in-app purchases, no data collection.** Keep it that way and
> the Play policy work stays minimal.

## What's already done in the repo
- `project.godot`: `config/version="1.0.0"`, description, `config/icon`, and a branded boot splash.
- `assets/icon.svg`: launcher icon (golf ball + flag on brand blue).
- `assets/android/icon_foreground.svg` + `icon_background.svg`: adaptive icon layers.
- `assets/splash.png`: boot splash logo (rendered; `assets/splash.svg` is the editable source).
- `export_presets.cfg` (gitignored): Android preset — package `com.brett.birdieblitz`,
  versionCode 1, min SDK 21, target SDK 35, arm64-v8a + armeabi-v7a, **no permissions**, AAB
  output, icons wired. **Signing is left blank for you (step 2).**

## One-time setup

### 1. Tooling
- Install **JDK 17** and the **Android SDK** (Android Studio or command-line tools).
- In Godot: **Editor → Editor Settings → Export → Android** — set the Android SDK path and the
  debug keystore (Godot can auto-create the debug one).
- **Editor → Manage Export Templates** — download the 4.6 export templates if not present.
- **Project → Install Android Build Template** (required because the preset uses Gradle build).

### 2. Create a RELEASE keystore — and never lose it
Losing this key means you can permanently lose the ability to update the app.
```
keytool -genkey -v -keystore birdieblitz-release.keystore \
  -alias birdieblitz -keyalg RSA -keysize 2048 -validity 10000
```
- Store the `.keystore` file and its passwords somewhere safe and backed up.
- **Do not commit it** (it's covered by `.gitignore` patterns; double-check).
- In **Project → Export → Android**, fill in the **Release** keystore path, alias, and passwords.

### 3. Confirm app identity
- **Package name**: `com.brett.birdieblitz` is a placeholder. Pick your final reverse-domain id —
  it is **permanent** once published. Update it in the export preset.
- On every new upload, bump `version/code` (integer) and usually `version/name` /
  `project.godot config/version`.

## Per-release build

### 4. Export the signed AAB
- **Project → Export → Android**, ensure **Use Gradle Build** is on and **Export Format = AAB**.
- **Export Project** → `build/birdie-blitz.aab` (Play requires an App Bundle, not an APK).
- For quick on-device testing you can also export an **APK** and sideload it.

### 5. Verify on a real device
- Sideload the APK (or use Play internal testing).
- Confirm: portrait lock; drag-to-shoot works by touch; audio plays; a round **saves and survives
  an app kill + relaunch**; the custom **launcher icon** and **boot splash** appear.

## Google Play Console (one-time + per release)

### 6. Account & app
- Register a Play Console developer account (**$25 one-time fee**).
- Create the app: type = Game, free, default language.

### 7. App content / policy declarations
- **Privacy policy**: host `STORE/privacy-policy.md` publicly and paste the URL.
- **Data safety**: declare **no data collected and no data shared** (true for this app).
- **Ads**: **No ads**.
- **Content rating**: complete the IARC questionnaire (golf → expect "Everyone").
- **Target audience**, **Government apps**, **Financial features**: answer truthfully (all No /
  general audience).

### 8. Store listing
- Fill name, short + full description from `STORE/listing.md`.
- Upload: **512×512 icon** (render from `assets/icon.svg`), **1024×500 feature graphic** (needs a
  wordmark — design separately), and **≥2 phone screenshots** (shot-list in `STORE/listing.md`).

### 9. Release
- Upload the AAB to the **Internal testing** track first; add yourself as a tester; install and
  smoke-test from the Play link.
- When happy, promote to **Production** with a **staged rollout**.

## Optional polish before launch
- A designed **splash.png** with the "Birdie Blitz" wordmark. The current `assets/splash.png` (the
  boot image; `splash.svg` is its editable source) is text-free because the boot splash only
  supports PNG and Godot's SVG importer doesn't render text reliably. Re-render or replace
  `assets/splash.png` to add a wordmark.
- A custom-designed launcher icon (drop-in replace the `assets/*.svg` files).
- Feature graphic artwork.
