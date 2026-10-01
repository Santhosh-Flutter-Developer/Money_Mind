import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../../domain/entities/entities.dart';

/// Local notifications on Android/iOS. On web/desktop the same reminders are
/// shown inside the app (Notifications screen) because OS scheduling is unavailable.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  bool get supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> init() async {
    if (!supported) return;
    try {
      tzdata.initializeTimeZones();
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _plugin.initialize(settings);
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  Future<void> reschedule(List<Reminder> reminders) async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
      const details = NotificationDetails(
        android: AndroidNotificationDetails('moneymind_reminders', 'MoneyMind reminders',
            importance: Importance.high, priority: Priority.high),
        iOS: DarwinNotificationDetails(),
      );
      final now = DateTime.now();
      final upcoming = reminders.where((r) => r.when.isAfter(now)).take(60).toList();
      var id = 1;
      for (final r in upcoming) {
        await _plugin.zonedSchedule(
          id++,
          r.title,
          r.body,
          tz.TZDateTime.from(r.when, tz.local),
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    } catch (_) {/* reminders are best-effort */}
  }
}
