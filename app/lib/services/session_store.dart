import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../learning/domain/learning_event.dart';
import '../learning/domain/learning_economy.dart';
import '../learning/domain/learning_policy.dart';
import '../learning/domain/learning_progress.dart';
import '../learning/services/learning_quest_plan_v2.dart';
import '../learning/services/local_weekly_league_finalization.dart';
import '../learning/services/local_weekly_league_catch_up.dart';
import '../learning/services/local_weekly_league_projection.dart';
import '../models/concept_progress.dart';
import '../models/day_key.dart';
import '../models/dossier.dart';
import '../models/mission.dart';
import '../models/league_ladder.dart';
import '../models/review.dart';
import '../models/streak.dart';

/// 端末に残す会話の記録。
///
/// ## なぜ端末なのか
///
/// 理解カルテは「1台の端末が持つ1つの会話」の状態なので、端末が持てば
/// サーバは状態を持たずに済む。DB もセッションもロックも要らない。
///
/// ## OS に殺される前提で書く
///
/// **「アプリを離れる」ではなく「OS に殺される」前提**で設計する。
/// Android は裏に回ったアプリを予告なく落とすので、`dispose` や
/// ライフサイクルのコールバックが呼ばれる保証はない。
/// だから終了時にまとめて書かず、**1ターンごとに書く**。
class SavedSession {
  const SavedSession({
    required this.id,
    required this.unitId,
    this.focusConceptKey,
    this.tactic,
    this.missionKind = MissionKind.teach,
    required this.startedAt,
    required this.updatedAt,
    required this.endedAt,
    required this.dossier,
    required this.transcript,
  });

  final int id;
  final String unitId;

  /// 1概念ミッションの対象。null は旧来の単元全体会話。
  ///
  /// 同じ単元でも概念が違えば Vertex の文脈を混ぜてはいけないため、
  /// 中断再開の照合に使う。
  final String? focusConceptKey;

  /// 教材を閉じる前に本人が選んだ説明の足場。
  final TeachingTactic? tactic;

  /// この会話で要求する学習行為。旧セッションは[MissionKind.teach]。
  final MissionKind missionKind;

  final DateTime startedAt;
  final DateTime updatedAt;

  /// null なら**終わっていない**。次回起動時に再開を提案する
  final DateTime? endedAt;

  final Dossier? dossier;
  final List<Utterance> transcript;

  bool get isFinished => endedAt != null;
}

abstract class SessionStore {
  Future<int> startSession(
    String unitId, {
    String? focusConceptKey,
    TeachingTactic? tactic,
    MissionKind missionKind = MissionKind.teach,
  });

  /// 1ターンごとに呼ぶ。**上書きで丸ごと保存する。**
  /// 差分更新にすると、途中で落ちたときに壊れた状態が残る。
  Future<void> saveProgress(
    int sessionId, {
    required List<Utterance> transcript,
    Dossier? dossier,
  });

  Future<void> finishSession(int sessionId);

  /// 終わっていない会話。あれば再開を提案する。
  /// 終わっていない会話を1件返す。[unitId]を渡した場合は概念も厳密に
  /// 照合し、[focusConceptKey]がnullなら旧来の単元全体会話だけを見る。
  /// これにより、同じ単元の別概念を誤って再開・破棄しない。
  Future<SavedSession?> unfinished({
    String? unitId,
    String? focusConceptKey,
    MissionKind? missionKind,
  });

  Future<List<SavedSession>> recentSessions({int limit = 20});

  /// 復習の一覧。同じ概念は最後の1件だけ残す。
  Future<List<ReviewItem>> reviewItems();

  /// 会話の結果を反映する。**[ReviewItem.timesSeen] は保つ**
  /// （会話するたびに見直し回数が0に戻ると、間隔が伸びない）。
  Future<void> upsertReviews(List<ReviewItem> items);

  /// 見直した。回数を1つ進めて、次の間隔を伸ばす。
  Future<void> markReviewed(String unitId, String conceptKey);

  /// その日の記録を積む。**足し算で、上書きしない。**
  ///
  /// [done] は片づけた「きょうの1件」の数。新しい概念でも、
  /// 期限が来た復習でもよい（教材が8節しかないので、
  /// 新しい概念だけを条件にすると9日目に誰も続けられなくなる）。
  Future<void> recordActivity(
    String day, {
    int sessions = 0,
    int done = 0,
    int textTurns = 0,
  });

  /// 日ごとの記録。新しい順。連続日数はこれを数えて出す。
  Future<List<DayRecord>> days({int limit = 400});

  /// 「言えるようになったこと」を1件残す。
  ///
  /// **これが報酬の本体**（C5）。ポイントのような行動と切り離された報酬ではなく、
  /// 行動の成果そのもの＝生徒が自分の言葉で言えた内容を積む。
  /// 同じ概念は最後の1件だけ残す（言い直すたびに増えると水増しになる）。
  Future<void> recordExplained(ExplainedItem item);

  /// 言えるようになったこと。新しい順。
  Future<List<ExplainedItem>> explained({int limit = 50});

  /// 概念ごとのMission Path状態。期限が早い順に返す。
  Future<List<ConceptProgress>> conceptProgress();

  Future<ConceptProgress?> progressFor(String unitId, String conceptKey);

  /// 1概念ミッションの最終結果を、1つの保存単位として確定する。
  ///
  /// 同じ[sessionId]を再試行しても、保持成功回数と`days.done`は増えない。
  /// [cleared]なら[explained]、未決着なら[review]を渡す。sessionに保存した
  /// unit/concept/kindを正として照合するため、別概念へ結果を誤記録できない。
  Future<ConceptProgress> completeMission(
    int sessionId, {
    required bool cleared,
    required DateTime completedAt,
    ExplainedItem? explained,
    ReviewItem? review,
  });

  /// 概念を見直した。もう出さない
  Future<void> clearReview(String unitId, String conceptKey);

  /// 次の定期考査。復習間隔の逆算に使う。
  Future<DateTime?> examDate();
  Future<void> setExamDate(DateTime? date);

  /// 端末に残す小さな値（端末ID・トークン・同意の記録など）。
  ///
  /// **秘密の保管庫ではない。** root を取られた端末では読める。
  /// ここに置いてよいのは「盗まれても本人の情報にならないもの」だけ。
  Future<String?> getSetting(String key);

  /// null を渡すと消す。
  Future<void> setSetting(String key, String? value);

  /// 学習ゲームの1行為を、進捗・復習・クエスト・報酬と同時に確定する。
  ///
  /// 同じevent IDを再送しても二重加算しない。回答本文を受け取る引数はない。
  Future<CommitLearningResult> commitLearningEvent(
    LearningEventCommand event, {
    LearningCommitRules rules = const LearningCommitRules(),
  });

  /// 未着手のV2 daily/monthly Questをprogress 0・報酬0で冪等に保存する。
  ///
  /// [definitions]はinstance IDからmetadata全体を復元できるcanonical定義に限る。
  /// 学校scopeは空listだけをno-opとして受け付け、個人Questを保存しない。
  Future<LearningQuestMaterializationResult>
  materializeLearningQuestDefinitions({
    required LearningScope scope,
    required Iterable<LearningQuestDefinition> definitions,
  });

  Future<LearningProgressSnapshot> learningProgressSnapshot(
    LearningScope scope,
  );

  /// 理解カルテ用のneed状態。activeと解消済みtombstoneの両方を返す。
  Future<List<LearningNeedStateView>> learningNeedStates(LearningScope scope);

  Future<LearningRun> beginLearningRun(LearningRun run);

  Future<LearningRun> checkpointLearningRun(
    String runId, {
    required int activityIndex,
    int? challengeHearts,
    required DateTime updatedAt,
  });

  Future<void> discardLearningRun(String runId);

  /// 個人固定課題のheartを1つだけ、transaction内で冪等に消費する。
  Future<LearningChallengeHeartSpendResult> spendLearningChallengeHeart(
    String runId, {
    required String lossId,
    required int activityIndex,
    required String learningDay,
    required DateTime occurredAt,
  });

  Future<LearningLocalCoopRun> beginLearningLocalCoopRun(
    LearningLocalCoopRunCommand command,
  );

  /// 経過した30分ごとに個人heartを1つ戻す。
  Future<LearningChallengeHeartRefreshResult> refreshLearningChallengeHearts({
    required String learningDay,
    required DateTime occurredAt,
  });

  /// 完了済みの専用回復練習eventを根拠に、個人heartを1つだけ戻す。
  Future<LearningChallengeHeartPracticeRecoveryResult>
  recoverLearningChallengeHeartWithPractice({
    required String recoveryId,
    required String sourceEventId,
    required String learningDay,
    required DateTime occurredAt,
  });

  Future<LearningLocalCoopContributionResult> contributeLearningLocalCoopRun(
    String runId, {
    required String contributionId,
    required String participantId,
    required String eventId,
    required DateTime occurredAt,
  });

  /// 指定した実在runに紐づく寄与eventを、回答なしで読み出す。
  Future<List<LearningLocalCoopContribution>> localCoopContributions(
    Set<String> runIds,
  );

  /// 保存済みの匿名run / meaningful contributionだけから、終了済み週を確定する。
  ///
  /// 順位・件数・氏名・回答は引数にできない。同じ週の再送は保存済み結果を返し、
  /// 5人未満・週の途中・不整合では履歴を作らない。
  Future<LearningLocalLeagueFinalizeResult> finalizeLearningLocalWeeklyLeague({
    required String weekKey,
    required DateTime finalizedAt,
  });

  /// 終了済みの保存済みLeague週を、古い順に1つの保存単位で追いつかせる。
  ///
  /// 現在週と空週は確定対象にせず、1 passは最大104候補へ制限する。途中の
  /// 保存失敗では一部の週だけを確定せず、呼出し元は通常snapshotを別途読める。
  Future<LearningLocalLeagueCatchUpResult> catchUpLearningLocalWeeklyLeagues({
    required String currentWeekKey,
    required DateTime finalizedAt,
    String? afterWeekKey,
  });

  /// TLS pin済みLAN friends roomの共同達成に、固定1結晶を一度だけ付与する。
  ///
  /// 学習event、XP、streak、Pathは変更しない。room IDを冪等キーとし、再joinや
  /// refreshを何度行っても同じ台帳行を返す。
  Future<LearningLanFriendsRewardResult> grantLearningLanFriendsReward({
    required String roomId,
    required DateTime completedAt,
  });

  Future<LearningGemSpendResult> replenishLearningStreakFreezeWithGems({
    required String spendId,
    required String learningDay,
    required DateTime occurredAt,
    SafeLearningEconomyPolicyV1 economyPolicy =
        const SafeLearningEconomyPolicyV1(),
  });

  Future<LearningGemSpendResult> recoverLearningChallengeHeartsWithGems({
    required String spendId,
    required String learningDay,
    required DateTime occurredAt,
    SafeLearningEconomyPolicyV1 economyPolicy =
        const SafeLearningEconomyPolicyV1(),
  });

  Future<LearningCosmeticPurchaseResult> purchaseLearningCosmeticWithGems({
    required LearningScope scope,
    required String spendId,
    required String productId,
    required String learningDay,
    required DateTime occurredAt,
    SafeLearningEconomyCatalogV1 catalog = const SafeLearningEconomyCatalogV1(),
  });

  Future<LearningCosmeticEquipResult> equipLearningCosmetic({
    required LearningScope scope,
    required String productId,
    required DateTime occurredAt,
    SafeLearningEconomyCatalogV1 catalog = const SafeLearningEconomyCatalogV1(),
  });

  /// Plus entitlement が確認できた端末へ、requiresPlusAccess の見た目を所有に付ける。
  ///
  /// 結晶台帳へ0額の行を入れるだけで、学習event・XP・進行は変更しない。
  /// spendId を `plus-grant:<productId>` に固定し、呼び直しても二重付与しない。
  Future<LearningCosmeticState> grantLearningPlusCosmetics({
    required LearningScope scope,
    required DateTime occurredAt,
    SafeLearningEconomyCatalogV1 catalog = const SafeLearningEconomyCatalogV1(),
  });

  Future<LearningChallengePassPurchaseResult>
  purchaseLearningChallengePassWithGems({
    required LearningScope scope,
    required String spendId,
    required String productId,
    required String learningDay,
    required DateTime occurredAt,
    SafeLearningEconomyCatalogV1 catalog = const SafeLearningEconomyCatalogV1(),
  });

  Future<LearningRun?> activeLearningRun({
    required LearningScope scope,
    String? nodeId,
  });

  /// 指定scopeだけを消す。学校と個人を同じ操作で巻き込まない。
  Future<void> clearLearningScope(LearningScope scope);

  Future<void> close();
}

/// sqflite 版。Android / iOS 用。
class SqfliteSessionStore implements SessionStore {
  SqfliteSessionStore._(this._db);

  final Database _db;

  /// スキーマの履歴。**`_migrations[i]` は「バージョン i+1 にするための変更」。**
  ///
  /// 完成形の `CREATE TABLE` を別に持たない。2か所に書くと、
  /// 新規インストールと更新でスキーマがずれて、片方でしか出ない不具合になる。
  /// 新規は空の DB に全件を順に流し、更新は差分だけ流す。
  ///
  /// **追加するときは末尾に足すだけ。既存の要素は書き換えない。**
  /// 書き換えると、すでに更新を終えた端末には二度と適用されない。
  static final List<Future<void> Function(DatabaseExecutor)> _migrations = [
    // v1 — 最初のスキーマ
    (db) async {
      await db.execute('''
        CREATE TABLE sessions(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          unit_id TEXT NOT NULL,
          started_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          ended_at INTEGER,
          dossier TEXT,
          transcript TEXT NOT NULL DEFAULT '[]'
        )''');
      await db.execute('''
        CREATE TABLE reviews(
          unit_id TEXT NOT NULL,
          concept_key TEXT NOT NULL,
          label TEXT NOT NULL,
          reason TEXT NOT NULL,
          last_seen INTEGER NOT NULL,
          PRIMARY KEY(unit_id, concept_key)
        )''');
      await db.execute(
        'CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT)',
      );
    },
    // v2 — 見直した回数。これが無いと間隔反復が1日目に固定される
    (db) async {
      await db.execute(
        'ALTER TABLE reviews ADD COLUMN times_seen INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE reviews ADD COLUMN last_reviewed_at INTEGER',
      );
    },
    // v3 — 日ごとの記録。連続日数はここから毎回数える（保存しない）
    (db) async {
      await db.execute('''
        CREATE TABLE days(
          day TEXT PRIMARY KEY,
          sessions INTEGER NOT NULL DEFAULT 0,
          done INTEGER NOT NULL DEFAULT 0,
          text_turns INTEGER NOT NULL DEFAULT 0
        )''');
    },
    // v4 — 言えるようになったこと。**報酬の本体。**
    // ポイントではなく生徒自身の言葉を積む（C5）
    (db) async {
      await db.execute('''
        CREATE TABLE explained(
          unit_id TEXT NOT NULL,
          concept_key TEXT NOT NULL,
          label TEXT NOT NULL,
          said TEXT NOT NULL,
          at INTEGER NOT NULL,
          PRIMARY KEY(unit_id, concept_key)
        )''');
    },
    // v5 — 1概念ミッションの中断再開に必要な文脈。
    // 既存行はどちらも null（旧来の単元全体会話）として残す。
    (db) async {
      await db.execute(
        'ALTER TABLE sessions ADD COLUMN focus_concept_key TEXT',
      );
      await db.execute('ALTER TABLE sessions ADD COLUMN teaching_tactic TEXT');
    },
    // v6 — Mission Path。既存の復習/説明を捨てずに概念状態へ写す。
    (db) async {
      await db.execute(
        "ALTER TABLE sessions ADD COLUMN mission_kind TEXT NOT NULL DEFAULT 'teach'",
      );
      // ended_atだけでは、旧finishSession済みかcompleteMission適用済みかを
      // 区別できない。加算を再試行で二重適用しないための確定印。
      await db.execute(
        'ALTER TABLE sessions ADD COLUMN completion_applied '
        'INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute('''
        CREATE TABLE concept_progress(
          unit_id TEXT NOT NULL,
          concept_key TEXT NOT NULL,
          last_outcome TEXT NOT NULL CHECK(
            last_outcome IN ('learned', 'rematchNeeded', 'retained')
          ),
          successful_retrievals INTEGER NOT NULL DEFAULT 0
            CHECK(successful_retrievals >= 0),
          last_attempt_day TEXT NOT NULL,
          last_success_day TEXT,
          next_due_day TEXT NOT NULL,
          source_session_id INTEGER,
          PRIMARY KEY(unit_id, concept_key)
        )''');
      await db.execute(
        'CREATE INDEX concept_progress_due_idx '
        'ON concept_progress(next_due_day, last_outcome)',
      );

      // reviewsは「次に修復が必要」という、より新しく強い観測。
      final reviewRows = await db.query('reviews');
      final rematchKeys = <String>{};
      for (final row in reviewRows) {
        final unitId = row['unit_id'] as String? ?? '';
        final conceptKey = row['concept_key'] as String? ?? '';
        if (unitId.isEmpty || conceptKey.isEmpty) continue;
        final seen = DateTime.fromMillisecondsSinceEpoch(
          (row['last_seen'] as int?) ?? 0,
        );
        final day = dayKeyOf(seen.toLocal());
        rematchKeys.add(_conceptId(unitId, conceptKey));
        await db.insert('concept_progress', {
          'unit_id': unitId,
          'concept_key': conceptKey,
          'last_outcome': ConceptOutcome.rematchNeeded.wire,
          'successful_retrievals': 0,
          'last_attempt_day': day,
          'last_success_day': null,
          'next_due_day': day,
          'source_session_id': null,
        });
      }

      // reviewが無い説明済み概念は、翌日のcase retryから始める。
      final explainedRows = await db.query('explained');
      for (final row in explainedRows) {
        final unitId = row['unit_id'] as String? ?? '';
        final conceptKey = row['concept_key'] as String? ?? '';
        if (unitId.isEmpty || conceptKey.isEmpty) continue;
        if (rematchKeys.contains(_conceptId(unitId, conceptKey))) continue;
        final at = DateTime.fromMillisecondsSinceEpoch(
          (row['at'] as int?) ?? 0,
        );
        final day = dayKeyOf(at.toLocal());
        await db.insert('concept_progress', {
          'unit_id': unitId,
          'concept_key': conceptKey,
          'last_outcome': ConceptOutcome.learned.wire,
          'successful_retrievals': 0,
          'last_attempt_day': day,
          'last_success_day': day,
          'next_due_day': shiftDay(day, 1),
          'source_session_id': null,
        });
      }
    },
    // v7 — 全学習形式を同じpathへ載せる、回答非保存の学習台帳。
    //
    // staticなnode定義はcatalog側が正本。DBはeventとprojectionだけを持つ。
    // 学校scopeは同じ表でも複合PKで分離し、報酬表はSQLでもpersonal限定にする。
    (db) async {
      await db.execute('''
        CREATE TABLE learning_events(
          id TEXT PRIMARY KEY,
          scope TEXT NOT NULL CHECK(scope IN ('personal', 'schoolLocal')),
          origin TEXT NOT NULL CHECK(origin IN (
            'path', 'practice', 'story', 'lab', 'challenge',
            'legacyImport', 'schoolAssignment'
          )),
          course_id TEXT NOT NULL,
          node_id TEXT NOT NULL,
          activity_id TEXT NOT NULL,
          activity_kind TEXT NOT NULL CHECK(activity_kind IN (
            'read', 'predict', 'singleSelect', 'classify', 'sequence',
            'listen', 'speak', 'diagram', 'equation', 'story', 'transfer',
            'checkpoint', 'timed'
          )),
          outcome TEXT NOT NULL CHECK(outcome IN (
            'completed', 'retryNeeded', 'corrected', 'structuredSuccess'
          )),
          evidence_rank INTEGER NOT NULL CHECK(evidence_rank BETWEEN 0 AND 4),
          content_version TEXT NOT NULL,
          learning_day TEXT NOT NULL,
          occurred_at INTEGER NOT NULL,
          run_id TEXT,
          source_session_id INTEGER,
          reward_eligible INTEGER NOT NULL CHECK(reward_eligible IN (0, 1)),
          CHECK(scope = 'personal' OR reward_eligible = 0)
        )''');
      await db.execute(
        'CREATE INDEX learning_events_scope_day_idx '
        'ON learning_events(scope, learning_day, occurred_at)',
      );
      await db.execute(
        'CREATE INDEX learning_events_node_idx '
        'ON learning_events(scope, node_id, occurred_at)',
      );
      await db.execute('''
        CREATE TABLE learning_event_skills(
          event_id TEXT NOT NULL,
          skill_id TEXT NOT NULL,
          PRIMARY KEY(event_id, skill_id)
        )''');
      await db.execute('''
        CREATE TABLE learning_practice_needs(
          event_id TEXT NOT NULL,
          skill_id TEXT NOT NULL,
          need_code TEXT NOT NULL,
          PRIMARY KEY(event_id, skill_id, need_code)
        )''');
      await db.execute('''
        CREATE TABLE learning_node_progress(
          scope TEXT NOT NULL CHECK(scope IN ('personal', 'schoolLocal')),
          node_id TEXT NOT NULL,
          state TEXT NOT NULL CHECK(state IN ('inProgress', 'cleared')),
          attempt_count INTEGER NOT NULL CHECK(attempt_count >= 0),
          best_evidence_rank INTEGER NOT NULL
            CHECK(best_evidence_rank BETWEEN 0 AND 4),
          last_attempt_day TEXT NOT NULL,
          last_event_id TEXT NOT NULL,
          completed_at INTEGER,
          content_version TEXT NOT NULL,
          PRIMARY KEY(scope, node_id)
        )''');
      await db.execute('''
        CREATE TABLE learning_skill_progress(
          scope TEXT NOT NULL CHECK(scope IN ('personal', 'schoolLocal')),
          skill_id TEXT NOT NULL,
          last_outcome TEXT NOT NULL CHECK(last_outcome IN (
            'needsPractice', 'completed', 'retained'
          )),
          successful_retrievals INTEGER NOT NULL DEFAULT 0
            CHECK(successful_retrievals >= 0),
          last_attempt_day TEXT NOT NULL,
          last_success_day TEXT,
          next_due_day TEXT NOT NULL,
          last_event_id TEXT NOT NULL,
          PRIMARY KEY(scope, skill_id)
        )''');
      await db.execute(
        'CREATE INDEX learning_skill_due_idx '
        'ON learning_skill_progress(scope, next_due_day, last_outcome)',
      );
      await db.execute('''
        CREATE TABLE learning_days(
          scope TEXT NOT NULL CHECK(scope IN ('personal', 'schoolLocal')),
          day TEXT NOT NULL,
          qualifying_count INTEGER NOT NULL DEFAULT 0
            CHECK(qualifying_count >= 0),
          first_event_at INTEGER NOT NULL,
          last_event_at INTEGER NOT NULL,
          PRIMARY KEY(scope, day)
        )''');
      await db.execute('''
        CREATE TABLE learning_reward_ledger(
          entry_id TEXT PRIMARY KEY,
          scope TEXT NOT NULL CHECK(scope = 'personal'),
          reward_type TEXT NOT NULL CHECK(reward_type IN ('xp', 'gems')),
          amount INTEGER NOT NULL CHECK(amount > 0),
          reason TEXT NOT NULL,
          source_event_id TEXT,
          created_at INTEGER NOT NULL
        )''');
      await db.execute('''
        CREATE UNIQUE INDEX learning_reward_source_idx
        ON learning_reward_ledger(
          scope, reward_type, reason, IFNULL(source_event_id, '')
        )''');
      await db.execute('''
        CREATE TABLE learning_quest_progress(
          scope TEXT NOT NULL CHECK(scope = 'personal'),
          quest_instance_id TEXT NOT NULL,
          progress INTEGER NOT NULL DEFAULT 0 CHECK(progress >= 0),
          target INTEGER NOT NULL CHECK(target > 0),
          completed_at INTEGER,
          rewarded_at INTEGER,
          definition_version TEXT NOT NULL,
          PRIMARY KEY(scope, quest_instance_id)
        )''');
      await db.execute('''
        CREATE TABLE learning_quest_events(
          quest_instance_id TEXT NOT NULL,
          event_id TEXT NOT NULL,
          PRIMARY KEY(quest_instance_id, event_id)
        )''');
      await db.execute('''
        CREATE TABLE learning_freezes(
          scope TEXT NOT NULL CHECK(scope = 'personal'),
          day TEXT NOT NULL,
          week_key TEXT NOT NULL,
          used_at INTEGER NOT NULL,
          PRIMARY KEY(scope, day)
        )''');
      await db.execute('''
        CREATE TABLE learning_runs(
          run_id TEXT PRIMARY KEY,
          scope TEXT NOT NULL CHECK(scope IN ('personal', 'schoolLocal')),
          node_id TEXT NOT NULL,
          activity_index INTEGER NOT NULL DEFAULT 0 CHECK(activity_index >= 0),
          challenge_hearts INTEGER CHECK(challenge_hearts >= 0),
          content_version TEXT NOT NULL,
          updated_at INTEGER NOT NULL
        )''');
      await db.execute(
        'CREATE INDEX learning_runs_scope_idx '
        'ON learning_runs(scope, updated_at DESC)',
      );
    },
    // v8 — streak freezeの週次制約と、個人heartの安全な台帳。
    //
    // heart lossには回答・正誤を置かず、同じloss IDの二重消費を防ぐために
    // 必要な操作情報だけを残す。v11以降は全固定課題で共有する。
    (db) async {
      // v7では週次unique制約が無かった。もし開発版が重複行を残していても、
      // 各週で最初に消費した1件を正として安全に移行する。
      await db.execute('''
        DELETE FROM learning_freezes
        WHERE rowid NOT IN (
          SELECT MIN(rowid) FROM learning_freezes GROUP BY scope, week_key
        )
      ''');
      await db.execute('''
        CREATE UNIQUE INDEX learning_freezes_week_idx
        ON learning_freezes(scope, week_key)
      ''');
      await db.execute('''
        CREATE TABLE learning_challenge_heart_state(
          scope TEXT PRIMARY KEY CHECK(scope = 'personal'),
          current_hearts INTEGER NOT NULL
            CHECK(current_hearts BETWEEN 0 AND 5),
          last_loss_day TEXT,
          last_recovery_day TEXT,
          updated_at INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE learning_challenge_heart_losses(
          loss_id TEXT PRIMARY KEY,
          scope TEXT NOT NULL CHECK(scope = 'personal'),
          run_id TEXT NOT NULL,
          activity_index INTEGER NOT NULL CHECK(activity_index >= 0),
          learning_day TEXT NOT NULL,
          occurred_at INTEGER NOT NULL,
          remaining_hearts INTEGER NOT NULL
            CHECK(remaining_hearts BETWEEN 0 AND 4)
        )
      ''');
      await db.execute('''
        CREATE INDEX learning_challenge_heart_losses_scope_idx
        ON learning_challenge_heart_losses(scope, occurred_at)
      ''');
      // v7ではheartがrun内だけだった。最新値を初期stateとして引き継ぎ、
      // 旧値が新しい安全上限を超える場合だけ上限へ丸める。
      await db.execute('''
        INSERT INTO learning_challenge_heart_state(
          scope, current_hearts, last_loss_day, last_recovery_day, updated_at
        )
        SELECT 'personal', MIN(5, MAX(0, challenge_hearts)), NULL, NULL,
               updated_at
        FROM learning_runs
        WHERE scope = 'personal' AND challenge_hearts IS NOT NULL
        ORDER BY updated_at DESC
        LIMIT 1
      ''');
      await db.execute('''
        UPDATE learning_runs
        SET challenge_hearts = (
          SELECT current_hearts FROM learning_challenge_heart_state
          WHERE scope = 'personal'
        )
        WHERE scope = 'personal' AND challenge_hearts IS NOT NULL
          AND EXISTS(
            SELECT 1 FROM learning_challenge_heart_state
            WHERE scope = 'personal'
          )
      ''');
      await db.execute('''
        UPDATE learning_runs SET challenge_hearts = NULL
        WHERE scope = 'schoolLocal' AND challenge_hearts IS NOT NULL
      ''');
    },
    // v9 — 実在する端末内モチベーション台帳。
    //
    // v8以前のeventをmeaningfulと推測して報酬を遡及しない。外部の友達・順位は
    // 保存せず、明示的な同一端末coop run、結晶2用途、週次tier履歴だけを持つ。
    (db) async {
      await db.execute(
        'ALTER TABLE learning_events ADD COLUMN meaningful_progress '
        'INTEGER NOT NULL DEFAULT 0 CHECK(meaningful_progress IN (0, 1))',
      );
      await db.execute('DROP INDEX learning_freezes_week_idx');
      await db.execute('''
        CREATE TABLE learning_gem_spends(
          spend_id TEXT PRIMARY KEY,
          scope TEXT NOT NULL CHECK(scope = 'personal'),
          spend_kind TEXT NOT NULL CHECK(spend_kind IN (
            'streakFreezeRefill', 'challengeHeartRecovery'
          )),
          amount INTEGER NOT NULL CHECK(amount > 0),
          learning_day TEXT NOT NULL,
          week_key TEXT,
          occurred_at INTEGER NOT NULL,
          CHECK(
            (spend_kind = 'streakFreezeRefill' AND week_key IS NOT NULL) OR
            (spend_kind = 'challengeHeartRecovery' AND week_key IS NULL)
          )
        )
      ''');
      await db.execute('''
        CREATE TABLE learning_local_coop_runs(
          run_id TEXT PRIMARY KEY,
          scope TEXT NOT NULL CHECK(scope = 'personal'),
          quest_instance_id TEXT NOT NULL UNIQUE,
          target INTEGER NOT NULL CHECK(target >= 2),
          reward_gems INTEGER NOT NULL CHECK(reward_gems >= 0),
          start_day TEXT NOT NULL,
          end_day TEXT NOT NULL,
          definition_version TEXT NOT NULL,
          started_at INTEGER NOT NULL,
          completed_at INTEGER,
          rewarded_at INTEGER
        )
      ''');
      await db.execute('''
        CREATE TABLE learning_local_coop_participants(
          run_id TEXT NOT NULL,
          participant_id TEXT NOT NULL,
          PRIMARY KEY(run_id, participant_id)
        )
      ''');
      await db.execute('''
        CREATE TABLE learning_local_coop_contributions(
          contribution_id TEXT PRIMARY KEY,
          run_id TEXT NOT NULL,
          participant_id TEXT NOT NULL,
          event_id TEXT NOT NULL,
          contributed_at INTEGER NOT NULL,
          UNIQUE(event_id)
        )
      ''');
      await db.execute('''
        CREATE TABLE learning_league_history(
          scope TEXT NOT NULL CHECK(scope = 'personal'),
          week_key TEXT NOT NULL,
          xp INTEGER NOT NULL CHECK(xp >= 0),
          previous_tier TEXT NOT NULL CHECK(previous_tier IN (
            'observer', 'experimenter', 'investigator', 'researchLead'
          )),
          tier TEXT NOT NULL CHECK(tier IN (
            'observer', 'experimenter', 'investigator', 'researchLead'
          )),
          movement TEXT NOT NULL CHECK(movement IN (
            'promoted', 'stayed', 'demoted'
          )),
          finalized_at INTEGER NOT NULL,
          PRIMARY KEY(scope, week_key)
        )
      ''');
    },
    // v10 — 固定誤答から得た一般化needのactive/tombstone投影。
    //
    // 回答や選択肢IDは保存しない。解消済み行もtombstoneとして残し、後着した
    // 古いretry eventでneedが復活しないようevent順序を比較できるようにする。
    (db) async {
      await db.execute(
        'ALTER TABLE learning_practice_needs ADD COLUMN resolved '
        'INTEGER NOT NULL DEFAULT 0 CHECK(resolved IN (0, 1))',
      );
      await db.execute('''
        CREATE TABLE learning_need_state(
          scope TEXT NOT NULL CHECK(scope IN ('personal', 'schoolLocal')),
          skill_id TEXT NOT NULL,
          need_code TEXT NOT NULL,
          first_observed_day TEXT,
          last_observed_day TEXT,
          last_observed_at INTEGER,
          last_observation_event_id TEXT,
          resolved_day TEXT,
          resolved_at INTEGER,
          resolution_event_id TEXT,
          PRIMARY KEY(scope, skill_id, need_code),
          CHECK(
            (first_observed_day IS NULL AND last_observed_day IS NULL AND
             last_observed_at IS NULL AND last_observation_event_id IS NULL) OR
            (first_observed_day IS NOT NULL AND last_observed_day IS NOT NULL AND
             last_observed_at IS NOT NULL AND last_observation_event_id IS NOT NULL)
          ),
          CHECK(
            (resolved_day IS NULL AND resolved_at IS NULL AND
             resolution_event_id IS NULL) OR
            (resolved_day IS NOT NULL AND resolved_at IS NOT NULL AND
             resolution_event_id IS NOT NULL)
          ),
          CHECK(last_observed_day IS NOT NULL OR resolved_day IS NOT NULL)
        )
      ''');
      await db.execute(
        'CREATE INDEX learning_need_active_idx '
        'ON learning_need_state(scope, resolution_event_id, last_observed_day, skill_id)',
      );
      // v7〜v9の観測済みneedは捨てずactiveへ移す。旧schemaには対応する
      // resolutionの正本が無いため、安全側に解消済みとは推測しない。
      await db.execute('''
        INSERT INTO learning_need_state(
          scope, skill_id, need_code, first_observed_day,
          last_observed_day, last_observed_at, last_observation_event_id,
          resolved_day, resolved_at, resolution_event_id
        )
        SELECT event.scope, need.skill_id, need.need_code,
               MIN(event.learning_day), MAX(event.learning_day),
               MAX(event.occurred_at), MAX(event.id), NULL, NULL, NULL
        FROM learning_practice_needs AS need
        JOIN learning_events AS event ON event.id = need.event_id
        WHERE need.resolved = 0
        GROUP BY event.scope, need.skill_id, need.need_code
      ''');
    },
    // v11 — 通常固定課題まで広げたheartと、専用回復練習の冪等台帳。
    //
    // 既存v8 lossは同じ共有stateに残るため移し替えない。回答・選択肢は保存せず、
    // 回復根拠は固定activity IDを持つcommit済みeventだけに限定する。
    (db) async {
      await db.execute('''
        CREATE TABLE learning_challenge_heart_practice_recoveries(
          recovery_id TEXT PRIMARY KEY,
          scope TEXT NOT NULL CHECK(scope = 'personal'),
          source_event_id TEXT NOT NULL UNIQUE,
          learning_day TEXT NOT NULL,
          occurred_at INTEGER NOT NULL,
          recovered_hearts INTEGER NOT NULL
            CHECK(recovered_hearts BETWEEN 0 AND 1),
          resulting_hearts INTEGER NOT NULL
            CHECK(resulting_hearts BETWEEN 0 AND 5)
        )
      ''');
    },
    // v12 — 固定catalogの見た目購入・装備と、任意Timedの学習日pass。
    //
    // 既存spendを保持してCHECKを拡張する。商品IDと価格はDBでも固定し、
    // 回答・選択・正誤・音声・自由記述を保存する列は追加しない。
    (db) async {
      await db.execute(
        'ALTER TABLE learning_gem_spends RENAME TO learning_gem_spends_v11',
      );
      await db.execute('''
        CREATE TABLE learning_gem_spends(
          spend_id TEXT PRIMARY KEY,
          scope TEXT NOT NULL CHECK(scope = 'personal'),
          spend_kind TEXT NOT NULL CHECK(spend_kind IN (
            'streakFreezeRefill', 'challengeHeartRecovery',
            'cosmeticPurchase', 'challengeEntry'
          )),
          amount INTEGER NOT NULL CHECK(amount > 0),
          learning_day TEXT NOT NULL,
          week_key TEXT,
          occurred_at INTEGER NOT NULL,
          reference_id TEXT,
          CHECK(
            (spend_kind = 'streakFreezeRefill' AND week_key IS NOT NULL
              AND reference_id IS NULL) OR
            (spend_kind = 'challengeHeartRecovery' AND week_key IS NULL
              AND reference_id IS NULL) OR
            (spend_kind = 'cosmeticPurchase' AND week_key IS NULL AND (
              (reference_id = 'cosmetic.path-mascot.orbit.v1' AND amount = 4) OR
              (reference_id = 'cosmetic.path-mascot.nova.v1' AND amount = 6)
            )) OR
            (spend_kind = 'challengeEntry' AND week_key IS NULL
              AND reference_id = 'challenge.timed.day-pass.v1'
              AND amount = 1)
          )
        )
      ''');
      await db.execute('''
        INSERT INTO learning_gem_spends(
          spend_id, scope, spend_kind, amount, learning_day,
          week_key, occurred_at, reference_id
        )
        SELECT spend_id, scope, spend_kind, amount, learning_day,
               week_key, occurred_at, NULL
        FROM learning_gem_spends_v11
      ''');
      await db.execute('DROP TABLE learning_gem_spends_v11');
      await db.execute('''
        CREATE UNIQUE INDEX learning_gem_cosmetic_product_idx
        ON learning_gem_spends(scope, reference_id)
        WHERE spend_kind = 'cosmeticPurchase'
      ''');
      await db.execute('''
        CREATE UNIQUE INDEX learning_gem_challenge_day_idx
        ON learning_gem_spends(scope, reference_id, learning_day)
        WHERE spend_kind = 'challengeEntry'
      ''');
      await db.execute('''
        CREATE TABLE learning_cosmetic_loadout(
          scope TEXT NOT NULL CHECK(scope = 'personal'),
          slot TEXT NOT NULL CHECK(slot = 'pathMascot'),
          product_id TEXT NOT NULL CHECK(product_id IN (
            'cosmetic.path-mascot.standard.v1',
            'cosmetic.path-mascot.orbit.v1',
            'cosmetic.path-mascot.nova.v1'
          )),
          updated_at INTEGER NOT NULL,
          PRIMARY KEY(scope, slot)
        )
      ''');
    },
    // v13 — 端末手渡し実参加者順位によるBronze→Diamond週次ladder。
    //
    // 旧4段XP履歴は互換のため残すが、新しい主表示には使わない。slot 1の
    // 派生順位・件数・tierだけを保存し、participant ID、氏名、回答の列は持たない。
    (db) async {
      await db.execute('''
        CREATE TABLE learning_local_league_history(
          scope TEXT NOT NULL CHECK(scope = 'personal'),
          week_key TEXT NOT NULL,
          meaningful_event_count INTEGER NOT NULL
            CHECK(meaningful_event_count >= 0),
          rank INTEGER CHECK(rank BETWEEN 1 AND 8),
          tied INTEGER NOT NULL CHECK(tied IN (0, 1)),
          participant_count INTEGER NOT NULL
            CHECK(participant_count BETWEEN 5 AND 8),
          previous_tier TEXT NOT NULL CHECK(previous_tier IN (
            'bronze', 'silver', 'gold', 'sapphire', 'ruby', 'emerald',
            'amethyst', 'pearl', 'obsidian', 'diamond'
          )),
          tier TEXT NOT NULL CHECK(tier IN (
            'bronze', 'silver', 'gold', 'sapphire', 'ruby', 'emerald',
            'amethyst', 'pearl', 'obsidian', 'diamond'
          )),
          movement TEXT NOT NULL CHECK(movement IN (
            'promoted', 'stayed', 'demoted'
          )),
          finalized_at INTEGER NOT NULL,
          PRIMARY KEY(scope, week_key),
          CHECK(rank IS NULL OR rank <= participant_count),
          CHECK(rank IS NOT NULL OR (meaningful_event_count = 0 AND tied = 0))
        )
      ''');
    },
    // v14 — Plus特典の見た目付与台帳と、auroraマスコットの装備許可。
    //
    // 特典付与は0額spendでなく専用表へ記録し、結晶の価格・残高CHECKを
    // そのまま守る。loadoutはproduct_id制約を拡張して作り直す。
    (db) async {
      await db.execute('''
        CREATE TABLE learning_cosmetic_grants(
          grant_id TEXT PRIMARY KEY,
          scope TEXT NOT NULL CHECK(scope = 'personal'),
          product_id TEXT NOT NULL CHECK(product_id IN (
            'cosmetic.path-mascot.aurora.v1'
          )),
          granted_at INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE UNIQUE INDEX learning_cosmetic_grants_product_idx
        ON learning_cosmetic_grants(scope, product_id)
      ''');
      await db.execute(
        'ALTER TABLE learning_cosmetic_loadout RENAME TO learning_cosmetic_loadout_v13',
      );
      await db.execute('''
        CREATE TABLE learning_cosmetic_loadout(
          scope TEXT NOT NULL CHECK(scope = 'personal'),
          slot TEXT NOT NULL CHECK(slot = 'pathMascot'),
          product_id TEXT NOT NULL CHECK(product_id IN (
            'cosmetic.path-mascot.standard.v1',
            'cosmetic.path-mascot.orbit.v1',
            'cosmetic.path-mascot.nova.v1',
            'cosmetic.path-mascot.aurora.v1'
          )),
          updated_at INTEGER NOT NULL,
          PRIMARY KEY(scope, slot)
        )
      ''');
      await db.execute('''
        INSERT INTO learning_cosmetic_loadout(scope, slot, product_id, updated_at)
        SELECT scope, slot, product_id, updated_at
        FROM learning_cosmetic_loadout_v13
      ''');
      await db.execute('DROP TABLE learning_cosmetic_loadout_v13');
    },
  ];

  /// [path] はテスト専用。本番では既定の場所に開く。
  static Future<SqfliteSessionStore> open({String? path}) async {
    final file = path ?? p.join(await getDatabasesPath(), 'dekisugi.db');
    final db = await openDatabase(
      file,
      version: _migrations.length,
      onCreate: (db, version) => _runMigrations(db, 0, version),
      onUpgrade: (db, from, to) => _runMigrations(db, from, to),
      // 古い APK に戻されたとき、新しいスキーマの DB は開けない。
      // **記録を捨ててでも起動する**方を選ぶ（起動不能は復旧の手立てが無い）
      onDowngrade: onDatabaseDowngradeDelete,
    );
    return SqfliteSessionStore._(db);
  }

  /// `from` の次から `to` までを順に流す。
  ///
  /// **ここで `db.transaction()` を呼ばないこと。** `onCreate` / `onUpgrade` は
  /// sqflite が既にトランザクションの中で走らせているので、
  /// 入れ子にすると待ち合わせで固まる。
  static Future<void> _runMigrations(
    DatabaseExecutor db,
    int from,
    int to,
  ) async {
    for (var v = from; v < to; v++) {
      await _migrations[v](db);
    }
  }

  @override
  Future<int> startSession(
    String unitId, {
    String? focusConceptKey,
    TeachingTactic? tactic,
    MissionKind missionKind = MissionKind.teach,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _db.insert('sessions', {
      'unit_id': unitId,
      'focus_concept_key': focusConceptKey,
      'teaching_tactic': tactic?.name,
      'mission_kind': missionKind.wire,
      'started_at': now,
      'updated_at': now,
      'transcript': '[]',
    });
  }

  @override
  Future<void> saveProgress(
    int sessionId, {
    required List<Utterance> transcript,
    Dossier? dossier,
  }) async {
    await _db.update(
      'sessions',
      {
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'transcript': jsonEncode(transcript.map((u) => u.toJson()).toList()),
        if (dossier != null) 'dossier': jsonEncode(dossier.toJson()),
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  @override
  Future<void> finishSession(int sessionId) async {
    await _db.update(
      'sessions',
      {'ended_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  @override
  Future<SavedSession?> unfinished({
    String? unitId,
    String? focusConceptKey,
    MissionKind? missionKind,
  }) async {
    final where = <String>['ended_at IS NULL'];
    final whereArgs = <Object?>[];
    if (unitId != null) {
      where.add('unit_id = ?');
      whereArgs.add(unitId);
    }
    if (focusConceptKey != null) {
      where.add('focus_concept_key = ?');
      whereArgs.add(focusConceptKey);
    } else if (unitId != null) {
      // unitだけを指定した旧来の画面へ、1概念ミッションを混ぜない。
      where.add('focus_concept_key IS NULL');
    }
    if (missionKind != null) {
      where.add('mission_kind = ?');
      whereArgs.add(missionKind.wire);
    }
    final rows = await _db.query(
      'sessions',
      where: where.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      // 同じミリ秒に2件あると順序が定まらない。id で確定させる
      orderBy: 'updated_at DESC, id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final s = _toSession(rows.first);
    // 中身が無い会話を「再開しますか」と聞かない
    return s.transcript.isEmpty ? null : s;
  }

  @override
  Future<List<SavedSession>> recentSessions({int limit = 20}) async {
    final rows = await _db.query(
      'sessions',
      orderBy: 'updated_at DESC, id DESC',
      limit: limit,
    );
    return rows.map(_toSession).toList();
  }

  @override
  Future<List<ReviewItem>> reviewItems() async {
    final rows = await _db.query('reviews', orderBy: 'last_seen ASC');
    return rows.map(ReviewItem.fromRow).toList();
  }

  @override
  Future<void> upsertReviews(List<ReviewItem> items) async {
    // **`ConflictAlgorithm.replace` を使わないこと。**
    // replace は行ごと入れ替えるので、会話するたびに `times_seen` が
    // 0 に戻り、間隔の階段が1段も上がらなくなる。
    // 更新句に `times_seen` と `last_reviewed_at` を**入れない**のが要点。
    final batch = _db.batch();
    for (final i in items) {
      batch.rawInsert(
        '''
        INSERT INTO reviews(unit_id, concept_key, label, reason, last_seen,
                            times_seen, last_reviewed_at)
        VALUES(?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(unit_id, concept_key) DO UPDATE SET
          label = excluded.label,
          reason = excluded.reason,
          last_seen = excluded.last_seen
        ''',
        [
          i.unitId,
          i.conceptKey,
          i.label,
          i.reason.wire,
          i.lastSeen.millisecondsSinceEpoch,
          i.timesSeen,
          i.lastReviewedAt?.millisecondsSinceEpoch,
        ],
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> markReviewed(String unitId, String conceptKey) async {
    await _db.rawUpdate(
      'UPDATE reviews SET times_seen = times_seen + 1, last_reviewed_at = ? '
      'WHERE unit_id = ? AND concept_key = ?',
      [DateTime.now().millisecondsSinceEpoch, unitId, conceptKey],
    );
  }

  @override
  Future<void> clearReview(String unitId, String conceptKey) async {
    await _db.delete(
      'reviews',
      where: 'unit_id = ? AND concept_key = ?',
      whereArgs: [unitId, conceptKey],
    );
  }

  @override
  Future<void> recordActivity(
    String day, {
    int sessions = 0,
    int done = 0,
    int textTurns = 0,
  }) async {
    await _db.rawInsert(
      '''
      INSERT INTO days(day, sessions, done, text_turns) VALUES(?, ?, ?, ?)
      ON CONFLICT(day) DO UPDATE SET
        sessions   = sessions   + excluded.sessions,
        done       = done       + excluded.done,
        text_turns = text_turns + excluded.text_turns
      ''',
      [day, sessions, done, textTurns],
    );
  }

  @override
  Future<List<DayRecord>> days({int limit = 400}) async {
    final rows = await _db.query('days', orderBy: 'day DESC', limit: limit);
    return rows.map(_toDay).toList();
  }

  static DayRecord _toDay(Map<String, Object?> row) => DayRecord(
    day: row['day'] as String? ?? '',
    sessions: (row['sessions'] as int?) ?? 0,
    done: (row['done'] as int?) ?? 0,
    textTurns: (row['text_turns'] as int?) ?? 0,
  );

  @override
  Future<void> recordExplained(ExplainedItem item) async {
    await _db.insert(
      'explained',
      item.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<ExplainedItem>> explained({int limit = 50}) async {
    final rows = await _db.query('explained', orderBy: 'at DESC', limit: limit);
    return rows.map(ExplainedItem.fromRow).toList();
  }

  @override
  Future<List<ConceptProgress>> conceptProgress() async {
    final rows = await _db.query(
      'concept_progress',
      orderBy: 'next_due_day ASC, unit_id ASC, concept_key ASC',
    );
    return rows.map(ConceptProgress.fromRow).toList();
  }

  @override
  Future<ConceptProgress?> progressFor(String unitId, String conceptKey) async {
    final rows = await _db.query(
      'concept_progress',
      where: 'unit_id = ? AND concept_key = ?',
      whereArgs: [unitId, conceptKey],
      limit: 1,
    );
    return rows.isEmpty ? null : ConceptProgress.fromRow(rows.first);
  }

  @override
  Future<ConceptProgress> completeMission(
    int sessionId, {
    required bool cleared,
    required DateTime completedAt,
    ExplainedItem? explained,
    ReviewItem? review,
  }) => _db.transaction((tx) async {
    final sessionRows = await tx.query(
      'sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );
    if (sessionRows.isEmpty) {
      throw StateError('session $sessionId does not exist');
    }
    final session = sessionRows.first;
    final unitId = session['unit_id'] as String? ?? '';
    final conceptKey = session['focus_concept_key'] as String? ?? '';
    if (unitId.isEmpty || conceptKey.isEmpty) {
      throw StateError('completeMission requires a focused session');
    }

    final currentRows = await tx.query(
      'concept_progress',
      where: 'unit_id = ? AND concept_key = ?',
      whereArgs: [unitId, conceptKey],
      limit: 1,
    );
    final current = currentRows.isEmpty
        ? null
        : ConceptProgress.fromRow(currentRows.first);

    // 再試行は読み取りだけで終える。現在の概念状態が後続セッションで
    // 更新済みでも、古いsessionをもう一度加算してはいけない。
    if ((session['completion_applied'] as int? ?? 0) != 0) {
      if (current == null) {
        throw StateError('completed session has no concept progress');
      }
      return current;
    }

    _validateCompletionPayload(
      unitId: unitId,
      conceptKey: conceptKey,
      cleared: cleared,
      explained: explained,
      review: review,
    );

    final localCompletedAt = completedAt.toLocal();
    final day = dayKeyOf(localCompletedAt);
    final examRows = await tx.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['exam_date'],
      limit: 1,
    );
    final examMillis = examRows.isEmpty
        ? null
        : int.tryParse(examRows.first['value'] as String? ?? '');
    final progress = _nextConceptProgress(
      unitId: unitId,
      conceptKey: conceptKey,
      kind: MissionKind.parse(session['mission_kind']),
      cleared: cleared,
      day: day,
      completedAt: localCompletedAt,
      examDate: examMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(examMillis),
      sourceSessionId: sessionId,
      previous: current,
    );

    if (cleared) {
      await tx.insert(
        'explained',
        explained!.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await tx.delete(
        'reviews',
        where: 'unit_id = ? AND concept_key = ?',
        whereArgs: [unitId, conceptKey],
      );
      await tx.rawInsert(
        '''
        INSERT INTO days(day, sessions, done, text_turns) VALUES(?, 0, 1, 0)
        ON CONFLICT(day) DO UPDATE SET done = done + 1
        ''',
        [day],
      );
    } else {
      final item = review!;
      // 見直し回数は既存APIと同じく保つ。last_seenだけは、この原子的な
      // 完了時刻を正として揃える。
      await tx.rawInsert(
        '''
        INSERT INTO reviews(unit_id, concept_key, label, reason, last_seen,
                            times_seen, last_reviewed_at)
        VALUES(?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(unit_id, concept_key) DO UPDATE SET
          label = excluded.label,
          reason = excluded.reason,
          last_seen = excluded.last_seen
        ''',
        [
          unitId,
          conceptKey,
          item.label,
          item.reason.wire,
          localCompletedAt.millisecondsSinceEpoch,
          item.timesSeen,
          item.lastReviewedAt?.millisecondsSinceEpoch,
        ],
      );
    }

    await tx.rawInsert(
      '''
      INSERT INTO concept_progress(
        unit_id, concept_key, last_outcome, successful_retrievals,
        last_attempt_day, last_success_day, next_due_day, source_session_id
      ) VALUES(?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(unit_id, concept_key) DO UPDATE SET
        last_outcome = excluded.last_outcome,
        successful_retrievals = excluded.successful_retrievals,
        last_attempt_day = excluded.last_attempt_day,
        last_success_day = excluded.last_success_day,
        next_due_day = excluded.next_due_day,
        source_session_id = excluded.source_session_id
      ''',
      [
        progress.unitId,
        progress.conceptKey,
        progress.lastOutcome.wire,
        progress.successfulRetrievals,
        progress.lastAttemptDay,
        progress.lastSuccessDay,
        progress.nextDueDay,
        progress.sourceSessionId,
      ],
    );

    final changed = await tx.update(
      'sessions',
      {
        'updated_at': localCompletedAt.millisecondsSinceEpoch,
        'ended_at': localCompletedAt.millisecondsSinceEpoch,
        'completion_applied': 1,
      },
      where: 'id = ? AND completion_applied = 0',
      whereArgs: [sessionId],
    );
    if (changed != 1) {
      throw StateError('session completion raced with another writer');
    }
    return progress;
  });

  @override
  Future<DateTime?> examDate() async {
    final v = int.tryParse(await getSetting('exam_date') ?? '');
    return v == null ? null : DateTime.fromMillisecondsSinceEpoch(v);
  }

  @override
  Future<void> setExamDate(DateTime? date) =>
      setSetting('exam_date', date?.millisecondsSinceEpoch.toString());

  @override
  Future<String?> getSetting(String key) async {
    final rows = await _db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  @override
  Future<void> setSetting(String key, String? value) async {
    if (value == null) {
      await _db.delete('settings', where: 'key = ?', whereArgs: [key]);
      return;
    }
    await _db.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<LearningQuestMaterializationResult>
  materializeLearningQuestDefinitions({
    required LearningScope scope,
    required Iterable<LearningQuestDefinition> definitions,
  }) async {
    final validated = _validateLearningQuestMaterialization(
      scope: scope,
      definitions: definitions,
    );
    if (validated.isEmpty) {
      return LearningQuestMaterializationResult(
        insertedCount: 0,
        quests: const [],
      );
    }
    return _db.transaction((tx) async {
      final materialized = <LearningQuestProgress>[];
      var insertedCount = 0;
      for (final definition in validated) {
        final parts = definition.questInstanceId.split(':');
        if (parts.first == 'daily') {
          final sameDayRows = await tx.query(
            'learning_quest_progress',
            columns: ['quest_instance_id'],
            where: 'scope = ? AND quest_instance_id LIKE ?',
            whereArgs: [LearningScope.personal.wire, 'daily:${parts[1]}:%'],
          );
          if (sameDayRows.any(
            (row) => row['quest_instance_id'] != definition.questInstanceId,
          )) {
            throw StateError(
              'another daily quest is already materialized for this day',
            );
          }
        }
        final rows = await tx.query(
          'learning_quest_progress',
          where: 'scope = ? AND quest_instance_id = ?',
          whereArgs: [LearningScope.personal.wire, definition.questInstanceId],
          limit: 1,
        );
        if (rows.isNotEmpty) {
          final existing = _learningQuestFromRow(rows.single);
          _requireCompatibleMaterializedQuest(existing, definition);
          materialized.add(existing);
          continue;
        }
        final created = LearningQuestProgress(
          scope: LearningScope.personal,
          questInstanceId: definition.questInstanceId,
          progress: 0,
          target: definition.target,
          completedAt: null,
          rewardedAt: null,
          definitionVersion: definition.definitionVersion,
        );
        await tx.insert('learning_quest_progress', {
          'scope': created.scope.wire,
          'quest_instance_id': created.questInstanceId,
          'progress': created.progress,
          'target': created.target,
          'completed_at': null,
          'rewarded_at': null,
          'definition_version': created.definitionVersion,
        });
        insertedCount++;
        materialized.add(created);
      }
      return LearningQuestMaterializationResult(
        insertedCount: insertedCount,
        quests: materialized,
      );
    });
  }

  @override
  Future<CommitLearningResult> commitLearningEvent(
    LearningEventCommand event, {
    LearningCommitRules rules = const LearningCommitRules(),
  }) {
    _validateLearningRules(rules);
    return _db.transaction((tx) async {
      final existingRows = await tx.query(
        'learning_events',
        where: 'id = ?',
        whereArgs: [event.eventId],
        limit: 1,
      );
      if (existingRows.isNotEmpty) {
        final existing = _learningEventFromRow(existingRows.single);
        final existingSkillRows = await tx.query(
          'learning_event_skills',
          columns: ['skill_id'],
          where: 'event_id = ?',
          whereArgs: [event.eventId],
        );
        final existingSkills = {
          for (final row in existingSkillRows) row['skill_id'] as String,
        };
        final existingNeedRows = await tx.query(
          'learning_practice_needs',
          columns: ['skill_id', 'need_code', 'resolved'],
          where: 'event_id = ?',
          whereArgs: [event.eventId],
        );
        final existingNeeds = <String, Set<String>>{};
        final existingResolvedNeeds = <String, Set<String>>{};
        for (final row in existingNeedRows) {
          final target = row['resolved'] == 1
              ? existingResolvedNeeds
              : existingNeeds;
          target
              .putIfAbsent(row['skill_id'] as String, () => <String>{})
              .add(row['need_code'] as String);
        }
        if (!_sameLearningEvent(existing, event) ||
            !_sameStringSet(existingSkills, event.skillIds) ||
            !_sameNeedCodes(existingNeeds, event.practiceNeedCodes) ||
            !_sameNeedCodes(
              existingResolvedNeeds,
              event.resolvedPracticeNeedCodes,
            )) {
          throw StateError('learning event ID was reused with different data');
        }
        return _learningCommitResult(
          tx,
          event: existing,
          inserted: false,
          skillIds: event.skillIds,
        );
      }

      if (event.runId case final runId?) {
        final runRows = await tx.query(
          'learning_runs',
          where: 'run_id = ?',
          whereArgs: [runId],
          limit: 1,
        );
        if (runRows.isNotEmpty) {
          final run = _learningRunFromRow(runRows.single);
          if (run.scope != event.scope || run.nodeId != event.nodeId) {
            throw StateError('learning run does not match the event');
          }
        }
      }

      await tx.insert('learning_events', {
        'id': event.eventId,
        'scope': event.scope.wire,
        'origin': event.origin.wire,
        'course_id': event.courseId,
        'node_id': event.nodeId,
        'activity_id': event.activityId,
        'activity_kind': event.activityKind.wire,
        'outcome': event.outcome.wire,
        'evidence_rank': event.evidence.rank,
        'content_version': event.contentVersion,
        'learning_day': event.learningDay,
        'occurred_at': event.occurredAt.millisecondsSinceEpoch,
        'run_id': event.runId,
        'source_session_id': event.sourceSessionId,
        'reward_eligible': event.allowsRewards ? 1 : 0,
        'meaningful_progress': 0,
      });
      for (final skillId in event.skillIds) {
        await tx.insert('learning_event_skills', {
          'event_id': event.eventId,
          'skill_id': skillId,
        });
      }
      for (final entry in event.practiceNeedCodes.entries) {
        for (final needCode in entry.value) {
          await tx.insert('learning_practice_needs', {
            'event_id': event.eventId,
            'skill_id': entry.key,
            'need_code': needCode,
            'resolved': 0,
          });
        }
      }
      for (final entry in event.resolvedPracticeNeedCodes.entries) {
        for (final needCode in entry.value) {
          await tx.insert('learning_practice_needs', {
            'event_id': event.eventId,
            'skill_id': entry.key,
            'need_code': needCode,
            'resolved': 1,
          });
        }
      }

      await _applyLearningNeedChangesSql(tx, event);

      final oldNodeRows = await tx.query(
        'learning_node_progress',
        where: 'scope = ? AND node_id = ?',
        whereArgs: [event.scope.wire, event.nodeId],
        limit: 1,
      );
      final oldNode = oldNodeRows.isEmpty
          ? null
          : _learningNodeFromRow(oldNodeRows.single);
      final eventClearsNode = event.qualifiesForLearningDay;
      final nodeState =
          oldNode?.state == LearningNodeState.cleared || eventClearsNode
          ? LearningNodeState.cleared
          : LearningNodeState.inProgress;
      final completedAt =
          oldNode?.completedAt ?? (eventClearsNode ? event.occurredAt : null);
      await tx.rawInsert(
        '''
        INSERT INTO learning_node_progress(
          scope, node_id, state, attempt_count, best_evidence_rank,
          last_attempt_day, last_event_id, completed_at, content_version
        ) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(scope, node_id) DO UPDATE SET
          state = excluded.state,
          attempt_count = excluded.attempt_count,
          best_evidence_rank = excluded.best_evidence_rank,
          last_attempt_day = excluded.last_attempt_day,
          last_event_id = excluded.last_event_id,
          completed_at = excluded.completed_at,
          content_version = excluded.content_version
        ''',
        [
          event.scope.wire,
          event.nodeId,
          nodeState.wire,
          (oldNode?.attemptCount ?? 0) + 1,
          oldNode == null
              ? event.evidence.rank
              : math.max(oldNode.bestEvidence.rank, event.evidence.rank),
          event.learningDay,
          event.eventId,
          completedAt?.millisecondsSinceEpoch,
          event.contentVersion,
        ],
      );

      var hasDueSpacedRetrieval = false;
      for (final skillId in event.skillIds) {
        final oldSkillRows = await tx.query(
          'learning_skill_progress',
          where: 'scope = ? AND skill_id = ?',
          whereArgs: [event.scope.wire, skillId],
          limit: 1,
        );
        final oldSkill = oldSkillRows.isEmpty
            ? null
            : _learningSkillFromRow(oldSkillRows.single);
        hasDueSpacedRetrieval |= _isDueSpacedRetrieval(
          event: event,
          previous: oldSkill,
        );
        final nextSkill = _nextLearningSkillProgress(
          event: event,
          skillId: skillId,
          previous: oldSkill,
          spacingPolicy: rules.spacingPolicy,
        );
        await tx.rawInsert(
          '''
          INSERT INTO learning_skill_progress(
            scope, skill_id, last_outcome, successful_retrievals,
            last_attempt_day, last_success_day, next_due_day, last_event_id
          ) VALUES(?, ?, ?, ?, ?, ?, ?, ?)
          ON CONFLICT(scope, skill_id) DO UPDATE SET
            last_outcome = excluded.last_outcome,
            successful_retrievals = excluded.successful_retrievals,
            last_attempt_day = excluded.last_attempt_day,
            last_success_day = excluded.last_success_day,
            next_due_day = excluded.next_due_day,
            last_event_id = excluded.last_event_id
          ''',
          [
            nextSkill.scope.wire,
            nextSkill.skillId,
            nextSkill.lastOutcome.wire,
            nextSkill.successfulRetrievals,
            nextSkill.lastAttemptDay,
            nextSkill.lastSuccessDay,
            nextSkill.nextDueDay,
            nextSkill.lastEventId,
          ],
        );
      }
      final meaningfulProgress = _isMeaningfulLearningProgress(
        event: event,
        previousNode: oldNode,
        hasDueSpacedRetrieval: hasDueSpacedRetrieval,
      );
      if (meaningfulProgress) {
        await tx.update(
          'learning_events',
          {'meaningful_progress': 1},
          where: 'id = ?',
          whereArgs: [event.eventId],
        );
      }

      await _maybeUseLearningFreezeSql(tx, event);

      if (event.qualifiesForLearningDay) {
        await tx.rawInsert(
          '''
          INSERT INTO learning_days(
            scope, day, qualifying_count, first_event_at, last_event_at
          ) VALUES(?, ?, 1, ?, ?)
          ON CONFLICT(scope, day) DO UPDATE SET
            qualifying_count = qualifying_count + 1,
            first_event_at = MIN(first_event_at, excluded.first_event_at),
            last_event_at = MAX(last_event_at, excluded.last_event_at)
          ''',
          [
            event.scope.wire,
            event.learningDay,
            event.occurredAt.millisecondsSinceEpoch,
            event.occurredAt.millisecondsSinceEpoch,
          ],
        );
      }

      final xpRows = await tx.rawQuery(
        '''
        SELECT COALESCE(SUM(reward.amount), 0) AS total
        FROM learning_reward_ledger AS reward
        JOIN learning_events AS event ON event.id = reward.source_event_id
        WHERE reward.scope = 'personal' AND reward.reward_type = 'xp'
          AND event.learning_day = ?
        ''',
        [event.learningDay],
      );
      final xpEarnedOnDay = (xpRows.single['total'] as num?)?.toInt() ?? 0;
      final xp = rules.rewardPolicy.xpForEvent(
        event: event,
        meaningfulProgress: meaningfulProgress,
        xpEarnedOnDay: xpEarnedOnDay,
      );
      if (xp < 0 || xp > 100000) {
        throw StateError('reward policy returned an invalid amount');
      }
      if (xp > 0) {
        if (!event.allowsRewards) {
          throw StateError('reward policy tried to reward an ineligible event');
        }
        await tx.insert('learning_reward_ledger', {
          'entry_id': 'xp:${event.eventId}',
          'scope': LearningScope.personal.wire,
          'reward_type': LearningRewardType.xp.wire,
          'amount': xp,
          'reason': 'meaningful-progress.v2',
          'source_event_id': event.eventId,
          'created_at': event.occurredAt.millisecondsSinceEpoch,
        });
      }

      if (event.allowsRewards && meaningfulProgress) {
        for (final quest in rules.quests) {
          if (!quest.matches(event)) continue;
          final questRows = await tx.query(
            'learning_quest_progress',
            where: 'scope = ? AND quest_instance_id = ?',
            whereArgs: [LearningScope.personal.wire, quest.questInstanceId],
            limit: 1,
          );
          LearningQuestProgress? oldQuest;
          if (questRows.isNotEmpty) {
            oldQuest = _learningQuestFromRow(questRows.single);
            _requireCompatibleMaterializedQuest(oldQuest, quest);
          } else {
            await tx.insert('learning_quest_progress', {
              'scope': LearningScope.personal.wire,
              'quest_instance_id': quest.questInstanceId,
              'progress': 0,
              'target': quest.target,
              'completed_at': null,
              'rewarded_at': null,
              'definition_version': quest.definitionVersion,
            });
          }
          await tx.insert('learning_quest_events', {
            'quest_instance_id': quest.questInstanceId,
            'event_id': event.eventId,
          });
          final progress = math.min(
            quest.target,
            (oldQuest?.progress ?? 0) + 1,
          );
          final newlyCompleted =
              progress >= quest.target && oldQuest?.completedAt == null;
          final completedAt =
              oldQuest?.completedAt ??
              (newlyCompleted ? event.occurredAt : null);
          DateTime? rewardedAt = oldQuest?.rewardedAt;
          if (newlyCompleted) {
            rewardedAt = event.occurredAt;
            if (quest.rewardGems > 0) {
              await tx.insert('learning_reward_ledger', {
                'entry_id': 'gems.quest:${quest.questInstanceId}',
                'scope': LearningScope.personal.wire,
                'reward_type': LearningRewardType.gems.wire,
                'amount': quest.rewardGems,
                'reason': 'quest.${quest.questInstanceId}',
                'source_event_id': event.eventId,
                'created_at': event.occurredAt.millisecondsSinceEpoch,
              });
            }
          }
          await tx.update(
            'learning_quest_progress',
            {
              'progress': progress,
              'completed_at': completedAt?.millisecondsSinceEpoch,
              'rewarded_at': rewardedAt?.millisecondsSinceEpoch,
            },
            where: 'scope = ? AND quest_instance_id = ?',
            whereArgs: [LearningScope.personal.wire, quest.questInstanceId],
          );
        }
      }

      await _rebuildLearningLeagueHistorySql(tx, event.occurredAt);

      if (event.runId case final runId?) {
        await tx.delete(
          'learning_runs',
          where: 'run_id = ?',
          whereArgs: [runId],
        );
      }

      return _learningCommitResult(
        tx,
        event: _learningEventFromCommand(
          event,
          meaningfulProgress: meaningfulProgress,
        ),
        inserted: true,
        skillIds: event.skillIds,
      );
    });
  }

  @override
  Future<LearningProgressSnapshot> learningProgressSnapshot(
    LearningScope scope,
  ) async => _learningSnapshot(_db, scope);

  @override
  Future<List<LearningNeedStateView>> learningNeedStates(
    LearningScope scope,
  ) async {
    final rows = await _db.query(
      'learning_need_state',
      where: 'scope = ?',
      whereArgs: [scope.wire],
      orderBy: 'skill_id ASC, need_code ASC',
    );
    return List.unmodifiable(
      rows.map(_learningNeedStateFromRow).map(
        (state) => LearningNeedStateView(
          scope: state.scope,
          skillId: state.skillId,
          needCode: state.needCode,
          firstObservedDay: state.firstObservedDay,
          lastObservedDay: state.lastObservedDay,
          resolvedDay: state.resolvedDay,
        ),
      ),
    );
  }

  @override
  Future<LearningLanFriendsRewardResult> grantLearningLanFriendsReward({
    required String roomId,
    required DateTime completedAt,
  }) {
    _validateLearningLanFriendsReward(roomId: roomId, completedAt: completedAt);
    return _db.transaction((tx) async {
      final expected = _learningLanFriendsReward(
        roomId: roomId,
        completedAt: completedAt,
      );
      final rows = await tx.query(
        'learning_reward_ledger',
        where: 'entry_id = ?',
        whereArgs: [expected.entryId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final existing = _learningRewardFromRow(rows.single);
        if (!_sameLearningLanFriendsReward(existing, expected)) {
          throw StateError('LAN friends reward ID was reused');
        }
        return LearningLanFriendsRewardResult(applied: false, reward: existing);
      }
      await tx.insert('learning_reward_ledger', {
        'entry_id': expected.entryId,
        'scope': expected.scope.wire,
        'reward_type': expected.type.wire,
        'amount': expected.amount,
        'reason': expected.reason,
        'source_event_id': null,
        'created_at': expected.createdAt.millisecondsSinceEpoch,
      });
      return LearningLanFriendsRewardResult(applied: true, reward: expected);
    });
  }

  @override
  Future<LearningRun> beginLearningRun(LearningRun run) {
    _validateLearningRun(run);
    return _db.transaction((tx) async {
      var normalized = run;
      if (run.scope == LearningScope.schoolLocal &&
          run.challengeHearts != null) {
        normalized = _copyLearningRun(run, challengeHearts: null);
      } else if (run.challengeHearts != null) {
        if (run.challengeHearts != LearningChallengeHeartState.defaultMaximum) {
          throw ArgumentError.value(
            run.challengeHearts,
            'challengeHearts',
            'a new challenge must start at the configured maximum',
          );
        }
        final stateRows = await tx.query(
          'learning_challenge_heart_state',
          where: 'scope = ?',
          whereArgs: [LearningScope.personal.wire],
          limit: 1,
        );
        final state = stateRows.isEmpty
            ? LearningChallengeHeartState(
                scope: LearningScope.personal,
                current: LearningChallengeHeartState.defaultMaximum,
                maximum: LearningChallengeHeartState.defaultMaximum,
                lastLossDay: null,
                lastRecoveryDay: null,
                updatedAt: run.updatedAt,
              )
            : _learningHeartStateFromRow(stateRows.single);
        if (stateRows.isEmpty) {
          await tx.insert(
            'learning_challenge_heart_state',
            _learningHeartStateRow(state),
          );
        }
        normalized = _copyLearningRun(run, challengeHearts: state.current);
      }

      final existingRows = await tx.query(
        'learning_runs',
        where: 'run_id = ?',
        whereArgs: [run.runId],
        limit: 1,
      );
      if (existingRows.isNotEmpty) {
        final existing = _learningRunFromRow(existingRows.single);
        if (!_sameLearningRun(existing, normalized)) {
          throw StateError('learning run ID was reused with different data');
        }
        return existing;
      }
      await tx.insert('learning_runs', _learningRunRow(normalized));
      return normalized;
    });
  }

  @override
  Future<LearningRun> checkpointLearningRun(
    String runId, {
    required int activityIndex,
    int? challengeHearts,
    required DateTime updatedAt,
  }) => _db.transaction((tx) async {
    final rows = await tx.query(
      'learning_runs',
      where: 'run_id = ?',
      whereArgs: [runId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('learning run does not exist');
    final current = _learningRunFromRow(rows.single);
    if (activityIndex < current.activityIndex) {
      throw StateError('learning run cannot move backwards');
    }
    if (challengeHearts != null && challengeHearts != current.challengeHearts) {
      throw StateError(
        'challenge hearts must be changed with spendLearningChallengeHeart',
      );
    }
    if (updatedAt.isBefore(current.updatedAt)) {
      throw StateError('learning run timestamp cannot move backwards');
    }
    final next = LearningRun(
      runId: current.runId,
      scope: current.scope,
      nodeId: current.nodeId,
      activityIndex: activityIndex,
      challengeHearts: challengeHearts ?? current.challengeHearts,
      contentVersion: current.contentVersion,
      updatedAt: updatedAt,
    );
    await tx.update(
      'learning_runs',
      _learningRunRow(next),
      where: 'run_id = ?',
      whereArgs: [runId],
    );
    return next;
  });

  @override
  Future<void> discardLearningRun(String runId) async {
    if (!_learningOpaqueId.hasMatch(runId)) {
      throw ArgumentError.value(runId, 'runId', 'opaque ASCII ID required');
    }
    await _db.delete('learning_runs', where: 'run_id = ?', whereArgs: [runId]);
  }

  @override
  Future<LearningChallengeHeartSpendResult> spendLearningChallengeHeart(
    String runId, {
    required String lossId,
    required int activityIndex,
    required String learningDay,
    required DateTime occurredAt,
  }) {
    _validateChallengeHeartLoss(
      runId: runId,
      lossId: lossId,
      activityIndex: activityIndex,
      learningDay: learningDay,
      occurredAt: occurredAt,
    );
    return _db.transaction((tx) async {
      final oldLossRows = await tx.query(
        'learning_challenge_heart_losses',
        where: 'loss_id = ?',
        whereArgs: [lossId],
        limit: 1,
      );
      if (oldLossRows.isNotEmpty) {
        final oldLoss = _challengeHeartLossFromRow(oldLossRows.single);
        if (!oldLoss.matches(
          runId: runId,
          activityIndex: activityIndex,
          learningDay: learningDay,
          occurredAt: occurredAt,
        )) {
          throw StateError('challenge heart loss ID was reused');
        }
        final state = await _learningHeartStateSql(tx);
        final runRows = await tx.query(
          'learning_runs',
          where: 'run_id = ?',
          whereArgs: [runId],
          limit: 1,
        );
        return LearningChallengeHeartSpendResult(
          spent: false,
          state: state,
          run: runRows.isEmpty ? null : _learningRunFromRow(runRows.single),
        );
      }

      final runRows = await tx.query(
        'learning_runs',
        where: 'run_id = ?',
        whereArgs: [runId],
        limit: 1,
      );
      if (runRows.isEmpty) throw StateError('learning run does not exist');
      final currentRun = _learningRunFromRow(runRows.single);
      if (currentRun.scope != LearningScope.personal ||
          currentRun.challengeHearts == null) {
        throw StateError('run does not use personal challenge hearts');
      }
      if (activityIndex < currentRun.activityIndex) {
        throw StateError('learning run cannot move backwards');
      }
      if (occurredAt.isBefore(currentRun.updatedAt)) {
        throw StateError('learning run timestamp cannot move backwards');
      }
      final storedState = await _learningHeartStateSql(tx);
      final refreshed = _refreshLearningHeartStateByTime(
        state: storedState,
        learningDay: learningDay,
        occurredAt: occurredAt,
      );
      if (refreshed.recovered > 0) {
        await _writeLearningHeartStateSql(tx, refreshed.state);
      }
      final currentState = refreshed.state;
      if (currentState.current <= 0) {
        throw StateError('challenge hearts are already empty');
      }
      final nextState = LearningChallengeHeartState(
        scope: LearningScope.personal,
        current: currentState.current - 1,
        maximum: currentState.maximum,
        lastLossDay: learningDay,
        lastRecoveryDay: currentState.lastRecoveryDay,
        updatedAt: occurredAt,
      );
      await tx.update(
        'learning_challenge_heart_state',
        _learningHeartStateRow(nextState),
        where: 'scope = ?',
        whereArgs: [LearningScope.personal.wire],
      );
      await tx.rawUpdate(
        '''
        UPDATE learning_runs SET challenge_hearts = ?
        WHERE scope = ? AND challenge_hearts IS NOT NULL
        ''',
        [nextState.current, LearningScope.personal.wire],
      );
      final nextRun = _copyLearningRun(
        currentRun,
        activityIndex: activityIndex,
        challengeHearts: nextState.current,
        updatedAt: occurredAt,
      );
      await tx.update(
        'learning_runs',
        _learningRunRow(nextRun),
        where: 'run_id = ?',
        whereArgs: [runId],
      );
      await tx.insert('learning_challenge_heart_losses', {
        'loss_id': lossId,
        'scope': LearningScope.personal.wire,
        'run_id': runId,
        'activity_index': activityIndex,
        'learning_day': learningDay,
        'occurred_at': occurredAt.millisecondsSinceEpoch,
        'remaining_hearts': nextState.current,
      });
      return LearningChallengeHeartSpendResult(
        spent: true,
        state: nextState,
        run: nextRun,
      );
    });
  }

  @override
  Future<LearningChallengeHeartRefreshResult> refreshLearningChallengeHearts({
    required String learningDay,
    required DateTime occurredAt,
  }) {
    _validateChallengeHeartClock(
      learningDay: learningDay,
      occurredAt: occurredAt,
    );
    return _db.transaction((tx) async {
      final state = await _learningHeartStateOrInitialSql(tx);
      final result = _refreshLearningHeartStateByTime(
        state: state,
        learningDay: learningDay,
        occurredAt: occurredAt,
      );
      if (result.recovered > 0) {
        await _writeLearningHeartStateSql(tx, result.state);
      }
      return result;
    });
  }

  @override
  Future<LearningChallengeHeartPracticeRecoveryResult>
  recoverLearningChallengeHeartWithPractice({
    required String recoveryId,
    required String sourceEventId,
    required String learningDay,
    required DateTime occurredAt,
  }) {
    _validateChallengeHeartPracticeRecovery(
      recoveryId: recoveryId,
      sourceEventId: sourceEventId,
      learningDay: learningDay,
      occurredAt: occurredAt,
    );
    return _db.transaction((tx) async {
      final oldRows = await tx.query(
        'learning_challenge_heart_practice_recoveries',
        where: 'recovery_id = ?',
        whereArgs: [recoveryId],
        limit: 1,
      );
      if (oldRows.isNotEmpty) {
        final old = _challengeHeartPracticeRecoveryFromRow(oldRows.single);
        if (!old.matches(
          sourceEventId: sourceEventId,
          learningDay: learningDay,
          occurredAt: occurredAt,
        )) {
          throw StateError('heart recovery ID was reused');
        }
        return LearningChallengeHeartPracticeRecoveryResult(
          applied: false,
          recovered: old.recoveredHearts,
          state: await _learningHeartStateOrInitialSql(tx),
        );
      }
      final eventRows = await tx.query(
        'learning_events',
        where: 'id = ?',
        whereArgs: [sourceEventId],
        limit: 1,
      );
      if (eventRows.isEmpty) {
        throw StateError('heart recovery practice event does not exist');
      }
      final event = _learningEventFromRow(eventRows.single);
      if (event.scope != LearningScope.personal ||
          event.origin != LearningOrigin.practice ||
          event.activityId != 'practice.heart-recovery.v1' ||
          event.outcome == LearningAttemptOutcome.retryNeeded ||
          event.learningDay != learningDay ||
          occurredAt.isBefore(event.occurredAt)) {
        throw StateError('event is not an eligible heart recovery practice');
      }
      final timed = _refreshLearningHeartStateByTime(
        state: await _learningHeartStateOrInitialSql(tx),
        learningDay: learningDay,
        occurredAt: occurredAt,
      );
      final recovered = timed.state.current < timed.state.maximum ? 1 : 0;
      final current = timed.state.current + recovered;
      final next = LearningChallengeHeartState(
        scope: LearningScope.personal,
        current: current,
        maximum: timed.state.maximum,
        lastLossDay: current >= timed.state.maximum
            ? null
            : timed.state.lastLossDay,
        lastRecoveryDay: recovered > 0
            ? learningDay
            : timed.state.lastRecoveryDay,
        updatedAt: recovered > 0 ? occurredAt : timed.state.updatedAt,
      );
      if (timed.recovered > 0 || recovered > 0) {
        await _writeLearningHeartStateSql(tx, next);
      }
      await tx.insert('learning_challenge_heart_practice_recoveries', {
        'recovery_id': recoveryId,
        'scope': LearningScope.personal.wire,
        'source_event_id': sourceEventId,
        'learning_day': learningDay,
        'occurred_at': occurredAt.millisecondsSinceEpoch,
        'recovered_hearts': recovered,
        'resulting_hearts': next.current,
      });
      return LearningChallengeHeartPracticeRecoveryResult(
        applied: true,
        recovered: recovered,
        state: next,
      );
    });
  }

  @override
  Future<LearningLocalCoopRun> beginLearningLocalCoopRun(
    LearningLocalCoopRunCommand command,
  ) {
    _validateLearningLocalCoopRun(command);
    return _db.transaction((tx) async {
      final existing = await _learningLocalCoopRunSql(tx, command.runId);
      if (existing != null) {
        if (!_sameLearningLocalCoopRun(existing, command)) {
          throw StateError('local coop run ID was reused with different data');
        }
        return existing;
      }
      await tx.insert('learning_local_coop_runs', {
        'run_id': command.runId,
        'scope': LearningScope.personal.wire,
        'quest_instance_id': command.questInstanceId,
        'target': command.target,
        'reward_gems': command.rewardGems,
        'start_day': command.startDay,
        'end_day': command.endDay,
        'definition_version': command.definitionVersion,
        'started_at': command.startedAt.millisecondsSinceEpoch,
        'completed_at': null,
        'rewarded_at': null,
      });
      for (final participantId in command.participantIds) {
        await tx.insert('learning_local_coop_participants', {
          'run_id': command.runId,
          'participant_id': participantId,
        });
      }
      await tx.insert('learning_quest_progress', {
        'scope': LearningScope.personal.wire,
        'quest_instance_id': command.questInstanceId,
        'progress': 0,
        'target': command.target,
        'completed_at': null,
        'rewarded_at': null,
        'definition_version': command.definitionVersion,
      });
      return (await _learningLocalCoopRunSql(tx, command.runId))!;
    });
  }

  @override
  Future<LearningLocalCoopContributionResult> contributeLearningLocalCoopRun(
    String runId, {
    required String contributionId,
    required String participantId,
    required String eventId,
    required DateTime occurredAt,
  }) {
    _validateLearningLocalCoopContribution(
      runId: runId,
      contributionId: contributionId,
      participantId: participantId,
      eventId: eventId,
      occurredAt: occurredAt,
    );
    return _db.transaction((tx) async {
      final oldContributionRows = await tx.query(
        'learning_local_coop_contributions',
        where: 'contribution_id = ?',
        whereArgs: [contributionId],
        limit: 1,
      );
      if (oldContributionRows.isNotEmpty) {
        final row = oldContributionRows.single;
        if (row['run_id'] != runId ||
            row['participant_id'] != participantId ||
            row['event_id'] != eventId ||
            (row['contributed_at'] as num?)?.toInt() !=
                occurredAt.millisecondsSinceEpoch) {
          throw StateError('local coop contribution ID was reused');
        }
        final existingRun = await _learningLocalCoopRunSql(tx, runId);
        if (existingRun == null) {
          throw StateError('local coop run does not exist');
        }
        final rewardRows = await tx.query(
          'learning_reward_ledger',
          where: 'entry_id = ?',
          whereArgs: ['gems.quest:${existingRun.questInstanceId}'],
        );
        return LearningLocalCoopContributionResult(
          applied: false,
          run: existingRun,
          rewards: List.unmodifiable(rewardRows.map(_learningRewardFromRow)),
        );
      }

      final run = await _learningLocalCoopRunSql(tx, runId);
      if (run == null) throw StateError('local coop run does not exist');
      if (run.completed) throw StateError('local coop run is already complete');
      if (!run.participantIds.contains(participantId)) {
        throw StateError('participant is not part of the local coop run');
      }
      final eventRows = await tx.query(
        'learning_events',
        where: 'id = ?',
        whereArgs: [eventId],
        limit: 1,
      );
      if (eventRows.isEmpty) throw StateError('learning event does not exist');
      final event = _learningEventFromRow(eventRows.single);
      if (event.scope != LearningScope.personal || !event.meaningfulProgress) {
        throw StateError('local coop requires a personal meaningful event');
      }
      if (event.learningDay.compareTo(run.startDay) < 0 ||
          event.learningDay.compareTo(run.endDay) > 0) {
        throw StateError('learning event is outside the local coop period');
      }
      if (occurredAt.isBefore(event.occurredAt)) {
        throw StateError('contribution cannot predate its learning event');
      }
      final reusedEventRows = await tx.query(
        'learning_local_coop_contributions',
        where: 'event_id = ?',
        whereArgs: [eventId],
        limit: 1,
      );
      if (reusedEventRows.isNotEmpty) {
        throw StateError('learning event already contributed to a coop run');
      }
      await tx.insert('learning_local_coop_contributions', {
        'contribution_id': contributionId,
        'run_id': runId,
        'participant_id': participantId,
        'event_id': eventId,
        'contributed_at': occurredAt.millisecondsSinceEpoch,
      });
      await tx.insert('learning_quest_events', {
        'quest_instance_id': run.questInstanceId,
        'event_id': eventId,
      });
      final updated = (await _learningLocalCoopRunSql(tx, runId))!;
      final completesNow =
          updated.progress >= updated.target &&
          updated.allParticipantsContributed;
      final completedAt = completesNow ? occurredAt : null;
      final rewardedAt = completesNow ? occurredAt : null;
      if (completesNow) {
        await tx.update(
          'learning_local_coop_runs',
          {
            'completed_at': completedAt!.millisecondsSinceEpoch,
            'rewarded_at': rewardedAt!.millisecondsSinceEpoch,
          },
          where: 'run_id = ?',
          whereArgs: [runId],
        );
        if (updated.rewardGems > 0) {
          await tx.insert('learning_reward_ledger', {
            'entry_id': 'gems.quest:${updated.questInstanceId}',
            'scope': LearningScope.personal.wire,
            'reward_type': LearningRewardType.gems.wire,
            'amount': updated.rewardGems,
            'reason': 'quest.${updated.questInstanceId}',
            'source_event_id': eventId,
            'created_at': occurredAt.millisecondsSinceEpoch,
          });
        }
      }
      await tx.update(
        'learning_quest_progress',
        {
          'progress': math.min(updated.progress, updated.target),
          'completed_at': completedAt?.millisecondsSinceEpoch,
          'rewarded_at': rewardedAt?.millisecondsSinceEpoch,
        },
        where: 'scope = ? AND quest_instance_id = ?',
        whereArgs: [LearningScope.personal.wire, updated.questInstanceId],
      );
      final resultRun = (await _learningLocalCoopRunSql(tx, runId))!;
      final rewardRows = await tx.query(
        'learning_reward_ledger',
        where: 'entry_id = ?',
        whereArgs: ['gems.quest:${resultRun.questInstanceId}'],
      );
      return LearningLocalCoopContributionResult(
        applied: true,
        run: resultRun,
        rewards: List.unmodifiable(rewardRows.map(_learningRewardFromRow)),
      );
    });
  }

  @override
  Future<List<LearningLocalCoopContribution>> localCoopContributions(
    Set<String> runIds,
  ) async {
    final ids = _validatedLearningLocalCoopRunIds(runIds);
    if (ids.isEmpty) return const [];
    final placeholders = List.filled(ids.length, '?').join(', ');
    final rows = await _db.rawQuery('''
      SELECT contribution.run_id, contribution.participant_id,
             contribution.event_id, event.scope, event.learning_day,
             event.meaningful_progress
      FROM learning_local_coop_contributions AS contribution
      JOIN learning_local_coop_runs AS run
        ON run.run_id = contribution.run_id
      JOIN learning_events AS event
        ON event.id = contribution.event_id
      WHERE contribution.run_id IN ($placeholders)
      ORDER BY event.learning_day ASC, contribution.run_id ASC,
               contribution.participant_id ASC, contribution.event_id ASC
      ''', ids);
    return List.unmodifiable(rows.map(_learningLocalCoopContributionFromRow));
  }

  @override
  Future<LearningLocalLeagueFinalizeResult> finalizeLearningLocalWeeklyLeague({
    required String weekKey,
    required DateTime finalizedAt,
  }) {
    if (learningWeekKey(weekKey) != weekKey) {
      throw ArgumentError.value(weekKey, 'weekKey', 'Monday required');
    }
    return _db.transaction((tx) async {
      final historyRows = await tx.query(
        'learning_local_league_history',
        where: 'scope = ?',
        whereArgs: [LearningScope.personal.wire],
        orderBy: 'week_key DESC',
      );
      final history = List<LearningLocalLeagueWeek>.unmodifiable(
        historyRows.map(_learningLocalLeagueFromRow),
      );
      final view = await _localWeeklyLeagueViewSql(
        tx,
        weekKey: weekKey,
        history: history,
      );
      final result = LocalWeeklyLeagueFinalization.finalize(
        view: view,
        history: history,
        finalizedAt: finalizedAt,
      );
      if (result.applied) {
        await tx.insert(
          'learning_local_league_history',
          _learningLocalLeagueRow(result.week!),
        );
      }
      return result;
    });
  }

  @override
  Future<LearningLocalLeagueCatchUpResult> catchUpLearningLocalWeeklyLeagues({
    required String currentWeekKey,
    required DateTime finalizedAt,
    String? afterWeekKey,
  }) {
    if (learningWeekKey(currentWeekKey) != currentWeekKey) {
      throw ArgumentError.value(
        currentWeekKey,
        'currentWeekKey',
        'Monday required',
      );
    }
    return _db.transaction((tx) async {
      final historyRows = await tx.query(
        'learning_local_league_history',
        where: 'scope = ?',
        whereArgs: [LearningScope.personal.wire],
        orderBy: 'week_key DESC',
      );
      final history = historyRows
          .map(_learningLocalLeagueFromRow)
          .toList(growable: true);
      final runWeekRows = await tx.query(
        'learning_local_coop_runs',
        distinct: true,
        columns: ['start_day'],
        where: 'scope = ? AND definition_version IN (?, ?)',
        whereArgs: [
          LearningScope.personal.wire,
          LocalWeeklyLeagueProjection.definitionVersion,
          LocalWeeklyLeagueProjection.pairBridgeDefinitionVersion,
        ],
        orderBy: 'start_day ASC',
      );
      final plan = LocalWeeklyLeagueCatchUp.plan(
        currentWeekKey: currentWeekKey,
        history: history,
        runWeekKeys: runWeekRows.map((row) => row['start_day'] as String),
        afterWeekKey: afterWeekKey,
      );
      final results = <LearningLocalLeagueFinalizeResult>[];
      for (final weekKey in plan.candidateWeekKeys) {
        final view = await _localWeeklyLeagueViewSql(
          tx,
          weekKey: weekKey,
          history: history,
        );
        final result = LocalWeeklyLeagueFinalization.finalize(
          view: view,
          history: history,
          finalizedAt: finalizedAt,
        );
        results.add(result);
        if (!result.applied) continue;
        await tx.insert(
          'learning_local_league_history',
          _learningLocalLeagueRow(result.week!),
        );
        history.add(result.week!);
      }
      return LearningLocalLeagueCatchUpResult(
        plan: plan,
        results: List.unmodifiable(results),
      );
    });
  }

  @override
  Future<LearningGemSpendResult> replenishLearningStreakFreezeWithGems({
    required String spendId,
    required String learningDay,
    required DateTime occurredAt,
    SafeLearningEconomyPolicyV1 economyPolicy =
        const SafeLearningEconomyPolicyV1(),
  }) {
    economyPolicy.validate();
    _validateLearningGemSpend(
      spendId: spendId,
      learningDay: learningDay,
      occurredAt: occurredAt,
    );
    return _db.transaction((tx) async {
      final oldRows = await tx.query(
        'learning_gem_spends',
        where: 'spend_id = ?',
        whereArgs: [spendId],
        limit: 1,
      );
      if (oldRows.isNotEmpty) {
        final old = _learningGemSpendFromRow(oldRows.single);
        if (old.kind != LearningGemSpendKind.streakFreezeRefill ||
            old.learningDay != learningDay ||
            old.occurredAt.millisecondsSinceEpoch !=
                occurredAt.millisecondsSinceEpoch) {
          throw StateError('gem spend ID was reused with different data');
        }
        return _learningGemSpendResultSql(tx, applied: false, spend: old);
      }
      final weekKey = learningWeekKey(learningDay);
      final refillRows = await tx.query(
        'learning_gem_spends',
        where: 'scope = ? AND spend_kind = ? AND week_key = ?',
        whereArgs: [
          LearningScope.personal.wire,
          LearningGemSpendKind.streakFreezeRefill.wire,
          weekKey,
        ],
      );
      if (refillRows.length >= economyPolicy.maxPaidFreezeRefillsPerWeek) {
        throw StateError('weekly streak freeze refill limit reached');
      }
      if (await _learningFreezeRemainingSql(tx, learningDay) > 0) {
        throw StateError('streak freeze is not empty');
      }
      final cost = economyPolicy.streakFreezeRefillGemCost;
      if (await _learningGemBalanceSql(tx) < cost) {
        throw StateError('not enough gems');
      }
      final spend = LearningGemSpend(
        spendId: spendId,
        scope: LearningScope.personal,
        kind: LearningGemSpendKind.streakFreezeRefill,
        amount: cost,
        learningDay: learningDay,
        weekKey: weekKey,
        occurredAt: occurredAt,
      );
      await tx.insert('learning_gem_spends', {
        'spend_id': spend.spendId,
        'scope': spend.scope.wire,
        'spend_kind': spend.kind.wire,
        'amount': spend.amount,
        'learning_day': spend.learningDay,
        'week_key': spend.weekKey,
        'occurred_at': spend.occurredAt.millisecondsSinceEpoch,
      });
      return _learningGemSpendResultSql(tx, applied: true, spend: spend);
    });
  }

  @override
  Future<LearningGemSpendResult> recoverLearningChallengeHeartsWithGems({
    required String spendId,
    required String learningDay,
    required DateTime occurredAt,
    SafeLearningEconomyPolicyV1 economyPolicy =
        const SafeLearningEconomyPolicyV1(),
  }) {
    economyPolicy.validate();
    _validateLearningGemSpend(
      spendId: spendId,
      learningDay: learningDay,
      occurredAt: occurredAt,
    );
    return _db.transaction((tx) async {
      final oldRows = await tx.query(
        'learning_gem_spends',
        where: 'spend_id = ?',
        whereArgs: [spendId],
        limit: 1,
      );
      if (oldRows.isNotEmpty) {
        final old = _learningGemSpendFromRow(oldRows.single);
        if (old.kind != LearningGemSpendKind.challengeHeartRecovery ||
            old.learningDay != learningDay ||
            old.occurredAt.millisecondsSinceEpoch !=
                occurredAt.millisecondsSinceEpoch) {
          throw StateError('gem spend ID was reused with different data');
        }
        return _learningGemSpendResultSql(tx, applied: false, spend: old);
      }
      final state = await _learningHeartStateOrInitialSql(tx);
      if (state.current >= state.maximum) {
        throw StateError('challenge hearts are already full');
      }
      final cost = economyPolicy.challengeHeartRecoveryGemCost;
      if (await _learningGemBalanceSql(tx) < cost) {
        throw StateError('not enough gems');
      }
      final spend = LearningGemSpend(
        spendId: spendId,
        scope: LearningScope.personal,
        kind: LearningGemSpendKind.challengeHeartRecovery,
        amount: cost,
        learningDay: learningDay,
        weekKey: null,
        occurredAt: occurredAt,
      );
      await tx.insert('learning_gem_spends', {
        'spend_id': spend.spendId,
        'scope': spend.scope.wire,
        'spend_kind': spend.kind.wire,
        'amount': spend.amount,
        'learning_day': spend.learningDay,
        'week_key': null,
        'occurred_at': spend.occurredAt.millisecondsSinceEpoch,
      });
      final recovered = LearningChallengeHeartState(
        scope: LearningScope.personal,
        current: state.maximum,
        maximum: state.maximum,
        lastLossDay: null,
        lastRecoveryDay: learningDay,
        updatedAt: occurredAt,
      );
      await tx.insert(
        'learning_challenge_heart_state',
        _learningHeartStateRow(recovered),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await tx.rawUpdate(
        'UPDATE learning_runs SET challenge_hearts = ? '
        'WHERE scope = ? AND challenge_hearts IS NOT NULL',
        [recovered.current, LearningScope.personal.wire],
      );
      return _learningGemSpendResultSql(tx, applied: true, spend: spend);
    });
  }

  @override
  Future<LearningCosmeticPurchaseResult> purchaseLearningCosmeticWithGems({
    required LearningScope scope,
    required String spendId,
    required String productId,
    required String learningDay,
    required DateTime occurredAt,
    SafeLearningEconomyCatalogV1 catalog = const SafeLearningEconomyCatalogV1(),
  }) async {
    _requirePersonalLearningEconomy(scope);
    catalog.validate();
    final product = catalog.cosmetic(productId);
    if (product.isDefault) {
      throw StateError('the default cosmetic is already owned');
    }
    if (product.requiresPlusAccess) {
      throw StateError('plus-exclusive cosmetic is not sold for gems');
    }
    _validateLearningGemSpend(
      spendId: spendId,
      learningDay: learningDay,
      occurredAt: occurredAt,
    );
    return _db.transaction((tx) async {
      final oldRows = await tx.query(
        'learning_gem_spends',
        where: 'spend_id = ?',
        whereArgs: [spendId],
        limit: 1,
      );
      if (oldRows.isNotEmpty) {
        final old = _learningGemSpendFromRow(oldRows.single);
        if (!_sameLearningCatalogSpend(
          old,
          kind: LearningGemSpendKind.cosmeticPurchase,
          productId: productId,
          learningDay: learningDay,
          occurredAt: occurredAt,
          amount: product.gemCost,
        )) {
          throw StateError('gem spend ID was reused with different data');
        }
        return LearningCosmeticPurchaseResult(
          applied: false,
          productId: productId,
          remainingGems: await _learningGemBalanceSql(tx),
          cosmetics: await _learningCosmeticStateSql(tx),
        );
      }
      final ownedRows = await tx.query(
        'learning_gem_spends',
        columns: ['spend_id'],
        where: 'scope = ? AND spend_kind = ? AND reference_id = ?',
        whereArgs: [
          LearningScope.personal.wire,
          LearningGemSpendKind.cosmeticPurchase.wire,
          productId,
        ],
        limit: 1,
      );
      if (ownedRows.isNotEmpty) {
        throw StateError('cosmetic is already owned');
      }
      if (await _learningGemBalanceSql(tx) < product.gemCost) {
        throw StateError('not enough gems');
      }
      final spend = LearningGemSpend(
        spendId: spendId,
        scope: LearningScope.personal,
        kind: LearningGemSpendKind.cosmeticPurchase,
        amount: product.gemCost,
        learningDay: learningDay,
        weekKey: null,
        occurredAt: occurredAt,
        referenceId: productId,
      );
      await tx.insert('learning_gem_spends', _learningGemSpendRow(spend));
      await tx.insert('learning_cosmetic_loadout', {
        'scope': LearningScope.personal.wire,
        'slot': product.slot.wire,
        'product_id': productId,
        'updated_at': occurredAt.millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return LearningCosmeticPurchaseResult(
        applied: true,
        productId: productId,
        remainingGems: await _learningGemBalanceSql(tx),
        cosmetics: await _learningCosmeticStateSql(tx),
      );
    });
  }

  @override
  Future<LearningCosmeticEquipResult> equipLearningCosmetic({
    required LearningScope scope,
    required String productId,
    required DateTime occurredAt,
    SafeLearningEconomyCatalogV1 catalog = const SafeLearningEconomyCatalogV1(),
  }) async {
    _requirePersonalLearningEconomy(scope);
    catalog.validate();
    final product = catalog.cosmetic(productId);
    if (occurredAt.millisecondsSinceEpoch < 0) {
      throw ArgumentError.value(occurredAt, 'occurredAt');
    }
    return _db.transaction((tx) async {
      final state = await _learningCosmeticStateSql(tx);
      if (!state.owns(productId)) {
        throw StateError('cosmetic is not owned');
      }
      if (state.equippedPathMascotId == productId) {
        return LearningCosmeticEquipResult(changed: false, cosmetics: state);
      }
      final oldRows = await tx.query(
        'learning_cosmetic_loadout',
        where: 'scope = ? AND slot = ?',
        whereArgs: [LearningScope.personal.wire, product.slot.wire],
        limit: 1,
      );
      final oldUpdatedAt = (oldRows.firstOrNull?['updated_at'] as num?)
          ?.toInt();
      if (oldUpdatedAt != null &&
          occurredAt.millisecondsSinceEpoch < oldUpdatedAt) {
        throw StateError('cosmetic loadout timestamp cannot move backwards');
      }
      await tx.insert('learning_cosmetic_loadout', {
        'scope': LearningScope.personal.wire,
        'slot': product.slot.wire,
        'product_id': productId,
        'updated_at': occurredAt.millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return LearningCosmeticEquipResult(
        changed: true,
        cosmetics: await _learningCosmeticStateSql(tx),
      );
    });
  }

  @override
  Future<LearningCosmeticState> grantLearningPlusCosmetics({
    required LearningScope scope,
    required DateTime occurredAt,
    SafeLearningEconomyCatalogV1 catalog = const SafeLearningEconomyCatalogV1(),
  }) async {
    _requirePersonalLearningEconomy(scope);
    catalog.validate();
    if (occurredAt.millisecondsSinceEpoch < 0) {
      throw ArgumentError.value(occurredAt, 'occurredAt');
    }
    return _db.transaction((tx) async {
      for (final product in SafeLearningEconomyCatalogV1.plusCosmetics) {
        await tx.insert('learning_cosmetic_grants', {
          'grant_id': 'plus:${product.productId}',
          'scope': LearningScope.personal.wire,
          'product_id': product.productId,
          'granted_at': occurredAt.millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      return _learningCosmeticStateSql(tx);
    });
  }

  @override
  Future<LearningChallengePassPurchaseResult>
  purchaseLearningChallengePassWithGems({
    required LearningScope scope,
    required String spendId,
    required String productId,
    required String learningDay,
    required DateTime occurredAt,
    SafeLearningEconomyCatalogV1 catalog = const SafeLearningEconomyCatalogV1(),
  }) async {
    _requirePersonalLearningEconomy(scope);
    catalog.validate();
    final product = catalog.challengePass(productId);
    _validateLearningGemSpend(
      spendId: spendId,
      learningDay: learningDay,
      occurredAt: occurredAt,
    );
    return _db.transaction((tx) async {
      final oldRows = await tx.query(
        'learning_gem_spends',
        where: 'spend_id = ?',
        whereArgs: [spendId],
        limit: 1,
      );
      if (oldRows.isNotEmpty) {
        final old = _learningGemSpendFromRow(oldRows.single);
        if (!_sameLearningCatalogSpend(
          old,
          kind: LearningGemSpendKind.challengeEntry,
          productId: productId,
          learningDay: learningDay,
          occurredAt: occurredAt,
          amount: product.gemCost,
        )) {
          throw StateError('gem spend ID was reused with different data');
        }
        return LearningChallengePassPurchaseResult(
          applied: false,
          productId: productId,
          learningDay: learningDay,
          remainingGems: await _learningGemBalanceSql(tx),
        );
      }
      final passRows = await tx.query(
        'learning_gem_spends',
        columns: ['spend_id'],
        where:
            'scope = ? AND spend_kind = ? AND reference_id = ? '
            'AND learning_day = ?',
        whereArgs: [
          LearningScope.personal.wire,
          LearningGemSpendKind.challengeEntry.wire,
          productId,
          learningDay,
        ],
        limit: 1,
      );
      if (passRows.isNotEmpty) {
        return LearningChallengePassPurchaseResult(
          applied: false,
          productId: productId,
          learningDay: learningDay,
          remainingGems: await _learningGemBalanceSql(tx),
        );
      }
      if (await _learningGemBalanceSql(tx) < product.gemCost) {
        throw StateError('not enough gems');
      }
      final spend = LearningGemSpend(
        spendId: spendId,
        scope: LearningScope.personal,
        kind: LearningGemSpendKind.challengeEntry,
        amount: product.gemCost,
        learningDay: learningDay,
        weekKey: null,
        occurredAt: occurredAt,
        referenceId: productId,
      );
      await tx.insert('learning_gem_spends', _learningGemSpendRow(spend));
      return LearningChallengePassPurchaseResult(
        applied: true,
        productId: productId,
        learningDay: learningDay,
        remainingGems: await _learningGemBalanceSql(tx),
      );
    });
  }

  @override
  Future<LearningRun?> activeLearningRun({
    required LearningScope scope,
    String? nodeId,
  }) async {
    final rows = await _db.query(
      'learning_runs',
      where: nodeId == null ? 'scope = ?' : 'scope = ? AND node_id = ?',
      whereArgs: nodeId == null ? [scope.wire] : [scope.wire, nodeId],
      orderBy: 'updated_at DESC, run_id DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : _learningRunFromRow(rows.single);
  }

  @override
  Future<void> clearLearningScope(LearningScope scope) =>
      _db.transaction((tx) async {
        final eventRows = await tx.query(
          'learning_events',
          columns: ['id'],
          where: 'scope = ?',
          whereArgs: [scope.wire],
        );
        final eventIds = eventRows
            .map((row) => row['id'] as String? ?? '')
            .where((id) => id.isNotEmpty)
            .toList();
        final questRows = await tx.query(
          'learning_quest_progress',
          columns: ['quest_instance_id'],
          where: 'scope = ?',
          whereArgs: [scope.wire],
        );
        final coopRunRows = await tx.query(
          'learning_local_coop_runs',
          columns: ['run_id'],
          where: 'scope = ?',
          whereArgs: [scope.wire],
        );
        for (final eventId in eventIds) {
          await tx.delete(
            'learning_event_skills',
            where: 'event_id = ?',
            whereArgs: [eventId],
          );
          await tx.delete(
            'learning_practice_needs',
            where: 'event_id = ?',
            whereArgs: [eventId],
          );
          await tx.delete(
            'learning_quest_events',
            where: 'event_id = ?',
            whereArgs: [eventId],
          );
        }
        for (final row in questRows) {
          await tx.delete(
            'learning_quest_events',
            where: 'quest_instance_id = ?',
            whereArgs: [row['quest_instance_id']],
          );
        }
        for (final row in coopRunRows) {
          await tx.delete(
            'learning_local_coop_contributions',
            where: 'run_id = ?',
            whereArgs: [row['run_id']],
          );
          await tx.delete(
            'learning_local_coop_participants',
            where: 'run_id = ?',
            whereArgs: [row['run_id']],
          );
        }
        for (final table in const [
          'learning_events',
          'learning_node_progress',
          'learning_skill_progress',
          'learning_days',
          'learning_reward_ledger',
          'learning_quest_progress',
          'learning_freezes',
          'learning_challenge_heart_state',
          'learning_challenge_heart_losses',
          'learning_challenge_heart_practice_recoveries',
          'learning_runs',
          'learning_gem_spends',
          'learning_cosmetic_loadout',
          'learning_cosmetic_grants',
          'learning_local_coop_runs',
          'learning_league_history',
          'learning_local_league_history',
          'learning_need_state',
        ]) {
          await tx.delete(table, where: 'scope = ?', whereArgs: [scope.wire]);
        }
      });

  @override
  Future<void> close() => _db.close();

  static SavedSession _toSession(Map<String, Object?> row) {
    final dossierJson = row['dossier'] as String?;
    return SavedSession(
      id: row['id'] as int,
      unitId: row['unit_id'] as String? ?? '',
      focusConceptKey: row['focus_concept_key'] as String?,
      tactic: _teachingTacticFromName(row['teaching_tactic'] as String?),
      missionKind: MissionKind.parse(row['mission_kind']),
      startedAt: DateTime.fromMillisecondsSinceEpoch(
        (row['started_at'] as int?) ?? 0,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (row['updated_at'] as int?) ?? 0,
      ),
      endedAt: row['ended_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row['ended_at'] as int),
      dossier: dossierJson == null || dossierJson.isEmpty
          ? null
          : Dossier.fromJson(
              (jsonDecode(dossierJson) as Map).cast<String, dynamic>(),
            ),
      transcript: decodeTranscript(row['transcript'] as String?),
    );
  }
}

TeachingTactic? _teachingTacticFromName(String? name) {
  if (name == null) return null;
  for (final tactic in TeachingTactic.values) {
    if (tactic.name == name) return tactic;
  }
  return null;
}

String _conceptId(String unitId, String conceptKey) => '$unitId/$conceptKey';

void _validateCompletionPayload({
  required String unitId,
  required String conceptKey,
  required bool cleared,
  required ExplainedItem? explained,
  required ReviewItem? review,
}) {
  if (cleared) {
    if (explained == null) {
      throw ArgumentError('cleared mission requires explained evidence');
    }
    if (explained.unitId != unitId || explained.conceptKey != conceptKey) {
      throw ArgumentError('explained item does not match the session concept');
    }
    if (review != null) {
      throw ArgumentError('cleared mission must not include a review item');
    }
    return;
  }
  if (review == null) {
    throw ArgumentError('unfinished mission requires a review item');
  }
  if (review.unitId != unitId || review.conceptKey != conceptKey) {
    throw ArgumentError('review item does not match the session concept');
  }
  if (explained != null) {
    throw ArgumentError(
      'unfinished mission must not record explained evidence',
    );
  }
}

ConceptProgress _nextConceptProgress({
  required String unitId,
  required String conceptKey,
  required MissionKind kind,
  required bool cleared,
  required String day,
  required DateTime completedAt,
  required DateTime? examDate,
  required int sourceSessionId,
  required ConceptProgress? previous,
}) {
  final retrievals = cleared && kind == MissionKind.caseRetry
      ? (previous?.successfulRetrievals ?? 0) + 1
      : 0;
  final outcome = !cleared
      ? ConceptOutcome.rematchNeeded
      : kind == MissionKind.caseRetry
      ? ConceptOutcome.retained
      : ConceptOutcome.learned;
  final gap = !cleared
      ? 0
      // teach/repairは保持確認ではない。考査日が遠くても、まず翌日に
      // 教材なしで使えるかを確かめてから間隔を伸ばす。
      : kind != MissionKind.caseRetry
      ? 1
      : nextGap(
          now: completedAt,
          examDate: examDate,
          timesSeen: retrievals,
        ).inDays;
  final gapDays = gap < 1 ? 1 : gap;
  return ConceptProgress(
    unitId: unitId,
    conceptKey: conceptKey,
    lastOutcome: outcome,
    successfulRetrievals: retrievals,
    lastAttemptDay: day,
    lastSuccessDay: cleared ? day : previous?.lastSuccessDay,
    nextDueDay: cleared ? shiftDay(day, gapDays) : day,
    sourceSessionId: sourceSessionId,
  );
}

Future<CommitLearningResult> _learningCommitResult(
  DatabaseExecutor db, {
  required LearningEventRecord event,
  required bool inserted,
  required Iterable<String> skillIds,
}) async {
  final nodeRows = await db.query(
    'learning_node_progress',
    where: 'scope = ? AND node_id = ?',
    whereArgs: [event.scope.wire, event.nodeId],
    limit: 1,
  );
  if (nodeRows.isEmpty) {
    throw StateError('learning event has no node projection');
  }
  final skills = <LearningSkillProgress>[];
  for (final skillId in skillIds) {
    final rows = await db.query(
      'learning_skill_progress',
      where: 'scope = ? AND skill_id = ?',
      whereArgs: [event.scope.wire, skillId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('learning event has no skill projection');
    }
    skills.add(_learningSkillFromRow(rows.single));
  }
  skills.sort((a, b) => a.skillId.compareTo(b.skillId));
  final rewardRows = await db.query(
    'learning_reward_ledger',
    where: 'source_event_id = ?',
    whereArgs: [event.eventId],
    orderBy: 'entry_id ASC',
  );
  final questRows = await db.rawQuery(
    '''
    SELECT progress.*
    FROM learning_quest_progress AS progress
    JOIN learning_quest_events AS link
      ON link.quest_instance_id = progress.quest_instance_id
    WHERE link.event_id = ?
    ORDER BY progress.quest_instance_id ASC
    ''',
    [event.eventId],
  );
  return CommitLearningResult(
    event: event,
    inserted: inserted,
    node: _learningNodeFromRow(nodeRows.single),
    skills: List.unmodifiable(skills),
    rewards: List.unmodifiable(rewardRows.map(_learningRewardFromRow)),
    quests: List.unmodifiable(questRows.map(_learningQuestFromRow)),
  );
}

Future<void> _applyLearningNeedChangesSql(
  DatabaseExecutor db,
  LearningEventCommand event,
) async {
  Future<_LearningNeedState?> current(String skillId, String needCode) async {
    final rows = await db.query(
      'learning_need_state',
      where: 'scope = ? AND skill_id = ? AND need_code = ?',
      whereArgs: [event.scope.wire, skillId, needCode],
      limit: 1,
    );
    return rows.isEmpty ? null : _learningNeedStateFromRow(rows.single);
  }

  Future<void> save(_LearningNeedState state) => db.insert(
    'learning_need_state',
    _learningNeedStateRow(state),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  for (final entry in event.practiceNeedCodes.entries) {
    for (final needCode in entry.value) {
      await save(
        _nextLearningNeedObservation(
          previous: await current(entry.key, needCode),
          event: event,
          skillId: entry.key,
          needCode: needCode,
        ),
      );
    }
  }
  for (final entry in event.resolvedPracticeNeedCodes.entries) {
    for (final needCode in entry.value) {
      await save(
        _nextLearningNeedResolution(
          previous: await current(entry.key, needCode),
          event: event,
          skillId: entry.key,
          needCode: needCode,
        ),
      );
    }
  }
}

/// 直前の学習日との間がちょうど1日だけ空いたとき、その欠けた日を守る。
/// event commitと同じtransactionからだけ呼び、週（月曜始まり）1件に制限する。
Future<void> _maybeUseLearningFreezeSql(
  DatabaseExecutor db,
  LearningEventCommand event,
) async {
  if (event.scope != LearningScope.personal || !event.qualifiesForLearningDay) {
    return;
  }
  final currentRows = await db.query(
    'learning_days',
    columns: ['day'],
    where: 'scope = ? AND day = ? AND qualifying_count > 0',
    whereArgs: [LearningScope.personal.wire, event.learningDay],
    limit: 1,
  );
  if (currentRows.isNotEmpty) return;
  final futureRows = await db.query(
    'learning_days',
    columns: ['day'],
    where: 'scope = ? AND day > ? AND qualifying_count > 0',
    whereArgs: [LearningScope.personal.wire, event.learningDay],
    limit: 1,
  );
  // 過去日のeventを後から入れても、当時使われなかったfreezeを遡及しない。
  if (futureRows.isNotEmpty) return;
  final previousRows = await db.query(
    'learning_days',
    columns: ['day'],
    where: 'scope = ? AND day < ? AND qualifying_count > 0',
    whereArgs: [LearningScope.personal.wire, event.learningDay],
    orderBy: 'day DESC',
    limit: 1,
  );
  if (previousRows.isEmpty) return;
  final previousDay = previousRows.single['day'] as String?;
  if (previousDay != shiftDay(event.learningDay, -2)) return;
  final missedDay = shiftDay(event.learningDay, -1);
  final weekKey = learningWeekKey(missedDay);
  final usedRows = await db.query(
    'learning_freezes',
    columns: ['day'],
    where: 'scope = ? AND week_key = ?',
    whereArgs: [LearningScope.personal.wire, weekKey],
  );
  final refillRows = await db.query(
    'learning_gem_spends',
    columns: ['spend_id'],
    where: 'scope = ? AND spend_kind = ? AND week_key = ?',
    whereArgs: [
      LearningScope.personal.wire,
      LearningGemSpendKind.streakFreezeRefill.wire,
      weekKey,
    ],
  );
  if (usedRows.length >= 1 + refillRows.length) return;
  await db.insert('learning_freezes', {
    'scope': LearningScope.personal.wire,
    'day': missedDay,
    'week_key': weekKey,
    'used_at': event.occurredAt.millisecondsSinceEpoch,
  });
}

Future<LearningProgressSnapshot> _learningSnapshot(
  DatabaseExecutor db,
  LearningScope scope,
) async {
  final results = await Future.wait<List<Map<String, Object?>>>([
    db.query(
      'learning_events',
      where: 'scope = ?',
      whereArgs: [scope.wire],
      orderBy: 'occurred_at ASC, id ASC',
    ),
    db.query(
      'learning_node_progress',
      where: 'scope = ?',
      whereArgs: [scope.wire],
      orderBy: 'node_id ASC',
    ),
    db.query(
      'learning_skill_progress',
      where: 'scope = ?',
      whereArgs: [scope.wire],
      orderBy: 'next_due_day ASC, skill_id ASC',
    ),
    db.query(
      'learning_days',
      where: 'scope = ?',
      whereArgs: [scope.wire],
      orderBy: 'day DESC',
    ),
    db.query(
      'learning_freezes',
      where: 'scope = ?',
      whereArgs: [scope.wire],
      orderBy: 'day ASC',
    ),
    db.query(
      'learning_challenge_heart_state',
      where: 'scope = ?',
      whereArgs: [scope.wire],
      limit: 1,
    ),
    db.query(
      'learning_reward_ledger',
      where: 'scope = ?',
      whereArgs: [scope.wire],
      orderBy: 'created_at ASC, entry_id ASC',
    ),
    db.query(
      'learning_quest_progress',
      where: 'scope = ?',
      whereArgs: [scope.wire],
      orderBy: 'quest_instance_id ASC',
    ),
    db.query(
      'learning_runs',
      where: 'scope = ?',
      whereArgs: [scope.wire],
      orderBy: 'updated_at DESC, run_id DESC',
    ),
    db.query(
      'learning_gem_spends',
      where: 'scope = ?',
      whereArgs: [scope.wire],
      orderBy: 'occurred_at ASC, spend_id ASC',
    ),
    db.query(
      'learning_local_coop_runs',
      where: 'scope = ?',
      whereArgs: [scope.wire],
      orderBy: 'started_at ASC, run_id ASC',
    ),
    db.query(
      'learning_local_coop_participants',
      orderBy: 'run_id ASC, participant_id ASC',
    ),
    db.query(
      'learning_local_coop_contributions',
      orderBy: 'contributed_at ASC, contribution_id ASC',
    ),
    db.query(
      'learning_need_state',
      where:
          'scope = ? AND resolution_event_id IS NULL '
          'AND last_observed_day IS NOT NULL',
      whereArgs: [scope.wire],
      orderBy:
          'first_observed_day ASC, last_observed_at ASC, skill_id ASC, need_code ASC',
    ),
    db.query(
      'learning_league_history',
      where: 'scope = ?',
      whereArgs: [scope.wire],
      orderBy: 'week_key ASC',
    ),
    db.query(
      'learning_cosmetic_loadout',
      where: 'scope = ?',
      whereArgs: [scope.wire],
      limit: 1,
    ),
    db.query(
      'learning_local_league_history',
      where: 'scope = ?',
      whereArgs: [scope.wire],
      orderBy: 'week_key DESC',
    ),
    db.query(
      'learning_cosmetic_grants',
      columns: ['product_id'],
      where: 'scope = ?',
      whereArgs: [scope.wire],
    ),
  ]);
  final localCoopRuns = _learningLocalCoopRunsFromRows(
    runRows: results[10],
    participantRows: results[11],
    contributionRows: results[12],
  );
  final gemSpends = List<LearningGemSpend>.unmodifiable(
    results[9].map(_learningGemSpendFromRow),
  );
  return LearningProgressSnapshot(
    scope: scope,
    events: List.unmodifiable(results[0].map(_learningEventFromRow)),
    nodes: List.unmodifiable(results[1].map(_learningNodeFromRow)),
    skills: List.unmodifiable(results[2].map(_learningSkillFromRow)),
    days: List.unmodifiable(results[3].map(_learningDayFromRow)),
    freezes: List.unmodifiable(results[4].map(_learningFreezeFromRow)),
    challengeHearts: scope == LearningScope.personal
        ? results[5].isEmpty
              ? const LearningChallengeHeartState.initial()
              : _learningHeartStateFromRow(results[5].single)
        : null,
    rewards: List.unmodifiable(results[6].map(_learningRewardFromRow)),
    quests: List.unmodifiable(results[7].map(_learningQuestFromRow)),
    runs: List.unmodifiable(results[8].map(_learningRunFromRow)),
    activeNeeds: List.unmodifiable(
      results[13]
          .map(_learningNeedStateFromRow)
          .map((state) => state.activeProjection)
          .nonNulls,
    ),
    gemSpends: gemSpends,
    cosmetics: scope == LearningScope.personal
        ? _learningCosmeticStateFromLedger(
            gemSpends,
            equippedProductId:
                results[15].firstOrNull?['product_id'] as String?,
            grantedProductIds: results[17]
                .map((row) => row['product_id'] as String)
                .toSet(),
          )
        : null,
    localCoopRuns: List.unmodifiable(localCoopRuns),
    leagueHistory: List.unmodifiable(results[14].map(_learningLeagueFromRow)),
    localLeagueHistory: List.unmodifiable(
      results[16].map(_learningLocalLeagueFromRow),
    ),
  );
}

Future<LearningLocalCoopRun?> _learningLocalCoopRunSql(
  DatabaseExecutor db,
  String runId,
) async {
  final runRows = await db.query(
    'learning_local_coop_runs',
    where: 'run_id = ?',
    whereArgs: [runId],
    limit: 1,
  );
  if (runRows.isEmpty) return null;
  final participantRows = await db.query(
    'learning_local_coop_participants',
    where: 'run_id = ?',
    whereArgs: [runId],
  );
  final contributionRows = await db.query(
    'learning_local_coop_contributions',
    where: 'run_id = ?',
    whereArgs: [runId],
  );
  return _learningLocalCoopRunsFromRows(
    runRows: runRows,
    participantRows: participantRows,
    contributionRows: contributionRows,
  ).single;
}

Future<LocalWeeklyLeagueView> _localWeeklyLeagueViewSql(
  DatabaseExecutor db, {
  required String weekKey,
  required List<LearningLocalLeagueWeek> history,
}) async {
  final runRows = await db.query(
    'learning_local_coop_runs',
    where:
        'scope = ? AND start_day = ? AND '
        'definition_version IN (?, ?)',
    whereArgs: [
      LearningScope.personal.wire,
      weekKey,
      LocalWeeklyLeagueProjection.definitionVersion,
      LocalWeeklyLeagueProjection.pairBridgeDefinitionVersion,
    ],
    orderBy: 'started_at ASC, run_id ASC',
  );
  if (runRows.isEmpty) {
    return LocalWeeklyLeagueProjection.project(
      scope: LearningScope.personal,
      weekKey: weekKey,
      history: history,
    );
  }
  final runIds = runRows
      .map((row) => row['run_id'] as String? ?? '')
      .toList(growable: false);
  final placeholders = List.filled(runIds.length, '?').join(', ');
  final participantRows = await db.rawQuery('''
    SELECT run_id, participant_id
    FROM learning_local_coop_participants
    WHERE run_id IN ($placeholders)
    ORDER BY run_id ASC, participant_id ASC
    ''', runIds);
  final contributionRows = await db.rawQuery('''
    SELECT contribution.run_id, contribution.participant_id,
           contribution.event_id, event.scope, event.learning_day,
           event.meaningful_progress
    FROM learning_local_coop_contributions AS contribution
    JOIN learning_events AS event ON event.id = contribution.event_id
    WHERE contribution.run_id IN ($placeholders)
    ORDER BY event.learning_day ASC, contribution.run_id ASC,
             contribution.participant_id ASC, contribution.event_id ASC
    ''', runIds);
  final runs = _learningLocalCoopRunsFromRows(
    runRows: runRows,
    participantRows: participantRows,
    contributionRows: contributionRows,
  );
  return LocalWeeklyLeagueProjection.project(
    scope: LearningScope.personal,
    weekKey: weekKey,
    runs: runs,
    contributions: contributionRows.map(_learningLocalCoopContributionFromRow),
    history: history,
  );
}

void _requirePersonalLearningEconomy(LearningScope scope) {
  if (scope != LearningScope.personal) {
    throw StateError('gem economy is unavailable for school scope');
  }
}

bool _sameLearningCatalogSpend(
  LearningGemSpend spend, {
  required LearningGemSpendKind kind,
  required String productId,
  required String learningDay,
  required DateTime occurredAt,
  required int amount,
}) =>
    spend.scope == LearningScope.personal &&
    spend.kind == kind &&
    spend.referenceId == productId &&
    spend.learningDay == learningDay &&
    spend.occurredAt.millisecondsSinceEpoch ==
        occurredAt.millisecondsSinceEpoch &&
    spend.amount == amount &&
    spend.weekKey == null;

Map<String, Object?> _learningGemSpendRow(LearningGemSpend spend) => {
  'spend_id': spend.spendId,
  'scope': spend.scope.wire,
  'spend_kind': spend.kind.wire,
  'amount': spend.amount,
  'learning_day': spend.learningDay,
  'week_key': spend.weekKey,
  'occurred_at': spend.occurredAt.millisecondsSinceEpoch,
  'reference_id': spend.referenceId,
};

Future<LearningCosmeticState> _learningCosmeticStateSql(
  DatabaseExecutor db,
) async {
  final spendRows = await db.query(
    'learning_gem_spends',
    where: 'scope = ? AND spend_kind = ?',
    whereArgs: [
      LearningScope.personal.wire,
      LearningGemSpendKind.cosmeticPurchase.wire,
    ],
  );
  final grantRows = await db.query(
    'learning_cosmetic_grants',
    columns: ['product_id'],
    where: 'scope = ?',
    whereArgs: [LearningScope.personal.wire],
  );
  final loadoutRows = await db.query(
    'learning_cosmetic_loadout',
    where: 'scope = ? AND slot = ?',
    whereArgs: [
      LearningScope.personal.wire,
      LearningCosmeticSlot.pathMascot.wire,
    ],
    limit: 1,
  );
  return _learningCosmeticStateFromLedger(
    spendRows.map(_learningGemSpendFromRow),
    equippedProductId: loadoutRows.firstOrNull?['product_id'] as String?,
    grantedProductIds: grantRows
        .map((row) => row['product_id'] as String)
        .toSet(),
  );
}

Future<int> _learningGemBalanceSql(DatabaseExecutor db) async {
  final rewardRows = await db.rawQuery('''
    SELECT COALESCE(SUM(amount), 0) AS total
    FROM learning_reward_ledger
    WHERE scope = 'personal' AND reward_type = 'gems'
  ''');
  final spendRows = await db.rawQuery('''
    SELECT COALESCE(SUM(amount), 0) AS total
    FROM learning_gem_spends
    WHERE scope = 'personal'
  ''');
  return ((rewardRows.single['total'] as num?)?.toInt() ?? 0) -
      ((spendRows.single['total'] as num?)?.toInt() ?? 0);
}

Future<int> _learningFreezeRemainingSql(
  DatabaseExecutor db,
  String learningDay,
) async {
  final weekKey = learningWeekKey(learningDay);
  final used =
      Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM learning_freezes '
          'WHERE scope = ? AND week_key = ?',
          [LearningScope.personal.wire, weekKey],
        ),
      ) ??
      0;
  final refills =
      Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM learning_gem_spends '
          'WHERE scope = ? AND spend_kind = ? AND week_key = ?',
          [
            LearningScope.personal.wire,
            LearningGemSpendKind.streakFreezeRefill.wire,
            weekKey,
          ],
        ),
      ) ??
      0;
  return (1 + refills - used).clamp(0, 1 + refills);
}

Future<LearningChallengeHeartState> _learningHeartStateOrInitialSql(
  DatabaseExecutor db,
) async {
  final rows = await db.query(
    'learning_challenge_heart_state',
    where: 'scope = ?',
    whereArgs: [LearningScope.personal.wire],
    limit: 1,
  );
  return rows.isEmpty
      ? const LearningChallengeHeartState.initial()
      : _learningHeartStateFromRow(rows.single);
}

LearningChallengeHeartRefreshResult _refreshLearningHeartStateByTime({
  required LearningChallengeHeartState state,
  required String learningDay,
  required DateTime occurredAt,
}) {
  final anchor = state.updatedAt;
  if (state.current >= state.maximum ||
      anchor == null ||
      !occurredAt.isAfter(anchor)) {
    return LearningChallengeHeartRefreshResult(recovered: 0, state: state);
  }
  final elapsed = occurredAt.difference(anchor);
  final intervals =
      elapsed.inMilliseconds ~/
      LearningChallengeHeartState.recoveryInterval.inMilliseconds;
  final recovered = math.min(state.maximum - state.current, intervals);
  if (recovered <= 0) {
    return LearningChallengeHeartRefreshResult(recovered: 0, state: state);
  }
  final nextCurrent = state.current + recovered;
  final next = LearningChallengeHeartState(
    scope: LearningScope.personal,
    current: nextCurrent,
    maximum: state.maximum,
    lastLossDay: nextCurrent >= state.maximum ? null : state.lastLossDay,
    lastRecoveryDay: learningDay,
    updatedAt: anchor.add(
      Duration(
        milliseconds:
            LearningChallengeHeartState.recoveryInterval.inMilliseconds *
            recovered,
      ),
    ),
  );
  return LearningChallengeHeartRefreshResult(recovered: recovered, state: next);
}

Future<void> _writeLearningHeartStateSql(
  DatabaseExecutor db,
  LearningChallengeHeartState state,
) async {
  await db.insert(
    'learning_challenge_heart_state',
    _learningHeartStateRow(state),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
  await db.rawUpdate(
    'UPDATE learning_runs SET challenge_hearts = ? '
    'WHERE scope = ? AND challenge_hearts IS NOT NULL',
    [state.current, LearningScope.personal.wire],
  );
}

Future<LearningGemSpendResult> _learningGemSpendResultSql(
  DatabaseExecutor db, {
  required bool applied,
  required LearningGemSpend spend,
}) async => LearningGemSpendResult(
  applied: applied,
  spend: spend,
  remainingGems: await _learningGemBalanceSql(db),
  streakFreezeRemaining: await _learningFreezeRemainingSql(
    db,
    spend.learningDay,
  ),
  challengeHearts: await _learningHeartStateOrInitialSql(db),
);

Future<void> _rebuildLearningLeagueHistorySql(
  DatabaseExecutor db,
  DateTime finalizedAt,
) async {
  final eventRows = await db.query(
    'learning_events',
    where: 'scope = ?',
    whereArgs: [LearningScope.personal.wire],
  );
  final rewardRows = await db.query(
    'learning_reward_ledger',
    where: 'scope = ? AND reward_type = ?',
    whereArgs: [LearningScope.personal.wire, LearningRewardType.xp.wire],
  );
  final existingRows = await db.query(
    'learning_league_history',
    where: 'scope = ?',
    whereArgs: [LearningScope.personal.wire],
  );
  final existing = {
    for (final row in existingRows)
      (row['week_key'] as String? ?? ''): _learningLeagueFromRow(row),
  };
  final rebuilt = _buildLearningLeagueHistory(
    events: eventRows.map(_learningEventFromRow),
    rewards: rewardRows.map(_learningRewardFromRow),
    existing: existing,
    finalizedAt: finalizedAt,
  );
  await db.delete(
    'learning_league_history',
    where: 'scope = ?',
    whereArgs: [LearningScope.personal.wire],
  );
  for (final week in rebuilt.values) {
    await db.insert('learning_league_history', {
      'scope': week.scope.wire,
      'week_key': week.weekKey,
      'xp': week.xp,
      'previous_tier': week.previousTier.wire,
      'tier': week.tier.wire,
      'movement': week.movement.wire,
      'finalized_at': week.finalizedAt.millisecondsSinceEpoch,
    });
  }
}

LearningEventRecord _learningEventFromCommand(
  LearningEventCommand event, {
  bool meaningfulProgress = false,
}) => LearningEventRecord(
  eventId: event.eventId,
  scope: event.scope,
  origin: event.origin,
  courseId: event.courseId,
  nodeId: event.nodeId,
  activityId: event.activityId,
  activityKind: event.activityKind,
  outcome: event.outcome,
  evidence: event.evidence,
  contentVersion: event.contentVersion,
  learningDay: event.learningDay,
  occurredAt: event.occurredAt,
  runId: event.runId,
  sourceSessionId: event.sourceSessionId,
  rewardEligible: event.allowsRewards,
  meaningfulProgress: meaningfulProgress,
);

LearningEventRecord _learningEventFromRow(Map<String, Object?> row) {
  final scope = LearningScope.parse(row['scope']);
  final origin = LearningOrigin.parse(row['origin']);
  final kind = LearningActivityKind.parse(row['activity_kind']);
  final outcome = LearningAttemptOutcome.parse(row['outcome']);
  final evidence = LearningEvidenceLevel.fromRank(row['evidence_rank']);
  if (scope == null ||
      origin == null ||
      kind == null ||
      outcome == null ||
      evidence == null) {
    throw StateError('invalid learning event row');
  }
  return LearningEventRecord(
    eventId: row['id'] as String? ?? '',
    scope: scope,
    origin: origin,
    courseId: row['course_id'] as String? ?? '',
    nodeId: row['node_id'] as String? ?? '',
    activityId: row['activity_id'] as String? ?? '',
    activityKind: kind,
    outcome: outcome,
    evidence: evidence,
    contentVersion: row['content_version'] as String? ?? '',
    learningDay: row['learning_day'] as String? ?? '',
    occurredAt: DateTime.fromMillisecondsSinceEpoch(
      (row['occurred_at'] as num?)?.toInt() ?? 0,
    ),
    runId: row['run_id'] as String?,
    sourceSessionId: (row['source_session_id'] as num?)?.toInt(),
    rewardEligible: row['reward_eligible'] == 1,
    meaningfulProgress: row['meaningful_progress'] == 1,
  );
}

final class _LearningNeedState {
  const _LearningNeedState({
    required this.scope,
    required this.skillId,
    required this.needCode,
    required this.firstObservedDay,
    required this.lastObservedDay,
    required this.lastObservedAt,
    required this.lastObservationEventId,
    required this.resolvedDay,
    required this.resolvedAt,
    required this.resolutionEventId,
  });

  final LearningScope scope;
  final String skillId;
  final String needCode;
  final String? firstObservedDay;
  final String? lastObservedDay;
  final DateTime? lastObservedAt;
  final String? lastObservationEventId;
  final String? resolvedDay;
  final DateTime? resolvedAt;
  final String? resolutionEventId;

  bool get active => lastObservedDay != null && resolutionEventId == null;

  LearningActiveNeed? get activeProjection {
    if (!active) return null;
    return LearningActiveNeed(
      scope: scope,
      skillId: skillId,
      needCode: needCode,
      firstObservedDay: firstObservedDay!,
      lastObservedDay: lastObservedDay!,
      lastObservedAt: lastObservedAt!,
    );
  }
}

_LearningNeedState _learningNeedStateFromRow(Map<String, Object?> row) {
  final scope = LearningScope.parse(row['scope']);
  if (scope == null) throw StateError('invalid learning need scope');
  final lastObservedAt = (row['last_observed_at'] as num?)?.toInt();
  final resolvedAt = (row['resolved_at'] as num?)?.toInt();
  final state = _LearningNeedState(
    scope: scope,
    skillId: row['skill_id'] as String? ?? '',
    needCode: row['need_code'] as String? ?? '',
    firstObservedDay: row['first_observed_day'] as String?,
    lastObservedDay: row['last_observed_day'] as String?,
    lastObservedAt: lastObservedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(lastObservedAt),
    lastObservationEventId: row['last_observation_event_id'] as String?,
    resolvedDay: row['resolved_day'] as String?,
    resolvedAt: resolvedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(resolvedAt),
    resolutionEventId: row['resolution_event_id'] as String?,
  );
  final hasObservation =
      state.lastObservedDay != null &&
      state.lastObservedAt != null &&
      state.lastObservationEventId != null &&
      state.firstObservedDay != null;
  final hasResolution =
      state.resolvedDay != null &&
      state.resolvedAt != null &&
      state.resolutionEventId != null;
  if (state.skillId.isEmpty ||
      state.needCode.isEmpty ||
      (!hasObservation && !hasResolution)) {
    throw StateError('invalid learning need row');
  }
  return state;
}

Map<String, Object?> _learningNeedStateRow(_LearningNeedState state) => {
  'scope': state.scope.wire,
  'skill_id': state.skillId,
  'need_code': state.needCode,
  'first_observed_day': state.firstObservedDay,
  'last_observed_day': state.lastObservedDay,
  'last_observed_at': state.lastObservedAt?.millisecondsSinceEpoch,
  'last_observation_event_id': state.lastObservationEventId,
  'resolved_day': state.resolvedDay,
  'resolved_at': state.resolvedAt?.millisecondsSinceEpoch,
  'resolution_event_id': state.resolutionEventId,
};

_LearningNeedState _nextLearningNeedObservation({
  required _LearningNeedState? previous,
  required LearningEventCommand event,
  required String skillId,
  required String needCode,
}) {
  if (previous == null) {
    return _LearningNeedState(
      scope: event.scope,
      skillId: skillId,
      needCode: needCode,
      firstObservedDay: event.learningDay,
      lastObservedDay: event.learningDay,
      lastObservedAt: event.occurredAt,
      lastObservationEventId: event.eventId,
      resolvedDay: null,
      resolvedAt: null,
      resolutionEventId: null,
    );
  }
  if (previous.resolutionEventId != null) {
    final afterResolution = _compareLearningNeedMarker(
      event.learningDay,
      event.occurredAt,
      event.eventId,
      previous.resolvedDay!,
      previous.resolvedAt!,
      previous.resolutionEventId!,
    );
    if (afterResolution <= 0) return previous;
    return _LearningNeedState(
      scope: event.scope,
      skillId: skillId,
      needCode: needCode,
      firstObservedDay: event.learningDay,
      lastObservedDay: event.learningDay,
      lastObservedAt: event.occurredAt,
      lastObservationEventId: event.eventId,
      resolvedDay: null,
      resolvedAt: null,
      resolutionEventId: null,
    );
  }
  final afterObservation = _compareLearningNeedMarker(
    event.learningDay,
    event.occurredAt,
    event.eventId,
    previous.lastObservedDay!,
    previous.lastObservedAt!,
    previous.lastObservationEventId!,
  );
  if (afterObservation <= 0) return previous;
  return _LearningNeedState(
    scope: previous.scope,
    skillId: previous.skillId,
    needCode: previous.needCode,
    firstObservedDay: previous.firstObservedDay,
    lastObservedDay: event.learningDay,
    lastObservedAt: event.occurredAt,
    lastObservationEventId: event.eventId,
    resolvedDay: null,
    resolvedAt: null,
    resolutionEventId: null,
  );
}

_LearningNeedState _nextLearningNeedResolution({
  required _LearningNeedState? previous,
  required LearningEventCommand event,
  required String skillId,
  required String needCode,
}) {
  if (previous?.lastObservationEventId case final observationEventId?) {
    final afterObservation = _compareLearningNeedMarker(
      event.learningDay,
      event.occurredAt,
      event.eventId,
      previous!.lastObservedDay!,
      previous.lastObservedAt!,
      observationEventId,
    );
    if (afterObservation < 0) return previous;
  }
  if (previous?.resolutionEventId case final resolutionEventId?) {
    final afterResolution = _compareLearningNeedMarker(
      event.learningDay,
      event.occurredAt,
      event.eventId,
      previous!.resolvedDay!,
      previous.resolvedAt!,
      resolutionEventId,
    );
    if (afterResolution <= 0) return previous;
  }
  return _LearningNeedState(
    scope: event.scope,
    skillId: skillId,
    needCode: needCode,
    firstObservedDay: previous?.firstObservedDay,
    lastObservedDay: previous?.lastObservedDay,
    lastObservedAt: previous?.lastObservedAt,
    lastObservationEventId: previous?.lastObservationEventId,
    resolvedDay: event.learningDay,
    resolvedAt: event.occurredAt,
    resolutionEventId: event.eventId,
  );
}

int _compareLearningNeedMarker(
  String leftDay,
  DateTime leftAt,
  String leftEventId,
  String rightDay,
  DateTime rightAt,
  String rightEventId,
) {
  final byDay = leftDay.compareTo(rightDay);
  if (byDay != 0) return byDay;
  final byTime = leftAt.compareTo(rightAt);
  if (byTime != 0) return byTime;
  return leftEventId.compareTo(rightEventId);
}

LearningNodeProgress _learningNodeFromRow(Map<String, Object?> row) {
  final scope = LearningScope.parse(row['scope']);
  final state = LearningNodeState.parse(row['state']);
  final evidence = LearningEvidenceLevel.fromRank(row['best_evidence_rank']);
  if (scope == null || state == null || evidence == null) {
    throw StateError('invalid learning node row');
  }
  final completed = (row['completed_at'] as num?)?.toInt();
  return LearningNodeProgress(
    scope: scope,
    nodeId: row['node_id'] as String? ?? '',
    state: state,
    attemptCount: (row['attempt_count'] as num?)?.toInt() ?? 0,
    bestEvidence: evidence,
    lastAttemptDay: row['last_attempt_day'] as String? ?? '',
    lastEventId: row['last_event_id'] as String? ?? '',
    completedAt: completed == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(completed),
    contentVersion: row['content_version'] as String? ?? '',
  );
}

LearningSkillProgress _learningSkillFromRow(Map<String, Object?> row) {
  final scope = LearningScope.parse(row['scope']);
  final outcome = LearningSkillOutcome.parse(row['last_outcome']);
  if (scope == null || outcome == null) {
    throw StateError('invalid learning skill row');
  }
  return LearningSkillProgress(
    scope: scope,
    skillId: row['skill_id'] as String? ?? '',
    lastOutcome: outcome,
    successfulRetrievals: (row['successful_retrievals'] as num?)?.toInt() ?? 0,
    lastAttemptDay: row['last_attempt_day'] as String? ?? '',
    lastSuccessDay: row['last_success_day'] as String?,
    nextDueDay: row['next_due_day'] as String? ?? '',
    lastEventId: row['last_event_id'] as String? ?? '',
  );
}

LearningDay _learningDayFromRow(Map<String, Object?> row) => LearningDay(
  scope:
      LearningScope.parse(row['scope']) ??
      (throw StateError('invalid learning day row')),
  day: row['day'] as String? ?? '',
  qualifyingCount: (row['qualifying_count'] as num?)?.toInt() ?? 0,
  firstEventAt: DateTime.fromMillisecondsSinceEpoch(
    (row['first_event_at'] as num?)?.toInt() ?? 0,
  ),
  lastEventAt: DateTime.fromMillisecondsSinceEpoch(
    (row['last_event_at'] as num?)?.toInt() ?? 0,
  ),
);

LearningStreakFreeze _learningFreezeFromRow(Map<String, Object?> row) {
  final scope = LearningScope.parse(row['scope']);
  if (scope != LearningScope.personal) {
    throw StateError('invalid learning freeze row');
  }
  return LearningStreakFreeze(
    scope: scope!,
    day: row['day'] as String? ?? '',
    weekKey: row['week_key'] as String? ?? '',
    usedAt: DateTime.fromMillisecondsSinceEpoch(
      (row['used_at'] as num?)?.toInt() ?? 0,
    ),
  );
}

LearningChallengeHeartState _learningHeartStateFromRow(
  Map<String, Object?> row,
) {
  final scope = LearningScope.parse(row['scope']);
  final current = (row['current_hearts'] as num?)?.toInt() ?? -1;
  if (scope != LearningScope.personal ||
      current < 0 ||
      current > LearningChallengeHeartState.defaultMaximum) {
    throw StateError('invalid learning challenge heart row');
  }
  return LearningChallengeHeartState(
    scope: scope!,
    current: current,
    maximum: LearningChallengeHeartState.defaultMaximum,
    lastLossDay: row['last_loss_day'] as String?,
    lastRecoveryDay: row['last_recovery_day'] as String?,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      (row['updated_at'] as num?)?.toInt() ?? 0,
    ),
  );
}

LearningRewardEntry _learningRewardFromRow(Map<String, Object?> row) {
  final scope = LearningScope.parse(row['scope']);
  final type = LearningRewardType.parse(row['reward_type']);
  if (scope == null || type == null) {
    throw StateError('invalid learning reward row');
  }
  return LearningRewardEntry(
    entryId: row['entry_id'] as String? ?? '',
    scope: scope,
    type: type,
    amount: (row['amount'] as num?)?.toInt() ?? 0,
    reason: row['reason'] as String? ?? '',
    sourceEventId: row['source_event_id'] as String?,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      (row['created_at'] as num?)?.toInt() ?? 0,
    ),
  );
}

LearningQuestProgress _learningQuestFromRow(Map<String, Object?> row) {
  final scope = LearningScope.parse(row['scope']);
  if (scope == null) throw StateError('invalid learning quest row');
  final completed = (row['completed_at'] as num?)?.toInt();
  final rewarded = (row['rewarded_at'] as num?)?.toInt();
  return LearningQuestProgress(
    scope: scope,
    questInstanceId: row['quest_instance_id'] as String? ?? '',
    progress: (row['progress'] as num?)?.toInt() ?? 0,
    target: (row['target'] as num?)?.toInt() ?? 0,
    completedAt: completed == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(completed),
    rewardedAt: rewarded == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(rewarded),
    definitionVersion: row['definition_version'] as String? ?? '',
  );
}

LearningGemSpend _learningGemSpendFromRow(Map<String, Object?> row) {
  final scope = LearningScope.parse(row['scope']);
  final kind = LearningGemSpendKind.parse(row['spend_kind']);
  if (scope != LearningScope.personal || kind == null) {
    throw StateError('invalid learning gem spend row');
  }
  return LearningGemSpend(
    spendId: row['spend_id'] as String? ?? '',
    scope: scope!,
    kind: kind,
    amount: (row['amount'] as num?)?.toInt() ?? 0,
    learningDay: row['learning_day'] as String? ?? '',
    weekKey: row['week_key'] as String?,
    occurredAt: DateTime.fromMillisecondsSinceEpoch(
      (row['occurred_at'] as num?)?.toInt() ?? 0,
    ),
    referenceId: row['reference_id'] as String?,
  );
}

LearningCosmeticState _learningCosmeticStateFromLedger(
  Iterable<LearningGemSpend> spends, {
  String? equippedProductId,
  Set<String> grantedProductIds = const {},
}) {
  const catalog = SafeLearningEconomyCatalogV1();
  catalog.validate();
  final owned = <String>{SafeLearningEconomyCatalogV1.standardMascotId};
  try {
    for (final productId in grantedProductIds) {
      if (!catalog.cosmetic(productId).requiresPlusAccess) {
        throw StateError('cosmetic grant does not match fixed catalog');
      }
      owned.add(productId);
    }
    for (final spend in spends) {
      switch (spend.kind) {
        case LearningGemSpendKind.cosmeticPurchase:
          final referenceId = spend.referenceId;
          if (referenceId == null) {
            throw StateError('cosmetic spend has no catalog reference');
          }
          final product = catalog.cosmetic(referenceId);
          if (product.isDefault || spend.amount != product.gemCost) {
            throw StateError('cosmetic spend does not match fixed catalog');
          }
          owned.add(referenceId);
        case LearningGemSpendKind.challengeEntry:
          final referenceId = spend.referenceId;
          if (referenceId == null ||
              spend.amount != catalog.challengePass(referenceId).gemCost) {
            throw StateError('challenge spend does not match fixed catalog');
          }
        case LearningGemSpendKind.streakFreezeRefill ||
            LearningGemSpendKind.challengeHeartRecovery:
          if (spend.referenceId != null) {
            throw StateError('legacy gem spend cannot reference a product');
          }
      }
    }
    final equipped =
        equippedProductId ?? SafeLearningEconomyCatalogV1.standardMascotId;
    catalog.cosmetic(equipped);
    if (!owned.contains(equipped)) {
      throw StateError('unowned cosmetic cannot be equipped');
    }
    return LearningCosmeticState(
      ownedProductIds: Set.unmodifiable(owned),
      equippedPathMascotId: equipped,
    );
  } on ArgumentError catch (error) {
    throw StateError(
      'learning economy ledger contains an unknown product: $error',
    );
  }
}

List<LearningLocalCoopRun> _learningLocalCoopRunsFromRows({
  required List<Map<String, Object?>> runRows,
  required List<Map<String, Object?>> participantRows,
  required List<Map<String, Object?>> contributionRows,
}) {
  final participants = <String, Set<String>>{};
  for (final row in participantRows) {
    participants
        .putIfAbsent(row['run_id'] as String? ?? '', () => <String>{})
        .add(row['participant_id'] as String? ?? '');
  }
  final contributors = <String, Set<String>>{};
  final progress = <String, int>{};
  for (final row in contributionRows) {
    final runId = row['run_id'] as String? ?? '';
    contributors
        .putIfAbsent(runId, () => <String>{})
        .add(row['participant_id'] as String? ?? '');
    progress[runId] = (progress[runId] ?? 0) + 1;
  }
  return [
    for (final row in runRows)
      _learningLocalCoopRunFromRow(
        row,
        participantIds: participants[row['run_id']] ?? const <String>{},
        contributingParticipantIds:
            contributors[row['run_id']] ?? const <String>{},
        progress: progress[row['run_id']] ?? 0,
      ),
  ];
}

LearningLocalCoopContribution _learningLocalCoopContributionFromRow(
  Map<String, Object?> row,
) {
  final scope = LearningScope.parse(row['scope']);
  final meaningful = row['meaningful_progress'];
  if (scope == null || (meaningful != 0 && meaningful != 1)) {
    throw StateError('invalid local coop contribution projection row');
  }
  return _learningLocalCoopContributionProjection(
    runId: row['run_id'] as String? ?? '',
    participantId: row['participant_id'] as String? ?? '',
    eventId: row['event_id'] as String? ?? '',
    scope: scope,
    learningDay: row['learning_day'] as String? ?? '',
    meaningfulProgress: meaningful == 1,
  );
}

LearningLocalCoopContribution _learningLocalCoopContributionProjection({
  required String runId,
  required String participantId,
  required String eventId,
  required LearningScope scope,
  required String learningDay,
  required bool meaningfulProgress,
}) {
  if (!_learningOpaqueId.hasMatch(runId) ||
      !_learningOpaqueId.hasMatch(participantId) ||
      !_learningOpaqueId.hasMatch(eventId)) {
    throw StateError('invalid local coop contribution projection ID');
  }
  learningWeekKey(learningDay);
  return LearningLocalCoopContribution(
    runId: runId,
    participantId: participantId,
    eventId: eventId,
    scope: scope,
    learningDay: learningDay,
    meaningfulProgress: meaningfulProgress,
  );
}

LearningLocalCoopRun _learningLocalCoopRunFromRow(
  Map<String, Object?> row, {
  required Set<String> participantIds,
  required Set<String> contributingParticipantIds,
  required int progress,
}) {
  final scope = LearningScope.parse(row['scope']);
  if (scope != LearningScope.personal) {
    throw StateError('invalid local coop run row');
  }
  final completed = (row['completed_at'] as num?)?.toInt();
  final rewarded = (row['rewarded_at'] as num?)?.toInt();
  return LearningLocalCoopRun(
    runId: row['run_id'] as String? ?? '',
    scope: scope!,
    questInstanceId: row['quest_instance_id'] as String? ?? '',
    participantIds: Set.unmodifiable(participantIds),
    contributingParticipantIds: Set.unmodifiable(contributingParticipantIds),
    progress: progress,
    target: (row['target'] as num?)?.toInt() ?? 0,
    rewardGems: (row['reward_gems'] as num?)?.toInt() ?? 0,
    startDay: row['start_day'] as String? ?? '',
    endDay: row['end_day'] as String? ?? '',
    definitionVersion: row['definition_version'] as String? ?? '',
    startedAt: DateTime.fromMillisecondsSinceEpoch(
      (row['started_at'] as num?)?.toInt() ?? 0,
    ),
    completedAt: completed == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(completed),
    rewardedAt: rewarded == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(rewarded),
  );
}

LearningLeagueWeek _learningLeagueFromRow(Map<String, Object?> row) {
  final scope = LearningScope.parse(row['scope']);
  final previousTier = LearningLeagueTier.parse(row['previous_tier']);
  final tier = LearningLeagueTier.parse(row['tier']);
  final movement = LearningLeagueMovement.parse(row['movement']);
  if (scope != LearningScope.personal ||
      previousTier == null ||
      tier == null ||
      movement == null) {
    throw StateError('invalid learning league row');
  }
  return LearningLeagueWeek(
    scope: scope!,
    weekKey: row['week_key'] as String? ?? '',
    xp: (row['xp'] as num?)?.toInt() ?? 0,
    previousTier: previousTier,
    tier: tier,
    movement: movement,
    finalizedAt: DateTime.fromMillisecondsSinceEpoch(
      (row['finalized_at'] as num?)?.toInt() ?? 0,
    ),
  );
}

LearningLocalLeagueWeek _learningLocalLeagueFromRow(Map<String, Object?> row) {
  final scope = LearningScope.parse(row['scope']);
  final previousTier = LanSocialLeagueTier.parse(row['previous_tier']);
  final tier = LanSocialLeagueTier.parse(row['tier']);
  final movement = LanSocialLeagueMovement.parse(row['movement']);
  final meaningfulEventCount = (row['meaningful_event_count'] as num?)?.toInt();
  final rank = (row['rank'] as num?)?.toInt();
  final tiedValue = row['tied'];
  final participantCount = (row['participant_count'] as num?)?.toInt();
  final weekKey = row['week_key'] as String? ?? '';
  final finalizedAt = (row['finalized_at'] as num?)?.toInt();
  if (scope != LearningScope.personal ||
      previousTier == null ||
      tier == null ||
      movement == null ||
      meaningfulEventCount == null ||
      rank != null && rank < 1 ||
      (tiedValue != 0 && tiedValue != 1) ||
      participantCount == null ||
      finalizedAt == null) {
    throw StateError('invalid local weekly league row');
  }
  try {
    if (learningWeekKey(weekKey) != weekKey) {
      throw const FormatException('Monday required');
    }
    final expected = resolveLeagueTierTransition(
      previousTier: previousTier,
      rank: rank,
      tied: tiedValue == 1,
      participantCount: participantCount,
      score: meaningfulEventCount,
    );
    if (expected.tier != tier || expected.movement != movement) {
      throw const FormatException('tier transition mismatch');
    }
  } on Object {
    throw StateError('invalid local weekly league row');
  }
  return LearningLocalLeagueWeek(
    scope: scope!,
    weekKey: weekKey,
    meaningfulEventCount: meaningfulEventCount,
    rank: rank,
    tied: tiedValue == 1,
    participantCount: participantCount,
    previousTier: previousTier,
    tier: tier,
    movement: movement,
    finalizedAt: DateTime.fromMillisecondsSinceEpoch(finalizedAt, isUtc: true),
  );
}

Map<String, Object?> _learningLocalLeagueRow(LearningLocalLeagueWeek week) => {
  'scope': week.scope.wire,
  'week_key': week.weekKey,
  'meaningful_event_count': week.meaningfulEventCount,
  'rank': week.rank,
  'tied': week.tied ? 1 : 0,
  'participant_count': week.participantCount,
  'previous_tier': week.previousTier.wire,
  'tier': week.tier.wire,
  'movement': week.movement.wire,
  'finalized_at': week.finalizedAt.toUtc().millisecondsSinceEpoch,
};

LearningRun _learningRunFromRow(Map<String, Object?> row) {
  final scope = LearningScope.parse(row['scope']);
  if (scope == null) throw StateError('invalid learning run row');
  return LearningRun(
    runId: row['run_id'] as String? ?? '',
    scope: scope,
    nodeId: row['node_id'] as String? ?? '',
    activityIndex: (row['activity_index'] as num?)?.toInt() ?? 0,
    challengeHearts: (row['challenge_hearts'] as num?)?.toInt(),
    contentVersion: row['content_version'] as String? ?? '',
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      (row['updated_at'] as num?)?.toInt() ?? 0,
    ),
  );
}

Map<String, Object?> _learningRunRow(LearningRun run) => {
  'run_id': run.runId,
  'scope': run.scope.wire,
  'node_id': run.nodeId,
  'activity_index': run.activityIndex,
  'challenge_hearts': run.challengeHearts,
  'content_version': run.contentVersion,
  'updated_at': run.updatedAt.millisecondsSinceEpoch,
};

const _keepChallengeHearts = Object();

LearningRun _copyLearningRun(
  LearningRun run, {
  int? activityIndex,
  Object? challengeHearts = _keepChallengeHearts,
  DateTime? updatedAt,
}) => LearningRun(
  runId: run.runId,
  scope: run.scope,
  nodeId: run.nodeId,
  activityIndex: activityIndex ?? run.activityIndex,
  challengeHearts: identical(challengeHearts, _keepChallengeHearts)
      ? run.challengeHearts
      : challengeHearts as int?,
  contentVersion: run.contentVersion,
  updatedAt: updatedAt ?? run.updatedAt,
);

Map<String, Object?> _learningHeartStateRow(
  LearningChallengeHeartState state,
) => {
  'scope': state.scope.wire,
  'current_hearts': state.current,
  'last_loss_day': state.lastLossDay,
  'last_recovery_day': state.lastRecoveryDay,
  'updated_at': state.updatedAt?.millisecondsSinceEpoch ?? 0,
};

Future<LearningChallengeHeartState> _learningHeartStateSql(
  DatabaseExecutor db,
) async {
  final rows = await db.query(
    'learning_challenge_heart_state',
    where: 'scope = ?',
    whereArgs: [LearningScope.personal.wire],
    limit: 1,
  );
  if (rows.isEmpty) {
    throw StateError('challenge heart state does not exist');
  }
  return _learningHeartStateFromRow(rows.single);
}

final class _ChallengeHeartLoss {
  const _ChallengeHeartLoss({
    required this.lossId,
    required this.runId,
    required this.activityIndex,
    required this.learningDay,
    required this.occurredAt,
    required this.remainingHearts,
  });

  final String lossId;
  final String runId;
  final int activityIndex;
  final String learningDay;
  final DateTime occurredAt;
  final int remainingHearts;

  bool matches({
    required String runId,
    required int activityIndex,
    required String learningDay,
    required DateTime occurredAt,
  }) =>
      this.runId == runId &&
      this.activityIndex == activityIndex &&
      this.learningDay == learningDay &&
      this.occurredAt.millisecondsSinceEpoch ==
          occurredAt.millisecondsSinceEpoch;
}

final class _ChallengeHeartPracticeRecovery {
  const _ChallengeHeartPracticeRecovery({
    required this.recoveryId,
    required this.sourceEventId,
    required this.learningDay,
    required this.occurredAt,
    required this.recoveredHearts,
    required this.resultingHearts,
  });

  final String recoveryId;
  final String sourceEventId;
  final String learningDay;
  final DateTime occurredAt;
  final int recoveredHearts;
  final int resultingHearts;

  bool matches({
    required String sourceEventId,
    required String learningDay,
    required DateTime occurredAt,
  }) =>
      this.sourceEventId == sourceEventId &&
      this.learningDay == learningDay &&
      this.occurredAt.millisecondsSinceEpoch ==
          occurredAt.millisecondsSinceEpoch;
}

final class _LearningLocalCoopContribution {
  const _LearningLocalCoopContribution({
    required this.contributionId,
    required this.runId,
    required this.participantId,
    required this.eventId,
    required this.occurredAt,
  });

  final String contributionId;
  final String runId;
  final String participantId;
  final String eventId;
  final DateTime occurredAt;

  bool matches({
    required String runId,
    required String participantId,
    required String eventId,
    required DateTime occurredAt,
  }) =>
      this.runId == runId &&
      this.participantId == participantId &&
      this.eventId == eventId &&
      this.occurredAt.millisecondsSinceEpoch ==
          occurredAt.millisecondsSinceEpoch;
}

_ChallengeHeartLoss _challengeHeartLossFromRow(Map<String, Object?> row) =>
    _ChallengeHeartLoss(
      lossId: row['loss_id'] as String? ?? '',
      runId: row['run_id'] as String? ?? '',
      activityIndex: (row['activity_index'] as num?)?.toInt() ?? -1,
      learningDay: row['learning_day'] as String? ?? '',
      occurredAt: DateTime.fromMillisecondsSinceEpoch(
        (row['occurred_at'] as num?)?.toInt() ?? 0,
      ),
      remainingHearts: (row['remaining_hearts'] as num?)?.toInt() ?? -1,
    );

_ChallengeHeartPracticeRecovery _challengeHeartPracticeRecoveryFromRow(
  Map<String, Object?> row,
) => _ChallengeHeartPracticeRecovery(
  recoveryId: row['recovery_id'] as String? ?? '',
  sourceEventId: row['source_event_id'] as String? ?? '',
  learningDay: row['learning_day'] as String? ?? '',
  occurredAt: DateTime.fromMillisecondsSinceEpoch(
    (row['occurred_at'] as num?)?.toInt() ?? 0,
  ),
  recoveredHearts: (row['recovered_hearts'] as num?)?.toInt() ?? -1,
  resultingHearts: (row['resulting_hearts'] as num?)?.toInt() ?? -1,
);

void _validateChallengeHeartLoss({
  required String runId,
  required String lossId,
  required int activityIndex,
  required String learningDay,
  required DateTime occurredAt,
}) {
  if (!_learningOpaqueId.hasMatch(runId) ||
      !_learningOpaqueId.hasMatch(lossId)) {
    throw ArgumentError('challenge heart loss requires opaque ASCII IDs');
  }
  if (activityIndex < 0 || occurredAt.millisecondsSinceEpoch < 0) {
    throw ArgumentError('challenge heart loss has an invalid value');
  }
  // validation目的で呼ぶ。返り値はfreezeの週次契約と同じ定義。
  learningWeekKey(learningDay);
}

void _validateChallengeHeartPracticeRecovery({
  required String recoveryId,
  required String sourceEventId,
  required String learningDay,
  required DateTime occurredAt,
}) {
  if (!_learningOpaqueId.hasMatch(recoveryId) ||
      !_learningOpaqueId.hasMatch(sourceEventId)) {
    throw ArgumentError('heart recovery requires opaque ASCII IDs');
  }
  if (occurredAt.millisecondsSinceEpoch < 0) {
    throw ArgumentError('heart recovery has an invalid timestamp');
  }
  learningWeekKey(learningDay);
}

void _validateChallengeHeartClock({
  required String learningDay,
  required DateTime occurredAt,
}) {
  if (occurredAt.millisecondsSinceEpoch < 0) {
    throw ArgumentError('heart clock has an invalid timestamp');
  }
  learningWeekKey(learningDay);
}

bool _sameLearningEvent(
  LearningEventRecord stored,
  LearningEventCommand incoming,
) =>
    stored.eventId == incoming.eventId &&
    stored.scope == incoming.scope &&
    stored.origin == incoming.origin &&
    stored.courseId == incoming.courseId &&
    stored.nodeId == incoming.nodeId &&
    stored.activityId == incoming.activityId &&
    stored.activityKind == incoming.activityKind &&
    stored.outcome == incoming.outcome &&
    stored.evidence == incoming.evidence &&
    stored.contentVersion == incoming.contentVersion &&
    stored.learningDay == incoming.learningDay &&
    stored.occurredAt.millisecondsSinceEpoch ==
        incoming.occurredAt.millisecondsSinceEpoch &&
    stored.runId == incoming.runId &&
    stored.sourceSessionId == incoming.sourceSessionId &&
    stored.rewardEligible == incoming.allowsRewards;

bool _sameStringSet(Set<String> left, Set<String> right) =>
    left.length == right.length && left.containsAll(right);

bool _sameNeedCodes(
  Map<String, Set<String>> left,
  Map<String, Set<String>> right,
) {
  if (left.length != right.length) return false;
  for (final entry in left.entries) {
    final other = right[entry.key];
    if (other == null || !_sameStringSet(entry.value, other)) return false;
  }
  return true;
}

final RegExp _learningOpaqueId = RegExp(
  r'^[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}$',
);
final RegExp _learningLanFriendsRoomId = RegExp(r'^[a-f0-9]{24}$');

void _validateLearningLanFriendsReward({
  required String roomId,
  required DateTime completedAt,
}) {
  if (!_learningLanFriendsRoomId.hasMatch(roomId) ||
      completedAt.millisecondsSinceEpoch < 0) {
    throw ArgumentError('LAN friends reward requires a valid room and time');
  }
}

LearningRewardEntry _learningLanFriendsReward({
  required String roomId,
  required DateTime completedAt,
}) => LearningRewardEntry(
  entryId: 'gems.lan-friends.v1:$roomId',
  scope: LearningScope.personal,
  type: LearningRewardType.gems,
  amount: 1,
  reason: 'lan-friends.v1:$roomId',
  sourceEventId: null,
  createdAt: completedAt.toUtc(),
);

bool _sameLearningLanFriendsReward(
  LearningRewardEntry stored,
  LearningRewardEntry expected,
) =>
    stored.entryId == expected.entryId &&
    stored.scope == LearningScope.personal &&
    stored.type == LearningRewardType.gems &&
    stored.amount == 1 &&
    stored.reason == expected.reason &&
    stored.sourceEventId == null;

void _validateLearningRun(LearningRun run) {
  if (!_learningOpaqueId.hasMatch(run.runId) ||
      !_learningOpaqueId.hasMatch(run.nodeId) ||
      !_learningOpaqueId.hasMatch(run.contentVersion)) {
    throw ArgumentError('learning run requires opaque ASCII identifiers');
  }
  if (run.activityIndex < 0 ||
      (run.challengeHearts != null && run.challengeHearts! < 0) ||
      run.updatedAt.millisecondsSinceEpoch < 0) {
    throw ArgumentError('learning run has an invalid value');
  }
}

bool _sameLearningRun(LearningRun left, LearningRun right) =>
    left.runId == right.runId &&
    left.scope == right.scope &&
    left.nodeId == right.nodeId &&
    left.activityIndex == right.activityIndex &&
    left.challengeHearts == right.challengeHearts &&
    left.contentVersion == right.contentVersion &&
    left.updatedAt.millisecondsSinceEpoch ==
        right.updatedAt.millisecondsSinceEpoch;

void _validateLearningLocalCoopRun(LearningLocalCoopRunCommand command) {
  if (!_learningOpaqueId.hasMatch(command.runId) ||
      !_learningOpaqueId.hasMatch(command.definitionVersion) ||
      command.participantIds.any(
        (participantId) => !_learningOpaqueId.hasMatch(participantId),
      )) {
    throw ArgumentError('local coop run requires opaque ASCII identifiers');
  }
  if (command.participantIds.length < 2 ||
      command.participantIds.length > 8 ||
      command.target < command.participantIds.length ||
      command.target > 100 ||
      command.rewardGems < 0 ||
      command.rewardGems > 100 ||
      command.startedAt.millisecondsSinceEpoch < 0) {
    throw ArgumentError('local coop run has an invalid value');
  }
  learningWeekKey(command.startDay);
  learningWeekKey(command.endDay);
  if (command.startDay.compareTo(command.endDay) > 0) {
    throw ArgumentError('local coop run ends before it starts');
  }
}

bool _sameLearningLocalCoopRun(
  LearningLocalCoopRun existing,
  LearningLocalCoopRunCommand command,
) =>
    existing.runId == command.runId &&
    _sameStringSet(existing.participantIds, command.participantIds) &&
    existing.target == command.target &&
    existing.rewardGems == command.rewardGems &&
    existing.startDay == command.startDay &&
    existing.endDay == command.endDay &&
    existing.definitionVersion == command.definitionVersion &&
    existing.startedAt.millisecondsSinceEpoch ==
        command.startedAt.millisecondsSinceEpoch;

LearningLocalCoopRun _copyLearningLocalCoopRun(
  LearningLocalCoopRun run, {
  Set<String>? contributingParticipantIds,
  int? progress,
  DateTime? completedAt,
  DateTime? rewardedAt,
}) => LearningLocalCoopRun(
  runId: run.runId,
  scope: run.scope,
  questInstanceId: run.questInstanceId,
  participantIds: run.participantIds,
  contributingParticipantIds:
      contributingParticipantIds ?? run.contributingParticipantIds,
  progress: progress ?? run.progress,
  target: run.target,
  rewardGems: run.rewardGems,
  startDay: run.startDay,
  endDay: run.endDay,
  definitionVersion: run.definitionVersion,
  startedAt: run.startedAt,
  completedAt: completedAt ?? run.completedAt,
  rewardedAt: rewardedAt ?? run.rewardedAt,
);

void _validateLearningLocalCoopContribution({
  required String runId,
  required String contributionId,
  required String participantId,
  required String eventId,
  required DateTime occurredAt,
}) {
  if (!_learningOpaqueId.hasMatch(runId) ||
      !_learningOpaqueId.hasMatch(contributionId) ||
      !_learningOpaqueId.hasMatch(participantId) ||
      !_learningOpaqueId.hasMatch(eventId) ||
      occurredAt.millisecondsSinceEpoch < 0) {
    throw ArgumentError('local coop contribution has an invalid value');
  }
}

List<String> _validatedLearningLocalCoopRunIds(Set<String> runIds) {
  if (runIds.length > 100 ||
      runIds.any((runId) => !_learningOpaqueId.hasMatch(runId))) {
    throw ArgumentError('local coop run IDs must be opaque ASCII IDs');
  }
  return runIds.toList()..sort();
}

void _validateLearningGemSpend({
  required String spendId,
  required String learningDay,
  required DateTime occurredAt,
}) {
  if (!_learningOpaqueId.hasMatch(spendId) ||
      occurredAt.millisecondsSinceEpoch < 0) {
    throw ArgumentError('gem spend has an invalid value');
  }
  learningWeekKey(learningDay);
}

int _learningGemBalance({
  required Iterable<LearningRewardEntry> rewards,
  required Iterable<LearningGemSpend> spends,
}) =>
    rewards
        .where(
          (item) =>
              item.scope == LearningScope.personal &&
              item.type == LearningRewardType.gems,
        )
        .fold(0, (sum, item) => sum + item.amount) -
    spends
        .where((item) => item.scope == LearningScope.personal)
        .fold(0, (sum, item) => sum + item.amount);

Map<String, LearningLeagueWeek> _buildLearningLeagueHistory({
  required Iterable<LearningEventRecord> events,
  required Iterable<LearningRewardEntry> rewards,
  required Map<String, LearningLeagueWeek> existing,
  required DateTime finalizedAt,
}) {
  final personalEvents = events
      .where((event) => event.scope == LearningScope.personal)
      .toList();
  if (personalEvents.isEmpty) return <String, LearningLeagueWeek>{};
  final firstDay = personalEvents
      .map((event) => event.learningDay)
      .reduce((left, right) => left.compareTo(right) <= 0 ? left : right);
  final lastDay = personalEvents
      .map((event) => event.learningDay)
      .reduce((left, right) => left.compareTo(right) >= 0 ? left : right);
  final firstWeek = learningWeekKey(firstDay);
  final activeWeek = learningWeekKey(lastDay);
  final eventDays = {
    for (final event in personalEvents) event.eventId: event.learningDay,
  };
  final xpByWeek = <String, int>{};
  for (final reward in rewards) {
    if (reward.scope != LearningScope.personal ||
        reward.type != LearningRewardType.xp ||
        reward.sourceEventId == null) {
      continue;
    }
    final day = eventDays[reward.sourceEventId];
    if (day == null) continue;
    final week = learningWeekKey(day);
    xpByWeek[week] = (xpByWeek[week] ?? 0) + reward.amount;
  }
  final out = <String, LearningLeagueWeek>{};
  var previousTier = LearningLeagueTier.observer;
  var week = firstWeek;
  while (week.compareTo(activeWeek) < 0) {
    final xp = xpByWeek[week] ?? 0;
    final tier = learningLeagueTierForXp(xp);
    final movement = tier.index > previousTier.index
        ? LearningLeagueMovement.promoted
        : tier.index < previousTier.index
        ? LearningLeagueMovement.demoted
        : LearningLeagueMovement.stayed;
    out[week] = LearningLeagueWeek(
      scope: LearningScope.personal,
      weekKey: week,
      xp: xp,
      previousTier: previousTier,
      tier: tier,
      movement: movement,
      finalizedAt: existing[week]?.finalizedAt ?? finalizedAt,
    );
    previousTier = tier;
    week = shiftDay(week, 7);
  }
  return out;
}

List<LearningQuestDefinition> _validateLearningQuestMaterialization({
  required LearningScope scope,
  required Iterable<LearningQuestDefinition> definitions,
}) {
  final validated = definitions.toList(growable: false);
  if (scope != LearningScope.personal) {
    if (validated.isEmpty) return validated;
    throw ArgumentError(
      'school scope must not materialize personal reward quests',
    );
  }
  final questIds = <String>{};
  final dailyPeriods = <String>{};
  for (final definition in validated) {
    if (!questIds.add(definition.questInstanceId)) {
      throw ArgumentError('quest instance IDs must be unique');
    }
    if (definition.questInstanceId.startsWith('local-coop:')) {
      throw ArgumentError(
        'local coop quests must use the explicit local coop run API',
      );
    }
    LearningQuestPlannerV2.requireCanonicalMaterializedDefinition(definition);
    final parts = definition.questInstanceId.split(':');
    if (parts.first == 'daily' && !dailyPeriods.add(parts[1])) {
      throw ArgumentError('only one daily quest may be materialized per day');
    }
  }
  return validated;
}

void _requireCompatibleMaterializedQuest(
  LearningQuestProgress saved,
  LearningQuestDefinition definition,
) {
  if (saved.scope != LearningScope.personal ||
      saved.questInstanceId != definition.questInstanceId ||
      saved.target != definition.target ||
      saved.definitionVersion != definition.definitionVersion) {
    throw StateError('quest instance was reused with a new definition');
  }
  if (saved.progress < 0 ||
      saved.progress > saved.target ||
      (saved.completedAt == null && saved.progress == saved.target) ||
      (saved.completedAt != null && saved.progress < saved.target) ||
      (saved.rewardedAt != null && saved.completedAt == null)) {
    throw StateError('materialized quest progress is inconsistent');
  }
}

void _validateLearningRules(LearningCommitRules rules) {
  final questIds = <String>{};
  for (final quest in rules.quests) {
    if (quest.questInstanceId.startsWith('local-coop:')) {
      throw ArgumentError(
        'local coop quests must use the explicit local coop run API',
      );
    }
    if (!questIds.add(quest.questInstanceId)) {
      throw ArgumentError('quest instance IDs must be unique');
    }
    if (LearningQuestPlannerV2.managesMaterializedDefinition(quest)) {
      LearningQuestPlannerV2.requireCanonicalMaterializedDefinition(quest);
    }
  }
}

/// 1つのskill projectionを、event順序に依存せず更新する。
///
/// non-spacedの再完了は既に得た保持証拠と復習期限を動かさない。
/// spaced retrievalは前回期限の到来後だけを新しい1回として数える。
LearningSkillProgress _nextLearningSkillProgress({
  required LearningEventCommand event,
  required String skillId,
  required LearningSkillProgress? previous,
  required LearningSpacingPolicy spacingPolicy,
}) {
  final retry = event.outcome == LearningAttemptOutcome.retryNeeded;
  final spaced =
      event.evidence == LearningEvidenceLevel.spacedTransfer && !retry;
  final useIncomingAttempt =
      previous == null ||
      event.learningDay.compareTo(previous.lastAttemptDay) >= 0;
  final lastAttemptDay = useIncomingAttempt
      ? event.learningDay
      : previous.lastAttemptDay;
  final lastEventId = useIncomingAttempt ? event.eventId : previous.lastEventId;

  if (retry) {
    if (previous != null &&
        event.learningDay.compareTo(previous.lastAttemptDay) < 0) {
      return previous;
    }
    final gap = _validatedLearningGap(
      spacingPolicy.gapDaysFor(event: event, successfulRetrievals: 0),
    );
    return LearningSkillProgress(
      scope: event.scope,
      skillId: skillId,
      lastOutcome: LearningSkillOutcome.needsPractice,
      successfulRetrievals: 0,
      lastAttemptDay: lastAttemptDay,
      lastSuccessDay: previous?.lastSuccessDay,
      nextDueDay: shiftDay(event.learningDay, gap),
      lastEventId: event.eventId,
    );
  }

  if (previous == null) {
    // 過去の成功が無いeventを「間隔を空けた想起」として水増ししない。
    const retrievals = 0;
    final gap = _validatedLearningGap(
      spacingPolicy.gapDaysFor(event: event, successfulRetrievals: retrievals),
    );
    return LearningSkillProgress(
      scope: event.scope,
      skillId: skillId,
      lastOutcome: LearningSkillOutcome.completed,
      successfulRetrievals: retrievals,
      lastAttemptDay: event.learningDay,
      lastSuccessDay: event.learningDay,
      nextDueDay: shiftDay(event.learningDay, gap),
      lastEventId: event.eventId,
    );
  }

  if (!spaced) {
    if (previous.lastSuccessDay == null) {
      final gap = _validatedLearningGap(
        spacingPolicy.gapDaysFor(event: event, successfulRetrievals: 0),
      );
      return LearningSkillProgress(
        scope: event.scope,
        skillId: skillId,
        lastOutcome: LearningSkillOutcome.completed,
        successfulRetrievals: 0,
        lastAttemptDay: lastAttemptDay,
        lastSuccessDay: event.learningDay,
        nextDueDay: shiftDay(event.learningDay, gap),
        lastEventId: event.eventId,
      );
    }
    return LearningSkillProgress(
      scope: event.scope,
      skillId: skillId,
      lastOutcome: previous.lastOutcome == LearningSkillOutcome.retained
          ? LearningSkillOutcome.retained
          : LearningSkillOutcome.completed,
      successfulRetrievals: previous.successfulRetrievals,
      lastAttemptDay: lastAttemptDay,
      lastSuccessDay: previous.lastSuccessDay ?? event.learningDay,
      nextDueDay: previous.nextDueDay,
      lastEventId: lastEventId,
    );
  }

  final previousSuccessDay = previous.lastSuccessDay;
  if (previousSuccessDay == null) {
    final gap = _validatedLearningGap(
      spacingPolicy.gapDaysFor(event: event, successfulRetrievals: 0),
    );
    return LearningSkillProgress(
      scope: event.scope,
      skillId: skillId,
      lastOutcome: LearningSkillOutcome.completed,
      successfulRetrievals: 0,
      lastAttemptDay: lastAttemptDay,
      lastSuccessDay: event.learningDay,
      nextDueDay: shiftDay(event.learningDay, gap),
      lastEventId: event.eventId,
    );
  }
  final isNewRetrieval = _isDueSpacedRetrieval(
    event: event,
    previous: previous,
  );
  if (!isNewRetrieval) {
    return LearningSkillProgress(
      scope: event.scope,
      skillId: skillId,
      lastOutcome: previous.lastOutcome,
      successfulRetrievals: previous.successfulRetrievals,
      lastAttemptDay: lastAttemptDay,
      lastSuccessDay: previous.lastSuccessDay,
      nextDueDay: previous.nextDueDay,
      lastEventId: lastEventId,
    );
  }

  final retrievals = previous.successfulRetrievals + 1;
  final gap = _validatedLearningGap(
    spacingPolicy.gapDaysFor(event: event, successfulRetrievals: retrievals),
  );
  return LearningSkillProgress(
    scope: event.scope,
    skillId: skillId,
    lastOutcome: LearningSkillOutcome.retained,
    successfulRetrievals: retrievals,
    lastAttemptDay: lastAttemptDay,
    lastSuccessDay: event.learningDay,
    nextDueDay: shiftDay(event.learningDay, gap),
    lastEventId: event.eventId,
  );
}

bool _isDueSpacedRetrieval({
  required LearningEventCommand event,
  required LearningSkillProgress? previous,
}) =>
    previous?.lastSuccessDay != null &&
    event.outcome != LearningAttemptOutcome.retryNeeded &&
    event.evidence == LearningEvidenceLevel.spacedTransfer &&
    event.learningDay.compareTo(previous!.lastSuccessDay!) > 0 &&
    event.learningDay.compareTo(previous.nextDueDay) >= 0;

bool _isMeaningfulLearningProgress({
  required LearningEventCommand event,
  required LearningNodeProgress? previousNode,
  required bool hasDueSpacedRetrieval,
}) {
  if (!event.qualifiesForLearningDay) return false;
  if (event.evidence == LearningEvidenceLevel.spacedTransfer) {
    return hasDueSpacedRetrieval;
  }
  return previousNode?.state != LearningNodeState.cleared;
}

int _validatedLearningGap(int gap) {
  if (gap < 0 || gap > 3650) {
    throw StateError('spacing policy returned an invalid gap');
  }
  return gap;
}

CommitLearningResult _memoryLearningCommitResult({
  required LearningEventRecord event,
  required bool inserted,
  required Iterable<String> skillIds,
  required Map<String, LearningNodeProgress> nodes,
  required Map<String, LearningSkillProgress> skills,
  required Map<String, LearningRewardEntry> rewards,
  required Map<String, LearningQuestProgress> quests,
  required Map<String, Set<String>> questEvents,
}) {
  final node = nodes[_learningProjectionKey(event.scope, event.nodeId)];
  if (node == null) throw StateError('learning event has no node projection');
  final projectedSkills = <LearningSkillProgress>[];
  for (final skillId in skillIds) {
    final skill = skills[_learningProjectionKey(event.scope, skillId)];
    if (skill == null) {
      throw StateError('learning event has no skill projection');
    }
    projectedSkills.add(skill);
  }
  projectedSkills.sort((a, b) => a.skillId.compareTo(b.skillId));
  final eventRewards =
      rewards.values
          .where((reward) => reward.sourceEventId == event.eventId)
          .toList()
        ..sort((a, b) => a.entryId.compareTo(b.entryId));
  final eventQuests = <LearningQuestProgress>[];
  for (final entry in questEvents.entries) {
    if (!entry.value.contains(event.eventId)) continue;
    final quest =
        quests[_learningProjectionKey(LearningScope.personal, entry.key)];
    if (quest != null) eventQuests.add(quest);
  }
  eventQuests.sort((a, b) => a.questInstanceId.compareTo(b.questInstanceId));
  return CommitLearningResult(
    event: event,
    inserted: inserted,
    node: node,
    skills: List.unmodifiable(projectedSkills),
    rewards: List.unmodifiable(eventRewards),
    quests: List.unmodifiable(eventQuests),
  );
}

LearningProgressSnapshot _memoryLearningSnapshot({
  required LearningScope scope,
  required Map<String, LearningEventRecord> events,
  required Map<String, LearningNodeProgress> nodes,
  required Map<String, LearningSkillProgress> skills,
  required Map<String, LearningDay> days,
  required Map<String, LearningStreakFreeze> freezes,
  required Map<String, LearningChallengeHeartState> heartStates,
  required Map<String, LearningRewardEntry> rewards,
  required Map<String, LearningQuestProgress> quests,
  required Map<String, LearningRun> runs,
  required Map<String, LearningGemSpend> gemSpends,
  required Map<String, ({String productId, DateTime updatedAt})>
  cosmeticLoadout,
  required Set<String> cosmeticGrants,
  required Map<String, LearningLocalCoopRun> localCoopRuns,
  required Map<String, LearningLeagueWeek> leagueHistory,
  required Map<String, LearningLocalLeagueWeek> localLeagueHistory,
  required Map<String, _LearningNeedState> needStates,
}) {
  final eventList = events.values.where((item) => item.scope == scope).toList()
    ..sort((a, b) {
      final byTime = a.occurredAt.compareTo(b.occurredAt);
      return byTime != 0 ? byTime : a.eventId.compareTo(b.eventId);
    });
  final nodeList = nodes.values.where((item) => item.scope == scope).toList()
    ..sort((a, b) => a.nodeId.compareTo(b.nodeId));
  final skillList = skills.values.where((item) => item.scope == scope).toList()
    ..sort((a, b) {
      final byDue = a.nextDueDay.compareTo(b.nextDueDay);
      return byDue != 0 ? byDue : a.skillId.compareTo(b.skillId);
    });
  final dayList = days.values.where((item) => item.scope == scope).toList()
    ..sort((a, b) => b.day.compareTo(a.day));
  final freezeList =
      freezes.values.where((item) => item.scope == scope).toList()
        ..sort((a, b) => a.day.compareTo(b.day));
  final rewardList =
      rewards.values.where((item) => item.scope == scope).toList()
        ..sort((a, b) {
          final byTime = a.createdAt.compareTo(b.createdAt);
          return byTime != 0 ? byTime : a.entryId.compareTo(b.entryId);
        });
  final questList = quests.values.where((item) => item.scope == scope).toList()
    ..sort((a, b) => a.questInstanceId.compareTo(b.questInstanceId));
  final runList = runs.values.where((item) => item.scope == scope).toList()
    ..sort((a, b) {
      final byTime = b.updatedAt.compareTo(a.updatedAt);
      return byTime != 0 ? byTime : b.runId.compareTo(a.runId);
    });
  final spendList =
      gemSpends.values.where((item) => item.scope == scope).toList()
        ..sort((a, b) {
          final byTime = a.occurredAt.compareTo(b.occurredAt);
          return byTime != 0 ? byTime : a.spendId.compareTo(b.spendId);
        });
  final coopList =
      localCoopRuns.values.where((item) => item.scope == scope).toList()
        ..sort((a, b) {
          final byTime = a.startedAt.compareTo(b.startedAt);
          return byTime != 0 ? byTime : a.runId.compareTo(b.runId);
        });
  final leagueList =
      leagueHistory.values.where((item) => item.scope == scope).toList()
        ..sort((a, b) => a.weekKey.compareTo(b.weekKey));
  final localLeagueList =
      localLeagueHistory.values.where((item) => item.scope == scope).toList()
        ..sort((a, b) => b.weekKey.compareTo(a.weekKey));
  final activeNeedList =
      needStates.values
          .where((item) => item.scope == scope)
          .map((item) => item.activeProjection)
          .nonNulls
          .toList()
        ..sort((a, b) {
          final byFirst = a.firstObservedDay.compareTo(b.firstObservedDay);
          if (byFirst != 0) return byFirst;
          final byTime = a.lastObservedAt.compareTo(b.lastObservedAt);
          if (byTime != 0) return byTime;
          final bySkill = a.skillId.compareTo(b.skillId);
          return bySkill != 0 ? bySkill : a.needCode.compareTo(b.needCode);
        });
  return LearningProgressSnapshot(
    scope: scope,
    events: List.unmodifiable(eventList),
    nodes: List.unmodifiable(nodeList),
    skills: List.unmodifiable(skillList),
    days: List.unmodifiable(dayList),
    freezes: List.unmodifiable(freezeList),
    challengeHearts: scope == LearningScope.personal
        ? heartStates[LearningScope.personal.wire] ??
              const LearningChallengeHeartState.initial()
        : null,
    rewards: List.unmodifiable(rewardList),
    quests: List.unmodifiable(questList),
    runs: List.unmodifiable(runList),
    activeNeeds: List.unmodifiable(activeNeedList),
    gemSpends: List.unmodifiable(spendList),
    cosmetics: scope == LearningScope.personal
        ? _learningCosmeticStateFromLedger(
            spendList,
            equippedProductId:
                cosmeticLoadout[LearningCosmeticSlot.pathMascot.wire]
                    ?.productId,
            grantedProductIds: cosmeticGrants,
          )
        : null,
    localCoopRuns: List.unmodifiable(coopList),
    leagueHistory: List.unmodifiable(leagueList),
    localLeagueHistory: List.unmodifiable(localLeagueList),
  );
}

LearningStreakFreeze? _learningFreezeForEvent({
  required LearningEventCommand event,
  required Iterable<LearningDay> days,
  required Iterable<LearningStreakFreeze> freezes,
  required Iterable<LearningGemSpend> gemSpends,
}) {
  if (event.scope != LearningScope.personal || !event.qualifiesForLearningDay) {
    return null;
  }
  final personalDays = days
      .where(
        (item) =>
            item.scope == LearningScope.personal && item.qualifyingCount > 0,
      )
      .toList();
  if (personalDays.any((item) => item.day == event.learningDay)) return null;
  if (personalDays.any((item) => item.day.compareTo(event.learningDay) > 0)) {
    return null;
  }
  final previous = personalDays
      .where((item) => item.day.compareTo(event.learningDay) < 0)
      .map((item) => item.day)
      .fold<String?>(
        null,
        (latest, day) =>
            latest == null || day.compareTo(latest) > 0 ? day : latest,
      );
  if (previous != shiftDay(event.learningDay, -2)) return null;
  final missedDay = shiftDay(event.learningDay, -1);
  final weekKey = learningWeekKey(missedDay);
  final used = freezes
      .where(
        (item) =>
            item.scope == LearningScope.personal && item.weekKey == weekKey,
      )
      .length;
  final refills = gemSpends
      .where(
        (item) =>
            item.scope == LearningScope.personal &&
            item.kind == LearningGemSpendKind.streakFreezeRefill &&
            item.weekKey == weekKey,
      )
      .length;
  if (used >= 1 + refills) return null;
  return LearningStreakFreeze(
    scope: LearningScope.personal,
    day: missedDay,
    weekKey: weekKey,
    usedAt: event.occurredAt,
  );
}

void _applyLearningNeedChangesMemory(
  Map<String, _LearningNeedState> states,
  LearningEventCommand event,
) {
  for (final entry in event.practiceNeedCodes.entries) {
    for (final needCode in entry.value) {
      final key = _learningNeedProjectionKey(event.scope, entry.key, needCode);
      states[key] = _nextLearningNeedObservation(
        previous: states[key],
        event: event,
        skillId: entry.key,
        needCode: needCode,
      );
    }
  }
  for (final entry in event.resolvedPracticeNeedCodes.entries) {
    for (final needCode in entry.value) {
      final key = _learningNeedProjectionKey(event.scope, entry.key, needCode);
      states[key] = _nextLearningNeedResolution(
        previous: states[key],
        event: event,
        skillId: entry.key,
        needCode: needCode,
      );
    }
  }
}

String _learningProjectionKey(LearningScope scope, String id) =>
    '${scope.wire}/$id';

String _learningNeedProjectionKey(
  LearningScope scope,
  String skillId,
  String needCode,
) => '${scope.wire}\u0000$skillId\u0000$needCode';

void _replaceMap<K, V>(Map<K, V> target, Map<K, V> source) {
  target
    ..clear()
    ..addAll(source);
}

void _replaceNestedSetMap<K>(
  Map<K, Set<String>> target,
  Map<K, Set<String>> source,
) {
  target
    ..clear()
    ..addAll({
      for (final entry in source.entries) entry.key: Set.of(entry.value),
    });
}

void _replaceNeedMap(
  Map<String, Map<String, Set<String>>> target,
  Map<String, Map<String, Set<String>>> source,
) {
  target
    ..clear()
    ..addAll({
      for (final event in source.entries)
        event.key: {
          for (final need in event.value.entries) need.key: Set.of(need.value),
        },
    });
}

/// 逐語の復元。**壊れていても落とさない**（記録が読めないより、欠けても開く方がまし）。
List<Utterance> decodeTranscript(String? json) {
  if (json == null || json.isEmpty) return const [];
  try {
    final list = jsonDecode(json);
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map(
          (m) => Utterance(
            id: m['id'] as String? ?? '',
            isStudent: m['speaker'] == 'student',
            text: m['text'] as String? ?? '',
            corrected: m['corrected'] as String?,
            challengeLureId: switch (m['challengeLureId']) {
              final String id => id,
              _ => null,
            },
            challengeLureText: switch (m['challengeLureText']) {
              final String text => text,
              _ => null,
            },
          ),
        )
        .where((u) => u.id.isNotEmpty)
        .toList();
  } catch (e) {
    debugPrint('逐語の復元に失敗: $e');
    return const [];
  }
}

/// メモリ版。テストと、sqflite が動かないプラットフォーム（web / Windows）用。
///
/// **開発プレビューで落ちないためのもので、記録は残らない。**
class MemorySessionStore implements SessionStore {
  final _sessions = <int, SavedSession>{};
  final _reviews = <String, ReviewItem>{};
  final _settings = <String, String>{};
  final _days = <String, DayRecord>{};
  final _explained = <String, ExplainedItem>{};
  final _conceptProgress = <String, ConceptProgress>{};
  final _completedMissionIds = <int>{};
  final _learningEvents = <String, LearningEventRecord>{};
  final _learningEventSkills = <String, Set<String>>{};
  final _learningPracticeNeeds = <String, Map<String, Set<String>>>{};
  final _learningResolvedPracticeNeeds = <String, Map<String, Set<String>>>{};
  final _learningNeedStates = <String, _LearningNeedState>{};
  final _learningNodes = <String, LearningNodeProgress>{};
  final _learningSkills = <String, LearningSkillProgress>{};
  final _learningDays = <String, LearningDay>{};
  final _learningFreezes = <String, LearningStreakFreeze>{};
  final _learningHeartStates = <String, LearningChallengeHeartState>{};
  final _learningHeartLosses = <String, _ChallengeHeartLoss>{};
  final _learningHeartPracticeRecoveries =
      <String, _ChallengeHeartPracticeRecovery>{};
  final _learningRewards = <String, LearningRewardEntry>{};
  final _learningQuests = <String, LearningQuestProgress>{};
  final _learningQuestEvents = <String, Set<String>>{};
  final _learningRuns = <String, LearningRun>{};
  final _learningGemSpends = <String, LearningGemSpend>{};
  final _learningCosmeticLoadout =
      <String, ({String productId, DateTime updatedAt})>{};
  final _learningCosmeticGrants = <String>{};
  final _learningLocalCoopRuns = <String, LearningLocalCoopRun>{};
  final _learningLocalCoopContributions =
      <String, _LearningLocalCoopContribution>{};
  final _learningLeagueHistory = <String, LearningLeagueWeek>{};
  final _learningLocalLeagueHistory = <String, LearningLocalLeagueWeek>{};
  DateTime? _exam;
  int _seq = 0;

  @override
  Future<int> startSession(
    String unitId, {
    String? focusConceptKey,
    TeachingTactic? tactic,
    MissionKind missionKind = MissionKind.teach,
  }) async {
    final id = ++_seq;
    final now = DateTime.now();
    _sessions[id] = SavedSession(
      id: id,
      unitId: unitId,
      focusConceptKey: focusConceptKey,
      tactic: tactic,
      missionKind: missionKind,
      startedAt: now,
      updatedAt: now,
      endedAt: null,
      dossier: null,
      transcript: const [],
    );
    return id;
  }

  @override
  Future<void> saveProgress(
    int sessionId, {
    required List<Utterance> transcript,
    Dossier? dossier,
  }) async {
    final s = _sessions[sessionId];
    if (s == null) return;
    _sessions[sessionId] = SavedSession(
      id: s.id,
      unitId: s.unitId,
      focusConceptKey: s.focusConceptKey,
      tactic: s.tactic,
      missionKind: s.missionKind,
      startedAt: s.startedAt,
      updatedAt: DateTime.now(),
      endedAt: s.endedAt,
      dossier: dossier ?? s.dossier,
      transcript: List.of(transcript),
    );
  }

  @override
  Future<void> finishSession(int sessionId) async {
    final s = _sessions[sessionId];
    if (s == null) return;
    _sessions[sessionId] = SavedSession(
      id: s.id,
      unitId: s.unitId,
      focusConceptKey: s.focusConceptKey,
      tactic: s.tactic,
      missionKind: s.missionKind,
      startedAt: s.startedAt,
      updatedAt: s.updatedAt,
      endedAt: DateTime.now(),
      dossier: s.dossier,
      transcript: s.transcript,
    );
  }

  @override
  Future<SavedSession?> unfinished({
    String? unitId,
    String? focusConceptKey,
    MissionKind? missionKind,
  }) async {
    final open =
        _sessions.values
            .where(
              (s) =>
                  !s.isFinished &&
                  s.transcript.isNotEmpty &&
                  (unitId == null || s.unitId == unitId) &&
                  (focusConceptKey != null
                      ? s.focusConceptKey == focusConceptKey
                      : unitId == null || s.focusConceptKey == null) &&
                  (missionKind == null || s.missionKind == missionKind),
            )
            .toList()
          ..sort(_newestFirst);
    return open.isEmpty ? null : open.first;
  }

  @override
  Future<List<SavedSession>> recentSessions({int limit = 20}) async {
    final all = _sessions.values.toList()..sort(_newestFirst);
    return all.take(limit).toList();
  }

  /// 同じミリ秒に2件あると順序が定まらない。id で確定させる
  static int _newestFirst(SavedSession a, SavedSession b) {
    final byTime = b.updatedAt.compareTo(a.updatedAt);
    return byTime != 0 ? byTime : b.id.compareTo(a.id);
  }

  @override
  Future<List<ReviewItem>> reviewItems() async {
    final all = _reviews.values.toList()
      ..sort((a, b) => a.lastSeen.compareTo(b.lastSeen));
    return all;
  }

  @override
  Future<void> upsertReviews(List<ReviewItem> items) async {
    for (final i in items) {
      final key = '${i.unitId}/${i.conceptKey}';
      final prev = _reviews[key];
      // sqflite 版の ON CONFLICT と同じ規則。**見直した回数は引き継ぐ**
      _reviews[key] = prev == null
          ? i
          : i.copyWith(
              timesSeen: prev.timesSeen,
              lastReviewedAt: prev.lastReviewedAt,
            );
    }
  }

  @override
  Future<void> markReviewed(String unitId, String conceptKey) async {
    final key = '$unitId/$conceptKey';
    final prev = _reviews[key];
    if (prev == null) return;
    _reviews[key] = prev.copyWith(
      timesSeen: prev.timesSeen + 1,
      lastReviewedAt: DateTime.now(),
    );
  }

  @override
  Future<void> clearReview(String unitId, String conceptKey) async {
    _reviews.remove('$unitId/$conceptKey');
  }

  @override
  Future<void> recordActivity(
    String day, {
    int sessions = 0,
    int done = 0,
    int textTurns = 0,
  }) async {
    final prev = _days[day];
    _days[day] = DayRecord(
      day: day,
      sessions: (prev?.sessions ?? 0) + sessions,
      done: (prev?.done ?? 0) + done,
      textTurns: (prev?.textTurns ?? 0) + textTurns,
    );
  }

  @override
  Future<List<DayRecord>> days({int limit = 400}) async {
    final all = _days.values.toList()..sort((a, b) => b.day.compareTo(a.day));
    return all.take(limit).toList();
  }

  @override
  Future<void> recordExplained(ExplainedItem item) async {
    _explained['${item.unitId}/${item.conceptKey}'] = item;
  }

  @override
  Future<List<ExplainedItem>> explained({int limit = 50}) async {
    final all = _explained.values.toList()
      ..sort((a, b) => b.at.compareTo(a.at));
    return all.take(limit).toList();
  }

  @override
  Future<List<ConceptProgress>> conceptProgress() async {
    final all = _conceptProgress.values.toList()
      ..sort((a, b) {
        final byDue = a.nextDueDay.compareTo(b.nextDueDay);
        if (byDue != 0) return byDue;
        final byUnit = a.unitId.compareTo(b.unitId);
        return byUnit != 0 ? byUnit : a.conceptKey.compareTo(b.conceptKey);
      });
    return all;
  }

  @override
  Future<ConceptProgress?> progressFor(
    String unitId,
    String conceptKey,
  ) async => _conceptProgress[_conceptId(unitId, conceptKey)];

  @override
  Future<ConceptProgress> completeMission(
    int sessionId, {
    required bool cleared,
    required DateTime completedAt,
    ExplainedItem? explained,
    ReviewItem? review,
  }) async {
    final session = _sessions[sessionId];
    if (session == null) {
      throw StateError('session $sessionId does not exist');
    }
    final conceptKey = session.focusConceptKey ?? '';
    if (session.unitId.isEmpty || conceptKey.isEmpty) {
      throw StateError('completeMission requires a focused session');
    }
    final id = _conceptId(session.unitId, conceptKey);
    final current = _conceptProgress[id];
    if (_completedMissionIds.contains(sessionId)) {
      if (current == null) {
        throw StateError('completed session has no concept progress');
      }
      return current;
    }

    _validateCompletionPayload(
      unitId: session.unitId,
      conceptKey: conceptKey,
      cleared: cleared,
      explained: explained,
      review: review,
    );
    final localCompletedAt = completedAt.toLocal();
    final progress = _nextConceptProgress(
      unitId: session.unitId,
      conceptKey: conceptKey,
      kind: session.missionKind,
      cleared: cleared,
      day: dayKeyOf(localCompletedAt),
      completedAt: localCompletedAt,
      examDate: _exam,
      sourceSessionId: sessionId,
      previous: current,
    );

    if (cleared) {
      _explained[id] = explained!;
      _reviews.remove(id);
      final day = progress.lastAttemptDay;
      final oldDay = _days[day];
      _days[day] = DayRecord(
        day: day,
        sessions: oldDay?.sessions ?? 0,
        done: (oldDay?.done ?? 0) + 1,
        textTurns: oldDay?.textTurns ?? 0,
      );
    } else {
      final item = review!;
      final oldReview = _reviews[id];
      _reviews[id] = ReviewItem(
        unitId: session.unitId,
        conceptKey: conceptKey,
        label: item.label,
        reason: item.reason,
        lastSeen: localCompletedAt,
        timesSeen: oldReview?.timesSeen ?? item.timesSeen,
        lastReviewedAt: oldReview?.lastReviewedAt ?? item.lastReviewedAt,
      );
    }
    _conceptProgress[id] = progress;
    _sessions[sessionId] = SavedSession(
      id: session.id,
      unitId: session.unitId,
      focusConceptKey: session.focusConceptKey,
      tactic: session.tactic,
      missionKind: session.missionKind,
      startedAt: session.startedAt,
      updatedAt: localCompletedAt,
      endedAt: localCompletedAt,
      dossier: session.dossier,
      transcript: session.transcript,
    );
    _completedMissionIds.add(sessionId);
    return progress;
  }

  @override
  Future<DateTime?> examDate() async => _exam;

  @override
  Future<void> setExamDate(DateTime? date) async => _exam = date;

  @override
  Future<String?> getSetting(String key) async => _settings[key];

  @override
  Future<void> setSetting(String key, String? value) async {
    if (value == null) {
      _settings.remove(key);
    } else {
      _settings[key] = value;
    }
  }

  @override
  Future<LearningQuestMaterializationResult>
  materializeLearningQuestDefinitions({
    required LearningScope scope,
    required Iterable<LearningQuestDefinition> definitions,
  }) async {
    final validated = _validateLearningQuestMaterialization(
      scope: scope,
      definitions: definitions,
    );
    if (validated.isEmpty) {
      return LearningQuestMaterializationResult(
        insertedCount: 0,
        quests: const [],
      );
    }

    // 既存衝突をすべて確認してからcopyへ書き込み、list全体を原子的に扱う。
    for (final definition in validated) {
      final parts = definition.questInstanceId.split(':');
      if (parts.first == 'daily') {
        final prefix = 'daily:${parts[1]}:';
        if (_learningQuests.values.any(
          (quest) =>
              quest.scope == LearningScope.personal &&
              quest.questInstanceId.startsWith(prefix) &&
              quest.questInstanceId != definition.questInstanceId,
        )) {
          throw StateError(
            'another daily quest is already materialized for this day',
          );
        }
      }
      final existing =
          _learningQuests[_learningProjectionKey(
            LearningScope.personal,
            definition.questInstanceId,
          )];
      if (existing != null) {
        _requireCompatibleMaterializedQuest(existing, definition);
      }
    }

    final quests = Map<String, LearningQuestProgress>.of(_learningQuests);
    final materialized = <LearningQuestProgress>[];
    var insertedCount = 0;
    for (final definition in validated) {
      final key = _learningProjectionKey(
        LearningScope.personal,
        definition.questInstanceId,
      );
      final existing = quests[key];
      if (existing != null) {
        materialized.add(existing);
        continue;
      }
      final created = LearningQuestProgress(
        scope: LearningScope.personal,
        questInstanceId: definition.questInstanceId,
        progress: 0,
        target: definition.target,
        completedAt: null,
        rewardedAt: null,
        definitionVersion: definition.definitionVersion,
      );
      quests[key] = created;
      insertedCount++;
      materialized.add(created);
    }
    _replaceMap(_learningQuests, quests);
    return LearningQuestMaterializationResult(
      insertedCount: insertedCount,
      quests: materialized,
    );
  }

  @override
  Future<CommitLearningResult> commitLearningEvent(
    LearningEventCommand event, {
    LearningCommitRules rules = const LearningCommitRules(),
  }) async {
    _validateLearningRules(rules);
    final existing = _learningEvents[event.eventId];
    if (existing != null) {
      if (!_sameLearningEvent(existing, event) ||
          !_sameStringSet(
            _learningEventSkills[event.eventId] ?? const {},
            event.skillIds,
          ) ||
          !_sameNeedCodes(
            _learningPracticeNeeds[event.eventId] ?? const {},
            event.practiceNeedCodes,
          ) ||
          !_sameNeedCodes(
            _learningResolvedPracticeNeeds[event.eventId] ?? const {},
            event.resolvedPracticeNeedCodes,
          )) {
        throw StateError('learning event ID was reused with different data');
      }
      return _memoryLearningCommitResult(
        event: existing,
        inserted: false,
        skillIds: event.skillIds,
        nodes: _learningNodes,
        skills: _learningSkills,
        rewards: _learningRewards,
        quests: _learningQuests,
        questEvents: _learningQuestEvents,
      );
    }

    if (event.runId case final runId?) {
      final run = _learningRuns[runId];
      if (run != null &&
          (run.scope != event.scope || run.nodeId != event.nodeId)) {
        throw StateError('learning run does not match the event');
      }
    }

    // Copy-on-writeにし、policyや検証が途中でthrowしても既存状態を変えない。
    final events = Map<String, LearningEventRecord>.of(_learningEvents);
    final eventSkills = {
      for (final entry in _learningEventSkills.entries)
        entry.key: Set<String>.of(entry.value),
    };
    final practiceNeeds = {
      for (final entry in _learningPracticeNeeds.entries)
        entry.key: {
          for (final needs in entry.value.entries)
            needs.key: Set<String>.of(needs.value),
        },
    };
    final resolvedPracticeNeeds = {
      for (final entry in _learningResolvedPracticeNeeds.entries)
        entry.key: {
          for (final needs in entry.value.entries)
            needs.key: Set<String>.of(needs.value),
        },
    };
    final needStates = Map<String, _LearningNeedState>.of(_learningNeedStates);
    final nodes = Map<String, LearningNodeProgress>.of(_learningNodes);
    final skills = Map<String, LearningSkillProgress>.of(_learningSkills);
    final days = Map<String, LearningDay>.of(_learningDays);
    final freezes = Map<String, LearningStreakFreeze>.of(_learningFreezes);
    final heartStates = Map<String, LearningChallengeHeartState>.of(
      _learningHeartStates,
    );
    final rewards = Map<String, LearningRewardEntry>.of(_learningRewards);
    final quests = Map<String, LearningQuestProgress>.of(_learningQuests);
    final questEvents = {
      for (final entry in _learningQuestEvents.entries)
        entry.key: Set<String>.of(entry.value),
    };
    final runs = Map<String, LearningRun>.of(_learningRuns);
    final leagueHistory = Map<String, LearningLeagueWeek>.of(
      _learningLeagueHistory,
    );

    eventSkills[event.eventId] = Set.of(event.skillIds);
    practiceNeeds[event.eventId] = {
      for (final entry in event.practiceNeedCodes.entries)
        entry.key: Set.of(entry.value),
    };
    resolvedPracticeNeeds[event.eventId] = {
      for (final entry in event.resolvedPracticeNeedCodes.entries)
        entry.key: Set.of(entry.value),
    };
    _applyLearningNeedChangesMemory(needStates, event);

    final nodeKey = _learningProjectionKey(event.scope, event.nodeId);
    final oldNode = nodes[nodeKey];
    final eventClearsNode = event.qualifiesForLearningDay;
    final nodeState =
        oldNode?.state == LearningNodeState.cleared || eventClearsNode
        ? LearningNodeState.cleared
        : LearningNodeState.inProgress;
    nodes[nodeKey] = LearningNodeProgress(
      scope: event.scope,
      nodeId: event.nodeId,
      state: nodeState,
      attemptCount: (oldNode?.attemptCount ?? 0) + 1,
      bestEvidence: LearningEvidenceLevel.fromRank(
        math.max(oldNode?.bestEvidence.rank ?? 0, event.evidence.rank),
      )!,
      lastAttemptDay: event.learningDay,
      lastEventId: event.eventId,
      completedAt:
          oldNode?.completedAt ?? (eventClearsNode ? event.occurredAt : null),
      contentVersion: event.contentVersion,
    );

    var hasDueSpacedRetrieval = false;
    for (final skillId in event.skillIds) {
      final skillKey = _learningProjectionKey(event.scope, skillId);
      final oldSkill = skills[skillKey];
      hasDueSpacedRetrieval |= _isDueSpacedRetrieval(
        event: event,
        previous: oldSkill,
      );
      skills[skillKey] = _nextLearningSkillProgress(
        event: event,
        skillId: skillId,
        previous: oldSkill,
        spacingPolicy: rules.spacingPolicy,
      );
    }
    final meaningfulProgress = _isMeaningfulLearningProgress(
      event: event,
      previousNode: oldNode,
      hasDueSpacedRetrieval: hasDueSpacedRetrieval,
    );
    final record = _learningEventFromCommand(
      event,
      meaningfulProgress: meaningfulProgress,
    );
    events[event.eventId] = record;

    final freeze = _learningFreezeForEvent(
      event: event,
      days: days.values,
      freezes: freezes.values,
      gemSpends: _learningGemSpends.values,
    );
    if (freeze != null) {
      freezes[_learningProjectionKey(freeze.scope, freeze.day)] = freeze;
    }

    if (event.qualifiesForLearningDay) {
      final dayKey = _learningProjectionKey(event.scope, event.learningDay);
      final oldDay = days[dayKey];
      days[dayKey] = LearningDay(
        scope: event.scope,
        day: event.learningDay,
        qualifyingCount: (oldDay?.qualifyingCount ?? 0) + 1,
        firstEventAt:
            oldDay == null || event.occurredAt.isBefore(oldDay.firstEventAt)
            ? event.occurredAt
            : oldDay.firstEventAt,
        lastEventAt:
            oldDay == null || event.occurredAt.isAfter(oldDay.lastEventAt)
            ? event.occurredAt
            : oldDay.lastEventAt,
      );
    }

    final xpEarnedOnDay = rewards.values
        .where((entry) => entry.type == LearningRewardType.xp)
        .where((entry) {
          final source = entry.sourceEventId == null
              ? null
              : events[entry.sourceEventId];
          return source?.learningDay == event.learningDay;
        })
        .fold(0, (sum, entry) => sum + entry.amount);
    final xp = rules.rewardPolicy.xpForEvent(
      event: event,
      meaningfulProgress: meaningfulProgress,
      xpEarnedOnDay: xpEarnedOnDay,
    );
    if (xp < 0 || xp > 100000) {
      throw StateError('reward policy returned an invalid amount');
    }
    if (xp > 0) {
      if (!event.allowsRewards) {
        throw StateError('reward policy tried to reward an ineligible event');
      }
      final entry = LearningRewardEntry(
        entryId: 'xp:${event.eventId}',
        scope: LearningScope.personal,
        type: LearningRewardType.xp,
        amount: xp,
        reason: 'meaningful-progress.v2',
        sourceEventId: event.eventId,
        createdAt: event.occurredAt,
      );
      rewards[entry.entryId] = entry;
    }

    if (event.allowsRewards && meaningfulProgress) {
      for (final quest in rules.quests) {
        if (!quest.matches(event)) continue;
        final questKey = _learningProjectionKey(
          LearningScope.personal,
          quest.questInstanceId,
        );
        final oldQuest = quests[questKey];
        if (oldQuest != null) {
          _requireCompatibleMaterializedQuest(oldQuest, quest);
        }
        questEvents
            .putIfAbsent(quest.questInstanceId, () => <String>{})
            .add(event.eventId);
        final progress = math.min(quest.target, (oldQuest?.progress ?? 0) + 1);
        final newlyCompleted =
            progress >= quest.target && oldQuest?.completedAt == null;
        final completedAt =
            oldQuest?.completedAt ?? (newlyCompleted ? event.occurredAt : null);
        DateTime? rewardedAt = oldQuest?.rewardedAt;
        if (newlyCompleted) {
          rewardedAt = event.occurredAt;
          if (quest.rewardGems > 0) {
            final reward = LearningRewardEntry(
              entryId: 'gems.quest:${quest.questInstanceId}',
              scope: LearningScope.personal,
              type: LearningRewardType.gems,
              amount: quest.rewardGems,
              reason: 'quest.${quest.questInstanceId}',
              sourceEventId: event.eventId,
              createdAt: event.occurredAt,
            );
            rewards[reward.entryId] = reward;
          }
        }
        quests[questKey] = LearningQuestProgress(
          scope: LearningScope.personal,
          questInstanceId: quest.questInstanceId,
          progress: progress,
          target: quest.target,
          completedAt: completedAt,
          rewardedAt: rewardedAt,
          definitionVersion: quest.definitionVersion,
        );
      }
    }
    final rebuiltLeagueHistory = _buildLearningLeagueHistory(
      events: events.values,
      rewards: rewards.values,
      existing: leagueHistory,
      finalizedAt: event.occurredAt,
    );
    if (event.runId case final runId?) runs.remove(runId);

    _replaceMap(_learningEvents, events);
    _replaceNestedSetMap(_learningEventSkills, eventSkills);
    _replaceNeedMap(_learningPracticeNeeds, practiceNeeds);
    _replaceNeedMap(_learningResolvedPracticeNeeds, resolvedPracticeNeeds);
    _replaceMap(_learningNeedStates, needStates);
    _replaceMap(_learningNodes, nodes);
    _replaceMap(_learningSkills, skills);
    _replaceMap(_learningDays, days);
    _replaceMap(_learningFreezes, freezes);
    _replaceMap(_learningHeartStates, heartStates);
    _replaceMap(_learningRewards, rewards);
    _replaceMap(_learningQuests, quests);
    _replaceNestedSetMap(_learningQuestEvents, questEvents);
    _replaceMap(_learningRuns, runs);
    _replaceMap(_learningLeagueHistory, rebuiltLeagueHistory);

    return _memoryLearningCommitResult(
      event: record,
      inserted: true,
      skillIds: event.skillIds,
      nodes: _learningNodes,
      skills: _learningSkills,
      rewards: _learningRewards,
      quests: _learningQuests,
      questEvents: _learningQuestEvents,
    );
  }

  @override
  Future<LearningProgressSnapshot> learningProgressSnapshot(
    LearningScope scope,
  ) async => _memoryLearningSnapshot(
    scope: scope,
    events: _learningEvents,
    nodes: _learningNodes,
    skills: _learningSkills,
    days: _learningDays,
    freezes: _learningFreezes,
    heartStates: _learningHeartStates,
    rewards: _learningRewards,
    quests: _learningQuests,
    runs: _learningRuns,
    gemSpends: _learningGemSpends,
    cosmeticLoadout: _learningCosmeticLoadout,
    cosmeticGrants: _learningCosmeticGrants,
    localCoopRuns: _learningLocalCoopRuns,
    leagueHistory: _learningLeagueHistory,
    localLeagueHistory: _learningLocalLeagueHistory,
    needStates: _learningNeedStates,
  );

  @override
  Future<List<LearningNeedStateView>> learningNeedStates(
    LearningScope scope,
  ) async {
    final states =
        _learningNeedStates.values.where((state) => state.scope == scope).map(
          (state) => LearningNeedStateView(
            scope: state.scope,
            skillId: state.skillId,
            needCode: state.needCode,
            firstObservedDay: state.firstObservedDay,
            lastObservedDay: state.lastObservedDay,
            resolvedDay: state.resolvedDay,
          ),
        )
        .toList()
      ..sort((a, b) {
        final bySkill = a.skillId.compareTo(b.skillId);
        return bySkill != 0 ? bySkill : a.needCode.compareTo(b.needCode);
      });
    return List.unmodifiable(states);
  }

  @override
  Future<LearningLanFriendsRewardResult> grantLearningLanFriendsReward({
    required String roomId,
    required DateTime completedAt,
  }) async {
    _validateLearningLanFriendsReward(roomId: roomId, completedAt: completedAt);
    final expected = _learningLanFriendsReward(
      roomId: roomId,
      completedAt: completedAt,
    );
    final existing = _learningRewards[expected.entryId];
    if (existing != null) {
      if (!_sameLearningLanFriendsReward(existing, expected)) {
        throw StateError('LAN friends reward ID was reused');
      }
      return LearningLanFriendsRewardResult(applied: false, reward: existing);
    }
    _learningRewards[expected.entryId] = expected;
    return LearningLanFriendsRewardResult(applied: true, reward: expected);
  }

  @override
  Future<LearningRun> beginLearningRun(LearningRun run) async {
    _validateLearningRun(run);
    var normalized = run;
    LearningChallengeHeartState? stateToCreate;
    if (run.scope == LearningScope.schoolLocal && run.challengeHearts != null) {
      normalized = _copyLearningRun(run, challengeHearts: null);
    } else if (run.challengeHearts != null) {
      if (run.challengeHearts != LearningChallengeHeartState.defaultMaximum) {
        throw ArgumentError.value(
          run.challengeHearts,
          'challengeHearts',
          'a new challenge must start at the configured maximum',
        );
      }
      final state =
          _learningHeartStates[LearningScope.personal.wire] ??
          (stateToCreate = LearningChallengeHeartState(
            scope: LearningScope.personal,
            current: LearningChallengeHeartState.defaultMaximum,
            maximum: LearningChallengeHeartState.defaultMaximum,
            lastLossDay: null,
            lastRecoveryDay: null,
            updatedAt: run.updatedAt,
          ));
      normalized = _copyLearningRun(run, challengeHearts: state.current);
    }
    final existing = _learningRuns[run.runId];
    if (existing != null) {
      if (!_sameLearningRun(existing, normalized)) {
        throw StateError('learning run ID was reused with different data');
      }
      return existing;
    }
    if (stateToCreate != null) {
      _learningHeartStates[LearningScope.personal.wire] = stateToCreate;
    }
    _learningRuns[run.runId] = normalized;
    return normalized;
  }

  @override
  Future<LearningRun> checkpointLearningRun(
    String runId, {
    required int activityIndex,
    int? challengeHearts,
    required DateTime updatedAt,
  }) async {
    final current = _learningRuns[runId];
    if (current == null) throw StateError('learning run does not exist');
    if (activityIndex < current.activityIndex) {
      throw StateError('learning run cannot move backwards');
    }
    if (challengeHearts != null && challengeHearts != current.challengeHearts) {
      throw StateError(
        'challenge hearts must be changed with spendLearningChallengeHeart',
      );
    }
    if (updatedAt.isBefore(current.updatedAt)) {
      throw StateError('learning run timestamp cannot move backwards');
    }
    final next = LearningRun(
      runId: current.runId,
      scope: current.scope,
      nodeId: current.nodeId,
      activityIndex: activityIndex,
      challengeHearts: challengeHearts ?? current.challengeHearts,
      contentVersion: current.contentVersion,
      updatedAt: updatedAt,
    );
    _learningRuns[runId] = next;
    return next;
  }

  @override
  Future<void> discardLearningRun(String runId) async {
    if (!_learningOpaqueId.hasMatch(runId)) {
      throw ArgumentError.value(runId, 'runId', 'opaque ASCII ID required');
    }
    _learningRuns.remove(runId);
  }

  @override
  Future<LearningChallengeHeartSpendResult> spendLearningChallengeHeart(
    String runId, {
    required String lossId,
    required int activityIndex,
    required String learningDay,
    required DateTime occurredAt,
  }) async {
    _validateChallengeHeartLoss(
      runId: runId,
      lossId: lossId,
      activityIndex: activityIndex,
      learningDay: learningDay,
      occurredAt: occurredAt,
    );
    final oldLoss = _learningHeartLosses[lossId];
    if (oldLoss != null) {
      if (!oldLoss.matches(
        runId: runId,
        activityIndex: activityIndex,
        learningDay: learningDay,
        occurredAt: occurredAt,
      )) {
        throw StateError('challenge heart loss ID was reused');
      }
      final state = _learningHeartStates[LearningScope.personal.wire];
      if (state == null) {
        throw StateError('challenge heart state does not exist');
      }
      return LearningChallengeHeartSpendResult(
        spent: false,
        state: state,
        run: _learningRuns[runId],
      );
    }
    final currentRun = _learningRuns[runId];
    if (currentRun == null) throw StateError('learning run does not exist');
    if (currentRun.scope != LearningScope.personal ||
        currentRun.challengeHearts == null) {
      throw StateError('run does not use personal challenge hearts');
    }
    if (activityIndex < currentRun.activityIndex) {
      throw StateError('learning run cannot move backwards');
    }
    if (occurredAt.isBefore(currentRun.updatedAt)) {
      throw StateError('learning run timestamp cannot move backwards');
    }
    final storedState = _learningHeartStates[LearningScope.personal.wire];
    if (storedState == null) {
      throw StateError('challenge heart state does not exist');
    }
    final refreshed = _refreshLearningHeartStateByTime(
      state: storedState,
      learningDay: learningDay,
      occurredAt: occurredAt,
    );
    final currentState = refreshed.state;
    if (currentState.current <= 0) {
      throw StateError('challenge hearts are already empty');
    }
    // Copy-on-write: 検証完了前に既存run/stateを変更しない。
    final nextState = LearningChallengeHeartState(
      scope: LearningScope.personal,
      current: currentState.current - 1,
      maximum: currentState.maximum,
      lastLossDay: learningDay,
      lastRecoveryDay: currentState.lastRecoveryDay,
      updatedAt: occurredAt,
    );
    final nextRuns = Map<String, LearningRun>.of(_learningRuns);
    for (final entry in nextRuns.entries.toList()) {
      if (entry.value.scope == LearningScope.personal &&
          entry.value.challengeHearts != null) {
        nextRuns[entry.key] = _copyLearningRun(
          entry.value,
          challengeHearts: nextState.current,
        );
      }
    }
    final nextRun = _copyLearningRun(
      nextRuns[runId]!,
      activityIndex: activityIndex,
      challengeHearts: nextState.current,
      updatedAt: occurredAt,
    );
    nextRuns[runId] = nextRun;
    _learningHeartStates[LearningScope.personal.wire] = nextState;
    _learningHeartLosses[lossId] = _ChallengeHeartLoss(
      lossId: lossId,
      runId: runId,
      activityIndex: activityIndex,
      learningDay: learningDay,
      occurredAt: occurredAt,
      remainingHearts: nextState.current,
    );
    _replaceMap(_learningRuns, nextRuns);
    return LearningChallengeHeartSpendResult(
      spent: true,
      state: nextState,
      run: nextRun,
    );
  }

  @override
  Future<LearningChallengeHeartRefreshResult> refreshLearningChallengeHearts({
    required String learningDay,
    required DateTime occurredAt,
  }) async {
    _validateChallengeHeartClock(
      learningDay: learningDay,
      occurredAt: occurredAt,
    );
    final state =
        _learningHeartStates[LearningScope.personal.wire] ??
        const LearningChallengeHeartState.initial();
    final result = _refreshLearningHeartStateByTime(
      state: state,
      learningDay: learningDay,
      occurredAt: occurredAt,
    );
    if (result.recovered > 0) {
      _learningHeartStates[LearningScope.personal.wire] = result.state;
      _syncMemoryHeartRuns(result.state);
    }
    return result;
  }

  @override
  Future<LearningChallengeHeartPracticeRecoveryResult>
  recoverLearningChallengeHeartWithPractice({
    required String recoveryId,
    required String sourceEventId,
    required String learningDay,
    required DateTime occurredAt,
  }) async {
    _validateChallengeHeartPracticeRecovery(
      recoveryId: recoveryId,
      sourceEventId: sourceEventId,
      learningDay: learningDay,
      occurredAt: occurredAt,
    );
    final old = _learningHeartPracticeRecoveries[recoveryId];
    if (old != null) {
      if (!old.matches(
        sourceEventId: sourceEventId,
        learningDay: learningDay,
        occurredAt: occurredAt,
      )) {
        throw StateError('heart recovery ID was reused');
      }
      return LearningChallengeHeartPracticeRecoveryResult(
        applied: false,
        recovered: old.recoveredHearts,
        state:
            _learningHeartStates[LearningScope.personal.wire] ??
            const LearningChallengeHeartState.initial(),
      );
    }
    final event = _learningEvents[sourceEventId];
    if (event == null ||
        event.scope != LearningScope.personal ||
        event.origin != LearningOrigin.practice ||
        event.activityId != 'practice.heart-recovery.v1' ||
        event.outcome == LearningAttemptOutcome.retryNeeded ||
        event.learningDay != learningDay ||
        occurredAt.isBefore(event.occurredAt)) {
      throw StateError('event is not an eligible heart recovery practice');
    }
    final timed = _refreshLearningHeartStateByTime(
      state:
          _learningHeartStates[LearningScope.personal.wire] ??
          const LearningChallengeHeartState.initial(),
      learningDay: learningDay,
      occurredAt: occurredAt,
    );
    final recovered = timed.state.current < timed.state.maximum ? 1 : 0;
    final current = timed.state.current + recovered;
    final next = LearningChallengeHeartState(
      scope: LearningScope.personal,
      current: current,
      maximum: timed.state.maximum,
      lastLossDay: current >= timed.state.maximum
          ? null
          : timed.state.lastLossDay,
      lastRecoveryDay: recovered > 0
          ? learningDay
          : timed.state.lastRecoveryDay,
      updatedAt: recovered > 0 ? occurredAt : timed.state.updatedAt,
    );
    _learningHeartPracticeRecoveries[recoveryId] =
        _ChallengeHeartPracticeRecovery(
          recoveryId: recoveryId,
          sourceEventId: sourceEventId,
          learningDay: learningDay,
          occurredAt: occurredAt,
          recoveredHearts: recovered,
          resultingHearts: next.current,
        );
    if (timed.recovered > 0 || recovered > 0) {
      _learningHeartStates[LearningScope.personal.wire] = next;
      _syncMemoryHeartRuns(next);
    }
    return LearningChallengeHeartPracticeRecoveryResult(
      applied: true,
      recovered: recovered,
      state: next,
    );
  }

  void _syncMemoryHeartRuns(LearningChallengeHeartState state) {
    for (final entry in _learningRuns.entries.toList()) {
      if (entry.value.scope == LearningScope.personal &&
          entry.value.challengeHearts != null) {
        _learningRuns[entry.key] = _copyLearningRun(
          entry.value,
          challengeHearts: state.current,
        );
      }
    }
  }

  @override
  Future<LearningLocalCoopRun> beginLearningLocalCoopRun(
    LearningLocalCoopRunCommand command,
  ) async {
    _validateLearningLocalCoopRun(command);
    final existing = _learningLocalCoopRuns[command.runId];
    if (existing != null) {
      if (!_sameLearningLocalCoopRun(existing, command)) {
        throw StateError('local coop run ID was reused with different data');
      }
      return existing;
    }
    final questKey = _learningProjectionKey(
      LearningScope.personal,
      command.questInstanceId,
    );
    if (_learningQuests.containsKey(questKey)) {
      throw StateError('local coop quest ID already exists');
    }
    final run = LearningLocalCoopRun(
      runId: command.runId,
      scope: LearningScope.personal,
      questInstanceId: command.questInstanceId,
      participantIds: Set.unmodifiable(command.participantIds),
      contributingParticipantIds: const <String>{},
      progress: 0,
      target: command.target,
      rewardGems: command.rewardGems,
      startDay: command.startDay,
      endDay: command.endDay,
      definitionVersion: command.definitionVersion,
      startedAt: command.startedAt,
      completedAt: null,
      rewardedAt: null,
    );
    _learningLocalCoopRuns[command.runId] = run;
    _learningQuests[questKey] = LearningQuestProgress(
      scope: LearningScope.personal,
      questInstanceId: command.questInstanceId,
      progress: 0,
      target: command.target,
      completedAt: null,
      rewardedAt: null,
      definitionVersion: command.definitionVersion,
    );
    return run;
  }

  @override
  Future<LearningLocalCoopContributionResult> contributeLearningLocalCoopRun(
    String runId, {
    required String contributionId,
    required String participantId,
    required String eventId,
    required DateTime occurredAt,
  }) async {
    _validateLearningLocalCoopContribution(
      runId: runId,
      contributionId: contributionId,
      participantId: participantId,
      eventId: eventId,
      occurredAt: occurredAt,
    );
    final oldContribution = _learningLocalCoopContributions[contributionId];
    if (oldContribution != null) {
      if (!oldContribution.matches(
        runId: runId,
        participantId: participantId,
        eventId: eventId,
        occurredAt: occurredAt,
      )) {
        throw StateError('local coop contribution ID was reused');
      }
      final oldRun = _learningLocalCoopRuns[runId];
      if (oldRun == null) throw StateError('local coop run does not exist');
      final reward = _learningRewards['gems.quest:${oldRun.questInstanceId}'];
      return LearningLocalCoopContributionResult(
        applied: false,
        run: oldRun,
        rewards: reward == null ? const [] : [reward],
      );
    }
    final run = _learningLocalCoopRuns[runId];
    if (run == null) throw StateError('local coop run does not exist');
    if (run.completed) throw StateError('local coop run is already complete');
    if (!run.participantIds.contains(participantId)) {
      throw StateError('participant is not part of the local coop run');
    }
    final event = _learningEvents[eventId];
    if (event == null) throw StateError('learning event does not exist');
    if (event.scope != LearningScope.personal || !event.meaningfulProgress) {
      throw StateError('local coop requires a personal meaningful event');
    }
    if (event.learningDay.compareTo(run.startDay) < 0 ||
        event.learningDay.compareTo(run.endDay) > 0) {
      throw StateError('learning event is outside the local coop period');
    }
    if (occurredAt.isBefore(event.occurredAt)) {
      throw StateError('contribution cannot predate its learning event');
    }
    if (_learningLocalCoopContributions.values.any(
      (item) => item.eventId == eventId,
    )) {
      throw StateError('learning event already contributed to a coop run');
    }

    final contributions = Map<String, _LearningLocalCoopContribution>.of(
      _learningLocalCoopContributions,
    );
    contributions[contributionId] = _LearningLocalCoopContribution(
      contributionId: contributionId,
      runId: runId,
      participantId: participantId,
      eventId: eventId,
      occurredAt: occurredAt,
    );
    final runContributions = contributions.values
        .where((item) => item.runId == runId)
        .toList();
    final contributors = {
      for (final item in runContributions) item.participantId,
    };
    final completesNow =
        runContributions.length >= run.target &&
        contributors.containsAll(run.participantIds);
    final completedAt = completesNow ? occurredAt : null;
    final nextRun = _copyLearningLocalCoopRun(
      run,
      contributingParticipantIds: contributors,
      progress: runContributions.length,
      completedAt: completedAt,
      rewardedAt: completedAt,
    );
    final quests = Map<String, LearningQuestProgress>.of(_learningQuests);
    final questEvents = {
      for (final entry in _learningQuestEvents.entries)
        entry.key: Set<String>.of(entry.value),
    };
    final questKey = _learningProjectionKey(
      LearningScope.personal,
      run.questInstanceId,
    );
    quests[questKey] = LearningQuestProgress(
      scope: LearningScope.personal,
      questInstanceId: run.questInstanceId,
      progress: math.min(nextRun.progress, nextRun.target),
      target: nextRun.target,
      completedAt: completedAt,
      rewardedAt: completedAt,
      definitionVersion: nextRun.definitionVersion,
    );
    questEvents.putIfAbsent(run.questInstanceId, () => <String>{}).add(eventId);
    final rewards = Map<String, LearningRewardEntry>.of(_learningRewards);
    LearningRewardEntry? reward;
    if (completesNow && run.rewardGems > 0) {
      reward = LearningRewardEntry(
        entryId: 'gems.quest:${run.questInstanceId}',
        scope: LearningScope.personal,
        type: LearningRewardType.gems,
        amount: run.rewardGems,
        reason: 'quest.${run.questInstanceId}',
        sourceEventId: eventId,
        createdAt: occurredAt,
      );
      rewards[reward.entryId] = reward;
    }
    _replaceMap(_learningLocalCoopContributions, contributions);
    _learningLocalCoopRuns[runId] = nextRun;
    _replaceMap(_learningQuests, quests);
    _replaceNestedSetMap(_learningQuestEvents, questEvents);
    _replaceMap(_learningRewards, rewards);
    return LearningLocalCoopContributionResult(
      applied: true,
      run: nextRun,
      rewards: reward == null ? const [] : [reward],
    );
  }

  @override
  Future<List<LearningLocalCoopContribution>> localCoopContributions(
    Set<String> runIds,
  ) async {
    final ids = _validatedLearningLocalCoopRunIds(runIds).toSet();
    if (ids.isEmpty) return const [];
    final result = <LearningLocalCoopContribution>[];
    for (final contribution in _learningLocalCoopContributions.values) {
      if (!ids.contains(contribution.runId) ||
          !_learningLocalCoopRuns.containsKey(contribution.runId)) {
        continue;
      }
      final event = _learningEvents[contribution.eventId];
      if (event == null) continue;
      result.add(
        _learningLocalCoopContributionProjection(
          runId: contribution.runId,
          participantId: contribution.participantId,
          eventId: contribution.eventId,
          scope: event.scope,
          learningDay: event.learningDay,
          meaningfulProgress: event.meaningfulProgress,
        ),
      );
    }
    result.sort((left, right) {
      final day = left.learningDay.compareTo(right.learningDay);
      if (day != 0) return day;
      final run = left.runId.compareTo(right.runId);
      if (run != 0) return run;
      final participant = left.participantId.compareTo(right.participantId);
      if (participant != 0) return participant;
      return left.eventId.compareTo(right.eventId);
    });
    return List.unmodifiable(result);
  }

  @override
  Future<LearningLocalLeagueFinalizeResult> finalizeLearningLocalWeeklyLeague({
    required String weekKey,
    required DateTime finalizedAt,
  }) async {
    if (learningWeekKey(weekKey) != weekKey) {
      throw ArgumentError.value(weekKey, 'weekKey', 'Monday required');
    }
    final history = _learningLocalLeagueHistory.values.toList(growable: false)
      ..sort((left, right) => right.weekKey.compareTo(left.weekKey));
    final runs = _learningLocalCoopRuns.values
        .where(
          (run) =>
              run.scope == LearningScope.personal &&
              run.startDay == weekKey &&
              (run.definitionVersion ==
                      LocalWeeklyLeagueProjection.definitionVersion ||
                  run.definitionVersion ==
                      LocalWeeklyLeagueProjection.pairBridgeDefinitionVersion),
        )
        .toList(growable: false);
    final contributions = await localCoopContributions({
      for (final run in runs) run.runId,
    });
    final view = LocalWeeklyLeagueProjection.project(
      scope: LearningScope.personal,
      weekKey: weekKey,
      runs: runs,
      contributions: contributions,
      history: history,
    );
    final result = LocalWeeklyLeagueFinalization.finalize(
      view: view,
      history: history,
      finalizedAt: finalizedAt,
    );
    if (result.applied) {
      _learningLocalLeagueHistory[weekKey] = result.week!;
    }
    return result;
  }

  @override
  Future<LearningLocalLeagueCatchUpResult> catchUpLearningLocalWeeklyLeagues({
    required String currentWeekKey,
    required DateTime finalizedAt,
    String? afterWeekKey,
  }) async {
    if (learningWeekKey(currentWeekKey) != currentWeekKey) {
      throw ArgumentError.value(
        currentWeekKey,
        'currentWeekKey',
        'Monday required',
      );
    }
    final stagedHistory = Map<String, LearningLocalLeagueWeek>.of(
      _learningLocalLeagueHistory,
    );
    final history = stagedHistory.values.toList(growable: true);
    final plan = LocalWeeklyLeagueCatchUp.plan(
      currentWeekKey: currentWeekKey,
      history: history,
      runWeekKeys: _learningLocalCoopRuns.values
          .where(
            (run) =>
                run.scope == LearningScope.personal &&
                (run.definitionVersion ==
                        LocalWeeklyLeagueProjection.definitionVersion ||
                    run.definitionVersion ==
                        LocalWeeklyLeagueProjection
                            .pairBridgeDefinitionVersion),
          )
          .map((run) => run.startDay),
      afterWeekKey: afterWeekKey,
    );
    final results = <LearningLocalLeagueFinalizeResult>[];
    for (final weekKey in plan.candidateWeekKeys) {
      final runs = _learningLocalCoopRuns.values
          .where(
            (run) =>
                run.scope == LearningScope.personal &&
                run.startDay == weekKey &&
                (run.definitionVersion ==
                        LocalWeeklyLeagueProjection.definitionVersion ||
                    run.definitionVersion ==
                        LocalWeeklyLeagueProjection
                            .pairBridgeDefinitionVersion),
          )
          .toList(growable: false);
      final contributions = await localCoopContributions({
        for (final run in runs) run.runId,
      });
      final view = LocalWeeklyLeagueProjection.project(
        scope: LearningScope.personal,
        weekKey: weekKey,
        runs: runs,
        contributions: contributions,
        history: history,
      );
      final result = LocalWeeklyLeagueFinalization.finalize(
        view: view,
        history: history,
        finalizedAt: finalizedAt,
      );
      results.add(result);
      if (!result.applied) continue;
      stagedHistory[weekKey] = result.week!;
      history.add(result.week!);
    }
    _replaceMap(_learningLocalLeagueHistory, stagedHistory);
    return LearningLocalLeagueCatchUpResult(
      plan: plan,
      results: List.unmodifiable(results),
    );
  }

  @override
  Future<LearningGemSpendResult> replenishLearningStreakFreezeWithGems({
    required String spendId,
    required String learningDay,
    required DateTime occurredAt,
    SafeLearningEconomyPolicyV1 economyPolicy =
        const SafeLearningEconomyPolicyV1(),
  }) async {
    economyPolicy.validate();
    _validateLearningGemSpend(
      spendId: spendId,
      learningDay: learningDay,
      occurredAt: occurredAt,
    );
    final old = _learningGemSpends[spendId];
    if (old != null) {
      if (old.kind != LearningGemSpendKind.streakFreezeRefill ||
          old.learningDay != learningDay ||
          old.occurredAt.millisecondsSinceEpoch !=
              occurredAt.millisecondsSinceEpoch) {
        throw StateError('gem spend ID was reused with different data');
      }
      return _memoryLearningGemSpendResult(applied: false, spend: old);
    }
    final weekKey = learningWeekKey(learningDay);
    final refills = _learningGemSpends.values
        .where(
          (item) =>
              item.kind == LearningGemSpendKind.streakFreezeRefill &&
              item.weekKey == weekKey,
        )
        .length;
    if (refills >= economyPolicy.maxPaidFreezeRefillsPerWeek) {
      throw StateError('weekly streak freeze refill limit reached');
    }
    final used = _learningFreezes.values
        .where((item) => item.weekKey == weekKey)
        .length;
    if (1 + refills - used > 0) {
      throw StateError('streak freeze is not empty');
    }
    final cost = economyPolicy.streakFreezeRefillGemCost;
    if (_learningGemBalance(
          rewards: _learningRewards.values,
          spends: _learningGemSpends.values,
        ) <
        cost) {
      throw StateError('not enough gems');
    }
    final spend = LearningGemSpend(
      spendId: spendId,
      scope: LearningScope.personal,
      kind: LearningGemSpendKind.streakFreezeRefill,
      amount: cost,
      learningDay: learningDay,
      weekKey: weekKey,
      occurredAt: occurredAt,
    );
    _learningGemSpends[spendId] = spend;
    return _memoryLearningGemSpendResult(applied: true, spend: spend);
  }

  @override
  Future<LearningGemSpendResult> recoverLearningChallengeHeartsWithGems({
    required String spendId,
    required String learningDay,
    required DateTime occurredAt,
    SafeLearningEconomyPolicyV1 economyPolicy =
        const SafeLearningEconomyPolicyV1(),
  }) async {
    economyPolicy.validate();
    _validateLearningGemSpend(
      spendId: spendId,
      learningDay: learningDay,
      occurredAt: occurredAt,
    );
    final old = _learningGemSpends[spendId];
    if (old != null) {
      if (old.kind != LearningGemSpendKind.challengeHeartRecovery ||
          old.learningDay != learningDay ||
          old.occurredAt.millisecondsSinceEpoch !=
              occurredAt.millisecondsSinceEpoch) {
        throw StateError('gem spend ID was reused with different data');
      }
      return _memoryLearningGemSpendResult(applied: false, spend: old);
    }
    final state =
        _learningHeartStates[LearningScope.personal.wire] ??
        const LearningChallengeHeartState.initial();
    if (state.current >= state.maximum) {
      throw StateError('challenge hearts are already full');
    }
    final cost = economyPolicy.challengeHeartRecoveryGemCost;
    if (_learningGemBalance(
          rewards: _learningRewards.values,
          spends: _learningGemSpends.values,
        ) <
        cost) {
      throw StateError('not enough gems');
    }
    final spend = LearningGemSpend(
      spendId: spendId,
      scope: LearningScope.personal,
      kind: LearningGemSpendKind.challengeHeartRecovery,
      amount: cost,
      learningDay: learningDay,
      weekKey: null,
      occurredAt: occurredAt,
    );
    final recovered = LearningChallengeHeartState(
      scope: LearningScope.personal,
      current: state.maximum,
      maximum: state.maximum,
      lastLossDay: null,
      lastRecoveryDay: learningDay,
      updatedAt: occurredAt,
    );
    _learningGemSpends[spendId] = spend;
    _learningHeartStates[LearningScope.personal.wire] = recovered;
    for (final entry in _learningRuns.entries.toList()) {
      if (entry.value.scope == LearningScope.personal &&
          entry.value.challengeHearts != null) {
        _learningRuns[entry.key] = _copyLearningRun(
          entry.value,
          challengeHearts: recovered.current,
        );
      }
    }
    return _memoryLearningGemSpendResult(applied: true, spend: spend);
  }

  @override
  Future<LearningCosmeticPurchaseResult> purchaseLearningCosmeticWithGems({
    required LearningScope scope,
    required String spendId,
    required String productId,
    required String learningDay,
    required DateTime occurredAt,
    SafeLearningEconomyCatalogV1 catalog = const SafeLearningEconomyCatalogV1(),
  }) async {
    _requirePersonalLearningEconomy(scope);
    catalog.validate();
    final product = catalog.cosmetic(productId);
    if (product.isDefault) {
      throw StateError('the default cosmetic is already owned');
    }
    if (product.requiresPlusAccess) {
      throw StateError('plus-exclusive cosmetic is not sold for gems');
    }
    _validateLearningGemSpend(
      spendId: spendId,
      learningDay: learningDay,
      occurredAt: occurredAt,
    );
    final old = _learningGemSpends[spendId];
    if (old != null) {
      if (!_sameLearningCatalogSpend(
        old,
        kind: LearningGemSpendKind.cosmeticPurchase,
        productId: productId,
        learningDay: learningDay,
        occurredAt: occurredAt,
        amount: product.gemCost,
      )) {
        throw StateError('gem spend ID was reused with different data');
      }
      return LearningCosmeticPurchaseResult(
        applied: false,
        productId: productId,
        remainingGems: _learningGemBalance(
          rewards: _learningRewards.values,
          spends: _learningGemSpends.values,
        ),
        cosmetics: _memoryLearningCosmeticState(),
      );
    }
    if (_learningGemSpends.values.any(
      (item) =>
          item.kind == LearningGemSpendKind.cosmeticPurchase &&
          item.referenceId == productId,
    )) {
      throw StateError('cosmetic is already owned');
    }
    final balance = _learningGemBalance(
      rewards: _learningRewards.values,
      spends: _learningGemSpends.values,
    );
    if (balance < product.gemCost) throw StateError('not enough gems');
    final spend = LearningGemSpend(
      spendId: spendId,
      scope: LearningScope.personal,
      kind: LearningGemSpendKind.cosmeticPurchase,
      amount: product.gemCost,
      learningDay: learningDay,
      weekKey: null,
      occurredAt: occurredAt,
      referenceId: productId,
    );
    _learningGemSpends[spendId] = spend;
    _learningCosmeticLoadout[product.slot.wire] = (
      productId: productId,
      updatedAt: occurredAt,
    );
    return LearningCosmeticPurchaseResult(
      applied: true,
      productId: productId,
      remainingGems: balance - product.gemCost,
      cosmetics: _memoryLearningCosmeticState(),
    );
  }

  @override
  Future<LearningCosmeticEquipResult> equipLearningCosmetic({
    required LearningScope scope,
    required String productId,
    required DateTime occurredAt,
    SafeLearningEconomyCatalogV1 catalog = const SafeLearningEconomyCatalogV1(),
  }) async {
    _requirePersonalLearningEconomy(scope);
    catalog.validate();
    final product = catalog.cosmetic(productId);
    if (occurredAt.millisecondsSinceEpoch < 0) {
      throw ArgumentError.value(occurredAt, 'occurredAt');
    }
    final state = _memoryLearningCosmeticState();
    if (!state.owns(productId)) throw StateError('cosmetic is not owned');
    if (state.equippedPathMascotId == productId) {
      return LearningCosmeticEquipResult(changed: false, cosmetics: state);
    }
    final old = _learningCosmeticLoadout[product.slot.wire];
    if (old != null && occurredAt.isBefore(old.updatedAt)) {
      throw StateError('cosmetic loadout timestamp cannot move backwards');
    }
    _learningCosmeticLoadout[product.slot.wire] = (
      productId: productId,
      updatedAt: occurredAt,
    );
    return LearningCosmeticEquipResult(
      changed: true,
      cosmetics: _memoryLearningCosmeticState(),
    );
  }

  @override
  Future<LearningCosmeticState> grantLearningPlusCosmetics({
    required LearningScope scope,
    required DateTime occurredAt,
    SafeLearningEconomyCatalogV1 catalog = const SafeLearningEconomyCatalogV1(),
  }) async {
    _requirePersonalLearningEconomy(scope);
    catalog.validate();
    if (occurredAt.millisecondsSinceEpoch < 0) {
      throw ArgumentError.value(occurredAt, 'occurredAt');
    }
    for (final product in SafeLearningEconomyCatalogV1.plusCosmetics) {
      _learningCosmeticGrants.add(product.productId);
    }
    return _memoryLearningCosmeticState();
  }

  @override
  Future<LearningChallengePassPurchaseResult>
  purchaseLearningChallengePassWithGems({
    required LearningScope scope,
    required String spendId,
    required String productId,
    required String learningDay,
    required DateTime occurredAt,
    SafeLearningEconomyCatalogV1 catalog = const SafeLearningEconomyCatalogV1(),
  }) async {
    _requirePersonalLearningEconomy(scope);
    catalog.validate();
    final product = catalog.challengePass(productId);
    _validateLearningGemSpend(
      spendId: spendId,
      learningDay: learningDay,
      occurredAt: occurredAt,
    );
    final old = _learningGemSpends[spendId];
    if (old != null) {
      if (!_sameLearningCatalogSpend(
        old,
        kind: LearningGemSpendKind.challengeEntry,
        productId: productId,
        learningDay: learningDay,
        occurredAt: occurredAt,
        amount: product.gemCost,
      )) {
        throw StateError('gem spend ID was reused with different data');
      }
      return LearningChallengePassPurchaseResult(
        applied: false,
        productId: productId,
        learningDay: learningDay,
        remainingGems: _learningGemBalance(
          rewards: _learningRewards.values,
          spends: _learningGemSpends.values,
        ),
      );
    }
    if (_learningGemSpends.values.any(
      (item) =>
          item.kind == LearningGemSpendKind.challengeEntry &&
          item.referenceId == productId &&
          item.learningDay == learningDay,
    )) {
      return LearningChallengePassPurchaseResult(
        applied: false,
        productId: productId,
        learningDay: learningDay,
        remainingGems: _learningGemBalance(
          rewards: _learningRewards.values,
          spends: _learningGemSpends.values,
        ),
      );
    }
    final balance = _learningGemBalance(
      rewards: _learningRewards.values,
      spends: _learningGemSpends.values,
    );
    if (balance < product.gemCost) throw StateError('not enough gems');
    final spend = LearningGemSpend(
      spendId: spendId,
      scope: LearningScope.personal,
      kind: LearningGemSpendKind.challengeEntry,
      amount: product.gemCost,
      learningDay: learningDay,
      weekKey: null,
      occurredAt: occurredAt,
      referenceId: productId,
    );
    _learningGemSpends[spendId] = spend;
    return LearningChallengePassPurchaseResult(
      applied: true,
      productId: productId,
      learningDay: learningDay,
      remainingGems: balance - product.gemCost,
    );
  }

  LearningCosmeticState _memoryLearningCosmeticState() {
    final equipped =
        _learningCosmeticLoadout[LearningCosmeticSlot.pathMascot.wire]
            ?.productId;
    return _learningCosmeticStateFromLedger(
      _learningGemSpends.values,
      equippedProductId: equipped,
      grantedProductIds: _learningCosmeticGrants,
    );
  }

  LearningGemSpendResult _memoryLearningGemSpendResult({
    required bool applied,
    required LearningGemSpend spend,
  }) {
    final weekKey = learningWeekKey(spend.learningDay);
    final used = _learningFreezes.values
        .where((item) => item.weekKey == weekKey)
        .length;
    final refills = _learningGemSpends.values
        .where(
          (item) =>
              item.kind == LearningGemSpendKind.streakFreezeRefill &&
              item.weekKey == weekKey,
        )
        .length;
    return LearningGemSpendResult(
      applied: applied,
      spend: spend,
      remainingGems: _learningGemBalance(
        rewards: _learningRewards.values,
        spends: _learningGemSpends.values,
      ),
      streakFreezeRemaining: (1 + refills - used).clamp(0, 1 + refills),
      challengeHearts:
          _learningHeartStates[LearningScope.personal.wire] ??
          const LearningChallengeHeartState.initial(),
    );
  }

  @override
  Future<LearningRun?> activeLearningRun({
    required LearningScope scope,
    String? nodeId,
  }) async {
    final candidates =
        _learningRuns.values
            .where(
              (run) =>
                  run.scope == scope &&
                  (nodeId == null || run.nodeId == nodeId),
            )
            .toList()
          ..sort((a, b) {
            final byTime = b.updatedAt.compareTo(a.updatedAt);
            return byTime != 0 ? byTime : b.runId.compareTo(a.runId);
          });
    return candidates.isEmpty ? null : candidates.first;
  }

  @override
  Future<void> clearLearningScope(LearningScope scope) async {
    final eventIds = _learningEvents.values
        .where((event) => event.scope == scope)
        .map((event) => event.eventId)
        .toSet();
    _learningEvents.removeWhere((_, event) => event.scope == scope);
    _learningEventSkills.removeWhere(
      (eventId, _) => eventIds.contains(eventId),
    );
    _learningPracticeNeeds.removeWhere(
      (eventId, _) => eventIds.contains(eventId),
    );
    _learningResolvedPracticeNeeds.removeWhere(
      (eventId, _) => eventIds.contains(eventId),
    );
    _learningNeedStates.removeWhere((_, item) => item.scope == scope);
    _learningNodes.removeWhere((_, item) => item.scope == scope);
    _learningSkills.removeWhere((_, item) => item.scope == scope);
    _learningDays.removeWhere((_, item) => item.scope == scope);
    _learningFreezes.removeWhere((_, item) => item.scope == scope);
    _learningHeartStates.removeWhere((_, item) => item.scope == scope);
    _learningHeartLosses.removeWhere(
      (_, item) => scope == LearningScope.personal,
    );
    if (scope == LearningScope.personal) {
      _learningHeartPracticeRecoveries.clear();
    }
    _learningRewards.removeWhere((_, item) => item.scope == scope);
    final questIds = _learningQuests.values
        .where((item) => item.scope == scope)
        .map((item) => item.questInstanceId)
        .toSet();
    _learningQuests.removeWhere((_, item) => item.scope == scope);
    _learningQuestEvents.removeWhere((id, _) => questIds.contains(id));
    for (final events in _learningQuestEvents.values) {
      events.removeAll(eventIds);
    }
    _learningRuns.removeWhere((_, item) => item.scope == scope);
    _learningGemSpends.removeWhere((_, item) => item.scope == scope);
    if (scope == LearningScope.personal) {
      _learningCosmeticLoadout.clear();
      _learningCosmeticGrants.clear();
    }
    final coopRunIds = _learningLocalCoopRuns.values
        .where((item) => item.scope == scope)
        .map((item) => item.runId)
        .toSet();
    _learningLocalCoopRuns.removeWhere((_, item) => item.scope == scope);
    _learningLocalCoopContributions.removeWhere(
      (_, item) => coopRunIds.contains(item.runId),
    );
    _learningLeagueHistory.removeWhere((_, item) => item.scope == scope);
    _learningLocalLeagueHistory.removeWhere((_, item) => item.scope == scope);
  }

  @override
  Future<void> close() async {}
}

/// 本番端末では永続DBだけを開く。
///
/// sqflite非対応のweb / Windows / Linuxは開発プレビューとしてMemoryを使う。
/// Android / iOS / macOSでopenやmigrationに失敗した場合は例外を呼び出し元へ
/// 返し、保存できたように見える一時セッションへ黙って切り替えない。
Future<SessionStore> openSessionStore({
  Future<SessionStore> Function()? openPersistentStore,
}) async {
  if (kIsWeb ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux) {
    return MemorySessionStore();
  }
  final openPersistent =
      openPersistentStore ?? () async => SqfliteSessionStore.open();
  return openPersistent();
}
