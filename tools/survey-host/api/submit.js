// アンケート回答の受け口。
//
// ブラウザ → ここ（同一オリジンなので成功/失敗を素直に返せる）→ Vercel Blob。
// Blob が未接続なら 503 を返し、ブラウザ側は「コードをコピーして渡す」経路に落ちる。
// つまり **保存先が無くても回答は失われない**。
//
// 保存は access:'private'。中高生の自由記述なので公開URLは作らない。

import { put } from '@vercel/blob';

const MAX_BYTES = 64 * 1024; // 1件の上限。自由記述2問なので十分すぎる

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST');
    return res.status(405).json({ error: 'method_not_allowed' });
  }

  let body = req.body;
  if (typeof body === 'string') {
    try {
      body = JSON.parse(body);
    } catch {
      return res.status(400).json({ error: 'invalid_json' });
    }
  }
  if (!body || typeof body !== 'object') {
    return res.status(400).json({ error: 'empty_body' });
  }

  const raw = JSON.stringify(body);
  if (Buffer.byteLength(raw, 'utf8') > MAX_BYTES) {
    return res.status(413).json({ error: 'too_large' });
  }

  // kind でアンケートを分ける（type = 行間字間 / misconception = 誤概念）
  const kind = typeof body.kind === 'string' && /^[a-z]+$/.test(body.kind) ? body.kind : 'unknown';

  if (!process.env.BLOB_READ_WRITE_TOKEN) {
    // Blob ストアが未接続。ブラウザはコード表示へフォールバックする
    return res.status(503).json({ error: 'no_store' });
  }

  try {
    const stamp = new Date().toISOString().replace(/[:.]/g, '-');
    const rand = Math.random().toString(36).slice(2, 10);
    const { pathname } = await put(
      `responses/${kind}/${stamp}_${rand}.json`,
      raw,
      {
        access: 'private',
        contentType: 'application/json',
        addRandomSuffix: false,
      },
    );
    return res.status(200).json({ ok: true, id: pathname });
  } catch (e) {
    console.error('blob put failed', e);
    return res.status(500).json({ error: 'store_failed' });
  }
}
