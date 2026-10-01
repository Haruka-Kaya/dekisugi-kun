#!/usr/bin/env python3
"""実キャプチャ・台本・ローカル音声から1080p紹介動画を再生成する。"""
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
p.add_argument('--raw', required=True, type=Path)
p.add_argument('--output', required=True, type=Path)
p.add_argument('--ffmpeg', default='/opt/homebrew/opt/ffmpeg-full/bin/ffmpeg')
p.add_argument('--font', default='/System/Library/Fonts/Avenir Next.ttc')
p.add_argument('--preview', help='指定シーンの構図をJPEGだけで書き出す')
a = p.parse_args()
a.output.mkdir(parents=True, exist_ok=True)
work = a.raw / 'render'
work.mkdir(exist_ok=True)
script = json.loads(a.script.read_text())
edit = json.loads(a.edit.read_text())
CREAM, INK, TEAL, MUTED = '#F4F1E8', '#183039', '#006B73', '#536970'

def font(size, bold=False):
    return ImageFont.truetype(a.font, size, index=0 if bold else 5)

def run(args):
    subprocess.run([a.ffmpeg, '-hide_banner', '-loglevel', 'error', '-y', *args], check=True)

def draw_lines(draw, value, xy, size, fill, bold=False, leading=1.22):
    x, y = xy
    for line in value.split('\n'):
        assert draw.textlength(line, font=font(size, bold)) <= 1030, 'Text exceeds column: ' + line
        draw.text((x, y), line, font=font(size, bold), fill=fill)
        y += size * leading

def card(scene, index):
    im = Image.new('RGB', (1920, 1080), CREAM)
    d = ImageDraw.Draw(im)
    d.text((90, 46), 'DEKISUGI-KUN', font=font(26, True), fill=INK)
    d.text((1450, 46), 'LEARN BY TEACHING', font=font(23), fill=MUTED)
    d.line((90, 104, 1828, 104), fill='#C1CDC9', width=2)
    d.text((90, 150), scene['chapter'], font=font(28, True), fill=TEAL)
    draw_lines(d, scene['title'], (84, 208), 78, INK, True, 1.10)
    draw_lines(d, scene['body'], (90, 493 if len(scene['title'].split('\n')) <= 2 else 515), 36, MUTED, leading=1.37)
    # 字幕はアプリと完全に分離した固定の帯に置く。
    d.rectangle((0, 947, 1920, 1080), fill=INK)
    d.rectangle((0, 1073, 1920, 1080), fill='#41575B')
    d.rectangle((0, 1073, int(1920 * (index+1) / len(script['scenes'])), 1080), fill='#E6AA58')
    tag = scene['tag']
    if d.textlength(tag, font=font(25)) > 1700:
        raise ValueError('Tag too long')
    d.text((90, 891), tag, font=font(25), fill=TEAL)
    if edit[scene['id']].get('shots'):
        d.rounded_rectangle((1192, 120, 1714, 938), radius=28, fill='#D8DDD6')
        d.rounded_rectangle((1180, 112, 1700, 930), radius=28, fill=INK)
        d.text((1200, 925), 'ACTUAL ANDROID APP', font=font(16, True), fill=MUTED)
    else:
        # 概念の導入用図。アプリ画面とは独立して示す。
        if scene['id'] == '01-hook':
            d.line((1190, 422, 1770, 422), fill='#B3C5C0', width=3)
            d.ellipse((1220, 312, 1440, 532), fill=TEAL)
            d.ellipse((1560, 362, 1680, 482), fill='#5F5ADD')
            d.text((1220, 562), 'HEAVY', font=font(30, True), fill=TEAL)
            d.text((1550, 512), 'LIGHT', font=font(30, True), fill='#514BC2')
            d.line((1190, 777, 1770, 777), fill=INK, width=4)
            d.text((1240, 814), 'Same height · In a vacuum', font=font(26), fill=MUTED)
            d.text((1430, 583), '?', font=font(116, True), fill=INK)
        else:
            icon_path = a.script.parent.parent / 'store' / 'icon-1024.png'
            brand = Image.open(icon_path).convert('RGB').resize((500, 500), Image.Resampling.LANCZOS)
            im.paste(brand, (1200, 236))
            d.text((1220, 770), 'DEKISUGI-KUN', font=font(42, True), fill=INK)
            d.text((90, 725), 'github.com/Haruka-Kaya/dekisugi-kun', font=font(30), fill=TEAL)
    if detail := edit[scene['id']].get('detail'):
        if 'text' in detail:
            d.text((90, 645), 'FROM MY EXPLANATION', font=font(18, True), fill=TEAL)
            d.rounded_rectangle((90, 680, 1090, 850), radius=16, fill='#E3ECE7', outline='#B3C5C0', width=2)
            draw_lines(d, detail['text'], (115, 704), 42, INK, leading=1.3)
        else:
            img = Image.open(a.raw / detail['file']).convert('RGB').crop(detail['crop'])
            img.thumbnail((990, 195), Image.Resampling.LANCZOS)
            d.text((90, 645), 'DETAIL FROM THE APP', font=font(18, True), fill=TEAL)
            im.paste(img, (90, 680))
            d.rectangle((90, 680, 90+img.width, 680+img.height), outline='#B3C5C0', width=2)
    path = work / (scene['id'] + '.png')
    im.save(path)
    return path

def ass_time(t):
    ticks = round(t*100)
    return f'{ticks//360000}:{ticks//6000%60:02d}:{ticks//100%60:02d}.{ticks%100:02d}'

def srt_time(t):
    ticks = round(t*1000)
    return f'{ticks//3600000:02d}:{ticks//60000%60:02d}:{ticks//1000%60:02d},{ticks%1000:03d}'

if a.preview:
    scene = next(s for s in script['scenes'] if s['id'] == a.preview)
    background = card(scene, script['scenes'].index(scene))
    im = Image.open(background)
    shots = edit[scene['id']].get('shots', [])
    if shots:
        shot = shots[0]
        source = a.raw / shot['file']
        if source.suffix == '.mp4':
            tmp = work / 'preview-app.png'
            run(['-ss', str(shot.get('start', 0)), '-i', str(source), '-frames:v', '1', str(tmp)])
            source = tmp
        phone = Image.open(source).crop((0,110,1080,1858)).resize((486,786), Image.Resampling.LANCZOS)
        im.paste(phone, (1197,128))
    im.save(a.output / (a.preview + '-preview.jpg'))
    raise SystemExit(0)

all_cues, files, manifest = [], [], []
offset = 0.0
for index, scene in enumerate(script['scenes']):
    ident = scene['id']
    cues = json.loads((a.raw / 'narration' / (ident + '.cues.json')).read_text())
    # テンポを落とし、最後の文に短い余韻を足す。30fpsの境界にそろえる。
    duration = math.ceil((cues[-1]['end'] / 0.92 + 1.15) * 30) / 30
    duration = max(duration, edit[ident].get('minimum_duration', 0))
    background = card(scene, index)
    voice = a.raw / 'narration' / (ident + '.wav')
    output = work / (ident + '.mp4')
    shots = edit[ident].get('shots', [])
    args = ['-loop', '1', '-framerate', '30', '-i', str(background)]
    if shots:
        pieces = []
        for j, shot in enumerate(shots):
            source = a.raw / shot['file']
            segment = work / f'{ident}-shot{j}.mp4'
            still = source.suffix.lower() == '.png'
            source_args = ['-loop', '1', '-framerate', '30'] if still else ['-ss', str(shot.get('start', 0))]
            run([*source_args, '-i', str(source), '-vf', 'crop=1080:1748:0:110,scale=486:786:flags=lanczos,fps=30,setsar=1,tpad=stop_mode=clone:stop_duration=120', '-t', str(shot['duration']), '-an', '-c:v', 'libx264', '-preset', 'fast', '-crf', '18', '-pix_fmt', 'yuv420p', str(segment)])
            pieces.append(segment)
        listing = work / (ident + '-shots.txt')
        listing.write_text(''.join(f"file '{s}'\n" for s in pieces))
        phone = work / (ident + '-phone.mp4')
        run(['-f', 'concat', '-safe', '0', '-i', str(listing), '-c', 'copy', str(phone)])
        args += ['-i', str(phone), '-i', str(voice)]
        fc = f'[1:v]tpad=stop_mode=clone:stop_duration=120[phone];[0:v][phone]overlay=1197:128,fade=t=in:st=0:d=0.2[v];[2:a]atempo=0.92,apad,atrim=duration={duration},afade=t=out:st={duration-0.5}:d=0.5[a]'
    else:
        args += ['-i', str(voice)]
        fc = f'[0:v]fade=t=in:st=0:d=0.2[v];[1:a]atempo=0.92,apad,atrim=duration={duration},afade=t=out:st={duration-0.5}:d=0.5[a]'
    args += ['-filter_complex', fc, '-map', '[v]', '-map', '[a]', '-t', str(duration), '-c:v', 'libx264', '-preset', 'fast', '-crf', '19', '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-b:a', '192k', '-ar', '48000', '-ac', '2', str(output)]
    run(args)
    files.append(output)
    for cue in cues:
        all_cues.append({'start': offset + cue['start']/0.92, 'end': offset + cue['end']/0.92, 'text': cue['text']})
    manifest.append({'scene': ident, 'start': round(offset, 3), 'duration': duration, 'shots': shots})
    offset += duration
    print(ident, duration, flush=True)

assert offset < 120, f'Too long: {offset}'
ass = '[Script Info]\nPlayResX: 1920\nPlayResY: 1080\nWrapStyle: 0\n\n[V4+ Styles]\nFormat: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding\nStyle: Default,Avenir Next,34,&H00FFFFFF,&H00FFFFFF,&H00393018,&H00393018,0,0,0,0,100,100,0,0,1,0,0,2,130,130,34,1\n\n[Events]\nFormat: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\n'
srt = ''
for i, cue in enumerate(all_cues):
    # 長文を2つの字幕に分け、音声の長さに比例して切り替える。
    remaining = cue['text'].split()
    parts = []
    lines = math.ceil(len(cue['text']) / 84)
    for left in range(lines, 1, -1):
        target = len(' '.join(remaining)) / left
        cut = min(range(1, len(remaining) - left + 2), key=lambda n: abs(len(' '.join(remaining[:n])) - target))
        parts.append(' '.join(remaining[:cut]))
        remaining = remaining[cut:]
    parts.append(' '.join(remaining))
    count = sum(len(part) for part in parts)
    at = cue['start']
    for part in parts:
        end = at + (cue['end']-cue['start']) * len(part) / count
        ass += f'Dialogue: 0,{ass_time(at)},{ass_time(end)},Default,,0,0,0,,{part}\n'
        srt += f'{srt.count(" --> ")+1}\n{srt_time(at)} --> {srt_time(end)}\n{part}\n\n'
        at = end
captions = a.output / 'shipaton-demo-v8-captions.en.srt'
captions.write_text(srt)
ass_path = work / 'captions.ass'
ass_path.write_text(ass)
# 自作の控えめな伴奏。台本やアプリ音声の一部と誤認しない低い音量。
rate = 24000
bed = np.zeros(int((offset+1)*rate), dtype=np.float32)
chords = [(220, 261.626, 329.628), (174.614, 220, 261.626), (196, 246.942, 293.665), (164.814, 196, 246.942)]
for n, start in enumerate(np.arange(0, offset, 4.0)):
    count = min(int(5*rate), len(bed)-int(start*rate))
    t = np.arange(count)/rate
    envelope = (1-np.exp(-t*3))*np.exp(-t*0.65)
    chord = sum(np.sin(2*np.pi*f*t) + .12*np.sin(4*np.pi*f*t) for f in chords[n%4]) / 3
    bed[int(start*rate):int(start*rate)+count] += (0.018*chord*envelope).astype(np.float32)
bed_path = work / 'original-music.wav'
sf.write(bed_path, bed, rate)
final = a.output / 'shipaton-demo-v8.mp4'
# 個別シーンをデコードして結合する。AACのprimingや色メタデータの差で
# concat demuxer後のフィルターが再初期化され、字幕と音声がずれるのを防ぐ。
inputs, filters, pairs = [], [], []
for i, (file, item) in enumerate(zip(files, manifest)):
    inputs += ['-threads', '2', '-i', str(file)]
    duration = item['duration']
    filters += [
        f'[{i}:v]fps=30,setsar=1,setparams=range=limited:color_primaries=bt709:color_trc=bt709:colorspace=bt709,tpad=stop_mode=clone:stop_duration=1,trim=duration={duration},setpts=PTS-STARTPTS[v{i}]',
        f'[{i}:a]aresample=48000,apad,atrim=duration={duration},asetpts=PTS-STARTPTS[a{i}]',
    ]
    pairs.append(f'[v{i}][a{i}]')
filters += [
    ''.join(pairs) + f'concat=n={len(files)}:v=1:a=1[video][speech]',
    f'[video]ass={ass_path}[v]',
    '[speech]loudnorm=I=-16:TP=-1.5:LRA=7[voice]',
    f'[{len(files)}:a]afade=t=in:d=1,afade=t=out:st={offset-2}:d=2[bed]',
    '[voice][bed]amix=inputs=2:duration=first:normalize=0,alimiter=limit=0.84:level=false[a]',
]
run([*inputs, '-i', str(bed_path), '-filter_complex', ';'.join(filters), '-map', '[v]', '-map', '[a]', '-c:v', 'libx264', '-preset', 'medium', '-crf', '19', '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-b:a', '192k', '-ar', '48000', '-ac', '2', '-t', str(offset), '-movflags', '+faststart', '-metadata', 'title=' + script['title'], '-metadata', 'comment=Native emulator footage; edited for pace; RevenueCat Test Store; no real charge; external generative AI disabled', str(final)])
manifest_path = a.output / 'v8-manifest.json'
sources = sorted({shot['file'] for value in edit.values() for shot in value.get('shots', [])} | {value['detail']['file'] for value in edit.values() if value.get('detail')})
manifest_path.write_text(json.dumps({'source_commit': script['source_commit'], 'duration': round(offset, 3), 'capture': script['capture'], 'narrator': 'Local Kokoro af_sarah; tempo 0.92', 'sources': {s: hashlib.sha256((a.raw/s).read_bytes()).hexdigest() for s in sources}, 'scenes': manifest, 'sha256': hashlib.sha256(final.read_bytes()).hexdigest()}, indent=2) + '\n')
run(['-ss', '10', '-i', str(final), '-frames:v', '1', str(a.output / 'shipaton-demo-v8-poster.jpg')])
print(final, round(offset, 3), flush=True)
