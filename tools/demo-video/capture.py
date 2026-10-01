#!/usr/bin/env python3
"""実画面の観測・操作・撮影。対象 serial と保存先を必ず明示する。"""
import argparse
import json
from pathlib import Path
import re
import shlex
import subprocess
import time
import xml.etree.ElementTree as ET

p = argparse.ArgumentParser()
p.add_argument('--serial', required=True)
p.add_argument('--output', required=True, type=Path)
p.add_argument('action', choices=['snapshot', 'tap', 'tap-point', 'text', 'swipe', 'back', 'record', 'stop'])
p.add_argument('value', nargs='?', default='screen')
p.add_argument('--kind', default='any', choices=['any', 'button', 'edit'])
p.add_argument('--before', help='編集欄の直後にあるボタンを配置アンカーにする')
p.add_argument('--long', action='store_true', help='観測した対象を長押しする')
a = p.parse_args()
a.output.mkdir(parents=True, exist_ok=True)
if a.action in ('snapshot', 'record') and not re.fullmatch(r'[A-Za-z0-9_-]+', a.value):
    raise SystemExit('Capture names may contain only letters, numbers, underscores, and hyphens')

def adb(*args, binary=False):
    return subprocess.check_output(['adb', '-s', a.serial, *args], text=not binary)

def snapshot(name):
    adb('shell', 'uiautomator', 'dump', '/sdcard/dekisugi-video.xml')
    xml = adb('shell', 'cat', '/sdcard/dekisugi-video.xml')
    (a.output / (name + '.xml')).write_text(xml)
    (a.output / (name + '.png')).write_bytes(adb('exec-out', 'screencap', '-p', binary=True))
    nodes = list(ET.fromstring(xml).iter('node'))
    for n in nodes:
        label = ' '.join(n.get(k, '') for k in ('text', 'content-desc', 'hint')).strip()
        if label and a.action == 'snapshot':
            print(json.dumps({k: n.get(k) for k in ('class', 'bounds', 'enabled', 'clickable')} | {'label': label}))
    return nodes

if a.action == 'snapshot':
    snapshot(a.value)
elif a.action == 'tap':
    nodes = snapshot('before-tap')
    anchor = None
    if a.before:
        for n in nodes:
            if n.get('class', '').endswith('Button') and a.before in n.get('content-desc', ''):
                anchor = int(re.findall(r'\d+', n.get('bounds', ''))[1])
    matches = []
    for n in nodes:
        label = '\n'.join(n.get(k, '') for k in ('text', 'content-desc', 'hint'))
        if a.value not in label or n.get('enabled') != 'true':
            continue
        cls = n.get('class', '')
        if a.kind == 'button' and not cls.endswith('Button'):
            continue
        if a.kind == 'edit' and not cls.endswith('EditText'):
            continue
        b = tuple(map(int, re.findall(r'\d+', n.get('bounds', ''))))
        if len(b) != 4:
            continue
        x1, y1, x2, y2 = b
        if x2 <= x1 or y2 <= y1:
            continue
        y = y2 - min(260, (y2-y1)//4) if a.kind == 'edit' else (y1+y2)//2
        if anchor is not None and a.kind == 'edit':
            y = max(y1 + 40, min(y2 - 40, anchor - 300))
        matches.append(((x2-x1)*(y2-y1), (x1+x2)//2, y))
    if not matches:
        raise SystemExit('No observed enabled target: ' + a.value)
    _, x, y = min(matches)
    if a.long:
        adb('shell', 'input', 'swipe', str(x), str(y), str(x), str(y), '1000')
    else:
        adb('shell', 'input', 'tap', str(x), str(y))
elif a.action == 'text':
    if not a.value.isascii():
        raise SystemExit('adb input text requires ASCII; use the native IME for other text')
    ime = adb('shell', 'dumpsys', 'input_method')
    if 'mInputShown=true' not in ime:
        raise SystemExit('The native keyboard is not open; input was not sent')
    adb('shell', 'input text ' + shlex.quote(a.value.replace(' ', '%s')))
elif a.action == 'swipe':
    coords = a.value.split(',')
    if len(coords) != 5 or not all(x.isdigit() for x in coords):
        raise SystemExit('swipe requires x1,y1,x2,y2,duration')
    adb('shell', 'input', 'swipe', *coords)
elif a.action == 'tap-point':
    # Semanticが親へ統合された場合だけ、直前のPNGで確認した座標を使う。
    coords = a.value.split(',')
    if len(coords) != 2 or not all(x.isdigit() for x in coords):
        raise SystemExit('tap-point requires observed x,y coordinates')
    adb('shell', 'input', 'tap', *coords)
elif a.action == 'back':
    adb('shell', 'input', 'keyevent', '4')
elif a.action == 'record':
    remote = '/sdcard/dekisugi-video-' + a.value + '.mp4'
    if subprocess.run(['adb', '-s', a.serial, 'shell', 'pidof', 'screenrecord'], capture_output=True).returncode == 0:
        raise SystemExit('Another screen recording is running')
    proc = subprocess.Popen(['adb', '-s', a.serial, 'shell', 'screenrecord', '--size', '1080x1920', '--bit-rate', '12M', '--time-limit', '180', remote], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    (a.output / 'recording.json').write_text(json.dumps({'name': a.value, 'remote': remote, 'started': time.time(), 'host_pid': proc.pid}))
elif a.action == 'stop':
    info = json.loads((a.output / 'recording.json').read_text())
    pid = subprocess.run(['adb', '-s', a.serial, 'shell', 'pidof', 'screenrecord'], capture_output=True, text=True).stdout.strip()
    if pid:
        adb('shell', 'kill', '-2', pid)
        time.sleep(1)
    adb('pull', info['remote'], str(a.output / (info['name'] + '.mp4')))
    info['ended'] = time.time()
    (a.output / (info['name'] + '.recording.json')).write_text(json.dumps(info, indent=2))

with (a.output / 'actions.jsonl').open('a') as f:
    f.write(json.dumps({'at': time.time(), 'action': a.action, 'value': a.value}) + '\n')
