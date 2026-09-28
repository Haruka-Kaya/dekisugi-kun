/**
 * 未成年・学校利用に関係しうる外部データ処理の内部テストguard。
 *
 * Vercel production / preview、および `NODE_ENV=production` は環境変数で
 * 解除できず、常に閉じる。ローカル（VERCEL_ENV未設定）またはVercel
 * developmentで、専用フラグが厳密に `1` の場合だけ開く。
 *
 * AI・学校Team用のフラグとは分離する。一方の内部テストを始めただけで
 * UpstashやRevenueCatへの保存・同期が開かないようにする。
 */
export function restrictedDataProcessingEnabled(): boolean {
  if (process.env.NODE_ENV === 'production') return false
  const environment = process.env.VERCEL_ENV
  if (environment !== undefined && environment !== 'development') return false
  return process.env.DEKISUGI_INTERNAL_RESTRICTED_DATA_TESTING === '1'
}
