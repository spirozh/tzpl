-- Regression: the bandwidth alpha's two numeric singularities.
--
-- alpha = sin(w0) * sinh(ln(2)/2 * bw * w0 / sin(w0)) has two places where the
-- math is not representable, and both used to make every coefficient NaN,
-- which poisons a biquad's state for good: the filter stays silent even after
-- the parameter comes back into range (the engine zaps NaN to 0 at the
-- master, so the failure is indistinguishable from a dead synth).
--
--   1. 0/0 at 0 Hz: w0/sin(w0). The denominator is floored, so alpha is 0
--      there and the band closes instead.
--   2. sinh overflows f32 at |x| ~ 88: a huge bw becomes inf, then inf/inf NaN.
--      The argument is bounded at the overflow point.
--
-- The refusals to police the rest of the range are deliberate: a negative rq
-- or bw, a center past Nyquist and an extreme db are outside the design and
-- are the caller's business (they can grow or overflow; see the filters
-- reference).
--
-- Renders:
--   fromzero: fc is exactly 0 Hz for the first sample, then sweeps up. With
--             the 0/0 it stayed silent for the whole render.
--   bwhuge:   bw = 1e6. With the sinh overflow it stayed silent for the whole
--             render.
--   closed0:  a constant 0 Hz center. Quiet from a zero state.
--   normal / shimmer: the ordinary path and the two-stage narrow patch, which
--             must keep sounding.
import synthdef.*;
import common_ugens.*;
import filters.*;
import synthc.compile.*;
import std.result.*;
import audio_engine.*;

let kIn = 0.15;
fn pinkIn() S = pink(2) * kIn;

fn fromzero() S {
	let fc = phasor(0.5) * 1600.0;
	pinkIn() bpf(fc, 0.005) mul(15) outlet
}
fn bwhuge() S = pinkIn() bpf(800.0, 1e6) mul(15) outlet;
fn closed0() S = pinkIn() bpf(0.0, 0.005) mul(15) outlet;
fn normal() S = pinkIn() rlpf(1000.0, 0.707) bpf(800.0, 0.05) mul(15) outlet;
fn shimmer() S {
	let s = pink(2) * 0.4;
	let m = lfnoise3(asSignal(105.2), 2);
	s bpf(220.0 - m, 0.05) mul(15) bpf(220.005 + m, 0.05) mul(2) fadein(0.2) outlet
}

let cases = [
	("fs_fromzero", fromzero),
	("fs_bwhuge", bwhuge),
	("fs_closed0", closed0),
	("fs_normal", normal),
	("fs_shimmer", shimmer),
];

let fails = &0;
for (c : cases) {
	match (c.1 defSynthChecked(c.0) await) {
		ok(_): println("PASS " $ c.0 $ " compile");
		err(m): { fails <- *fails + 1; println("FAIL " $ c.0 $ " compile: " $ m); }
	}
}

fn renderOne(name String, path String) Void {
	let h = renderNRT(path, 2.0, fn() Void {
		safetyLimiter(false);
		play(name);
	});
	await renderDone(h);
	println("RENDERED " $ path);
}

if (*fails == 0) {
	for (c : cases) {
		renderOne(c.0, "/tmp/tzpl_" $ c.0 $ ".wav");
	}
	println("FILTER SINGULARITIES ALL RENDERED");
} else {
	println("FILTER SINGULARITIES COMPILE FAILED: " $ *fails toString);
}
