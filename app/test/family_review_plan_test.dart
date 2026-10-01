import 'package:dekisugi/config/app_language.dart' as lang;
import 'package:dekisugi/learning/services/family_review_plan.dart';
import 'package:dekisugi/learning/services/learning_karte_projection.dart';
import 'package:dekisugi/models/unit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => lang.appLanguage = lang.AppLanguage.ja);
  test(
    'active observation comes before practiced topic; no learner diagnosis',
    () {
      lang.appLanguage = lang.AppLanguage.en;
      final view = LearningKarteView(
        concepts: [
          const LearningKarteConcept(
            unitId: 'u',
            unitTitle: 'Motion',
            conceptKey: 'a',
            label: 'Inertia',
            grade: 7,
            field: UnitCurriculumField.energy,
            misconception: null,
            activeNeeds: [],
            resolvedNeeds: [],
            taught: true,
          ),
          const LearningKarteConcept(
            unitId: 'u',
            unitTitle: 'Motion',
            conceptKey: 'b',
            label: 'Falling',
            grade: 7,
            field: UnitCurriculumField.energy,
            misconception: null,
            activeNeeds: ['conditions'],
            resolvedNeeds: [],
            taught: true,
          ),
        ],
        summary: const LearningKarteSummary(
          conceptCount: 2,
          taughtCount: 2,
          activeNeedCount: 1,
          resolvedNeedCount: 0,
        ),
      );
      final report = familyReviewPlan(view);
      expect(report, contains('Next topic: Falling (Motion)'));
      expect(report, contains('Which conditions matter?'));
      expect(
        report,
        contains(
          'Independent understanding, transfer and retention must be checked separately',
        ),
      );
      expect(report, isNot(contains('weakness')));
      expect(report, isNot(matches(RegExp(r'[\u3040-\u30ff\u4e00-\u9fff]'))));
    },
  );
  test('empty record does not invent observations', () {
    lang.appLanguage = lang.AppLanguage.en;
    expect(
      familyReviewPlan(
        const LearningKarteView(
          concepts: [],
          summary: LearningKarteSummary(
            conceptCount: 0,
            taughtCount: 0,
            activeNeedCount: 0,
            resolvedNeedCount: 0,
          ),
        ),
      ),
      contains('teach once'),
    );
  });
}
