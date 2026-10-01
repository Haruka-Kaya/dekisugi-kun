import {
  localPracticeVariantsFor,
  type CognitiveTask,
  type LocalPracticeVariant,
} from './local-practice-variants.js'
import {
  canonicalNotationTasks,
  isNotationArrangeTask,
  notationLabFor,
  type NotationTask,
} from './notation-labs.js'
import { scienceStoryFor, type ScienceStory } from './science-stories.js'
import type { LocalCheckpoint, Unit } from './units.js'

/**
 * 英語コンテンツの差し替え表（`server/lib/en/<unitId>.ts` が供給する）。
 *
 * `i18n.ts` の EN_UNITS が単元・教材・誤概念を差し替えるのに対し、
 * ここでは練習3周・構造化課題・Science Story・Notation Lab の
 * **見せる文言**だけを差し替える。id・needCode・正答構造は言語を
 * またいで不変なので、差し替え表は「id → 文言」の写像だけを持つ。
 *
 * 差し替えが無いキーは日本語がそのまま出る（落とさない）。
 * 穴は `missingContentTranslations` が拾い、英語カタログ生成を止める。
 */

export type CheckpointText = {
  lure: string
  explanation: string
  /** option.id → 見せる文言 */
  options: Record<string, { text: string; hint?: string }>
}

export type CognitiveText = {
  /** item.id → 見せる文言 */
  items: Record<string, string>
  /** classify のときだけ target.id → 見せる文言 */
  targets?: Record<string, string>
}

export type VariantText = {
  recallPrompt: string
  reasoningPrompt: string
  /** conditions/transfer のみ。foundation の transferPrompt は教材 tryIt から来る。 */
  transferPrompt?: string
  expectedOutcome: string
  expectedReason: string
  /** conditions/transfer のみ。foundation の checkpoint は教材 localCheckpoint から来る。 */
  checkpoint?: CheckpointText
  cognitiveTask: CognitiveText
}

export type StoryText = {
  title: string
  setting: string
  /** character.id → 表示名・役割 */
  characters: Record<string, { name: string; role: string }>
  /** openingLines[].id → セリフ本文 */
  openingLines: Record<string, string>
  /** choiceResponses[].optionId → 選択肢への反応セリフ */
  choiceResponses: Record<string, string>
  /** resolutionLines[].id → セリフ本文 */
  resolutionLines: Record<string, string>
  /** オチの1行 */
  punchline: string
}

export type NotationTaskText = {
  title: string
  prompt: string
  /** arrange系のみ */
  guide?: string
  solutionSummary: string
  /** token.id → ラベル */
  tokens?: Record<string, string>
  /** choice.id → ラベル */
  choices?: Record<string, string>
  /** choice系のみ */
  representation?: string[]
  representationSemanticsLabel?: string
  /** tracePattern があるときだけ */
  tracePattern?: { semanticsLabel: string; strokes: Record<string, string> }
}

export type NotationText = {
  /** task.id → 文言 */
  tasks: Record<string, NotationTaskText>
}

export type ConceptContentText = {
  practice: {
    foundation: VariantText
    conditions: VariantText
    transfer: VariantText
  }
  story: StoryText
  notation: NotationText
}

export type UnitContentText = {
  /** 確認用。原本の unit.id と一致させる */
  unitId: string
  concepts: Record<string, ConceptContentText>
}

// ── 差し替え ────────────────────────────────────────────────

function textOr(map: Record<string, string> | undefined, id: string, fallback: string): string {
  const value = map?.[id]
  return typeof value === 'string' && value.trim() !== '' ? value : fallback
}

export function localizeCognitiveTask(
  task: CognitiveTask,
  text: CognitiveText | undefined,
): CognitiveTask {
  if (!text) return task
  const items = task.items.map((item) => ({
    ...item,
    text: textOr(text.items, item.id, item.text),
  }))
  if (task.kind === 'classify') {
    const targets = task.targets.map((target) => ({
      ...target,
      label: textOr(text.targets, target.id, target.label),
    }))
    return { ...task, items, targets }
  }
  return { ...task, items }
}

export function localizeCheckpoint(
  checkpoint: LocalCheckpoint,
  text: CheckpointText | undefined,
): LocalCheckpoint {
  if (!text) return checkpoint
  return {
    ...checkpoint,
    lure: text.lure.trim() !== '' ? text.lure : checkpoint.lure,
    explanation:
      text.explanation.trim() !== '' ? text.explanation : checkpoint.explanation,
    options: checkpoint.options.map((option) => {
      const replacement = text.options[option.id]
      if (!replacement) return option
      const localized = {
        ...option,
        text: replacement.text.trim() !== '' ? replacement.text : option.text,
        hint:
          replacement.hint != null && replacement.hint.trim() !== ''
            ? replacement.hint
            : option.hint,
      }
      // JSON化で消える undefined のkeyを残すと、同梱カタログとの比較が割れる
      if (localized.hint == null) delete localized.hint
      return localized
    }),
  }
}

export function localizePracticeVariant(
  variant: LocalPracticeVariant,
  text: VariantText | undefined,
): LocalPracticeVariant {
  if (!text) return variant
  return {
    ...variant,
    recallPrompt:
      text.recallPrompt.trim() !== '' ? text.recallPrompt : variant.recallPrompt,
    reasoningPrompt:
      text.reasoningPrompt.trim() !== ''
        ? text.reasoningPrompt
        : variant.reasoningPrompt,
    transferPrompt:
      text.transferPrompt != null && text.transferPrompt.trim() !== ''
        ? text.transferPrompt
        : variant.transferPrompt,
    expectedOutcome:
      text.expectedOutcome.trim() !== ''
        ? text.expectedOutcome
        : variant.expectedOutcome,
    expectedReason:
      text.expectedReason.trim() !== ''
        ? text.expectedReason
        : variant.expectedReason,
    cognitiveTask: localizeCognitiveTask(variant.cognitiveTask, text.cognitiveTask),
    checkpoint:
      variant.stage === 'foundation'
        ? variant.checkpoint
        : localizeCheckpoint(variant.checkpoint, text.checkpoint),
  }
}

export function localizeStory(
  story: ScienceStory,
  text: StoryText | undefined,
): ScienceStory {
  if (!text) return story
  return {
    ...story,
    title: text.title.trim() !== '' ? text.title : story.title,
    setting: text.setting.trim() !== '' ? text.setting : story.setting,
    characters: story.characters.map((character) => {
      const replacement = text.characters[character.id]
      return replacement
        ? {
            ...character,
            name: replacement.name.trim() !== '' ? replacement.name : character.name,
            role: replacement.role.trim() !== '' ? replacement.role : character.role,
          }
        : character
    }),
    openingLines: story.openingLines.map((storyLine) => ({
      ...storyLine,
      text: textOr(text.openingLines, storyLine.id, storyLine.text),
    })),
    choiceResponses: story.choiceResponses.map((entry) => ({
      ...entry,
      line: {
        ...entry.line,
        text: textOr(text.choiceResponses, entry.optionId, entry.line.text),
      },
    })),
    resolutionLines: story.resolutionLines.map((storyLine) => ({
      ...storyLine,
      text: textOr(text.resolutionLines, storyLine.id, storyLine.text),
    })),
    punchline: {
      ...story.punchline,
      text: text.punchline.trim() !== '' ? text.punchline : story.punchline.text,
    },
  }
}

export function localizeNotationTask(
  task: NotationTask,
  text: NotationTaskText | undefined,
): NotationTask {
  if (!text) return task
  const title = text.title.trim() !== '' ? text.title : task.title
  const prompt = text.prompt.trim() !== '' ? text.prompt : task.prompt
  const solutionSummary =
    text.solutionSummary.trim() !== ''
      ? text.solutionSummary
      : task.solutionSummary
  if (isNotationArrangeTask(task)) {
    const tracePattern =
      task.tracePattern != null && text.tracePattern != null
        ? {
            ...task.tracePattern,
            semanticsLabel:
              text.tracePattern.semanticsLabel.trim() !== ''
                ? text.tracePattern.semanticsLabel
                : task.tracePattern.semanticsLabel,
            strokes: task.tracePattern.strokes.map((stroke) => ({
              ...stroke,
              label: textOr(text.tracePattern?.strokes, stroke.id, stroke.label),
            })),
          }
        : task.tracePattern
    return {
      ...task,
      title,
      prompt,
      solutionSummary,
      guide:
        text.guide != null && text.guide.trim() !== '' ? text.guide : task.guide,
      tokens: task.tokens.map((token) => ({
        ...token,
        label: textOr(text.tokens, token.id, token.label),
      })),
      // undefined のkeyを残すと同梱JSONとの比較が割れる
      ...(tracePattern == null ? {} : { tracePattern }),
    }
  }
  const choice = task
  return {
    ...choice,
    title,
    prompt,
    solutionSummary,
    representation:
      text.representation != null && text.representation.length > 0
        ? [...text.representation]
        : [...choice.representation],
    representationSemanticsLabel:
      text.representationSemanticsLabel != null &&
      text.representationSemanticsLabel.trim() !== ''
        ? text.representationSemanticsLabel
        : choice.representationSemanticsLabel,
    choices: choice.choices.map((option) => ({
      ...option,
      label: textOr(text.choices, option.id, option.label),
    })),
  }
}

// ── 穴の検査 ────────────────────────────────────────────────

/**
 * EN コンテンツ差し替え表の穴。**テストと英語カタログ生成で落とす。**
 *
 * 差し替え表のキーは「見せる文言のid」と1:1。漏れると英語の途中に
 * 日本語が1文だけ混ざる。必須の見せる文言:
 * - 3周練習の recall/reasoning/transfer の問い、expected、
 *   conditions/transfer の checkpoint(lure/options/explanation)、
 *   構造化課題の items(+classify の targets)
 * - Story の題名・舞台・登場人物・全セリフ・選択肢反応・オチ
 * - Notation 全 task の題名・問い・案内・トークン/選択肢ラベル・解説
 *   (+tracePattern の semanticsLabel と strokeラベル)
 */
export function missingContentTranslations(
  units: readonly Unit[],
  content: Readonly<Record<string, UnitContentText | undefined>>,
): string[] {
  const problems: string[] = []
  for (const unit of units) {
    const unitText = content[unit.id]
    if (unitText == null) {
      problems.push(`単元の英語コンテンツが無い: ${unit.id}`)
      continue
    }
    if (unitText.unitId !== unit.id) {
      problems.push(`unitId不一致: ${unit.id} → ${unitText.unitId}`)
    }
    for (const section of unit.sections) {
      const key = section.conceptKey
      const prefix = `${unit.id}/${key}`
      const conceptText = unitText.concepts[key]
      if (conceptText == null) {
        problems.push(`概念の英語コンテンツが無い: ${prefix}`)
        continue
      }
      const variants = localPracticeVariantsFor(section)
      for (const variant of variants) {
        const vt = conceptText.practice[variant.stage]
        if (vt == null) {
          problems.push(`練習${variant.stage}の英語が無い: ${prefix}`)
          continue
        }
        for (const [field, value] of [
          ['recallPrompt', vt.recallPrompt],
          ['reasoningPrompt', vt.reasoningPrompt],
          ['expectedOutcome', vt.expectedOutcome],
          ['expectedReason', vt.expectedReason],
        ] as const) {
          if (!value || value.trim() === '') {
            problems.push(`練習${variant.stage}.${field}が空: ${prefix}`)
          }
        }
        if (variant.stage !== 'foundation') {
          if (!vt.transferPrompt || vt.transferPrompt.trim() === '') {
            problems.push(`練習${variant.stage}.transferPromptが空: ${prefix}`)
          }
          const ct = vt.checkpoint
          if (ct == null) {
            problems.push(`練習${variant.stage}.checkpointが無い: ${prefix}`)
          } else {
            if (ct.lure.trim() === '') problems.push(`checkpoint.lureが空: ${prefix}`)
            if (ct.explanation.trim() === '') {
              problems.push(`checkpoint.explanationが空: ${prefix}`)
            }
            for (const option of variant.checkpoint.options) {
              const ot = ct.options[option.id]
              if (ot == null || ot.text.trim() === '') {
                problems.push(`checkpoint option未翻訳: ${prefix} ${variant.stage} ${option.id}`)
              }
            }
          }
        }
        const gt = vt.cognitiveTask
        if (gt == null) {
          problems.push(`構造化課題${variant.stage}の英語が無い: ${prefix}`)
        } else {
          for (const item of variant.cognitiveTask.items) {
            const itemText = gt.items[item.id]
            if (itemText == null || itemText.trim() === '') {
              problems.push(`課題item未翻訳: ${prefix} ${variant.stage} ${item.id}`)
            }
          }
          if (variant.cognitiveTask.kind === 'classify') {
            for (const target of variant.cognitiveTask.targets) {
              const label = gt.targets?.[target.id]
              if (label == null || label.trim() === '') {
                problems.push(`課題target未翻訳: ${prefix} ${variant.stage} ${target.id}`)
              }
            }
          }
        }
      }
      const story = variants[0] == null
        ? undefined
        : scienceStoryFor(key, variants[0])
      if (story != null) {
        const st = conceptText.story
        if (st == null) {
          problems.push(`Storyの英語が無い: ${prefix}`)
        } else {
          if (st.title.trim() === '') problems.push(`Story題名が空: ${prefix}`)
          if (st.setting.trim() === '') problems.push(`Story舞台が空: ${prefix}`)
          for (const character of story.characters) {
            const ct = st.characters[character.id]
            if (ct == null || ct.name.trim() === '' || ct.role.trim() === '') {
              problems.push(`Story登場人物未翻訳: ${prefix} ${character.id}`)
            }
          }
          for (const storyLine of story.openingLines) {
            if (!st.openingLines[storyLine.id]?.trim()) {
              problems.push(`Story冒頭未翻訳: ${prefix} ${storyLine.id}`)
            }
          }
          for (const entry of story.choiceResponses) {
            if (!st.choiceResponses[entry.optionId]?.trim()) {
              problems.push(`Story選択肢反応未翻訳: ${prefix} ${entry.optionId}`)
            }
          }
          for (const storyLine of story.resolutionLines) {
            if (!st.resolutionLines[storyLine.id]?.trim()) {
              problems.push(`Story解決未翻訳: ${prefix} ${storyLine.id}`)
            }
          }
          if (st.punchline.trim() === '') problems.push(`Storyオチが空: ${prefix}`)
        }
      }
      const lab = notationLabFor(key)
      if (lab != null) {
        const nt = conceptText.notation
        if (nt == null) {
          problems.push(`Notationの英語が無い: ${prefix}`)
        } else {
          for (const task of canonicalNotationTasks(lab)) {
            const tt = nt.tasks[task.id]
            if (tt == null) {
              problems.push(`Notation task未翻訳: ${prefix} ${task.id}`)
              continue
            }
            if (tt.title.trim() === '') problems.push(`task.titleが空: ${prefix} ${task.id}`)
            if (tt.prompt.trim() === '') problems.push(`task.promptが空: ${prefix} ${task.id}`)
            if (tt.solutionSummary.trim() === '') {
              problems.push(`task.solutionSummaryが空: ${prefix} ${task.id}`)
            }
            if (isNotationArrangeTask(task)) {
              if (!tt.guide || tt.guide.trim() === '') {
                problems.push(`task.guideが空: ${prefix} ${task.id}`)
              }
              for (const token of task.tokens) {
                if (!tt.tokens?.[token.id]?.trim()) {
                  problems.push(`token未翻訳: ${prefix} ${task.id} ${token.id}`)
                }
              }
              if (task.tracePattern != null) {
                const tp = tt.tracePattern
                if (tp == null || tp.semanticsLabel.trim() === '') {
                  problems.push(`tracePattern未翻訳: ${prefix} ${task.id}`)
                } else {
                  for (const stroke of task.tracePattern.strokes) {
                    if (!tp.strokes[stroke.id]?.trim()) {
                      problems.push(`stroke未翻訳: ${prefix} ${task.id} ${stroke.id}`)
                    }
                  }
                }
              }
            } else {
              for (const option of task.choices) {
                if (!tt.choices?.[option.id]?.trim()) {
                  problems.push(`choice未翻訳: ${prefix} ${task.id} ${option.id}`)
                }
              }
              if (!tt.representationSemanticsLabel?.trim()) {
                problems.push(`representationSemanticsLabelが空: ${prefix} ${task.id}`)
              }
            }
          }
        }
      }
    }
  }
  for (const [unitId, unitText] of Object.entries(content)) {
    if (unitText == null) continue
    if (!units.some((u) => u.id === unitId)) {
      problems.push(`原本に無い単元の英語コンテンツがある: ${unitId}`)
      continue
    }
    const source = units.find((u) => u.id === unitId)
    const sourceKeys = new Set(source?.sections.map((s) => s.conceptKey) ?? [])
    for (const conceptKey of Object.keys(unitText.concepts)) {
      if (!sourceKeys.has(conceptKey)) {
        problems.push(`原本に無い概念の英語コンテンツがある: ${unitId}/${conceptKey}`)
      }
    }
  }
  return problems
}
