#!/usr/bin/env bash
# Regression: the two numeric singularities of the bandwidth alpha.
#
# alpha = sin(w0) * sinh(ln2/2 * bw * w0 / sin(w0)) is 0/0 at 0 Hz, and sinh
# overflows f32 around |x| = 88. Either one used to make every coefficient NaN,
# which poisons a biquad's state for good; the engine zaps NaN to 0 at the
# master, so the symptom is a filter that is silent forever, even after the
# parameter returns to range.
#
# The renders cover both (a center that starts at exactly 0 Hz and sweeps up, a
# bw of 1e6), a closed 0 Hz band, and the ordinary path plus the two-stage
# shimmer patch. The checks are in filter_singularities_check.py.
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

export TZPL_RNG_SEED=0x5eed

OUT="$("$APP" --nogui --no-audio "${MODS[@]}" "$SCRIPTS/filter_singularities_check.x" 2>/dev/null \
       | grep -E '^(PASS|FAIL|RENDERED|FILTER)')"
echo "$OUT"
echo "$OUT" | grep -q "FILTER SINGULARITIES ALL RENDERED" || { echo "FAIL: filter renders"; exit 1; }

"$PY" "$SCRIPTS/filter_singularities_check.py" /tmp/tzpl_fs_*.wav \
    || { echo "FAIL: filter singularity regression"; exit 1; }

echo "PASS: filter singularity fixes"
