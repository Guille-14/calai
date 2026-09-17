import '../../core/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../../core/utils/date_key.dart';
import 'database_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  static const String _enabledKey = 'notifications_enabled';
  static const String _quietHoursKey = 'quiet_hours';
  static const String _reminderTimesKey = 'reminder_times';
  static const String _goalsKey = 'notification_goals';

  Future<void> initialize() async {
    if (_isInitialized) return;

    tz_data.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _isInitialized = true;
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
  }

  Future<bool> requestPermissions() async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  Future<void> scheduleSmartNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_enabledKey) ?? true;

    if (!enabled) {
      await cancelAllNotifications();
      return;
    }

    final quietHours = _QuietHours.parse(prefs.getString(_quietHoursKey));
    final reminderTimes =
        prefs.getStringList(_reminderTimesKey) ?? ['08:00', '13:00', '19:00'];
    final goalsEnabled =
        prefs.getStringList(_goalsKey) ?? ['calories', 'water'];

    await cancelAllNotifications();

    await _scheduleMealReminders(reminderTimes, quietHours);
    await _scheduleGoalReminders(goalsEnabled, quietHours);
    await _scheduleMotivationalNotifications();
  }

  /// Antes hacía `int.parse(parts[0])` sin validar: una preferencia corrupta
  /// lanzaba FormatException y bloqueaba el arranque de la app.
  Future<void> _scheduleMealReminders(
      List<String> times, _QuietHours? quiet) async {
    for (int i = 0; i < times.length; i++) {
      final timeOfDay = _parseHHMM(times[i]);
      if (timeOfDay == null) {
        debugPrint('NotificationService: hora inválida "${times[i]}", se omite');
        continue;
      }
      if (_isInQuietHours(timeOfDay, quiet)) continue;

      await _scheduleDailyNotification(
        id: 100 + i,
        title: '🍽️ Hora de registrar tu comida',
        body: _getMealReminderMessage(i),
        hour: timeOfDay.$1,
        minute: timeOfDay.$2,
      );
    }
  }

  static (int, int)? _parseHHMM(String value) {
    final parts = value.trim().split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return (h, m);
  }

  static bool _isInQuietHours((int, int) time, _QuietHours? quiet) {
    if (quiet == null) return false;
    final minutes = time.$1 * 60 + time.$2;
    if (quiet.startMinutes == quiet.endMinutes) return false;
    if (quiet.startMinutes < quiet.endMinutes) {
      return minutes >= quiet.startMinutes && minutes < quiet.endMinutes;
    }
    // Ventana que cruza medianoche (p.ej. 22:00-08:00)
    return minutes >= quiet.startMinutes || minutes < quiet.endMinutes;
  }

  String _getMealReminderMessage(int mealIndex) {
    const messages = [
      '¿Ya registraste el desayuno? ¡Empieza bien el día!',
      '¿Ya comiste? No olvides registrar tu almuerzo',
      'Hora de cenar. Registra lo que comiste hoy',
    ];
    return messages[mealIndex % messages.length];
  }

  Future<void> _scheduleGoalReminders(
      List<String> goals, _QuietHours? quiet) async {
    if (goals.contains('calories')) {
      if (_isInQuietHours((18, 0), quiet)) return;
      await _scheduleDailyNotification(
        id: 200,
        title: '🔥 Control de Calorías',
        body: 'Recuerda revisar cuántas kcal has consumido hoy',
        hour: 18,
        minute: 0,
      );
    }

    if (goals.contains('water')) {
      if (!_isInQuietHours((14, 0), quiet)) {
        await _scheduleDailyNotification(
          id: 201,
          title: '💧 Hidratación',
          body: '¿Has bebido suficiente agua hoy?',
          hour: 14,
          minute: 0,
        );
      }
    }

    if (goals.contains('protein')) {
      if (_isInQuietHours((21, 0), quiet)) return;
      await _scheduleDailyNotification(
        id: 202,
        title: '💪 Proteína',
        body: 'Revisa tu consumo de proteína today',
        hour: 21,
        minute: 0,
      );
    }
  }

  Future<void> _scheduleMotivationalNotifications() async {
    final motivationalMessages = [
      ('🌟', 'Cada comida cuenta. ¡Sigue así!'),
      ('💪', 'Tu cuerpo te agradecerá'),
      ('🥗', 'La nutrición es la base de todo'),
      ('⚡', 'Pequeños pasos, grandes cambios'),
      ('🎯', 'Hoy es un buen día para cumplir tus metas'),
    ];

    final now = DateTime.now();
    for (int i = 0; i < motivationalMessages.length; i++) {
      final dayOffset = i * 2;
      final scheduledDate = now.add(Duration(days: dayOffset, hours: 10));

      await _scheduleNotification(
        id: 300 + i,
        title: motivationalMessages[i].$1,
        body: motivationalMessages[i].$2,
        scheduledDate: scheduledDate,
      );
    }
  }

  Future<void> _scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_channel',
          'Notificaciones Diarias',
          channelDescription: 'Recordatorios diarios de nutrición',
          importance: Importance.high,
          priority: Priority.high,
          color: AppColors.accent,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tzDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'motivation_channel',
          'Motivación',
          channelDescription: 'Mensajes motivacionales',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> showInstantNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'instant_channel',
          'Notificaciones Instantáneas',
          channelDescription: 'Notificaciones inmediatas',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  Future<void> showGoalAchievedNotification(
      double calories, double goal) async {
    final percentage = ((calories / goal) * 100).round();

    await showInstantNotification(
      title: '🎉 ¡Objetivo alcanzado!',
      body: 'Has consumido el $percentage% de tu objetivo calórico diario',
      payload: 'goal_achieved',
    );
  }

  Future<void> showWaterReminderNotification(int glasses, int goal) async {
    await showInstantNotification(
      title: '💧 Recordatorio de Hidratación',
      body: 'Has bebido $glasses de $goal vasos de agua hoy',
      payload: 'water_reminder',
    );
  }

  Future<void> showWeeklySummaryNotification(
      Map<String, dynamic> summary) async {
    final avgCalories = summary['avgCalories'] ?? 0;
    final daysOnGoal = summary['daysOnGoal'] ?? 0;
    final totalMeals = summary['totalMeals'] ?? 0;

    await showInstantNotification(
      title: '📊 Resumen Semanal',
      body:
          'Promedio: ${avgCalories.toInt()} kcal | $daysOnGoal días en objetivo | $totalMeals comidas',
      payload: 'weekly_summary',
    );
  }

  Future<void> analyzeAndNotify() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    // El registro diario ya vive en SQLite (tabla food_entries, indexada
    // por fecha): se lee vía DatabaseService en vez de la clave
    // food_log_ de SharedPreferences.
    final rows = await DatabaseService().getFoodEntriesBetween(now, now);
    if (rows.isEmpty) return;

    final totalCalories = rows.fold(
        0.0, (sum, r) => sum + ((r['calories'] as num?)?.toDouble() ?? 0));
    final goal = prefs.getDouble('calorie_goal') ?? 2000;

    if (totalCalories >= goal * 0.9 && totalCalories <= goal * 1.1) {
      await showGoalAchievedNotification(totalCalories, goal);
    }

    final waterGlasses =
        prefs.getInt('water_glasses_${formatDateKey(now)}') ?? 0;
    if (waterGlasses < 4 && now.hour >= 14) {
      await showWaterReminderNotification(waterGlasses, 8);
    }
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
    if (enabled) {
      await scheduleSmartNotifications();
    } else {
      await cancelAllNotifications();
    }
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? true;
  }

  Future<void> setReminderTimes(List<String> times) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_reminderTimesKey, times);
    await scheduleSmartNotifications();
  }

  Future<List<String>> getReminderTimes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_reminderTimesKey) ??
        ['08:00', '13:00', '19:00'];
  }

  Future<void> setQuietHours(String start, String end) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_quietHoursKey, '$start-$end');
    await scheduleSmartNotifications();
  }

  Future<Map<String, String>> getQuietHours() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_quietHoursKey) ?? '22:00-08:00';
    final parts = value.split('-');
    if (parts.length < 2) return {'start': '22:00', 'end': '08:00'};
    return {'start': parts[0], 'end': parts[1]};
  }

  Future<void> setGoalNotifications(List<String> goals) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_goalsKey, goals);
    await scheduleSmartNotifications();
  }

  Future<List<String>> getGoalNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_goalsKey) ?? ['calories', 'water'];
  }
}

/// Ventana de silencio ("HH:MM-HH:MM") respetada al programar recordatorios.
/// Antes se leía de preferencias pero jamás se aplicaba.
class _QuietHours {
  final int startMinutes;
  final int endMinutes;

  const _QuietHours(this.startMinutes, this.endMinutes);

  static _QuietHours? parse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split('-');
    if (parts.length != 2) return null;
    final start = _minutes(parts[0]);
    final end = _minutes(parts[1]);
    if (start == null || end == null) return null;
    return _QuietHours(start, end);
  }

  static int? _minutes(String value) {
    final p = value.trim().split(':');
    if (p.length != 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return h * 60 + m;
  }
}
