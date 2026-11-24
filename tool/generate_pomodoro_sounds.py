"""Synthesises the bundled pomodoro sounds (no third-party samples, so no licence to track).

Writes 16-bit mono 44.1 kHz WAV files to assets/sounds/ and android/app/src/main/res/raw/.
Run from the repository root: python3 tool/generate_pomodoro_sounds.py
"""
import math
import os
import struct
import wave

RATE = 44100


def note(freq, start, length, amp=0.5, decay=4.0, harmonics=((1, 1.0), (2, 0.35), (3, 0.15))):
    return (freq, start, length, amp, decay, harmonics)


def render(notes, total, fade_in=0.004):
    n = int(total * RATE)
    buf = [0.0] * n
    for freq, start, length, amp, decay, harmonics in notes:
        s0 = int(start * RATE)
        for i in range(int(length * RATE)):
            idx = s0 + i
            if idx >= n:
                break
            t = i / RATE
            env = math.exp(-decay * t) * min(1.0, t / fade_in)
            v = sum(w * math.sin(2 * math.pi * freq * h * t) for h, w in harmonics)
            buf[idx] += amp * env * v
    peak = max(abs(x) for x in buf) or 1.0
    scale = 0.85 / peak
    return [x * scale for x in buf]


def write(path, samples):
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, x)) * 32767)) for x in samples))


C5, E5, G5, C6, E6, G6, A5, F5 = 523.25, 659.25, 783.99, 1046.5, 1318.5, 1568.0, 880.0, 698.46

SOUNDS = {
    'bell': (render([note(A5, 0, 1.8, decay=2.5, harmonics=((1, 1), (2.76, 0.4), (5.4, 0.2)))], 1.8)),
    'chime': render([note(C6, 0, 1.2, decay=3.5), note(E6, 0.18, 1.2, decay=3.5)], 1.4),
    'ding_dong': render([note(E5, 0, 1.0, decay=3.0), note(C5, 0.45, 1.2, decay=2.5)], 1.7),
    'marimba': render([note(G5, 0, 0.6, decay=9.0, harmonics=((1, 1), (4, 0.3))), note(C6, 0.15, 0.7, decay=8.0, harmonics=((1, 1), (4, 0.3)))], 0.9),
    'triple_beep': render([note(A5 * 2, i * 0.22, 0.14, decay=6.0, harmonics=((1, 1),)) for i in range(3)], 0.8),
    'arpeggio': render([note(f, i * 0.14, 1.0, decay=3.0) for i, f in enumerate([C5, E5, G5, C6, E6, G6])], 1.9),
    'soft_gong': render([note(F5 / 2, 0, 2.5, decay=1.6, harmonics=((1, 1), (2.4, 0.5), (3.9, 0.25), (5.2, 0.1)))], 2.5),
    'tick': render([note(2000, 0, 0.03, amp=0.4, decay=120.0, harmonics=((1, 1), (1.5, 0.5)))], 0.05, fade_in=0.0005),
}

if __name__ == '__main__':
    out_assets = os.path.join('assets', 'sounds')
    out_raw = os.path.join('android', 'app', 'src', 'main', 'res', 'raw')
    os.makedirs(out_assets, exist_ok=True)
    os.makedirs(out_raw, exist_ok=True)
    for name, samples in SOUNDS.items():
        write(os.path.join(out_assets, f'{name}.wav'), samples)
        write(os.path.join(out_raw, f'pomodoro_{name}.wav'), samples)
        print(name, f'{len(samples) / RATE:.2f}s')
