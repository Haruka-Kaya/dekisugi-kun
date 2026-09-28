import { type Req, type Res } from '../lib/http.js'
import { emptyDossier } from '../lib/dossier.js'
import { envLang, localizeUnit, parseLang } from '../lib/i18n.js'
import {
  BUNDLED_UNIT_CATALOG_SCHEMA_VERSION,
  publicUnitDetail,
  publicUnitSummary,
} from '../lib/public-unit-catalog.js'
import { UNITS, unitById, validateCatalog } from '../lib/units.js'

/**
 * 単元の一覧と、教材と、空の理解カルテ。
 *
 * カタログの正はサーバに置き、端末は通常ここから更新する。
 * アプリには初回オフライン用の機械生成スナップショットも同梱するが、
 * `server/lib/units.ts` から生成して一致テストを通し、手編集はしない。
 *
 * オンライン誘発の文言（[Misconception.lure]）は**返さない**。
 * 生徒の端末に「AI がこれから言う嘘」がそのまま入っていると、
 * 覗けば誘発が成立しなくなる。判定基準の `intent` も返さない。
 * 詳細に含む `localPracticeVariants[].checkpoint.lure` と、旧クライアント用の
 * `localCheckpoint.lure` は端末内練習専用の別文で、Directorが逐語で話す文とは
 * 不変条件テストで分離する。
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

  // 明示があればそれが勝つ。無ければ環境変数の既定
  const rawLang = req.query?.lang
  const langParam =
    (Array.isArray(rawLang) ? rawLang[0] : rawLang) ??
    /[?&]lang=([^&]+)/.exec(req.url ?? '')?.[1]
  const lang = langParam == null ? envLang() : parseLang(langParam)
  const local = (u: (typeof UNITS)[number]) => localizeUnit(u, lang)

  if (id) {
    const found = unitById(decodeURIComponent(id))
    if (!found) {
      res.status(404).json({ error: 'unknown_unit' })
      return
    }
    const unit = local(found)
    // カタログは滅多に変わらない。端末と CDN に持たせる。
    // **言語ごとに別のものを配るので Vary を付ける** —
    // 付けないと CDN が日本語を英語の要求に返す
    res.setHeader('Cache-Control', 'public, max-age=300, s-maxage=3600')
    res.setHeader('Vary', 'Accept-Language')
    res.status(200).json({
      schemaVersion: BUNDLED_UNIT_CATALOG_SCHEMA_VERSION,
      unit: publicUnitDetail(unit),
      dossier: emptyDossier(unit.id),
    })
    return
  }

  // 一覧に教材の本文は載せない。選ぶのに要らないぶんを運ばない
  res.setHeader('Cache-Control', 'public, max-age=300, s-maxage=3600')
  res.setHeader('Vary', 'Accept-Language')
  res.status(200).json({
    schemaVersion: BUNDLED_UNIT_CATALOG_SCHEMA_VERSION,
    units: UNITS.map(local).map(publicUnitSummary),
  })
}
