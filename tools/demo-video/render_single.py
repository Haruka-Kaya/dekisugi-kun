#!/usr/bin/env python3
"""可変fpsのnative録画を時間軸どおりに切り出し、単一画面の縦型デモにする。"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import subprocess
from PIL import Image, ImageDraw, ImageFont

p = argparse.ArgumentParser()
p.add_argument('script', type=Path)
p.add_argument('edit', type=Path)
p.add_argument('--raw', required=True, type=Path)
p.add_argument('--output', required=True, type=Path)
p.add_argument('--name', default='shipaton-demo-v11')
p.add_argument('--ffmpeg', default='/opt/homebrew/opt/ffmpeg-full/bin/ffmpeg')
p.add_argument('--font', default='/System/Library/Fonts/Avenir Next.ttc')
a = p.parse_args()
if not a.name.replace('-', '').replace('_', '').isalnum(): p.error('Invalid name')
a.raw, a.output = a.raw.resolve(), a.output.resolve()
a.output.mkdir(parents=True, exist_ok=True)
work = a.raw / ('render-single-' + a.name)
work.mkdir(exist_ok=True)
script, edit = json.loads(a.script.read_text()), json.loads(a.edit.read_text())
INK, CREAM, TEAL = '#183039', '#F4F1E8', '#006B73'

def font(size, bold=False):
    return ImageFont.truetype(a.font, size, index=0 if bold else 5)

def run(args):
    subprocess.run([a.ffmpeg, '-hide_banner', '-loglevel', 'error', '-y', *args], check=True)

def timestamp(seconds, ass=False):
    unit = 100 if ass else 1000
    n = round(seconds * unit)
    h, m, s = n // (3600 * unit), n // (60 * unit) % 60, n // unit % 60
    return f'{h}:{m:02d}:{s:02d}.{n%unit:02d}' if ass else f'{h:02d}:{m:02d}:{s:02d},{n%unit:03d}'

files, manifest, all_cues = [], [], []
offset = 0
for scene in script['scenes']:
    ident, spec = scene['id'], edit[scene['id']]
    bg = Image.new('RGB', (1080, 1920), CREAM)
    d = ImageDraw.Draw(bg)
    d.text((60, 34), 'DEKISUGI-KUN', font=font(26, True), fill=TEAL)
    if d.textlength(scene['title'], font=font(44, True)) > 960:
        raise ValueError('Title exceeds canvas')
    d.text((60, 82), scene['title'], font=font(44, True), fill=INK)
    if d.textlength(scene['tag'], font=font(20)) > 960:
        raise ValueError('Context label exceeds canvas')
    d.text((60, 137), scene['tag'], font=font(20), fill=TEAL)
    d.rectangle((58, 166, 1022, 1724), outline=INK, width=2)
    d.rectangle((0, 1750, 1080, 1920), fill=INK)
    if not spec.get('shots'):
        bg = Image.new('RGB', (1080, 1920), CREAM)
        d = ImageDraw.Draw(bg)
        icon = Image.open(a.script.resolve().parent.parent / 'store/icon-1024.png').convert('RGB')
        bg.paste(icon.resize((360, 360), Image.Resampling.LANCZOS), (360, 490))
        d.text((130, 940), 'Learn by teaching.', font=font(76, True), fill=INK)
        d.text((255, 1060), 'DEKISUGI-KUN', font=font(44, True), fill=TEAL)
        d.text((60, 1360), 'github.com/Haruka-Kaya/dekisugi-kun', font=font(35), fill=INK)
        d.rectangle((0, 1750, 1080, 1920), fill=INK)
    bg_path = work / (ident + '-background.png')
    bg.save(bg_path)
    segments = []
    for j, shot in enumerate(spec.get('shots', [])):
        source = a.raw / shot['file']
        still = source.suffix.lower() in ('.png', '.jpg')
        speed, duration = shot.get('speed', 1), shot['duration']
        assert duration > 0 and speed > 0
        if not still:
            probe = str(Path(a.ffmpeg).with_name('ffprobe'))
            source_duration = float(subprocess.check_output([
                probe, '-v', 'error', '-show_entries', 'format=duration',
                '-of', 'default=nw=1:nk=1', str(source),
            ]))
            if shot.get('start', 0) + duration * speed > source_duration:
                raise ValueError(f'{ident}/{j}: cut exceeds source duration')
        args = ['-loop', '1', '-framerate', '30', '-i', str(bg_path)]
        if still: args += ['-loop', '1', '-framerate', '30']
        args += ['-i', str(source)]
        # screenrecordは変化時だけフレームを保存する。入力seek→STARTPTSだと
        # 最初の変化フレームが先頭へ移り、タップ前の時間が失われる。
        # 必ず元の時間軸をCFRへ展開してからtrimする。
        start = shot.get('start', 0)
        crop_y, crop_h = shot.get('crop_y', 110), shot.get('crop_h', 1748)
        phone_h = round(crop_h * 960 / 1080 / 2) * 2
        phone_y = 168 + (1554 - phone_h) // 2
        assert 0 <= crop_y and crop_h > 0 and crop_y + crop_h <= 1920
        fc = (f'[1:v]fps=30:start_time=0,trim=start={start}:duration={duration*speed},'
              f'setpts=(PTS-STARTPTS)/{speed},fps=30,'
              f'crop=1080:{crop_h}:0:{crop_y},scale=960:{phone_h}:flags=lanczos,setsar=1[phone];'
              f'[0:v][phone]overlay=60:{phone_y}:shortest=1[v]')
        segment = work / f'{ident}-{j}.mp4'
        run([*args, '-filter_complex', fc, '-map', '[v]', '-t', str(duration), '-an',
             '-c:v', 'libx264', '-preset', 'fast', '-crf', '18', '-pix_fmt', 'yuv420p', str(segment)])
        segments.append(segment)
    duration = round((sum(s['duration'] for s in spec.get('shots', [])) or spec['duration'])*30)/30
    cues = json.loads((a.raw/'narration'/(ident+'.cues.json')).read_text())
    assert cues[-1]['end'] < duration - .04, f'{ident}: voice exceeds scene'
    voice = a.raw/'narration'/(ident+'.wav')
    target = work/(ident+'.mp4')
    args, filters = [], []
    if segments:
        for j, segment in enumerate(segments):
            args += ['-threads', '2', '-i', str(segment)]
            filters.append(f'[{j}:v]setparams=range=limited:color_primaries=bt709:color_trc=bt709:colorspace=bt709,setpts=PTS-STARTPTS[v{j}]')
        filters.append(''.join(f'[v{j}]' for j in range(len(segments))) + f'concat=n={len(segments)}:v=1:a=0,fps=30[v]')
        args += ['-i', str(voice)]
        filters.append(f'[{len(segments)}:a]apad,atrim=duration={duration},asetpts=PTS-STARTPTS[a]')
    else:
        args = ['-loop', '1', '-framerate', '30', '-i', str(bg_path), '-i', str(voice)]
        filters = ['[0:v]null[v]', f'[1:a]apad,atrim=duration={duration}[a]']
    run([*args, '-filter_complex', ';'.join(filters), '-map', '[v]', '-map', '[a]', '-t', str(duration),
         '-c:v', 'libx264', '-preset', 'fast', '-crf', '19', '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-ar', '48000', '-ac', '2', str(target)])
    files.append(target)
    manifest.append({'scene': ident, 'start': round(offset, 3), 'duration': duration, 'shots': spec.get('shots', [])})
    all_cues += [{'start':offset+c['start'], 'end':offset+c['end'], 'text':c['text']} for c in cues]
    offset += duration
    print(ident, duration, flush=True)

ass = '[Script Info]\nPlayResX: 1080\nPlayResY: 1920\nWrapStyle: 0\n\n[V4+ Styles]\nFormat: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding\nStyle: Default,Avenir Next,38,&H00FFFFFF,&H00FFFFFF,&H00393018,&H00393018,0,0,0,0,100,100,0,0,1,0,0,2,70,70,55,1\n\n[Events]\nFormat: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\n'
srt, count = '', 0
for cue in all_cues:
    words, parts = cue['text'].split(), []
    splits = math.ceil(len(cue['text'])/85)
    for left in range(splits, 1, -1):
        target = len(' '.join(words))/left
        cut = min(range(1, len(words)-left+2), key=lambda n: abs(len(' '.join(words[:n]))-target))
        parts.append(' '.join(words[:cut])); words = words[cut:]
    parts.append(' '.join(words))
    at, total = cue['start'], sum(map(len, parts))
    for part in parts:
        end = at + (cue['end']-cue['start'])*len(part)/total
        ass += f'Dialogue: 0,{timestamp(at,True)},{timestamp(end,True)},Default,,0,0,0,,{part}\n'
        count += 1
        srt += f'{count}\n{timestamp(at)} --> {timestamp(end)}\n{part}\n\n'
        at = end
(a.output/(a.name+'-captions.en.srt')).write_text(srt.rstrip()+'\n')
ass_path = work/'captions.ass'; ass_path.write_text(ass)
inputs, filters, pairs = [], [], []
for i,(file,item) in enumerate(zip(files,manifest)):
    inputs += ['-threads','2','-i',str(file)]
    dur = item['duration']
    filters += [f'[{i}:v]fps=30,setsar=1,setparams=range=limited:color_primaries=bt709:color_trc=bt709:colorspace=bt709,tpad=stop_mode=clone:stop_duration=1,trim=duration={dur},setpts=PTS-STARTPTS[v{i}]',f'[{i}:a]aresample=48000,apad,atrim=duration={dur},asetpts=PTS-STARTPTS[a{i}]']
    pairs.append(f'[v{i}][a{i}]')
filters += [''.join(pairs)+f'concat=n={len(files)}:v=1:a=1[video][speech]', f'[video]fps=30,ass={ass_path}[v]', '[speech]loudnorm=I=-16:TP=-1.5:LRA=7[a]']
final = a.output/(a.name+'.mp4')
run([*inputs,'-filter_complex',';'.join(filters),'-map','[v]','-map','[a]','-t',str(offset),'-c:v','libx264','-preset','medium','-crf','19','-pix_fmt','yuv420p','-c:a','aac','-b:a','192k','-ar','48000','-ac','2','-movflags','+faststart','-metadata','title='+script['title'],'-metadata','comment=Single native app view; CFR before trimming; editorial voice; no music; Test Store/no real charge; external AI disabled',str(final)])
sources = sorted({s['file'] for e in edit.values() for s in e.get('shots',[])})
stills = sum(s['duration'] for e in edit.values() for s in e.get('shots',[]) if Path(s['file']).suffix != '.mp4')
(a.output/(a.name.removeprefix('shipaton-demo-')+'-manifest.json')).write_text(json.dumps({'source_commit':script['source_commit'],'capture':script['capture'],'narrator':'Local Kokoro af_sarah; separate editorial voice; no music','duration':round(offset,3),'held_screenshot_seconds':stills,'end_card_seconds':edit['10-close']['duration'],'sources':{s:hashlib.sha256((a.raw/s).read_bytes()).hexdigest() for s in sources},'scenes':manifest,'sha256':hashlib.sha256(final.read_bytes()).hexdigest()},indent=2)+'\n')
run(['-ss','18','-i',str(final),'-frames:v','1',str(a.output/(a.name+'-poster.jpg'))])
print(final, offset, flush=True)
