import { readFile, mkdir, writeFile } from 'node:fs/promises'
import { dirname, relative, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

import { buildBundledUnitCatalog } from '../lib/public-unit-catalog.js'
import { UNITS, validateCatalog } from '../lib/units.js'

const here = dirname(fileURLToPath(import.meta.url))
const outputPath = resolve(here, '../../app/assets/catalog/units.ja.json')
const expected = `${JSON.stringify(buildBundledUnitCatalog(UNITS), null, 2)}\n`

const problems = validateCatalog()
if (problems.length > 0) {
  throw new Error(`壊れた教材カタログは生成できません:\n${problems.join('\n')}`)
}

if (process.argv.includes('--check')) {
  let actual: string
  try {
    actual = await readFile(outputPath, 'utf8')
  } catch {
    throw new Error(`同梱カタログがありません: ${outputPath}`)
  }
  if (actual !== expected) {
    throw new Error(
      '同梱カタログが server/lib/units.ts と一致しません。'
      + ' `npm run catalog:generate` で再生成してください。',
    )
  }
  console.log(`同梱カタログ同期済み: ${relative(process.cwd(), outputPath)}`)
} else {
  await mkdir(dirname(outputPath), { recursive: true })
  await writeFile(outputPath, expected, 'utf8')
  console.log(`同梱カタログを生成: ${relative(process.cwd(), outputPath)}`)
}
