#!/usr/bin/env python3
"""Check the degenerate-filter render set (see filter_guards_check.x).

Every file must be finite (no NaN/inf) and bounded (no runaway). The "swing"
cases have a bad parameter for the first half second and a good one after, so
the last half must sound: before the parameter guards, a bad value poisoned
the biquad's state and the filter stayed silent. "stuck" cases only have to
stay bounded. The normal path and the shimmer patch must sound.

usage: filter_guards_check.py <wav> ...
"""
import math
import struct
import sys

SWING = {'fg_fromzero', 'fg_bwswing', 'fg_rqswing', 'fg_dbswing'}
SOUNDING = SWING | {'fg_normal', 'fg_shimmer'}
# The stuck cases must be finite and not grow. Their level can be loud (a +120 dB
# shelf is +1e6), so the absolute cap is only a runaway detector.
ABSURD = 1e6
GROWTH = 4.0         # last quarter vs first quarter, for the stuck cases
SILENT = 1e-4        # rms below this counts as silence


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
        p = peak(frames)
        check(name + ': finite', finite, '%d frames' % len(frames))
        check(name + ': no runaway', p < ABSURD, 'peak %.2e' % p)
        if name in SOUNDING:
            late = rms(frames, len(frames) // 2)
            check(name + ': sounds', late > SILENT, 'rms %.2e' % late)
        else:
            q = len(frames) // 4
            first, last = rms(frames, 0, q), rms(frames, len(frames) - q)
            check(name + ': not growing', last <= GROWTH * first + 1e-6,
                  'first %.2e last %.2e' % (first, last))
    return 1 if fails else 0


if __name__ == '__main__':
    sys.exit(main())
