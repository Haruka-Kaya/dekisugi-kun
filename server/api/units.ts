import { emptyDossier } from '../lib/dossier.js'
import { UNITS, unitById, validateCatalog } from '../lib/units.js'

/**
 * 単元の一覧と、教材と、空の理解カルテ。
 *
 * 端末に単元カタログを焼き込むと、教材を足すたびにアプリの更新が要る。
 * カタログはサーバに置いて、端末は取りに来るだけにする。
 *
 * 誤概念の文言（[Misconception.lure]）は**返さない**。
 * 生徒の端末に「AI がこれから言う嘘」がそのまま入っていると、
 * 覗けば誘発が成立しなくなる。判定基準の `intent` も返さない。
 *
 * > [!note] 教材が誤概念に触れることは許す
 * > 各節の終わりは「よくある引っかかり」で、中身は誤概念カタログと重なる。
 * > 隠したいのは**AI が言う具体的なセリフ**であって、誤りの存在ではない。
 * > むしろ教材で扱っていない誤りを誘発すると、
 * > 「教材を理解したか」ではなく「もともと知っていたか」を測ってしまう。
 *
 * 認証は要求しない。中身は誰に対しても同じ教科の読み物で、
 * 個人情報を含まず、CDN に載せたいため。
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

  // **壊れたカタログを配らない。** 教材の無い概念を配ると、
  // 復習が読み直す先を持てないまま画面に出る
  const problems = validateCatalog()
  if (problems.length > 0) {
    console.error('カタログが壊れている', problems)
    res.status(500).json({ error: 'catalog_broken' })
    return
  }

  const raw = req.query?.id
  const fromQuery = Array.isArray(raw) ? raw[0] : raw
  // query を組み立てない実行環境でも読めるようにする
  const id = fromQuery || /[?&]id=([^&]+)/.exec(req.url ?? '')?.[1]

  if (id) {
    const unit = unitById(decodeURIComponent(id))
    if (!unit) {
      res.status(404).json({ error: 'unknown_unit' })
      return
    }
    // カタログは滅多に変わらない。端末と CDN に持たせる
    res.setHeader('Cache-Control', 'public, max-age=300, s-maxage=3600')
    res.status(200).json({
      unit: { ...publicUnit(unit), sections: unit.sections },
      dossier: emptyDossier(unit.id),
    })
    return
  }

  // 一覧に教材の本文は載せない。選ぶのに要らないぶんを運ばない
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
    sectionCount: u.sections.length,
  }
}
