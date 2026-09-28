import {
  localizeMisconception,
  localizeUnit,
  type Lang,
} from './i18n.js'
import {
  localizeNotationTask,
  localizePracticeVariant,
  localizeStory,
  type UnitContentText,
} from './i18n-content.js'
import type { Unit } from './units.js'
import { curriculumCoverageFor } from './curriculum-coverage.js'
import { localPracticeVariantsFor } from './local-practice-variants.js'
import { MISCONCEPTIONS } from './misconceptions.js'
import { notationLabFor, publicNotationLab } from './notation-labs.js'
import { scienceStoryFor, scienceStoryTitleFor } from './science-stories.js'

/**
 * 生徒の端末へ公開してよい単元情報。
 *
 * 判定基準の `intent` と、AI が口にする逐語の誘発文（lure）は含めない。
 * 誤概念の一般表現と正しい理解は「記録と復習の表示に使う」情報なので、
 * 理解カルテが端末内表示できるよう concept ごとに同梱する。
 * `localCheckpoint` は旧クライアント用の1周目。新クライアントは
 * `localPracticeVariants` の3周を使う。どちらもAIとは別文で、詳細だけに含める。
 * API とアプリ同梱カタログが同じ変換を通ることで、公開形の二重管理を防ぐ。
 */
export function publicUnitSummary(unit: Unit, lang: Lang = 'ja') {
  const localized = lang === 'en' ? localizeUnit(unit, lang) : unit
  return {
    id: localized.id,
    title: localized.title,
    brief: localized.brief,
    concepts: localized.concepts.map((concept) => {
      const storyTitle = scienceStoryTitleFor(concept.key)
      const coverage = curriculumCoverageFor(concept.key)
      if (storyTitle == null) {
        throw new Error(`Science Storyが無いconcept: ${concept.key}`)
      }
      if (coverage == null || coverage.unitId !== unit.id) {
        throw new Error(`curriculum coverageが無いconcept: ${concept.key}`)
      }
      const found = MISCONCEPTIONS.find((m) => m.conceptKey === concept.key)
      if (found == null) {
        throw new Error(`誤概念が無いconcept: ${concept.key}`)
      }
      const misconception =
        lang === 'en' ? localizeMisconception(found, lang) : found
      return {
        key: concept.key,
        label: concept.label,
        storyTitle,
        misconception: {
          id: misconception.id,
          statement: misconception.misconception,
          correct: misconception.correct,
        },
        field: coverage.field,
        grade: coverage.grade,
        curriculumRefs: coverage.curriculumRefs.map((entry) => ({
          ...entry,
          pages: [...entry.pages],
        })),
        prerequisites: [...coverage.prerequisites],
        difficulty: coverage.difficulty,
        safety: { ...coverage.safety },
      }
    }),
    sectionCount: unit.sections.length,
  }
}

/** 教材本文を含む公開形。配列もコピーし、正カタログを変更できないようにする。 */
export function publicUnitDetail(
  unit: Unit,
  lang: Lang = 'ja',
  content?: UnitContentText,
) {
  const localized = lang === 'en' ? localizeUnit(unit, lang) : unit
  return {
    ...publicUnitSummary(unit, lang),
    sections: localized.sections.map((section) => {
      const conceptText = content?.concepts[section.conceptKey]
      const localPracticeVariants = localPracticeVariantsFor(section).map(
        (variant) =>
          localizePracticeVariant(
            variant,
            lang === 'en' ? conceptText?.practice[variant.stage] : undefined,
          ),
      )
      const notationLab = notationLabFor(section.conceptKey)
      if (notationLab == null) {
        throw new Error(`Notation Labが無いconcept: ${section.conceptKey}`)
      }
      const foundation = localPracticeVariants[0]
      const rawStory = foundation == null
        ? undefined
        : scienceStoryFor(section.conceptKey, foundation)
      const scienceStory = rawStory == null
        ? undefined
        : localizeStory(
            rawStory,
            lang === 'en' ? conceptText?.story : undefined,
          )
      if (scienceStory == null) {
        throw new Error(`Science Storyが無いconcept: ${section.conceptKey}`)
      }
      const notationTasks = publicNotationLab(notationLab).tasks.map((task) =>
        localizeNotationTask(
          task,
          lang === 'en' ? conceptText?.notation.tasks[task.id] : undefined,
        ),
      )
      return {
        conceptKey: section.conceptKey,
        title: section.title,
        body: [...section.body],
        tryIt: section.tryIt,
        localSpeakingPractice: {
          targetPhrase: section.localSpeakingPractice.targetPhrase,
          acceptedTranscripts: [
            ...section.localSpeakingPractice.acceptedTranscripts,
          ],
        },
        localPracticeVariants,
        notationLab: { tasks: notationTasks },
        scienceStory,
        // 旧クライアントが同じ1周目を続けられるよう公開形だけ残す。
        localCheckpoint: localPracticeVariants[0]?.checkpoint,
      }
    }),
  }
}

// v10: curriculum coverageと、領域固有のNotation tagged unionを正本化。
// v9以前を混ぜると新taskと安全条件を推測することになるため拒否する。
export const BUNDLED_UNIT_CATALOG_SCHEMA_VERSION = 10 as const

/**
 * アプリに同梱する日本語教材カタログを組み立てる。
 * 科学内容の正は `UNITS` と `NOTATION_LABS`。戻り値は機械生成物に過ぎない。
 */
export function buildBundledUnitCatalog(
  units: readonly Unit[],
  lang: Lang = 'ja',
  content: Readonly<Record<string, UnitContentText | undefined>> = {},
) {
  return {
    schemaVersion: BUNDLED_UNIT_CATALOG_SCHEMA_VERSION,
    language: lang,
    units: units.map((unit) => publicUnitDetail(unit, lang, content[unit.id])),
  }
}
