#!/usr/bin/env python3
"""操作録画を主役にし、同じ瞬間の拡大表示と短い字幕を合成する。"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import subprocess

import numpy as np
import soundfile as sf
from PIL import Image, ImageDraw, ImageFont

p = argparse.ArgumentParser()
p.add_argument('script', type=Path)
p.add_argument('edit', type=Path)
p.add_argument('--raw', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
p.add_argument('--name', default='shipaton-demo-v10')
p.add_argument('--ffmpeg', default='/opt/homebrew/opt/ffmpeg-full/bin/ffmpeg')
p.add_argument('--font', default='/System/Library/Fonts/Avenir Next.ttc')
p.add_argument('--poster-time', type=float, default=20)
a = p.parse_args()
if not a.name.replace('-', '').replace('_', '').isalnum():
    p.error('Invalid output name')
a.raw, a.output = a.raw.resolve(), a.output.resolve()
a.output.mkdir(parents=True, exist_ok=True)
work = a.raw / 'render-motion'
work.mkdir(exist_ok=True)
script, edit = json.loads(a.script.read_text()), json.loads(a.edit.read_text())
INK, CREAM, TEAL = '#183039', '#F4F1E8', '#006B73'

def font(size, bold=False):
    return ImageFont.truetype(a.font, size, index=0 if bold else 5)

def run(args):
    subprocess.run([a.ffmpeg, '-hide_banner', '-loglevel', 'error', '-y', *args], check=True)

def background(scene):
    im = Image.new('RGB', (1920, 1080), CREAM)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((34, 26, 610, 936), radius=22, fill=INK)
    d.text((654, 38), 'DEKISUGI-KUN', font=font(24, True), fill=INK)
    d.text((654, 104), scene['chapter'], font=font(24, True), fill=TEAL)
    if d.textlength(scene['title'], font=font(54, True)) > 1180:
        raise ValueError('Heading exceeds available width')
    d.text((650, 143), scene['title'], font=font(54, True), fill=INK)
    d.text((654, 219), 'ACTUAL APP · ENLARGED DETAIL FROM THE SAME FRAME', font=font(18), fill='#536970')
    d.text((654, 891), scene['tag'], font=font(23), fill=TEAL)
    d.rectangle((0, 947, 1920, 1080), fill=INK)
    if not edit[scene['id']].get('shots'):
        # 締めだけは短いブランド画面。アプリの動作として見せない。
        im = Image.new('RGB', (1920, 1080), CREAM)
        d = ImageDraw.Draw(im)
        icon = Image.open(a.script.resolve().parent.parent / 'store/icon-1024.png').convert('RGB')
        im.paste(icon.resize((360, 360), Image.Resampling.LANCZOS), (130, 270))
        d.text((590, 260), 'DEKISUGI-KUN', font=font(35, True), fill=TEAL)
        d.text((584, 340), scene['title'], font=font(87, True), fill=INK)
        d.text((590, 490), scene['tag'], font=font(32), fill=INK)
        d.text((590, 620), 'github.com/Haruka-Kaya/dekisugi-kun', font=font(31), fill=TEAL)
        d.rectangle((0, 947, 1920, 1080), fill=INK)
    dest = work / (scene['id'] + '-background.png')
    im.save(dest)
    return dest

def timestamp(seconds, ass=False):
    unit = 100 if ass else 1000
    n = round(seconds * unit)
    h, m, s = n // (3600 * unit), n // (60 * unit) % 60, n // unit % 60
    return f'{h}:{m:02d}:{s:02d}.{n%unit:02d}' if ass else f'{h:02d}:{m:02d}:{s:02d},{n%unit:03d}'

files, manifest, cues_all = [], [], []
offset = 0.0
for scene in script['scenes']:
    ident, spec = scene['id'], edit[scene['id']]
    bg = background(scene)
    segments = []
    for j, shot in enumerate(spec.get('shots', [])):
        source = a.raw / shot['file']
        still = source.suffix.lower() in ('.png', '.jpg')
        speed, duration = shot.get('speed', 1), shot['duration']
        assert duration > 0 and speed > 0
        # 速度変更は両表示に同時適用。画面に偽のパンやタップ演出を足さない。
        x1, y1, x2, y2 = shot['crop']
        args = ['-loop', '1', '-framerate', '30', '-i', str(bg)]
        args += (['-loop', '1', '-framerate', '30'] if still else ['-ss', str(shot.get('start', 0))])
        args += ['-i', str(source)]
        fc = (
            f'[1:v]setpts=(PTS-STARTPTS)/{speed},fps=30,split=2[full][zoom];'
            '[full]crop=1080:1748:0:110,scale=540:874:flags=lanczos,setsar=1[phone];'
            f'[zoom]crop={x2-x1}:{y2-y1}:{x1}:{y1},scale=1180:614:force_original_aspect_ratio=decrease:flags=lanczos,setsar=1,'
            f'pad=1180:614:(ow-iw)/2:(oh-ih)/2:color={CREAM}[detail];'
            '[0:v][phone]overlay=52:44:shortest=1[base];'
            '[base][detail]overlay=654:263:shortest=1[v]'
        )
        segment = work / f'{ident}-{j}.mp4'
        run([*args, '-filter_complex', fc, '-map', '[v]', '-t', str(duration), '-an', '-c:v', 'libx264', '-preset', 'fast', '-crf', '18', '-pix_fmt', 'yuv420p', str(segment)])
        segments.append(segment)
    duration = sum(s['duration'] for s in spec.get('shots', [])) or spec['duration']
    duration = round(duration * 30) / 30
    cues = json.loads((a.raw / 'narration' / (ident + '.cues.json')).read_text())
    assert cues[-1]['end'] <= duration - 0.04, f'{ident}: narration {cues[-1]["end"]:.2f}s exceeds edit {duration}s'
    voice = a.raw / 'narration' / (ident + '.wav')
    target = work / (ident + '.mp4')
    if segments:
        args, filters = [], []
        for j, segment in enumerate(segments):
            args += ['-threads', '2', '-i', str(segment)]
            filters.append(f'[{j}:v]setparams=range=limited:color_primaries=bt709:color_trc=bt709:colorspace=bt709,setpts=PTS-STARTPTS[v{j}]')
        filters.append(''.join(f'[v{j}]' for j in range(len(segments))) + f'concat=n={len(segments)}:v=1:a=0[v]')
        args += ['-i', str(voice)]
        filters.append(f'[{len(segments)}:a]apad,atrim=duration={duration},asetpts=PTS-STARTPTS[a]')
    else:
        args = ['-loop', '1', '-framerate', '30', '-i', str(bg), '-i', str(voice)]
        filters = ['[0:v]null[v]', f'[1:a]apad,atrim=duration={duration}[a]']
    run([*args, '-filter_complex', ';'.join(filters), '-map', '[v]', '-map', '[a]', '-t', str(duration), '-c:v', 'libx264', '-preset', 'fast', '-crf', '19', '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-ar', '48000', '-ac', '2', str(target)])
    files.append(target)
    manifest.append({'scene': ident, 'start': round(offset, 3), 'duration': duration, 'shots': spec.get('shots', [])})
    cues_all += [{'start': offset+c['start'], 'end': offset+c['end'], 'text': c['text']} for c in cues]
    offset += duration
    print(ident, duration, flush=True)

assert offset < 120
ass = '[Script Info]\nPlayResX: 1920\nPlayResY: 1080\nWrapStyle: 0\n\n[V4+ Styles]\nFormat: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding\nStyle: Default,Avenir Next,36,&H00FFFFFF,&H00FFFFFF,&H00393018,&H00393018,0,0,0,0,100,100,0,0,1,0,0,2,130,130,36,1\n\n[Events]\nFormat: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\n'
srt, caption_count = '', 0
for cue in cues_all:
    words, parts = cue['text'].split(), []
    # 十分な長さの字幕を維持し、文字量が多い文だけ分割する。
    count = math.ceil(len(cue['text']) / 90)
    for left in range(count, 1, -1):
        target = len(' '.join(words)) / left
        cut = min(range(1, len(words)-left+2), key=lambda n: abs(len(' '.join(words[:n]))-target))
        parts.append(' '.join(words[:cut]))
        words = words[cut:]
    parts.append(' '.join(words))
    at, total = cue['start'], sum(map(len, parts))
    for part in parts:
        end = at + (cue['end']-cue['start']) * len(part)/total
        ass += f'Dialogue: 0,{timestamp(at, True)},{timestamp(end, True)},Default,,0,0,0,,{part}\n'
        caption_count += 1
        srt += f'{caption_count}\n{timestamp(at)} --> {timestamp(end)}\n{part}\n\n'
        at = end
(a.output / (a.name + '-captions.en.srt')).write_text(srt.rstrip() + '\n')
ass_path = work / 'captions.ass'
ass_path.write_text(ass)
rate = 24000
bed = np.zeros(int((offset+1)*rate), dtype=np.float32)
chords = [(220, 261.626, 329.628), (174.614, 220, 261.626), (196, 246.942, 293.665), (164.814, 196, 246.942)]
for n, start in enumerate(np.arange(0, offset, 4)):
    count = min(int(5*rate), len(bed)-int(start*rate))
    t = np.arange(count)/rate
    envelope = (1-np.exp(-t*3))*np.exp(-t*.65)
    chord = sum(np.sin(2*np.pi*f*t)+.12*np.sin(4*np.pi*f*t) for f in chords[n%4])/3
    bed[int(start*rate):int(start*rate)+count] += (.018*chord*envelope).astype(np.float32)
bed_path = work / 'original-music.wav'
sf.write(bed_path, bed, rate)
inputs, filters, pairs = [], [], []
for i, (file, item) in enumerate(zip(files, manifest)):
    inputs += ['-threads', '2', '-i', str(file)]
    duration = item['duration']
    filters += [f'[{i}:v]fps=30,setsar=1,setparams=range=limited:color_primaries=bt709:color_trc=bt709:colorspace=bt709,tpad=stop_mode=clone:stop_duration=1,trim=duration={duration},setpts=PTS-STARTPTS[v{i}]', f'[{i}:a]aresample=48000,apad,atrim=duration={duration},asetpts=PTS-STARTPTS[a{i}]']
    pairs.append(f'[v{i}][a{i}]')
filters += [''.join(pairs)+f'concat=n={len(files)}:v=1:a=1[video][speech]', f'[video]fps=30,ass={ass_path}[v]', '[speech]loudnorm=I=-16:TP=-1.5:LRA=7[voice]', f'[{len(files)}:a]afade=t=in:d=0.5,afade=t=out:st={offset-1}:d=1[bed]', '[voice][bed]amix=inputs=2:duration=first:normalize=0,alimiter=limit=0.84:level=false[a]']
final = a.output / (a.name + '.mp4')
run([*inputs, '-i', str(bed_path), '-filter_complex', ';'.join(filters), '-map', '[v]', '-map', '[a]', '-t', str(offset), '-c:v', 'libx264', '-preset', 'medium', '-crf', '19', '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-b:a', '192k', '-ar', '48000', '-ac', '2', '-movflags', '+faststart', '-metadata', 'title='+script['title'], '-metadata', 'comment=Real native recordings; cuts and speed changes for pace; synchronized detail crop; Test Store/no real charge; external AI disabled', str(final)])
sources = sorted({s['file'] for spec in edit.values() for s in spec.get('shots', [])})
still_seconds = sum(s['duration'] for spec in edit.values() for s in spec.get('shots', []) if Path(s['file']).suffix != '.mp4')
(a.output / (a.name.removeprefix('shipaton-demo-')+'-manifest.json')).write_text(json.dumps({'source_commit': script['source_commit'], 'capture': script['capture'], 'narrator': 'Local Kokoro af_sarah; speed 1.06; lead .12s; gap .08s', 'duration': round(offset, 3), 'recording_source_seconds': round(offset-still_seconds-edit['10-close']['duration'], 3), 'held_screenshot_seconds': still_seconds, 'end_card_seconds': edit['10-close']['duration'], 'sources': {s: hashlib.sha256((a.raw/s).read_bytes()).hexdigest() for s in sources}, 'scenes': manifest, 'sha256': hashlib.sha256(final.read_bytes()).hexdigest()}, indent=2)+'\n')
run(['-ss', str(a.poster_time), '-i', str(final), '-frames:v', '1', str(a.output / (a.name+'-poster.jpg'))])
print(final, offset, flush=True)
