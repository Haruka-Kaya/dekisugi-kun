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
a = p.parse_args()
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
    elapsed = 0.4
    chunks.append(np.zeros(int(0.4 * 24000), dtype=np.float32))
    for text in scene['narration']:
        samples, rate = k.create(text, voice='af_sarah', speed=1.0, lang='en-us')
        duration = len(samples) / rate
        cues.append({'start': elapsed, 'end': elapsed + duration, 'text': text})
        chunks += [samples, np.zeros(int(0.24 * rate), dtype=np.float32)]
        elapsed += duration + 0.24
    sf.write(a.output / (scene['id'] + '.wav'), np.concatenate(chunks), 24000)
    (a.output / (scene['id'] + '.cues.json')).write_text(json.dumps(cues, indent=2))
    print(scene['id'], round(elapsed, 2), flush=True)
