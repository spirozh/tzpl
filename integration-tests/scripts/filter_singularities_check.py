#!/usr/bin/env python3
"""Check the filter-singularity renders (see filter_singularities_check.x).

The engine zaps NaN to zero at the master, so a poisoned filter shows up as
*silence*, not as NaN in the file: the recovery cases must sound.

fromzero / bwhuge: the two singularities. Before the fix both rendered
silence for the whole file.
closed0: a 0 Hz center is a closed band; quiet, finite.
normal / shimmer: must keep sounding.

usage: filter_singularities_check.py <wav> ...
"""
import math
import struct
import sys

SOUNDING = {'fs_fromzero', 'fs_bwhuge', 'fs_normal', 'fs_shimmer'}
SILENT = 1e-4        # rms below this counts as silence
ABSURD = 1e6         # runaway detector; a filter's output should not exceed this


def readwav(path):
    b = open(path, 'rb').read()
    assert b[:4] == b'RIFF' and b[8:12] == b'WAVE', path
    i, fmt, data = 12, None, None
    while i + 8 <= len(b):
        cid = b[i:i + 4]
        sz = struct.unpack('<I', b[i + 4:i + 8])[0]
        body = b[i + 8:i + 8 + sz]
        if cid == b'fmt ':
            tag, ch, sr, _, _, bits = struct.unpack('<HHIIHH', body[:16])
            fmt = (tag, ch, sr, bits)
        elif cid == b'data':
            data = body
        i += 8 + sz + (sz & 1)
    assert fmt is not None and data is not None, path
    tag, ch, sr, bits = fmt
    assert tag == 3 and bits == 32, (path, tag, bits)
    a = struct.unpack('<%df' % (len(data) // 4), data)
    return [a[k * ch:(k + 1) * ch] for k in range(len(a) // ch)], sr


def rms(frames, lo=0, hi=None):
    seg = frames[lo:hi]
    if not seg:
        return 0.0
    total = 0.0
    n = 0
    for f in seg:
        for v in f:
            total += v * v
            n += 1
    return math.sqrt(total / n)


def peak(frames):
    return max((abs(v) for f in frames for v in f), default=0.0)


def main():
    fails = 0

    def check(label, ok, detail):
        nonlocal fails
        if ok:
            print('PASS %s (%s)' % (label, detail))
        else:
            print('FAIL %s (%s)' % (label, detail))
            fails += 1

    for path in sys.argv[1:]:
        name = path.rsplit('/tzpl_', 1)[-1].rsplit('.wav', 1)[0]
        frames, sr = readwav(path)
        finite = not any(math.isnan(v) or math.isinf(v) for f in frames for v in f)
        check(name + ': finite', finite, '%d frames' % len(frames))
        p = peak(frames)
        check(name + ': no runaway', p < ABSURD, 'peak %.2e' % p)
        half = len(frames) // 2
        late = rms(frames, half)
        if name in SOUNDING:
            check(name + ': sounds', late > SILENT, 'rms %.2e' % late)
        else:
            check(name + ': quiet', p < 0.5, 'peak %.2e' % p)
    return 1 if fails else 0


if __name__ == '__main__':
    sys.exit(main())
