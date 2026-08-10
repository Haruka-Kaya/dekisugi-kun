import 'package:dekisugi/services/director_client.dart';
import 'package:dekisugi/models/mission.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/stub_dio.dart';

void main() {
  test('1概念ミッションをDirectorへ失わず送る', () async {
    Object? sent;
    final client = DirectorClient(
      baseUrl: 'https://example.test',
      dio: fakeDio({
        'POST https://example.test/api/director': () => json200('''
{"corrections":[],"dossier":{"unitId":"force-motion","slots":[],"coverage":0},
"nextInstruction":"","lureId":null,"shouldEnd":false,"endReason":""}
'''),
      }, onRequest: (options) => sent = options.data),
    );

    await client.run(
      unitId: 'force-motion',
      focusConceptKey: 'fall',
      tactic: TeachingTactic.experiment,
      utterances: const [],
      secondsLeft: 300,
      turnCount: 0,
    );

    final body = (sent as Map).cast<String, dynamic>();
    expect(body['unitId'], 'force-motion');
    expect(body['focusConceptKey'], 'fall');
    expect(body['teachingTactic'], 'experiment');
    expect(body['missionKind'], 'teach');
  });

  test('未指定の作戦はreasonとして送る', () async {
    Object? sent;
    final client = DirectorClient(
      baseUrl: 'https://example.test',
      dio: fakeDio({
        'POST https://example.test/api/director': () => json200('''
{"corrections":[],"dossier":{"unitId":"force-motion","slots":[],"coverage":0},
"nextInstruction":"","lureId":null,"shouldEnd":false,"endReason":""}
'''),
      }, onRequest: (options) => sent = options.data),
    );

    await client.run(
      unitId: 'force-motion',
      utterances: const [],
      secondsLeft: 300,
      turnCount: 0,
    );

    expect((sent as Map)['teachingTactic'], 'reason');
  });
}
