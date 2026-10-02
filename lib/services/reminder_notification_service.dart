// Schedules local reminder notifications and routes notification-open events.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

/// Manages local notification setup, scheduling, cancellation, and taps.
class ReminderNotificationService {
  ReminderNotificationService._();

  static final ReminderNotificationService instance =
      ReminderNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<String> _openedReminderIds =
      StreamController<String>.broadcast();
  bool _initialized = false;
  bool? _permissionGranted;
  String? _pendingReminderId;

  /// Broadcasts reminder IDs opened from local notifications.
  Stream<String> get openedReminderIds => _openedReminderIds.stream;

  /// Initializes timezone/plugin state and checks whether notifications are allowed.
  Future<bool> initialize() async {
    await _ensureInitialized();
    _permissionGranted = await _notificationsAllowed();
    return _permissionGranted!;
  }

  /// Requests notification permission using the current platform's permission API.
  Future<bool> requestPermission() async {
    await _ensureInitialized();
    if (kIsWeb) {
      _permissionGranted = false;
      return false;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      _permissionGranted =
          await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
      return _permissionGranted!;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      _permissionGranted =
          await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
      return _permissionGranted!;
    }
    _permissionGranted = true;
    return true;
  }

  /// Schedules a local alert with customer details and a stable reminder ID.
  Future<bool> schedule({
    required String reminderId,
    required String customerName,
    required String customerMobile,
    required String customerAddress,
    required DateTime scheduledAt,
    required DateTime notifyAt,
  }) async {
    await _ensureInitialized();
    if (_permissionGranted == false) return false;
    if (!await _notificationsAllowed()) return false;

    final now = DateTime.now();
    final actualNotifyTime = notifyAt.isAfter(now)
        ? notifyAt
        : now.add(const Duration(seconds: 3));
    final customerDetails = [
      customerName,
      if (customerMobile.isNotEmpty) customerMobile,
      if (customerAddress.isNotEmpty) customerAddress,
    ].join(' · ');
    await _plugin.zonedSchedule(
      id: _notificationId(reminderId),
      title: 'PetCare reminder',
      body: '$customerDetails · ${_formatDateTime(scheduledAt)}',
      scheduledDate: timezone.TZDateTime.from(actualNotifyTime, timezone.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'petcare_reminders',
          'PetCare reminders',
          channelDescription: 'Alerts for upcoming customer reminders',
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: reminderId,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    return true;
  }

  /// Cancels the scheduled local notification associated with a reminder.
  Future<void> cancel(String reminderId) async {
    await _ensureInitialized();
    await _plugin.cancel(id: _notificationId(reminderId));
  }

  /// Initializes the local notification plugin once before it is used.
  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    timezone_data.initializeTimeZones();
    final localTimezone = await FlutterTimezone.getLocalTimezone();
    final identifier = localTimezone.identifier == 'Asia/Calcutta'
        ? 'Asia/Kolkata'
        : localTimezone.identifier;
    timezone.setLocalLocation(timezone.getLocation(identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final initialPayload = launchDetails?.notificationResponse?.payload;
    if (launchDetails?.didNotificationLaunchApp == true &&
        initialPayload != null &&
        initialPayload.isNotEmpty) {
      _publishOpenedReminder(initialPayload);
    }
    _initialized = true;
  }

  /// Checks the operating system settings to see whether notifications can be shown.
  Future<bool> _notificationsAllowed() async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.areNotificationsEnabled() ??
          false;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.checkPermissions()
              .then((permissions) => permissions?.isEnabled ?? false) ??
          false;
    }
    return true;
  }

  /// Routes a notification tap or action to the corresponding reminder handler.
  void _handleNotificationResponse(NotificationResponse response) {
    final reminderId = response.payload;
    if (reminderId != null && reminderId.isNotEmpty) {
      _publishOpenedReminder(reminderId);
    }
  }

  /// Emits the reminder ID selected from a notification tap.
  void _publishOpenedReminder(String reminderId) {
    if (_openedReminderIds.hasListener) {
      _openedReminderIds.add(reminderId);
    } else {
      _pendingReminderId = reminderId;
    }
  }

  /// Emits a reminder tap that arrived before the screen subscribed to events.
  void deliverPendingReminder() {
    final pendingReminderId = _pendingReminderId;
    if (pendingReminderId == null) return;
    _pendingReminderId = null;
    _openedReminderIds.add(pendingReminderId);
  }

  /// Derives a stable integer notification ID from a reminder ID.
  int _notificationId(String reminderId) {
    var hash = 0x811c9dc5;
    for (final unit in reminderId.codeUnits) {
      hash = (hash ^ unit) * 0x01000193;
    }
    return hash & 0x7fffffff;
  }

  /// Formats a reminder date and time for the notification display.
  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour < 12 ? 'AM' : 'PM';
    return '${local.day}/${local.month}/${local.year} $hour:$minute $period';
  }
}
