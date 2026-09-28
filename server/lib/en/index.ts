import type { UnitContentText } from '../i18n-content.js'

import { chemicalChangeContent } from './chemical-change.js'
import { chemicalChangeIonsContent } from './chemical-change-ions.js'
import { currentMagnetismContent } from './current-magnetism.js'
import { earthHistoryContent } from './earth-history.js'
import { forceBalanceContent } from './force-balance.js'
import { lifeContinuityContent } from './life-continuity.js'
import { livingBodyContent } from './living-body.js'
import { matterPropertiesContent } from './matter-properties.js'
import { pressureBuoyancyContent } from './pressure-buoyancy.js'
import { weatherChangeContent } from './weather-change.js'

/**
 * 英語コンテンツ差し替え表の登録簿。
 *
 * `server/lib/en/<unitId>.ts` が単元ごとの英語文言を供給する。
 * 差し替えが無いキーは日本語がそのまま出る。
 * 穴は `missingContentTranslations` が拾う。
 */
export const EN_CONTENT: Record<string, UnitContentText | undefined> = {
  'chemical-change': chemicalChangeContent,
  'chemical-change-ions': chemicalChangeIonsContent,
  'current-magnetism': currentMagnetismContent,
  'earth-history': earthHistoryContent,
  'force-balance': forceBalanceContent,
  'life-continuity': lifeContinuityContent,
  'living-body': livingBodyContent,
  'matter-properties': matterPropertiesContent,
  'pressure-buoyancy': pressureBuoyancyContent,
  'weather-change': weatherChangeContent,
}
