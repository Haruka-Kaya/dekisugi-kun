import type { UnitContentText } from '../i18n-content.js'

/**
 * 英語コンテンツ差し替え表の登録簿。
 *
 * `server/lib/en/<unitId>.ts` が単元ごとの英語文言を供給する。
 * 差し替えが無いキーは日本語がそのまま出る。
 * 穴は `missingContentTranslations` が拾う。
 */
export const EN_CONTENT: Record<string, UnitContentText | undefined> = {}
