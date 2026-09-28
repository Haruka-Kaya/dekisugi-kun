import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/reminder.dart';
import 'session_store.dart';

/// 端末の中だけで完結する通知。
///
/// > [!important] FCM を持たない
/// > サーバからの push はトークン管理と端末識別子の保存が増え、
/// > 「個人を特定しない」設計と保護者向けの同意文面に波及する。
/// > ローカルなら端末内で完結し、越境移転の話にならない。
///
/// ## 開くたびに立て直す
///
/// 文面は「考査まであと何日」「残り何つ」で変わるので、
/// 予約時に固定した文言は翌日には古くなる。
/// **繰り返し予約は使わず、開くたびに次の1件だけ立て直す。**
/// 何日も開かなければ通知も止まるが、それは正しい —
/// 何週間も来ていない生徒に毎晩「あと3つ」と送り続ける方がおかしい。
class Reminders {
  Reminders({
    required SessionStore store,
    FlutterLocalNotificationsPlugin? plugin,
  }) : // 公開constructorの`store:`名を保つ。
       // ignore: prefer_initializing_formals
       _store = store,
       _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final SessionStore _store;
  final FlutterLocalNotificationsPlugin _plugin;

  static const String _kEnabled = 'reminder.enabled';
  static const String _kHour = 'reminder.hour';

  /// 通知の識別子。**1つしか使わない**（1日1通の上限を仕組みで担保する）
  static const int _id = 1;

  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    // **`initializeTimeZones()` だけでは `tz.local` は UTC のまま。**
    // 設定しないと、20:00 のつもりの予約が翌朝5時に立つ（実機で確認）。
    // 端末のずれから当てる — 名前を取る API が Flutter に無いため
    _setLocalFromDeviceOffset();
    await _plugin.initialize(
      const InitializationSettings(
        // 通知のsmall iconは透明背景の単色シルエットだけを使う。
        // 全面不透明のランチャー画像だと、通知欄では四角い塊になる。
        android: AndroidInitializationSettings(
          '@drawable/ic_launcher_monochrome',
        ),
        iOS: DarwinInitializationSettings(
          // **起動時に権限を求めない。** 文脈のある場面で聞く
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  /// 端末の UTC ずれに合う場所を選ぶ。
  ///
  /// `timezone` は名前（`Asia/Tokyo`）でしか引けないが、
  /// Flutter には端末のタイムゾーン名を取る標準の口が無い。
  /// **ずれが合っていれば予約の時刻は正しく出る**ので、
  /// 同じずれを持つ場所のどれかに合わせれば足りる。
  static void _setLocalFromDeviceOffset() {
    final offset = DateTime.now().timeZoneOffset;
    for (final loc in tz.timeZoneDatabase.locations.values) {
      final here = tz.TZDateTime.now(loc);
      if (here.timeZoneOffset == offset) {
        tz.setLocalLocation(loc);
        return;
      }
    }
    // 見つからなければ UTC のまま。**時刻はずれるが落ちはしない**
    debugPrint('端末のタイムゾーンに合う場所が見つからなかった');
  }

  Future<bool> isEnabled() async => (await _store.getSetting(_kEnabled)) == '1';

  Future<int> hour() async =>
      int.tryParse(await _store.getSetting(_kHour) ?? '') ??
      kDefaultReminderHour;

  Future<void> setHour(int h) async {
    await _store.setSetting(_kHour, h.clamp(0, 23).toString());
  }

  /// 通知を使うか。**切ったら予約も消す。**
  Future<void> setEnabled(bool on) async {
    await _store.setSetting(_kEnabled, on ? '1' : null);
    if (!on) await cancel();
  }

  /// OS に許可を求める。**初回の会話を終えた直後に呼ぶ。**
  ///
  /// 同意画面では聞かない。あそこで一緒に聞くと、
  /// 何のための許可か分からないまま押させることになる。
  Future<bool> requestPermission() async {
    await _init();
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        return await ios.requestPermissions(alert: true, sound: true) ?? false;
      }
    } catch (e) {
      debugPrint('通知の許可を求められなかった: $e');
    }
    return false;
  }

  Future<void> cancel() async {
    await _init();
    try {
      await _plugin.cancel(_id);
    } catch (e) {
      debugPrint('通知の取り消しに失敗: $e');
    }
  }

  /// 次の1件を立て直す。**通知が要らない状態なら消して終わる。**
  ///
  /// 失敗しても何も止めない。通知はアプリの付随物で、
  /// これが動かなくても学習は続く。
  Future<void> reschedule(ReminderState state, {DateTime? now}) async {
    if (!await isEnabled()) return;
    final text = reminderText(state);
    if (text == null) {
      // 送る用が無い日は**黙る**。毎日必ず届く設計にしない
      await cancel();
      return;
    }

    await _init();
    try {
      await _plugin.cancel(_id);
      await _plugin.zonedSchedule(
        _id,
        kReminderTitle,
        text,
        _nextAt(await hour(), now ?? DateTime.now()),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'reminder',
            'まいにちの声かけ',
            channelDescription: '考査までに残っているところを1日1回だけ知らせます。',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('通知を立てられなかった: $e');
    }
  }

  /// 初回CLEARの直後、本人が望んだ場合だけ翌日のCASEを1件予約する。
  ///
  /// Homeの状態をまだ読み直していなくても、アプリを閉じる前に次の学習行為へ
  /// 橋をかけられる。次回Homeを開けば通常の[reschedule]が同じIDへ上書きする。
  Future<void> scheduleTomorrowCase(
    String conceptLabel, {
    DateTime? now,
  }) async {
    if (!await isEnabled()) return;
    await _init();
    try {
      await _plugin.cancel(_id);
      await _plugin.zonedSchedule(
        _id,
        kReminderTitle,
        missionFollowUpText(conceptLabel),
        _tomorrowAt(await hour(), now ?? DateTime.now()),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'reminder',
            'まいにちの声かけ',
            channelDescription: '考査までに残っているところを1日1回だけ知らせます。',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('翌日のCASE通知を立てられなかった: $e');
    }
  }

  /// 次にその時刻が来る瞬間。きょうの分を過ぎていれば明日。
  static tz.TZDateTime _nextAt(int hour, DateTime now) {
    final local = tz.local;
    final n = tz.TZDateTime.from(now, local);
    var at = tz.TZDateTime(local, n.year, n.month, n.day, hour);
    if (!at.isAfter(n)) at = at.add(const Duration(days: 1));
    return at;
  }

  static tz.TZDateTime _tomorrowAt(int hour, DateTime now) {
    final local = tz.local;
    final n = tz.TZDateTime.from(now, local);
    return tz.TZDateTime(local, n.year, n.month, n.day + 1, hour);
  }
}
