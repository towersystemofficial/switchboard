import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/member.dart';

/// Shows a persistent ("ongoing") notification with the current fronter(s).
///
/// Note: this uses a plain ongoing notification (autoCancel: false, ongoing: true),
/// which Android will keep visible but is not a guaranteed foreground service.
/// If Android kills the app process outright, the notification can disappear
/// until the app is next opened (SystemProvider re-posts it on both cold
/// start and app-resume).
class NotificationService {
  static const int _notificationId = 1001;
  static const String _channelId = 'current_fronter_channel';
  static const String _channelName = 'Current Fronter';
  static const String _channelDescription =
      'Persistent notification showing who is currently fronting.';

  // Importance.defaultImportance (not .low) is deliberate: Android buckets
  // low/min-importance channels as "Silent," and many phones (including
  // stock Android / Pixel) have a "Hide silent notifications in status bar"
  // setting that hides the icon for anything in that bucket, regardless of
  // DND-bypass. Default importance is bucketed as "Alerting" and is exempt
  // from that -- sound/vibration are turned off explicitly below instead,
  // so it still stays silent in practice.
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _channelBypassesDnd = false;

  Future<void> init() async {
    if (_initialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(settings: initSettings);

    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.defaultImportance,
        showBadge: false,
        playSound: false,
        enableVibration: false,
      ),
    );
    _initialized = true;
  }

  /// Requests the OS-level runtime notification permission (Android 13+).
  /// Kept separate from [init] -- which now runs silently on every
  /// startup -- so first-run can explain what it's for before this
  /// actually prompts, instead of the dialog appearing unannounced.
  Future<void> requestNotificationsPermission() async {
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
  }

  /// Whether the app currently has the OS-level "Do Not Disturb access"
  /// permission granted. Check this before/after prompting the user.
  Future<bool> hasDndBypassAccess() async {
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await androidPlugin?.hasNotificationPolicyAccess() ?? false;
  }

  /// Sends the user to the system settings screen where they can grant
  /// "Do Not Disturb access" for this app.
  Future<void> requestDndBypassAccess() async {
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationPolicyAccess();
  }

  /// Applies (or removes) DND-bypass on the notification channel.
  ///
  /// Android locks a channel's DND behaviour in at creation time, so to
  /// actually change it on an already-created channel, the channel has to
  /// be deleted and recreated with the new setting.
  ///
  /// NOTE: `deleteNotificationChannel`'s exact parameter name below
  /// (`channelId:`) is a best guess based on the plugin's changelog (it
  /// says this method moved from a positional to a named parameter in
  /// v20.0.0) but wasn't directly confirmed against the API docs. If the
  /// analyzer flags this line, paste the error back.
  Future<void> setBypassDnd(bool enabled) async {
    if (!_initialized) await init();
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final hasAccess = enabled ? await hasDndBypassAccess() : false;
    final effectiveBypass = enabled && hasAccess;
    if (effectiveBypass == _channelBypassesDnd) return;
    await androidPlugin?.deleteNotificationChannel(channelId: _channelId);
    await androidPlugin?.createNotificationChannel(
      AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.defaultImportance,
        showBadge: false,
        playSound: false,
        enableVibration: false,
        bypassDnd: effectiveBypass,
      ),
    );
    _channelBypassesDnd = effectiveBypass;
  }

  /// Shows one notification summarizing everyone currently fronting.
  /// - Empty list -> clears the notification.
  /// - One member -> "Fronting: Name", large icon = their avatar (if any).
  /// - Multiple members -> "Fronting: Name1, Name2 (+N more)" style title,
  ///   with the full list in the body. No large icon (a composited overlap
  ///   was tried and looked bad cropped down to notification icon size).
  Future<void> showCurrentFronters(
    List<Member> members, {
    String? Function(String?)? avatarPathResolver,
  }) async {
    if (!_initialized) await init();
    if (members.isEmpty) {
      await clear();
      return;
    }

    final names = members.map((m) => m.name).toList();
    String title;
    String? body;

    if (names.length == 1) {
      title = 'Fronting: ${names.first}';
      body = null;
    } else {
      // Keep the title short; overflow into the body if there are many.
      const maxInTitle = 3;
      if (names.length <= maxInTitle) {
        title = 'Fronting: ${names.join(', ')}';
        body = null;
      } else {
        final shown = names.take(maxInTitle).join(', ');
        final remaining = names.length - maxInTitle;
        title = 'Fronting: $shown (+$remaining more)';
        body = names.join(', ');
      }
    }

    AndroidBitmap<Object>? largeIcon;
    if (names.length == 1 && avatarPathResolver != null) {
      final path = avatarPathResolver(members.first.avatarFilename);
      if (path != null && await File(path).exists()) {
        largeIcon = FilePathAndroidBitmap(path);
      }
    }

    final details = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      showWhen: false,
      icon: '@mipmap/ic_launcher',
      largeIcon: largeIcon,
    );

    // Cancel first so Android fully re-renders the notification (icon
    // included) instead of potentially patching/caching over the previous
    // one posted under the same ID.
    await _plugin.cancel(id: _notificationId);
    await _plugin.show(
      id: _notificationId,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: details),
    );
  }

  Future<void> clear() async {
    await _plugin.cancel(id: _notificationId);
  }
}