#!/usr/bin/env python3
"""台本からローカル音声を生成。クラウド送信・従量課金なし。"""
import argparse
import json
from pathlib import Path
import numpy as np
import soundfile as sf
from kokoro_onnx import Kokoro

p = argparse.ArgumentParser()
p.add_argument('script', type=Path)
p.add_argument('--models', required=True, type=Path)
p.add_argument('--output', required=True, type=Path)
p.add_argument('--lead', type=float, default=0.4)
p.add_argument('--gap', type=float, default=0.24)
p.add_argument('--speed', type=float, default=1.0)
a = p.parse_args()
if a.lead < 0 or a.gap < 0 or not 0.5 <= a.speed <= 2:
    p.error('lead/gap must be nonnegative; speed must be between 0.5 and 2')
a.output.mkdir(parents=True, exist_ok=True)
k = Kokoro(str(a.models / 'kokoro-v1.0.onnx'), str(a.models / 'voices-v1.0.bin'))

class TypedSession:
    """ONNXの宣言型に合わせる。0.4.6は新exportのspeedをint32にする。"""
    def __init__(self, session):
        self.session = session
        self.types = {i.name: i.type for i in session.get_inputs()}

    def get_inputs(self):
        return self.session.get_inputs()

    def run(self, names, inputs):
        if self.types.get('speed') == 'tensor(float)':
            inputs['speed'] = np.asarray(inputs['speed'], dtype=np.float32)
        return self.session.run(names, inputs)

k.sess = TypedSession(k.sess)
for scene in json.loads(a.script.read_text())['scenes']:
    # センテンス単位で字幕と音声を一致させる。
    chunks = []
    cues = []
    elapsed = a.lead
    chunks.append(np.zeros(int(a.lead * 24000), dtype=np.float32))
    for text in scene['narration']:
        samples, rate = k.create(text, voice='af_sarah', speed=a.speed, lang='en-us')
        duration = len(samples) / rate
        cues.append({'start': elapsed, 'end': elapsed + duration, 'text': text})
        chunks += [samples, np.zeros(int(a.gap * rate), dtype=np.float32)]
        elapsed += duration + a.gap
    sf.write(a.output / (scene['id'] + '.wav'), np.concatenate(chunks), 24000)
    (a.output / (scene['id'] + '.cues.json')).write_text(json.dumps(cues, indent=2))
    print(scene['id'], round(elapsed, 2), flush=True)
