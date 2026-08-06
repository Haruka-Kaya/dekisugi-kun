// **/api/live-token が返した中身をそのまま使って**繋ぐ通信テスト。
//
// 端末がやることを1バイトも変えずになぞる。ここを通しておかないと、
// 次のような「接続の瞬間まで気づけない」失敗が実機でしか出てこない:
//
//   - モデル名の名前空間違い（Developer API の名前は Vertex に無い）
//   - setup の形の違い（Vertex は responseModalities を generationConfig の中に要求し、
//     直下に置くと 1007 Unknown name で切る）
//
// どちらも実際にここで捕まえた。
//
//   node --import tsx --test test/grant.live.test.ts
//
// 既定では本番を叩く。DEKISUGI_BASE で向き先を変えられる。

import assert from 'node:assert/strict'
import { describe, it } from 'node:test'

import WebSocket from 'ws'

import { LIVE_BASE, liveSkip } from './support/live.js'

const BASE = LIVE_BASE

type Grant = {
  token: string
  wsUrl: string
  model: string
  setupConfig: Record<string, unknown>
  sessionMinutes: number
  remainingSessions: number | null
}

async function getGrant(): Promise<Grant | 'exhausted'> {
  const deviceId = crypto.randomUUID()
  const reg = (await fetch(`${BASE}/api/register`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ deviceId }),
  }).then((r) => r.json())) as { token?: string }
  assert.ok(reg.token, '端末の登録に失敗')

  const res = await fetch(`${BASE}/api/live-token`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${reg.token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ unitId: 'force-motion' }),
  })
  if (res.status === 402) return 'exhausted'
  // body は一度しか読めない。**失敗メッセージ用に先に読んでおく**
  const text = await res.text()
  assert.equal(res.status, 200, `資格情報が取れない: ${text}`)
  return JSON.parse(text) as Grant
}

describe('端末と同じ経路で会話が成立する', { skip: liveSkip }, () => {
  it('サーバが返した設定をそのまま送って音声が返る', async () => {
    const grant = await getGrant()
    if (grant === 'exhausted') {
      // 新しい端末IDなので通常は起きない。起きたら全体の上限に当たっている
      assert.fail('新規端末なのに枠が無い。全体の上限に当たっている可能性')
    }

    // Vertex の名前空間であること。Developer API の名前は Vertex に無い
    assert.match(grant.model, /^projects\/.+\/locations\/.+\/publishers\/google\/models\//)
    assert.ok(grant.wsUrl.startsWith('wss://'), grant.wsUrl)

    // 資格情報の鍵そのものが漏れていないこと
    assert.ok(!JSON.stringify(grant).includes('BEGIN PRIVATE KEY'), '秘密鍵が漏れている')

    const ws = new WebSocket(grant.wsUrl, {
      headers: { Authorization: `Bearer ${grant.token}` },
    })

    let audio = 0
    let transcript = ''
    let setupOk = false
    let failure: string | null = null

    await new Promise<void>((res, rej) => {
      ws.once('open', () => res())
      ws.once('error', rej)
    })

    ws.on('message', (raw) => {
      const m = JSON.parse(raw.toString())
      if (m.setupComplete) setupOk = true
      if (m.error) failure ??= JSON.stringify(m.error)
      for (const p of m.serverContent?.modelTurn?.parts ?? []) {
        if (p.inlineData?.data) audio += Buffer.from(p.inlineData.data, 'base64').length
      }
      const t = m.serverContent?.outputTranscription?.text
      if (t) transcript += t
    })
    ws.on('close', (c, r) => {
      if (c !== 1000) failure ??= `close ${c} ${r.toString()}`
    })

    ws.send(JSON.stringify({ setup: { model: grant.model, ...grant.setupConfig } }))
    await new Promise((r) => setTimeout(r, 3000))

    ws.send(
      JSON.stringify({
        clientContent: {
          turns: [
            {
              role: 'user',
              parts: [{ text: '[DIRECTOR] 会話を始めて。落下について教えてほしいと短く頼んで。' }],
            },
          ],
          turnComplete: true,
        },
      }),
    )
    await new Promise((r) => setTimeout(r, 20000))
    ws.close()

    const said = transcript.trim()
    assert.equal(failure, null, `接続が拒否された: ${failure}`)
    assert.ok(setupOk, 'setup が受理されなかった')
    // **音声のバイト数で判定する。** 文字起こしの有無は音が出た証拠にならない
    assert.ok(audio > 0, '音声が1バイトも返っていない')
    assert.ok(said.length > 0, '文字起こしが空（設定が黙殺されている）')

    // 製品の前提: ディレクターの指示を読み上げない
    for (const leak of ['DIRECTOR', '会話を始めて', '短く頼んで']) {
      assert.ok(!said.includes(leak), `指示が漏れている: "${leak}" in "${said}"`)
    }

    console.log(`  音声 ${audio} バイト / 発話: ${said}`)
  })
})
