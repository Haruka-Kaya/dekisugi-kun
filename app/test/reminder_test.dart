import 'dart:io';

import 'package:dekisugi/models/reminder.dart';
import 'package:flutter_test/flutter_test.dart';

/// **通知は一次調査が存在しない領域。**
///
/// 使える一次データが1つも無いので、増やす余地を作らず下げる余地だけ持つ。
/// ここのテストは「増やす方向の変更」を落とすためにある。
void main() {
  ReminderState state({
    int? daysLeft,
    int remaining = 3,
    int dueCount = 0,
    int graceLeft = 2,
    bool doneToday = false,
    bool restDay = false,
  }) => ReminderState(
    daysLeft: daysLeft,
    remaining: remaining,
    dueCount: dueCount,
    graceLeft: graceLeft,
    doneToday: doneToday,
    restDay: restDay,
  );

  group('送らない場面', () {
    test('きょうの分が終わっていれば送らない', () {
      // 終わったのに通知が来るのは、見ていないと言われているのと同じ
      expect(reminderText(state(doneToday: true)), isNull);
    });

    test('考査の前日と当日は送らない', () {
      // その日に学習アプリを開かせない
      expect(reminderText(state(restDay: true, daysLeft: 1)), isNull);
      expect(reminderText(state(restDay: true, daysLeft: 0)), isNull);
    });

    test('用が無ければ送らない', () {
      // 毎日必ず届く設計にしない
      expect(reminderText(state(remaining: 0, dueCount: 0)), isNull);
    });

    test('猶予の残りだけでは呼び出さない', () {
      // 「使わずに済ませる」ための情報であって、呼び出す理由ではない
      expect(
        reminderText(state(remaining: 0, dueCount: 0, graceLeft: 0)),
        isNull,
      );
    });
  });

  group('文面', () {
    test('翌日CASEは次の学習行為だけを伝える', () {
      final text = missionFollowUpText('落下の速さ');
      expect(text, '「落下の速さ」を、別の場面でたしかめる日です。');
      for (final banned in ['連続', '失う', '待って', 'さびし', '今すぐ']) {
        expect(text.contains(banned), isFalse);
      }
    });

    test('考査が入っていれば残り日数と残り数を出す', () {
      expect(
        reminderText(state(daysLeft: 12, remaining: 3)),
        '考査まであと12日。まだ説明していないところが3つあります。',
      );
    });

    test('考査が無ければ残っているものだけ言う', () {
      expect(reminderText(state(remaining: 2)), 'まだ説明していないところが2つあります。');
    });

    test('説明し終えていれば復習を案内する', () {
      expect(
        reminderText(state(remaining: 0, dueCount: 4)),
        'もう一度見るところが4件あります。',
      );
    });

    test('主語が「進捗の事実」で、キャラの個人的な言葉にならない', () {
      // 罪悪感で動かす設計は C5/C6 の思想と正面から衝突する。
      // 「デキすぎ君が待っています」は**事実ではない**ので、
      // アプリが嘘を言うことになる
      const banned = ['待って', 'さびし', '会いたい', 'ぼく', 'わたし', '悲し', '残念'];
      for (final s in [
        reminderText(state(daysLeft: 3)),
        reminderText(state(remaining: 1)),
        reminderText(state(remaining: 0, dueCount: 2)),
      ]) {
        expect(s, isNotNull);
        for (final w in banned) {
          expect(s!.contains(w), isFalse, reason: '「$w」が入っている: $s');
        }
      }
    });

    test('見出しはアプリ名だけ。煽らない', () {
      expect(kReminderTitle, 'デキすぎ君');
      for (final w in ['！', '!', 'いま', '今すぐ']) {
        expect(kReminderTitle.contains(w), isFalse);
      }
    });
  });

  group('増やす余地を作らない', () {
    test('1日1通で固定', () {
      expect(kMaxNotificationsPerDay, 1);
    });

    test('通知は1つの識別子しか使わない（仕組みで上限を担保する）', () {
      // 識別子を増やせば同じ日に何通でも立てられてしまう。
      // **数を数える実装ではなく、立てられる場所を1つにする**
      final src = File('lib/services/reminders.dart').readAsStringSync();
      final ids = RegExp(r'static const int _id = (\d+)').allMatches(src);
      expect(ids, hasLength(1));
      expect(
        src.contains('periodicallyShow'),
        isFalse,
        reason: '繰り返し予約は文面が古くなるので使わない',
      );
    });

    test('考査が近くても文面は増えない', () {
      // 「あと1日」でも通知は1通のまま
      final near = reminderText(state(daysLeft: 1, remaining: 5));
      final far = reminderText(state(daysLeft: 30, remaining: 5));
      expect(near, isNotNull);
      expect(far, isNotNull);
      // 形が同じ（煽り文が足されていない）
      expect(near!.split('。').length, far!.split('。').length);
    });
  });

  group('予約の時刻', () {
    test('タイムゾーンを端末に合わせている', () {
      // **initializeTimeZones() だけでは tz.local は UTC のまま。**
      // 設定しないと 20:00 のつもりの予約が翌朝5時に立つ（実機で確認）
      final src = File('lib/services/reminders.dart').readAsStringSync();
      expect(
        src.contains('setLocalLocation'),
        isTrue,
        reason: 'tz.local が UTC のままだと予約の時刻がずれる',
      );
    });

    test('過ぎた時刻は翌日に回す', () {
      final src = File('lib/services/reminders.dart').readAsStringSync();
      expect(src.contains('at.add(const Duration(days: 1))'), isTrue);
    });
  });

  group('同意画面では聞かない', () {
    test('起動時に権限を求めない', () {
      // 何のための許可か分からないまま押させることになる。
      // **初回の会話を終えた直後**に、文脈のある場面で聞く
      final src = File('lib/services/reminders.dart').readAsStringSync();
      expect(src.contains('requestAlertPermission: false'), isTrue);
      final consent = File(
        'lib/screens/consent_screen.dart',
      ).readAsStringSync();
      expect(
        consent.contains('Reminders'),
        isFalse,
        reason: '同意画面で通知の許可を求めている',
      );
    });
  });
}
