import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'app_state.dart';

/// The foreground service has no work of its own: it only keeps the app
/// process alive (with a notification) so SSH sessions stay connected while
/// the app is in the background.
@pragma('vm:entry-point')
void foregroundStartCallback() {
  FlutterForegroundTask.setTaskHandler(_IdleHandler());
}

class _IdleHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

class Background {
  bool _running = false;
  Future<void> _chain = Future.value();

  void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'sessions',
        channelName: 'Active sessions',
        channelDescription: 'Keeps SSH sessions connected while the app is in the background.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(showNotification: false, playSound: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Call whenever the number of live sessions changes. Calls are queued so
  /// start/update/stop never overlap.
  void sync(int active, String text) {
    _chain = _chain.then((_) => _apply(active, text)).catchError((_) {});
  }

  Future<void> _apply(int active, String text) async {
    if (active == 0) {
      if (_running) {
        await FlutterForegroundTask.stopService();
        _running = false;
      }
      return;
    }
    final title = active == 1 ? '$appName — 1 session' : '$appName — $active sessions';
    if (_running) {
      await FlutterForegroundTask.updateService(notificationTitle: title, notificationText: text);
      return;
    }
    final perm = await FlutterForegroundTask.checkNotificationPermission();
    if (perm != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    if (!store.askedBatteryOpt && !await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      store.askedBatteryOpt = true;
      await store.saveSettings();
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
    await FlutterForegroundTask.startService(
      serviceId: 4711,
      serviceTypes: [ForegroundServiceTypes.specialUse],
      notificationTitle: title,
      notificationText: text,
      callback: foregroundStartCallback,
    );
    _running = true;
  }
}
