# SwitchBoard

SwitchBoard is a personal, local-first system tracker built with Flutter. It supports member profiles, co-fronting and fronting history, groups, customization, statistics, notifications, and an optional read-only local API.

## Local-first storage

SwitchBoard stores your data as plain Markdown, CSV, image, and configuration files inside a `FronterLog` folder in a directory you choose:

```text
<chosen-folder>/FronterLog/
  members/
  groups/
  avatars/
  sounds/
  AboutSystem.md
  config.md
  fronting_log.csv
  Fronting Log.md
```

The chosen directory can be an Obsidian vault, but Obsidian is optional. Any accessible folder works. Because the files use ordinary formats, you remain in control of viewing, backing up, syncing, moving, and deleting them.

System-tracking data stays on your device unless you independently place the chosen folder in a synced location. SwitchBoard has two explicit network features:

- The optional Local API, disabled by default, exposes read-only system data to devices on your local network while it is running. It does not currently require authentication, so only enable it on a trusted network.
- The optional Support & Contact form sends the subject, message, and any reply email you choose to provide to Web3Forms so the developer can receive your feedback. Nothing is sent until you press **Send**.

See the in-app Privacy Policy for details.

## Development setup

### Requirements

- Flutter with a compatible Dart SDK
- Android toolchain for Android development

Check your environment with:

```bash
flutter doctor
```

### Run the app

```bash
flutter pub get
flutter run
```

Choose a connected device or emulator when prompted. On first launch, SwitchBoard asks you to select the folder where its `FronterLog` data directory should live.

If platform scaffolding is missing from a source-only copy, generate it without replacing the existing Dart source:

```bash
flutter create . --project-name fronter_log --org com.yourname
```

Android builds require the permissions used by the app's enabled features, including storage access, notifications, image selection, and networking for the Local API and optional support form. The current platform project should be treated as the source of truth for its configured manifest and minimum SDK.

## Privacy and security notes

- SwitchBoard has no user accounts, advertising, or built-in analytics.
- You are responsible for backing up the selected data folder.
- The Local API has no authentication and should not be exposed to untrusted networks or the public internet.
- Sending feedback is optional and transmits only the form fields you submit through Web3Forms.

## Current limitations

- The persistent current-fronter notification is an ongoing notification rather than a true foreground service. Android may stop it under aggressive battery optimization.
- Desktop targets require platform-specific testing even though the main application is written in Flutter.
- The Local API is intended for trusted local use and does not yet provide authentication.
