#!/usr/bin/env bash
# Regression: degenerate filter parameters (the whole filters.x family).
#
# fc is clamped to 10 Hz..0.45 fs, rq and bw to >= 0, bw's sinh argument to
# +-80, db to +-120 dB and ring's ringTime to >= 0. Before the guards, a
# center frequency of 0 Hz was a 0/0 that poisoned a biquad's state for good, a
# negative rq/bw/ringTime put the poles outside the unit circle, and a huge bw
# or db overflowed the f32 coefficients to NaN.
#
# Renders a swinging-bad-parameter set (must recover), a stuck-bad set (must
# stay bounded and finite), the ordinary filter path and the two-stage shimmer
# patch. The checks are in filter_guards_check.py.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${TZPL_BUILD_DIR:-$ROOT/build}/app/tzpl_app"
SCRIPTS="$ROOT/integration-tests/scripts"
MODS=(-I "$ROOT/lang/modules" -I "$ROOT/bridge/modules")

[ -x "$APP" ] || { echo "tzpl_app not built at $APP"; exit 1; }

PY=""
for cand in python3 python3.12 python3.11; do
    if command -v "$cand" > /dev/null; then
        PY="$cand"
        break
    fi
done
[ -n "$PY" ] || { echo "FAIL: no python3 found (needed for the filter checks)"; exit 1; }

# Fixed seed so the noise renders reproduce (as run_pink_test.sh does).
export TZPL_RNG_SEED=0x5eed

OUT="$("$APP" --nogui --no-audio "${MODS[@]}" "$SCRIPTS/filter_guards_check.x" 2>/dev/null \
       | grep -E '^(PASS|FAIL|RENDERED|FILTER)')"
echo "$OUT"
echo "$OUT" | grep -q "FILTER GUARDS ALL RENDERED" || { echo "FAIL: filter guard render"; exit 1; }

"$PY" "$SCRIPTS/filter_guards_check.py" /tmp/tzpl_fg_*.wav \
    || { echo "FAIL: filter guard regression"; exit 1; }

echo "PASS: filter parameter guards"
