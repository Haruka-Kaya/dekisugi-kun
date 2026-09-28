/**
 * 生成AI経路の運用スイッチ。
 *
 * Vercel production / preview、および `NODE_ENV=production` は環境変数で
 * 解除できず、常に閉じる。ローカル（VERCEL_ENV未設定）またはVercel
 * developmentで、内部テスト用のフラグが厳密に `1` の場合だけ開く。
 * 公開再開にはレビュー付きのコード変更が要る。
 *
 * 学校・年齢・端末ごとの例外は作らない。このスイッチは全生成AI入口を
 * 一括停止する最後の砦であり、クライアントの申告を判断材料にしない。
 */
export function generativeAiEnabled(): boolean {
  if (process.env.NODE_ENV === 'production') return false
  const environment = process.env.VERCEL_ENV
  if (environment !== undefined && environment !== 'development') return false
  return process.env.DEKISUGI_INTERNAL_AI_TESTING === '1'
}
