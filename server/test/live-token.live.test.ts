// 一時トークンで実際に Gemini Live に繋がるかを確かめる。
//
// **UI を作る前にここを通す。** ephemeral token はドキュメントと実際が食い違う
// ところが多く（v1alpha 必須など）、繋がらないまま作り込むと全部やり直しになる。
//
//   node --import tsx --test test/live-token.live.test.ts

import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { describe, it } from 'node:test'

import { GoogleGenAI } from '@google/genai'

import { LIVE_MODEL } from '../lib/live-config.js'
import { createLiveToken } from '../lib/live-token.js'

function loadKey(): string | undefined {
  if (process.env.GEMINI_API_KEY) return process.env.GEMINI_API_KEY
  for (const p of ['../.env.local', 'C:/Users/kayah/jiyu-kenkyu-ai/.env.local']) {
    try {
      const m = /GEMINI_API_KEY\s*=\s*(\S+)/.exec(readFileSync(p, 'utf8'))
      if (m) return m[1]!.replace(/^["']|["']$/g, '')
    } catch {
      /* 次を試す */
    }
  }
  return undefined
}

const key = loadKey()
if (key) process.env.GEMINI_API_KEY = key

describe('一時トークン', { skip: key ? false : 'GEMINI_API_KEY が無い' }, () => {
  it('発行できる', async () => {
    const got = await createLiveToken()
    assert.ok(got.token.length > 10, `トークンが短すぎる: ${got.token}`)
    assert.equal(got.apiVersion, 'v1alpha')
    assert.equal(got.model, LIVE_MODEL)
    assert.ok(new Date(got.expiresAt).getTime() > Date.now())
    console.log('  トークン長:', got.token.length, '/ 期限:', got.expiresAt)
  })

  it('そのトークンで Live に繋がり、音声が返る', async () => {
    const issued = await createLiveToken()

    // **端末と同じ経路**: 生のキーではなくトークンで、v1alpha で繋ぐ
    const ai = new GoogleGenAI({
      apiKey: issued.token,
      httpOptions: { apiVersion: issued.apiVersion },
    })

    let audioBytes = 0
    let transcript = ''
    let failure: unknown = null
    const done = Promise.withResolvers<void>()

    const session = await ai.live.connect({
      model: issued.model,
      // **端末と同じ**: config を送らない。
      // 設定はトークンに焼いてあり、ここで送っても効かない（実測）
      config: {},
      callbacks: {
        onmessage: (m) => {
          for (const p of m.serverContent?.modelTurn?.parts ?? []) {
            const b64 = p.inlineData?.data
            if (b64) audioBytes += Buffer.from(b64, 'base64').length
          }
          const t = m.serverContent?.outputTranscription?.text
          if (t) transcript += t
          if (m.serverContent?.turnComplete) done.resolve()
        },
        onerror: (e) => {
          failure = e
          done.resolve()
        },
        onclose: () => done.resolve(),
      },
    })

    session.sendClientContent({
      turns: [{ role: 'user', parts: [{ text: '短くあいさつして' }] }],
      turnComplete: true,
    })

    const timeout = new Promise<void>((r) => setTimeout(r, 45_000))
    await Promise.race([done.promise, timeout])
    session.close()

    assert.equal(failure, null, `接続が拒否された: ${failure}`)
    // **音声のバイト数で判定する。** 文字起こしの有無は音が出た証拠にならない
    assert.ok(audioBytes > 0, '音声が1バイトも返っていない')
    console.log('  音声:', audioBytes, 'バイト / 発話:', transcript.trim())
  })

  // uses:1 の再接続テストは書けなかった。
  // 使い切ったトークンで connect() を呼ぶと **reject もせず返ってもこない**ので、
  // 「拒否された」と「まだ待っている」を区別できない。
  //
  // 上限の強制はこれに依存していない。**期限が来るとセッションごと切られる**
  // 方が本体で、そちらは実測済み（`code=1011 auth token has expired`、発行58秒後）。
})
