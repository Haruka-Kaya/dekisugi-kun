import { readFile, mkdir, writeFile } from 'node:fs/promises'
import { dirname, relative, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

import { EN_CONTENT } from '../lib/en/index.js'
import { missingContentTranslations } from '../lib/i18n-content.js'
import { buildBundledUnitCatalog } from '../lib/public-unit-catalog.js'
import { UNITS, validateCatalog } from '../lib/units.js'

const here = dirname(fileURLToPath(import.meta.url))
const checkOnly = process.argv.includes('--check')

const problems = validateCatalog()
if (problems.length > 0) {
  throw new Error(`壊れた教材カタログは生成できません:\n${problems.join('\n')}`)
}

// 英語カタログは差し替え表が揃っている時だけ生成できる。
// 穴があると英語の途中に日本語が混ざるので、中途半端なJSONは絶対に出さない。
const enProblems = missingContentTranslations(UNITS, EN_CONTENT)
const enReady = enProblems.length === 0

const outputs: { path: string; expected: string }[] = [
  {
    path: resolve(here, '../../app/assets/catalog/units.ja.json'),
    expected: `${JSON.stringify(buildBundledUnitCatalog(UNITS), null, 2)}\n`,
  },
]
if (checkOnly || enReady) {
  if (!enReady) {
    throw new Error(
      `英語コンテンツの差し替え表が揃っていません:\n${enProblems.join('\n')}`,
    )
  }
  outputs.push({
    path: resolve(here, '../../app/assets/catalog/units.en.json'),
    expected: `${JSON.stringify(buildBundledUnitCatalog(UNITS, 'en', EN_CONTENT), null, 2)}\n`,
  })
}

for (const output of outputs) {
  if (checkOnly) {
    let actual: string
    try {
      actual = await readFile(output.path, 'utf8')
    } catch {
      throw new Error(`同梱カタログがありません: ${output.path}`)
    }
    if (actual !== output.expected) {
      throw new Error(
        '同梱カタログが server/lib/units.ts と一致しません。'
        + ' `npm run catalog:generate` で再生成してください。',
      )
    }
    console.log(`同梱カタログ同期済み: ${relative(process.cwd(), output.path)}`)
  } else {
    await mkdir(dirname(output.path), { recursive: true })
    await writeFile(output.path, output.expected, 'utf8')
    console.log(`同梱カタログを生成: ${relative(process.cwd(), output.path)}`)
  }
}
