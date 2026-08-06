/**
 * 通信するテストの門。
 *
 * > [!warning] `npm test` の glob は `*.live.test.ts` も拾う
 * > `test/*.test.ts` は `.live.` を含むファイルにも一致する。
 * > README は「既定では走らない」と書いてあったが**嘘だった** —
 * > テストのたびに本番へ繋いで Vertex を叩き、課金していた
 * > （1回の `npm test` が 220 秒かかっていたのはこれ）。
 *
 * 通信するテストは**明示したときだけ**走らせる。
 *
 * ```
 * DEKISUGI_LIVE=1 npm test
 * DEKISUGI_LIVE=1 npx tsx --test test/jailbreak.live.test.ts
 * ```
 */
export const liveSkip: string | false =
  process.env.DEKISUGI_LIVE === '1'
    ? false
    : '通信するテスト（DEKISUGI_LIVE=1 を付けると走る。Vertex に課金される）'

/** 本番を向く。`DEKISUGI_BASE` で差し替えられる。 */
export const LIVE_BASE = process.env.DEKISUGI_BASE ?? 'https://rika-chousa.vercel.app'
