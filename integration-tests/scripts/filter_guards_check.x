-- Regression: degenerate filter parameters must not poison or blow up a filter.
--
-- Every RBJ design in filters.x needs its parameters finite and in range:
--   * fc is clamped to 10 Hz .. 0.45 fs. Past Nyquist sin(w0) turns negative,
--     which flips alpha's sign and moves the poles outside the unit circle; at
--     0 Hz every design lands on a double pole at z = 1, and the bandwidth
--     designs divide by sin(w0) (0/0 = NaN, which poisons the biquad's state
--     for good: the filter stays silent even after fc returns to range).
--   * rq and bw are clamped to >= 0 (a negative one flips alpha's sign and the
--     filter grows), and bw's sinh argument is clamped so a huge bw cannot
--     overflow to inf/NaN.
--   * db is clamped to +-120 dB (past that the f32 products overflow to inf,
--     and inf/inf is NaN).
--   * ring's ringTime is clamped to >= 0 (a negative one makes the pole radius
--     exceed 1 and the output grows).
--
-- Two sets of renders:
--   swing: the parameter is bad for the first half second, then good
--          (fc = 0, bw = 1000, rq = -1.3, db = 1e6, at 1 Hz). The filter must
--          sound again in the second half; before the guards, the bad phase
--          left it silent forever.
--   stuck: the parameter is bad throughout. The output must stay finite and
--          bounded (no NaN, no runaway).
--   plus the normal path and the two-stage shimmer patch, which must sound.
import synthdef.*;
import common_ugens.*;
import filters.*;
import synthc.compile.*;
import std.result.*;
import audio_engine.*;

let kIn = 0.15;
fn pinkIn() S = pink(2) * kIn;

-- swings: bad for 0 <= phasor < 0.5, good after
fn fromzero() S {
	let z = phasor(1.0) < 0.5;
	let fc = (1.0 - z) * 1600.0;
	pinkIn() bpf(fc, 0.005) mul(15) outlet
}
fn bwswing() S {
	let z = phasor(1.0) < 0.5;
	let bw = z * 1000.0 + 0.02;
	pinkIn() bpf(800.0, bw) mul(15) outlet
}
fn rqswing() S {
	let z = phasor(1.0) < 0.5;
	let rq = z * -2.0 + 0.707;
	pinkIn() rlpf(800.0, rq) mul(3) outlet
}
fn dbswing() S {
	let z = phasor(1.0) < 0.5;
	let db = z * 1e6;
	pinkIn() lowShelf(800.0, db, 0.7) mul(3) outlet
}

-- stuck: the degenerate value throughout
fn bw1000() S = pinkIn() bpf(800.0, 1000.0) mul(15) outlet;
fn brfneg() S = pinkIn() brf(800.0, -0.5) mul(15) outlet;
fn apfneg() S = pinkIn() apf(800.0, -1.0) mul(15) outlet;
fn lpf0() S = pinkIn() lpf(0.0) mul(15) outlet;
fn rlpfneg() S = pinkIn() rlpf(-100.0, -0.5) mul(15) outlet;
fn shelfdb() S = pinkIn() lowShelf(800.0, scalar(1000.0), 0.7) mul(3) outlet;
fn peqdb() S = pinkIn() peakEQ(800.0, scalar(2400.0), 0.5) mul(3) outlet;
fn ringneg() S = pinkIn() ring(800.0, -1.0) mul(15) outlet;
fn pling0() S = pinkIn() pling(800.0, 0.0, -1.0) mul(15) outlet;

-- the ordinary path, and the two-stage narrow patch from the bug report
fn normal() S = pinkIn() rlpf(1000.0, 0.707) bpf(800.0, 0.05) mul(15) outlet;
fn shimmer() S {
	let s = pink(2) * 0.4;
	let m = lfnoise3(asSignal(105.2), 2);
	s bpf(220.0 - m, 0.05) mul(15) bpf(220.005 + m, 0.05) mul(2) fadein(0.2) outlet
}

let cases = [
	("fg_fromzero", fromzero),
	("fg_bwswing", bwswing),
	("fg_rqswing", rqswing),
	("fg_dbswing", dbswing),
	("fg_bw1000", bw1000),
	("fg_brfneg", brfneg),
	("fg_apfneg", apfneg),
	("fg_lpf0", lpf0),
	("fg_rlpfneg", rlpfneg),
	("fg_shelfdb", shelfdb),
	("fg_peqdb", peqdb),
	("fg_ringneg", ringneg),
	("fg_pling0", pling0),
	("fg_normal", normal),
	("fg_shimmer", shimmer),
];

let fails = &0;
for (c : cases) {
	match (c.1 defSynthChecked(c.0) await) {
		ok(_): println("PASS " $ c.0 $ " compile");
		err(m): { fails <- *fails + 1; println("FAIL " $ c.0 $ " compile: " $ m); }
	}
}

fn renderOne(name String, path String) Void {
	let h = renderNRT(path, 1.5, fn() Void {
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
	println("FILTER GUARDS ALL RENDERED");

-- The limits are a switch, on by default: with them off the cookbook formulas
-- are emitted verbatim (no clamp nodes), so a patch can opt out.
fn switchProbe() S = (pink(2) * 0.15) lowShelf(800.0, scalar(6.0), 0.7) outlet;
filterLimits(true);
let cppOn = compileToCpp(makeGraph(switchProbe), "SwOn");
filterLimits(false);
let cppOff = compileToCpp(makeGraph(switchProbe), "SwOff");
filterLimits(true);
if (cppOn != cppOff) { println("PASS filterLimits switch changes the graph"); }
else { println("FAIL filterLimits switch changes the graph"); }
if (cppOff length < cppOn length) { println("PASS filterLimits off emits the raw formula"); }
else { println("FAIL filterLimits off emits the raw formula"); }
} else {
	println("FILTER GUARDS COMPILE FAILED: " $ *fails toString);
}
