import { emptyDossier } from '../lib/dossier.ts'
import { UNITS, unitById } from '../lib/units.ts'

/**
 * 単元の一覧と、空の理解カルテ。
 *
 * 端末に単元カタログを焼き込むと、教材を足すたびにアプリの更新が要る。
 * カタログはサーバに置いて、端末は取りに来るだけにする。
 *
 * 誤概念の文言は**返さない**。生徒の端末に「AI がこれから言う嘘」が
 * 入っていると、覗けば誘発が成立しなくなる。
 */

type Req = { method?: string; query?: Record<string, string | string[] | undefined>; url?: string }
type Res = {
  status: (code: number) => Res
  json: (body: unknown) => void
  setHeader: (name: string, value: string) => void
}

export default function handler(req: Req, res: Res) {
  if (req.method !== 'GET') {
    res.setHeader('Allow', 'GET')
    res.status(405).json({ error: 'method_not_allowed' })
    return
  }

  const raw = req.query?.id
  const id = Array.isArray(raw) ? raw[0] : raw

  if (id) {
    const unit = unitById(id)
    if (!unit) {
      res.status(404).json({ error: 'unknown_unit' })
      return
    }
    // カタログは滅多に変わらない。端末と CDN に持たせる
    res.setHeader('Cache-Control', 'public, max-age=300, s-maxage=3600')
    res.status(200).json({ unit: publicUnit(unit), dossier: emptyDossier(unit.id) })
    return
  }

  res.setHeader('Cache-Control', 'public, max-age=300, s-maxage=3600')
  res.status(200).json({ units: UNITS.map(publicUnit) })
}

/** 端末に出してよい形。intent（判定基準）も出さない */
function publicUnit(u: (typeof UNITS)[number]) {
  return {
    id: u.id,
    title: u.title,
    brief: u.brief,
    concepts: u.concepts.map((c) => ({ key: c.key, label: c.label })),
  }
}
