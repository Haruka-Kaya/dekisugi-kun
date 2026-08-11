import type { Unit } from './units.js'
import { curriculumCoverageFor } from './curriculum-coverage.js'
import { localPracticeVariantsFor } from './local-practice-variants.js'
import { notationLabFor, publicNotationLab } from './notation-labs.js'
import { scienceStoryFor, scienceStoryTitleFor } from './science-stories.js'

/**
 * 生徒の端末へ公開してよい単元情報。
 *
 * 判定基準の `intent` と、AI が口にする逐語の誤概念文は含めない。
 * `localCheckpoint` は旧クライアント用の1周目。新クライアントは
 * `localPracticeVariants` の3周を使う。どちらもAIとは別文で、詳細だけに含める。
 * API とアプリ同梱カタログが同じ変換を通ることで、公開形の二重管理を防ぐ。
 */
export function publicUnitSummary(unit: Unit) {
  return {
    id: unit.id,
    title: unit.title,
    brief: unit.brief,
    concepts: unit.concepts.map((concept) => {
      const storyTitle = scienceStoryTitleFor(concept.key)
      const coverage = curriculumCoverageFor(concept.key)
      if (storyTitle == null) {
        throw new Error(`Science Storyが無いconcept: ${concept.key}`)
      }
      if (coverage == null || coverage.unitId !== unit.id) {
        throw new Error(`curriculum coverageが無いconcept: ${concept.key}`)
      }
      return {
        key: concept.key,
        label: concept.label,
        storyTitle,
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
export function publicUnitDetail(unit: Unit) {
  return {
    ...publicUnitSummary(unit),
    sections: unit.sections.map((section) => {
      const localPracticeVariants = localPracticeVariantsFor(section)
      const notationLab = notationLabFor(section.conceptKey)
      if (notationLab == null) {
        throw new Error(`Notation Labが無いconcept: ${section.conceptKey}`)
      }
      const foundation = localPracticeVariants[0]
      const scienceStory = foundation == null
        ? undefined
        : scienceStoryFor(section.conceptKey, foundation)
      if (scienceStory == null) {
        throw new Error(`Science Storyが無いconcept: ${section.conceptKey}`)
      }
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
        notationLab: publicNotationLab(notationLab),
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
export function buildBundledUnitCatalog(units: readonly Unit[]) {
  return {
    schemaVersion: BUNDLED_UNIT_CATALOG_SCHEMA_VERSION,
    language: 'ja' as const,
    units: units.map(publicUnitDetail),
  }
}
