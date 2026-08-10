/**
 * 学校向けTeam APIの内部テストguard。
 *
 * production / previewを含むVercel development以外の明示環境、および
 * `NODE_ENV=production` ではフラグがあっても開かない。
 * 公開再開にはレビュー付きのコード変更が必要。
 * AI用フラグとは分離し、一方を試すだけで他方が開かないようにする。
 */
export function schoolTestingEnabled(): boolean {
  if (process.env.NODE_ENV === 'production') return false
  const environment = process.env.VERCEL_ENV
  if (environment !== undefined && environment !== 'development') return false
  return process.env.DEKISUGI_INTERNAL_SCHOOL_TESTING === '1'
}
