(
// ============================================================
// GRANULAR APP V2.1
// - safer architecture
// - per-note MIDI voices with note-on / note-off
// - dual granulators + osc layer
// - waveform region selection
// - XY pad
// - live input recording
// - page buttons
// - preset save/load
// ============================================================

s.options.memSize = 2.pow(20);
s.options.numWireBufs = 1024;

s.waitForBoot({

	// --------------------------------------------------------
	// cleanup previous instance
	// --------------------------------------------------------
	if(~granV21.notNil) {
		try { ~granV21[\free].value } { };
	};

	~granV21 = IdentityDictionary.new;

	// --------------------------------------------------------
	// state
	// --------------------------------------------------------
	~granV21[\buf] = nil;
	~granV21[\sampleBuf] = nil;
	~granV21[\liveBuf] = nil;
	~granV21[\recSynth] = nil;
	~granV21[\waveData] = FloatArray.newClear(0);
	~granV21[\samplePath] = "No sample loaded";
	~granV21[\voices] = IdentityDictionary.new;   // midi note -> Synth
	~granV21[\midiObjs] = List.new;
	~granV21[\pages] = List.new;
	~granV21[\tabButtons] = List.new;
	~granV21[\sliders] = IdentityDictionary.new;
	~granV21[\boxes] = IdentityDictionary.new;
	~granV21[\toggles] = IdentityDictionary.new;
	~granV21[\menus] = IdentityDictionary.new;
		~granV21[\modUi] = (
		lfoIndex: 1
	);
	~granV21[\recordSeconds] = 8.0;
	~granV21[\dragMode] = \none;
	~granV21[\dragTarget] = \none;
	~granV21[\dragScrollStart] = 0.0;
~granV21[\dragScrollOrigin] = 0.0;
	~granV21[\miniDrag] = false;
~granV21[\miniDragOffset] = 0.0;
~granV21[\playheadHitRadius] = 50;   // pixels
	~granV21[\isRecording] = false;
	~granV21[\isPreviewing] = false;
	~granV21[\previewNote] = 60;
~granV21[\grainDotsA] = List.new;
~granV21[\grainDotsB] = List.new;
~granV21[\visTime] = 0.0;
~granV21[\visRunning] = false;

	~granV21[\view] = (
	zoom: 1.0,       // 1 = full waveform
	scroll: 0.0,     // 0..1 scroll through zoomed view
	editMode: \region,
	loopStart: 0.0,
	loopEnd: 1.0
);

	~granV21[\params] = (
		masterAmp: 0.35,
		rootMidi: 60,
		glide: 0.03,

		regionStart: 0.0,
		regionEnd: 1.0,
		aPosition: 0.5,
		bPosition: 0.5,

		aOn: 1,
		aAmp: 0.9,
		aDensity: 18.0,
		aDur: 0.11,
		aJitter: 0.04,
		aRateMul: 1.0,
		aRateRand: 0.05,
		aScanRate: 0.08,
		aScanWidth: 0.08,
		aScanMode: 0,
		aPanWidth: 0.55,

		bOn: 1,
		bAmp: 0.65,
		bDensity: 8.0,
		bDur: 0.20,
		bJitter: 0.08,
		bRateMul: 0.5,
		bRateRand: 0.04,
		bScanRate: 0.03,
		bScanWidth: 0.15,
		bScanMode: 0,
		bPanWidth: 0.8,

		oscOn: 0,
		oscAmp: 0.18,
		oscWave: 0,
		oscDetune: 0.0,
		oscCutoff: 8000,
		oscRes: 0.15,

		filter1Type: 1,
		filter1Cutoff: 12000,
		filter1Res: 0.15,

		filter2Type: 0,
		filter2Cutoff: 8000,
		filter2Res: 0.15,

		filterRouting: 0,

		delayOn: 1,
		delayTime: 0.28,
		delayFb: 0.30,
		delayMix: 0.20,

		reverbOn: 1,
		reverbMix: 0.18,
		reverbRoom: 0.75,
		reverbDamp: 0.35,

		lfo1On: 0,
		lfo1Rate: 0.35,
		lfo1Depth: 0.25,
		lfo1Shape: 0,
		lfo1Dest1: 0,
		lfo1Amt1: 0.0,
		lfo1Dest2: 1,
		lfo1Amt2: 0.0,
		lfo1Dest3: 2,
		lfo1Amt3: 0.0,
		lfo1Dest4: 4,
		lfo1Amt4: 0.0,

		lfo2On: 0,
		lfo2Rate: 0.18,
		lfo2Depth: 0.25,
		lfo2Shape: 0,
		lfo2Dest1: 0,
		lfo2Amt1: 0.0,
		lfo2Dest2: 1,
		lfo2Amt2: 0.0,
		lfo2Dest3: 2,
		lfo2Amt3: 0.0,
		lfo2Dest4: 4,
		lfo2Amt4: 0.0,

		modEnv1Atk: 0.01,
		modEnv1Dec: 0.22,
		modEnv1Sus: 0.0,
		modEnv1Rel: 0.30,
		modEnv1Depth: 0.35,
		modEnv1Dest1: 0,
		modEnv1Amt1: 0.0,
		modEnv1Dest2: 1,
		modEnv1Amt2: 0.0,
		modEnv1Dest3: 2,
		modEnv1Amt3: 0.0,
		modEnv1Dest4: 4,
		modEnv1Amt4: 0.0,

		hpf: 20,
		lpf: 18000,

		atk: 0.01,
		rel: 0.35,

		xyX: 0.5,
		xyY: 0.5,
		xyXTarget: \position,
		xyYTarget: \aJitter
	);

	// --------------------------------------------------------
	// synthdefs
	// --------------------------------------------------------
	SynthDef(\granVoiceV21, {
		|out=0, bufnum=0, gate=1,
		masterAmp=0.35, pitchRatio=1.0, glide=0.03,
		regionStart=0.0, regionEnd=1.0, loopStart=0.0, loopEnd=1.0, position=0.5, aPosition=0.5, bPosition=0.5,

		aOn=1, aAmp=0.9, aDensity=18, aDur=0.11, aJitter=0.04, aRateMul=1.0, aRateRand=0.05, aScanRate=0.08, aScanWidth=0.08, aScanMode=0, aPanWidth=0.55,
		bOn=1, bAmp=0.65, bDensity=8, bDur=0.20, bJitter=0.08, bRateMul=0.5, bRateRand=0.04, bScanRate=0.03, bScanWidth=0.15, bScanMode=0, bPanWidth=0.8,

				oscOn=0, oscAmp=0.18, oscWave=0, oscDetune=0.0, oscCutoff=8000, oscRes=0.15,

		filter1Type=1, filter1Cutoff=12000, filter1Res=0.15,
		filter2Type=0, filter2Cutoff=8000, filter2Res=0.15,
		filterRouting=0,

		delayOn=1, delayTime=0.28, delayFb=0.30, delayMix=0.20,
		reverbOn=1, reverbMix=0.18, reverbRoom=0.75, reverbDamp=0.35,

		lfo1On=0, lfo1Rate=0.35, lfo1Depth=0.25, lfo1Shape=0,
		lfo1Dest1=0, lfo1Amt1=0.0,
		lfo1Dest2=1, lfo1Amt2=0.0,
		lfo1Dest3=2, lfo1Amt3=0.0,
		lfo1Dest4=4, lfo1Amt4=0.0,

		lfo2On=0, lfo2Rate=0.18, lfo2Depth=0.25, lfo2Shape=0,
		lfo2Dest1=0, lfo2Amt1=0.0,
		lfo2Dest2=1, lfo2Amt2=0.0,
		lfo2Dest3=2, lfo2Amt3=0.0,
		lfo2Dest4=4, lfo2Amt4=0.0,

		modEnv1Atk=0.01, modEnv1Dec=0.22, modEnv1Sus=0.0, modEnv1Rel=0.30, modEnv1Depth=0.35,
		modEnv1Dest1=0, modEnv1Amt1=0.0,
		modEnv1Dest2=1, modEnv1Amt2=0.0,
		modEnv1Dest3=2, modEnv1Amt3=0.0,
		modEnv1Dest4=4, modEnv1Amt4=0.0,

		hpf=20, lpf=18000, atk=0.01, rel=0.35|

var env, bufDur;
var regStartSec, regEndSec, regLen;
var loopStartNorm, loopEndNorm, loopStartSec, loopEndSec, loopLen;
var aBasePosNorm, bBasePosNorm;
var trigA, trigB, posA, posB, rateA, rateB, panA, panB, sigA, sigB;
var freq, osc, sig, rawSig, filt1Sig, filt2Sig, seriesSig, parallelSig, delaySig, wetDelaySig, revSig, scanA, scanB, ratioLag;
var aCenterPos, bCenterPos, aForwardPos, bForwardPos, aPingPongPos, bPingPongPos;
var filt1RQ, filt2RQ, applyFilter;
var lfo1, lfo2, lfoShapeSel, lfo2ShapeSel, destApply;
var modEnv1, destApplyEnv;

var modAPos, modBPos, modF1Cutoff, modF2Cutoff, modDelayMix;
var modADensity, modBDensity, modAScanWidth, modBScanWidth, modOscCutoff, modMasterAmp;

var modEnvAPos, modEnvBPos, modEnvF1Cutoff, modEnvF2Cutoff, modEnvDelayMix;
var modEnvADensity, modEnvBDensity, modEnvAScanWidth, modEnvBScanWidth, modEnvOscCutoff, modEnvMasterAmp;

var aDensityMod, bDensityMod, aScanWidthMod, bScanWidthMod, oscCutoffMod, masterAmpMod;


bufDur = BufDur.kr(bufnum).max(0.001);

regStartSec = regionStart.clip(0, 1) * bufDur;
regEndSec = regionEnd.clip(0, 1) * bufDur;
regEndSec = max(regEndSec, regStartSec + 0.001);
regLen = (regEndSec - regStartSec).max(0.001);

// loop lives inside region
loopStartNorm = loopStart.clip(regionStart.clip(0, 1), regionEnd.clip(0, 1) - 0.001);
loopEndNorm = loopEnd.clip(loopStartNorm + 0.001, regionEnd.clip(0, 1));

loopStartSec = loopStartNorm * bufDur;
loopEndSec = loopEndNorm * bufDur;
loopLen = (loopEndSec - loopStartSec).max(0.001);

ratioLag = Lag.kr(pitchRatio, glide.max(0.001));



filt1RQ = (1.0 - filter1Res.clip(0, 0.98)).max(0.02);
filt2RQ = (1.0 - filter2Res.clip(0, 0.98)).max(0.02);

applyFilter = { |inSig, type, cutoff, rq|
	SelectX.ar(type.clip(0, 3), [
		inSig,
		RLPF.ar(inSig, cutoff.clip(20, 20000), rq),
		RHPF.ar(inSig, cutoff.clip(20, 20000), rq),
		BPF.ar(inSig, cutoff.clip(20, 20000), rq)
	])
};

						lfoShapeSel = Select.kr(lfo1Shape.clip(0, 3), [
	SinOsc.kr(lfo1Rate.max(0.001)),
	LFTri.kr(lfo1Rate.max(0.001)),
	LFSaw.kr(lfo1Rate.max(0.001)),
	LFPulse.kr(lfo1Rate.max(0.001), 0, 0.5).linlin(0, 1, -1, 1)
]);

lfo1 = lfoShapeSel * lfo1Depth.clip(0, 1) * lfo1On.clip(0, 1);

lfo2ShapeSel = Select.kr(lfo2Shape.clip(0, 3), [
	SinOsc.kr(lfo2Rate.max(0.001)),
	LFTri.kr(lfo2Rate.max(0.001)),
	LFSaw.kr(lfo2Rate.max(0.001)),
	LFPulse.kr(lfo2Rate.max(0.001), 0, 0.5).linlin(0, 1, -1, 1)
]);

lfo2 = lfo2ShapeSel * lfo2Depth.clip(0, 1) * lfo2On.clip(0, 1);

modEnv1 = EnvGen.kr(
	Env.adsr(
		modEnv1Atk.max(0.001),
		modEnv1Dec.max(0.001),
		modEnv1Sus.clip(0, 1),
		modEnv1Rel.max(0.001)
	),
	gate
) * modEnv1Depth.clip(0, 1);

modAPos = 0.0;
modBPos = 0.0;
modF1Cutoff = 0.0;
modF2Cutoff = 0.0;
modDelayMix = 0.0;
modADensity = 0.0;
modBDensity = 0.0;
modAScanWidth = 0.0;
modBScanWidth = 0.0;
modOscCutoff = 0.0;
modMasterAmp = 0.0;

modEnvAPos = 0.0;
modEnvBPos = 0.0;
modEnvF1Cutoff = 0.0;
modEnvF2Cutoff = 0.0;
modEnvDelayMix = 0.0;
modEnvADensity = 0.0;
modEnvBDensity = 0.0;
modEnvAScanWidth = 0.0;
modEnvBScanWidth = 0.0;
modEnvOscCutoff = 0.0;
modEnvMasterAmp = 0.0;

destApply = { |src, dest, amt|
	var val = src * amt.clip(-1, 1);

	if(dest == 0)  { modAPos = modAPos + val };
	if(dest == 1)  { modBPos = modBPos + val };
	if(dest == 2)  { modF1Cutoff = modF1Cutoff + val };
	if(dest == 3)  { modF2Cutoff = modF2Cutoff + val };
	if(dest == 4)  { modDelayMix = modDelayMix + val };
	if(dest == 5)  { modADensity = modADensity + val };
	if(dest == 6)  { modBDensity = modBDensity + val };
	if(dest == 7)  { modAScanWidth = modAScanWidth + val };
	if(dest == 8)  { modBScanWidth = modBScanWidth + val };
	if(dest == 9)  { modOscCutoff = modOscCutoff + val };
	if(dest == 10) { modMasterAmp = modMasterAmp + val };
};

destApplyEnv = { |dest, amt|
	var val = modEnv1 * amt.clip(-1, 1);

	if(dest == 0)  { modEnvAPos = modEnvAPos + val };
	if(dest == 1)  { modEnvBPos = modEnvBPos + val };
	if(dest == 2)  { modEnvF1Cutoff = modEnvF1Cutoff + val };
	if(dest == 3)  { modEnvF2Cutoff = modEnvF2Cutoff + val };
	if(dest == 4)  { modEnvDelayMix = modEnvDelayMix + val };
	if(dest == 5)  { modEnvADensity = modEnvADensity + val };
	if(dest == 6)  { modEnvBDensity = modEnvBDensity + val };
	if(dest == 7)  { modEnvAScanWidth = modEnvAScanWidth + val };
	if(dest == 8)  { modEnvBScanWidth = modEnvBScanWidth + val };
	if(dest == 9)  { modEnvOscCutoff = modEnvOscCutoff + val };
	if(dest == 10) { modEnvMasterAmp = modEnvMasterAmp + val };
};

destApply.value(lfo1, lfo1Dest1, lfo1Amt1);
destApply.value(lfo1, lfo1Dest2, lfo1Amt2);
destApply.value(lfo1, lfo1Dest3, lfo1Amt3);
destApply.value(lfo1, lfo1Dest4, lfo1Amt4);

destApply.value(lfo2, lfo2Dest1, lfo2Amt1);
destApply.value(lfo2, lfo2Dest2, lfo2Amt2);
destApply.value(lfo2, lfo2Dest3, lfo2Amt3);
destApply.value(lfo2, lfo2Dest4, lfo2Amt4);

destApplyEnv.value(modEnv1Dest1, modEnv1Amt1);
destApplyEnv.value(modEnv1Dest2, modEnv1Amt2);
destApplyEnv.value(modEnv1Dest3, modEnv1Amt3);
destApplyEnv.value(modEnv1Dest4, modEnv1Amt4);

aBasePosNorm = (aPosition + modAPos + modEnvAPos).clip(0, 1);
bBasePosNorm = (bPosition + modBPos + modEnvBPos).clip(0, 1);

aDensityMod = (aDensity * (modADensity + modEnvADensity).linexp(-1, 1, 0.25, 4.0)).clip(0.1, 120);
bDensityMod = (bDensity * (modBDensity + modEnvBDensity).linexp(-1, 1, 0.25, 4.0)).clip(0.1, 120);

aScanWidthMod = (aScanWidth + ((modAScanWidth + modEnvAScanWidth) * 0.5)).clip(0, 1);
bScanWidthMod = (bScanWidth + ((modBScanWidth + modEnvBScanWidth) * 0.5)).clip(0, 1);

oscCutoffMod = (
	oscCutoff * (modOscCutoff + modEnvOscCutoff).clip(-1, 1).linexp(-1, 1, 0.25, 4.0)
).clip(80, 18000);

masterAmpMod = (
	masterAmp * (modMasterAmp + modEnvMasterAmp).clip(-1, 1).linexp(-1, 1, 0.25, 4.0)
).clip(0, 1);



		// ---------------- Gran A ----------------
	trigA = Dust.kr(aDensityMod.max(0.1));

// mode 0 = Center
// mode 1 = Forward
// mode 2 = PingPong
scanA = SinOsc.kr(aScanRate.max(0.001), 0, aScanWidthMod.clip(0, 1));
aCenterPos = (aBasePosNorm + scanA).clip(0, 1);
aForwardPos = Wrap.kr(
		aBasePosNorm + ((LFSaw.kr(aScanRate.max(0.001), 1) * 0.5) + 0.5) * aScanWidthMod.clip(0, 1),
	0, 1
);
aForwardPos = aForwardPos.clip(0, 1);

aPingPongPos = (
	aBasePosNorm
		+ (LFTri.kr(aScanRate.max(0.001), 0) * aScanWidthMod.clip(0, 1))
).clip(0, 1);

posA = Select.kr(aScanMode.clip(0, 2), [
	aCenterPos,
	aForwardPos,
	aPingPongPos
]);

posA = (posA + TRand.kr(0 - aJitter.clip(0,1), aJitter.clip(0,1), trigA)).clip(0, 1);

rateA = (ratioLag * aRateMul) + TRand.kr(0 - aRateRand, aRateRand, trigA);
panA = TRand.kr(0 - aPanWidth.clip(0,1), aPanWidth.clip(0,1), trigA);

		sigA = GrainBuf.ar(
			numChannels: 2,
			trigger: trigA,
			dur: aDur.max(0.005),
			sndbuf: bufnum,
			rate: rateA,
			pos: ((loopStartSec + (posA * loopLen)) / bufDur).clip(0, 1),
			interp: 4,
			pan: panA
		) * aAmp * aOn;

		// ---------------- Gran B ----------------
trigB = Dust.kr(bDensityMod.max(0.1));

// mode 0 = Center
// mode 1 = Forward
// mode 2 = PingPong
scanB = SinOsc.kr(bScanRate.max(0.001), 0, bScanWidthMod.clip(0, 1));
bCenterPos = (bBasePosNorm + scanB).clip(0, 1);
bForwardPos = Wrap.kr(
		bBasePosNorm + ((LFSaw.kr(bScanRate.max(0.001), 1) * 0.5) + 0.5) * bScanWidthMod.clip(0, 1),
	0, 1
);
bForwardPos = bForwardPos.clip(0, 1);

bPingPongPos = (
	bBasePosNorm
		+ (LFTri.kr(bScanRate.max(0.001), 0) * bScanWidthMod.clip(0, 1))
).clip(0, 1);

posB = Select.kr(bScanMode.clip(0, 2), [
	bCenterPos,
	bForwardPos,
	bPingPongPos
]);

posB = (posB + TRand.kr(0 - bJitter.clip(0,1), bJitter.clip(0,1), trigB)).clip(0, 1);

rateB = (ratioLag * bRateMul) + TRand.kr(0 - bRateRand, bRateRand, trigB);
panB = TRand.kr(0 - bPanWidth.clip(0,1), bPanWidth.clip(0,1), trigB);

		sigB = GrainBuf.ar(
			numChannels: 2,
			trigger: trigB,
			dur: bDur.max(0.005),
			sndbuf: bufnum,
			rate: rateB,
			pos: ((loopStartSec + (posB * loopLen)) / bufDur).clip(0, 1),
			interp: 4,
			pan: panB
		) * bAmp * bOn;

		// ---------------- Osc Layer ----------------
		freq = (60.midicps * ratioLag) * (2 ** (oscDetune / 12));

		osc = Select.ar(oscWave.clip(0, 3), [
			SinOsc.ar(freq),
			Saw.ar(freq),
			Pulse.ar(freq, 0.45),
			LFTri.ar(freq)
		]);

		osc = RLPF.ar(
			osc ! 2,
			oscCutoffMod.clip(80, 18000),
			(1 - oscRes.clip(0, 0.98)).max(0.02)
		) * oscAmp * oscOn;

		rawSig = sigA + sigB + osc;

		filt1Sig = applyFilter.value(
			rawSig,
			filter1Type,
			(
				filter1Cutoff
				* (modF1Cutoff + modEnvF1Cutoff).clip(-1, 1).linexp(-1, 1, 0.25, 4.0)
			).clip(20, 20000),
			filt1RQ
		);


				filt2Sig = applyFilter.value(
			rawSig,
			filter2Type,
			(
				filter2Cutoff
				* (modF2Cutoff + modEnvF2Cutoff).clip(-1, 1).linexp(-1, 1, 0.25, 4.0)
			).clip(20, 20000),
			filt2RQ
		);

				seriesSig = applyFilter.value(
			filt1Sig,
			filter2Type,
			(
				filter2Cutoff
				* (modF2Cutoff + modEnvF2Cutoff).clip(-1, 1).linexp(-1, 1, 0.25, 4.0)
			).clip(20, 20000),
			filt2RQ
		);

		parallelSig = (filt1Sig + filt2Sig) * 0.5;

			sig = SelectX.ar(filterRouting.clip(0, 1), [
			seriesSig,
			parallelSig
		]);

		// ---------------- Delay ----------------
		delaySig = CombC.ar(
			sig,
			1.5,
			delayTime.clip(0.01, 1.5),
			(delayFb.clip(0.001, 0.95) * 6.0).clip(0.001, 6.0)
		);

		wetDelaySig = (sig * 0.7) + (delaySig * 0.7);

			sig = SelectX.ar(
			(
				(delayMix + ((modDelayMix + modEnvDelayMix) * 0.5)).clip(0, 1)
				* delayOn.clip(0, 1)
			),
			[
				sig,
				wetDelaySig
			]
		);

		// ---------------- Reverb ----------------
		revSig = FreeVerb2.ar(
			sig[0],
			sig[1],
			reverbMix.clip(0, 1) * reverbOn.clip(0, 1),
			reverbRoom.clip(0, 1),
			reverbDamp.clip(0, 1)
		);

		sig = revSig;

		env = EnvGen.kr(
			Env.asr(atk.max(0.001), 1.0, rel.max(0.001)),
			gate,
			doneAction: 2
		);

		Out.ar(out, sig * masterAmpMod * env);
	}).add;

	SynthDef(\granInputRecorderV21, { |bufnum=0, in=0, recLevel=1.0, preLevel=0.0, run=1, loop=0|
		var sig;
		sig = SoundIn.ar(in);
		RecordBuf.ar(sig, bufnum, offset: 0, recLevel: recLevel, preLevel: preLevel, run: run, loop: loop, doneAction: 2);
	}).add;

	s.sync;

	// --------------------------------------------------------
	// helpers
	// --------------------------------------------------------
	~granV21[\voiceArgs] = { |note|
		var p = ~granV21[\params];
		var ratio = (note - p[\rootMidi]).midiratio;

		[
			\bufnum, (~granV21[\buf] ? 0),
			\masterAmp, p[\masterAmp],
			\pitchRatio, ratio,
			\glide, p[\glide],

			\regionStart, p[\regionStart],
\regionEnd, p[\regionEnd],
\loopStart, (~granV21[\view][\loopStart] ? 0.0),
\loopEnd, (~granV21[\view][\loopEnd] ? 1.0),
\aPosition, p[\aPosition],
\bPosition, p[\bPosition],

			\aOn, p[\aOn], \aAmp, p[\aAmp], \aDensity, p[\aDensity], \aDur, p[\aDur],
			\aJitter, p[\aJitter], \aRateMul, p[\aRateMul], \aRateRand, p[\aRateRand],
\aScanRate, p[\aScanRate], \aScanWidth, p[\aScanWidth], \aScanMode, p[\aScanMode], \aPanWidth, p[\aPanWidth],

			\bOn, p[\bOn], \bAmp, p[\bAmp], \bDensity, p[\bDensity], \bDur, p[\bDur],
			\bJitter, p[\bJitter], \bRateMul, p[\bRateMul], \bRateRand, p[\bRateRand],
\bScanRate, p[\bScanRate], \bScanWidth, p[\bScanWidth], \bScanMode, p[\bScanMode], \bPanWidth, p[\bPanWidth],

			\oscOn, p[\oscOn], \oscAmp, p[\oscAmp], \oscWave, p[\oscWave],
			\oscDetune, p[\oscDetune], \oscCutoff, p[\oscCutoff], \oscRes, p[\oscRes],

			\filter1Type, p[\filter1Type],
			\filter1Cutoff, p[\filter1Cutoff],
			\filter1Res, p[\filter1Res],

			\filter2Type, p[\filter2Type],
			\filter2Cutoff, p[\filter2Cutoff],
			\filter2Res, p[\filter2Res],

			\filterRouting, p[\filterRouting],

			\delayOn, p[\delayOn],
			\delayMix, p[\delayMix],
			\delayTime, p[\delayTime],
			\delayFb, p[\delayFb],

			\reverbOn, p[\reverbOn],
			\reverbMix, p[\reverbMix],
			\reverbRoom, p[\reverbRoom],
			\reverbDamp, p[\reverbDamp],

			\lfo1On, p[\lfo1On],
			\lfo1Rate, p[\lfo1Rate],
			\lfo1Depth, p[\lfo1Depth],
			\lfo1Shape, p[\lfo1Shape],

			\lfo1Dest1, p[\lfo1Dest1],
			\lfo1Amt1, p[\lfo1Amt1],
			\lfo1Dest2, p[\lfo1Dest2],
			\lfo1Amt2, p[\lfo1Amt2],
			\lfo1Dest3, p[\lfo1Dest3],
			\lfo1Amt3, p[\lfo1Amt3],
			\lfo1Dest4, p[\lfo1Dest4],
			\lfo1Amt4, p[\lfo1Amt4],

			\lfo2On, p[\lfo2On],
			\lfo2Rate, p[\lfo2Rate],
			\lfo2Depth, p[\lfo2Depth],
			\lfo2Shape, p[\lfo2Shape],

			\lfo2Dest1, p[\lfo2Dest1],
			\lfo2Amt1, p[\lfo2Amt1],
			\lfo2Dest2, p[\lfo2Dest2],
			\lfo2Amt2, p[\lfo2Amt2],
			\lfo2Dest3, p[\lfo2Dest3],
			\lfo2Amt3, p[\lfo2Amt3],
			\lfo2Dest4, p[\lfo2Dest4],
			\lfo2Amt4, p[\lfo2Amt4],

			\modEnv1Atk, p[\modEnv1Atk],
			\modEnv1Dec, p[\modEnv1Dec],
			\modEnv1Sus, p[\modEnv1Sus],
			\modEnv1Rel, p[\modEnv1Rel],
			\modEnv1Depth, p[\modEnv1Depth],

			\modEnv1Dest1, p[\modEnv1Dest1],
			\modEnv1Amt1, p[\modEnv1Amt1],
			\modEnv1Dest2, p[\modEnv1Dest2],
			\modEnv1Amt2, p[\modEnv1Amt2],
			\modEnv1Dest3, p[\modEnv1Dest3],
			\modEnv1Amt3, p[\modEnv1Amt3],
			\modEnv1Dest4, p[\modEnv1Dest4],
			\modEnv1Amt4, p[\modEnv1Amt4],


			\hpf, p[\hpf], \lpf, p[\lpf], \atk, p[\atk], \rel, p[\rel]
		]
	};

	~granV21[\updateAllVoices] = {
		~granV21[\voices].keysValuesDo { |note, sy|
			if(sy.notNil) {
				sy.set(*~granV21[\voiceArgs].value(note));
			};
		};

		if(~granV21[\waveView].notNil) { ~granV21[\waveView].refresh };
if(~granV21[\miniView].notNil) { ~granV21[\miniView].refresh };
if(~granV21[\xyView].notNil) { ~granV21[\xyView].refresh };
	};

	~granV21[\noteOn] = { |note, vel=100|
		var sy;

		if(~granV21[\buf].isNil) {
			"No sample or live buffer loaded.".warn;
			^nil;
		};

		if(~granV21[\voices][note].notNil) {
			try { ~granV21[\voices][note].set(\gate, 0) } { };
			~granV21[\voices].removeAt(note);
		};

		sy = Synth(\granVoiceV21, ~granV21[\voiceArgs].value(note));
		~granV21[\voices][note] = sy;
	};

	~granV21[\noteOff] = { |note|
		var sy = ~granV21[\voices][note];
		if(sy.notNil) {
			try { sy.set(\gate, 0) } { };
			~granV21[\voices].removeAt(note);
		};
	};

	~granV21[\panic] = {
		~granV21[\voices].keysValuesDo { |note, sy|
			try { sy.set(\gate, 0) } { };
		};
		~granV21[\voices].clear;
	};

	~granV21[\allocLiveBuf] = {
		var frames = (s.sampleRate * ~granV21[\recordSeconds]).asInteger.max(44100);
		if(~granV21[\liveBuf].notNil) {
			try { ~granV21[\liveBuf].free } { };
		};
		~granV21[\liveBuf] = Buffer.alloc(s, frames, 1);
	};



~granV21[\setCurrentBuffer] = { |buf, label|
	if(buf.isNil) {
		"setCurrentBuffer got nil buffer.".warn;
		^nil;
	};

	// stop anything currently sounding before swapping buffers
	~granV21[\panic].value;
	~granV21[\isPreviewing] = false;

	~granV21[\buf] = buf;
	~granV21[\sampleBuf] = buf;
	~granV21[\samplePath] = label ? "Untitled";
	~granV21[\params][\regionStart] = 0.0;
~granV21[\params][\regionEnd] = 1.0;
~granV21[\params][\aPosition] = 0.5;
~granV21[\params][\bPosition] = 0.5;

		~granV21[\view][\loopStart] = 0.0;
		~granV21[\view][\loopEnd] = 1.0;

	~granV21[\grainDotsA].clear;
	~granV21[\grainDotsB].clear;

	{
		if(~granV21[\pathLabel].notNil) {
			~granV21[\pathLabel].string_(~granV21[\samplePath]);
			~granV21[\pathLabel].refresh;
		};

		if(~granV21[\playButton].notNil) {
			~granV21[\playButton].value_(0);
			~granV21[\playButton].refresh;
		};

		~granV21[\refreshWaveData].value;
		~granV21[\updateAllVoices].value;

		if(~granV21[\waveView].notNil) { ~granV21[\waveView].refresh };
if(~granV21[\miniView].notNil) { ~granV21[\miniView].refresh };
if(~granV21[\win].notNil) { ~granV21[\win].refresh };
	}.defer;
};



~granV21[\refreshWaveData] = {
	var b = ~granV21[\buf];

	if(b.isNil) {
		~granV21[\waveData] = FloatArray.newClear(0);
		{
			if(~granV21[\waveView].notNil) {
	~granV21[\waveView].refresh;
};
if(~granV21[\miniView].notNil) {
	~granV21[\miniView].refresh;
};
		}.defer;
		^nil;
	};

	b.loadToFloatArray(action: { |arr|
		var targetSize, step, reduced, maxPeak;

		targetSize = 2200;

		if(arr.notNil and: { arr.size > 0 }) {
			step = (arr.size / targetSize).max(1).asInteger;
			reduced = FloatArray.newClear((arr.size / step).ceil.asInteger);

			reduced.size.do { |i|
				var startIdx = i * step;
				var endIdx = (startIdx + step - 1).clip(startIdx, arr.size - 1);
				var peak = 0.0;

				startIdx.to(endIdx).do { |j|
					var v = arr[j].abs;
					if(v > peak) { peak = v };
				};

				reduced[i] = peak;
			};

			maxPeak = reduced.maxItem ? 0.0;

			if(maxPeak > 0.000001) {
				reduced = reduced.collect { |v| (v / maxPeak).clip(0, 1) };
			};

			~granV21[\waveData] = reduced;
			("Waveform loaded: " ++ reduced.size ++ " points | maxPeak=" ++ maxPeak).postln;
		} {
			~granV21[\waveData] = FloatArray.newClear(0);
		};

		{
			if(~granV21[\waveView].notNil) {
				~granV21[\waveView].refresh;
			};
		}.defer;
	});
};





~granV21[\loadSample] = {
	Dialog.openPanel({ |path|
		if(path.isNil) {
			"Load cancelled.".postln;
			^nil;
		};

		path = path.asString.standardizePath;
		("Loading sample: " ++ path).postln;

			~granV21[\panic].value;

		if(~granV21[\sampleBuf].notNil) {
			try { ~granV21[\sampleBuf].free } { };
			~granV21[\sampleBuf] = nil;
		};

		Buffer.readChannel(
			s,
			path,
			channels: [0],
			action: { |buf|
				("Buffer.readChannel callback fired: " ++ buf).postln;
				~granV21[\setCurrentBuffer].value(
					buf,
					PathName(path).fileName
				);
				("Sample loaded: " ++ PathName(path).fileName).postln;
			}
		);
	});
};


	~granV21[\startRecording] = {
		if(~granV21[\liveBuf].isNil) {
			~granV21[\allocLiveBuf].value;
		};

		if(~granV21[\recSynth].notNil) {
			try { ~granV21[\recSynth].free } { };
		};

		~granV21[\liveBuf].zero;
		~granV21[\recSynth] = Synth(\granInputRecorderV21, [
			\bufnum, ~granV21[\liveBuf],
			\in, 0,
			\recLevel, 1.0,
			\preLevel, 0.0,
			\run, 1,
			\loop, 0
		]);

		~granV21[\isRecording] = true;
	};

	~granV21[\stopRecording] = {
		if(~granV21[\recSynth].notNil) {
			try { ~granV21[\recSynth].free } { };
			~granV21[\recSynth] = nil;
		};

		~granV21[\isRecording] = false;

		AppClock.sched(0.2, {
			~granV21[\setCurrentBuffer].value(~granV21[\liveBuf], "Live Recording");
			nil
		});
	};

	~granV21[\previewOn] = {
		if(~granV21[\buf].isNil) {
			"No sample or live buffer loaded.".warn;
			^nil;
		};

		if(~granV21[\voices][~granV21[\previewNote]].isNil) {
			~granV21[\noteOn].value(~granV21[\previewNote], 100);
		};

		~granV21[\isPreviewing] = true;
	};

	~granV21[\previewOff] = {
	~granV21[\noteOff].value(~granV21[\previewNote]);
	~granV21[\isPreviewing] = false;

	~granV21[\grainDotsA].clear;
	~granV21[\grainDotsB].clear;

	if(~granV21[\playButton].notNil) {
		{
			~granV21[\playButton].value_(0);
			~granV21[\playButton].refresh;
			if(~granV21[\waveView].notNil) { ~granV21[\waveView].refresh };
		}.defer;
	};
};

	~granV21[\applyXYTarget] = { |target, value|
	var p = ~granV21[\params];

	switch(target,
	\aPosition,  { p[\aPosition] = value.clip(0, 1) },
	\bPosition,  { p[\bPosition] = value.clip(0, 1) },
	\regionStart,{ p[\regionStart] = value.clip(0, p[\regionEnd] - 0.01) },
	\regionEnd,  { p[\regionEnd] = value.clip(p[\regionStart] + 0.01, 1.0) },
		\aJitter,    { p[\aJitter] = value.clip(0, 1) },
		\bJitter,    { p[\bJitter] = value.clip(0, 1) },
		\aDensity,   { p[\aDensity] = value.linexp(0, 1, 0.5, 80) },
		\bDensity,   { p[\bDensity] = value.linexp(0, 1, 0.5, 80) },
		\aScanWidth, { p[\aScanWidth] = value.clip(0, 1) },
		\bScanWidth, { p[\bScanWidth] = value.clip(0, 1) },
		\rateA,      { p[\aRateMul] = value.linlin(0, 1, -2, 2) },
		\rateB,      { p[\bRateMul] = value.linlin(0, 1, -2, 2) },
		\lpf,        { p[\lpf] = value.linexp(0, 1, 100, 20000) },
		\hpf,        { p[\hpf] = value.linexp(0, 1, 20, 8000) },
		\oscCutoff,  { p[\oscCutoff] = value.linexp(0, 1, 100, 18000) },
		\masterAmp,  { p[\masterAmp] = value.clip(0, 1) }
	);

	~granV21[\syncControls].value;
	~granV21[\updateAllVoices].value;
};

	~granV21[\savePreset] = {
		Dialog.savePanel({ |path|
			if(path.notNil) {
				~granV21[\params].copy.writeArchive(path);
			};
		});
	};

	~granV21[\loadPreset] = {
		Dialog.openPanel({ |path|
			var obj;
			if(path.notNil) {
				obj = Object.readArchive(path);
				if(obj.notNil) {
					obj.keysValuesDo { |k, v|
						~granV21[\params][k] = v;
					};
					~granV21[\syncControls].value;
					~granV21[\updateAllVoices].value;
				};
			};
		});
	};

	~granV21[\setupMIDI] = {
		var onFunc, offFunc;

		MIDIClient.init;
		MIDIIn.connectAll;

		onFunc = MIDIFunc.noteOn({ |vel, note, chan, src|
			{
				if(vel > 0) {
					~granV21[\noteOn].value(note, vel);
				} {
					~granV21[\noteOff].value(note);
				};
			}.defer;
		});

		offFunc = MIDIFunc.noteOff({ |vel, note, chan, src|
			{
				~granV21[\noteOff].value(note);
			}.defer;
		});

		~granV21[\midiObjs].add(onFunc);
		~granV21[\midiObjs].add(offFunc);
	};

	~granV21[\showPage] = { |index|
		~granV21[\pages].do { |view, i| view.visible = (i == index) };
		~granV21[\tabButtons].do { |bt, i| bt.value = if(i == index) { 1 } { 0 } };
	};

	~granV21[\setSliderAndBox] = { |key, value, minVal, maxVal, spec|
		var sl = ~granV21[\sliders][key];
		var nb = ~granV21[\boxes][key];
		var norm;

		if(sl.notNil) {
			norm = if(spec == \exp) {
				value.explin(minVal, maxVal, 0, 1).clip(0, 1)
			} {
				value.linlin(minVal, maxVal, 0, 1).clip(0, 1)
			};
			sl.value = norm;
		};

		if(nb.notNil) {
			nb.value = value;
		};
	};


	~granV21[\getWaveMetrics] = { |view|
	var p = ~granV21[\params];
	var vw = ~granV21[\view];
	var w = view.bounds.width;
	var h = view.bounds.height;

	var zoom = (vw[\zoom] ? 1.0).clip(1.0, 64.0);
	var visibleFrac = (1.0 / zoom).clip(0.0001, 1.0);
	var maxScroll = (1.0 - visibleFrac).max(0.0);
	var scroll = (vw[\scroll] ? 0.0).clip(0.0, 1.0) * maxScroll;
	var visStart = scroll;
	var visEnd = (scroll + visibleFrac).clip(0.0, 1.0);

var regStart = p[\regionStart];
var regEnd = p[\regionEnd];
var regLen = (regEnd - regStart).max(0.001);

var loopStart = (vw[\loopStart] ? regStart).clip(regStart, regEnd - 0.001);
var loopEnd = (vw[\loopEnd] ? regEnd).clip(loopStart + 0.001, regEnd);
var loopLen = (loopEnd - loopStart).max(0.001);

var aAbsNorm = (loopStart + (p[\aPosition].clip(0, 1) * loopLen)).clip(0, 1);
var bAbsNorm = (loopStart + (p[\bPosition].clip(0, 1) * loopLen)).clip(0, 1);

	var xFromNorm = { |n|
		((n - visStart) / visibleFrac * w).clip(0, w);
	};

	(
		w: w,
		h: h,
		visStart: visStart,
		visEnd: visEnd,
		visibleFrac: visibleFrac,
		regStart: regStart,
regEnd: regEnd,
regLen: regLen,
loopStart: loopStart,
loopEnd: loopEnd,
loopLen: loopLen,
		aAbsNorm: aAbsNorm,
		bAbsNorm: bAbsNorm,
		aX: xFromNorm.value(aAbsNorm),
		bX: xFromNorm.value(bAbsNorm),
		startX: xFromNorm.value(regStart),
		endX: xFromNorm.value(regEnd),
		xFromNorm: xFromNorm
	)
};


	~granV21[\syncControls] = {
		var p = ~granV21[\params];

		[
			[\masterAmp, 0, 1, \lin],
			[\atk, 0.001, 2, \exp],
			[\rel, 0.001, 4, \exp],

			[\aAmp, 0, 1, \lin],
			[\aPosition, 0, 1, \lin],
			[\aDensity, 0.5, 80, \exp],
			[\aDur, 0.005, 1.0, \exp],
			[\aJitter, 0, 1, \lin],
			[\aRateMul, -2, 2, \lin],
			[\aRateRand, 0, 1, \lin],
			[\aScanRate, 0.001, 6, \exp],
			[\aScanWidth, 0, 1, \lin],

			[\bAmp, 0, 1, \lin],
			[\bPosition, 0, 1, \lin],
			[\bDensity, 0.5, 80, \exp],
			[\bDur, 0.005, 1.0, \exp],
			[\bJitter, 0, 1, \lin],
			[\bRateMul, -2, 2, \lin],
			[\bRateRand, 0, 1, \lin],
			[\bScanRate, 0.001, 6, \exp],
			[\bScanWidth, 0, 1, \lin],

			[\oscAmp, 0, 1, \lin],
			[\oscDetune, -24, 24, \lin],
			[\oscCutoff, 100, 18000, \exp],
			[\oscRes, 0, 0.95, \lin],

			[\filter1Cutoff, 20, 20000, \exp],
			[\filter1Res, 0, 0.95, \lin],

			[\filter2Cutoff, 20, 20000, \exp],
			[\filter2Res, 0, 0.95, \lin],

			[\delayMix, 0, 1, \lin],
			[\delayTime, 0.001, 1.5, \exp],
			[\delayFb, 0, 0.95, \lin],

			[\reverbMix, 0, 1, \lin],
			[\reverbRoom, 0, 1, \lin],
			[\reverbDamp, 0, 1, \lin],

			[\lfo1Rate, 0.001, 20, \exp],
			[\lfo1Depth, 0, 1, \lin],
			[\lfo1Amt1, -1, 1, \lin],
			[\lfo1Amt2, -1, 1, \lin],
			[\lfo1Amt3, -1, 1, \lin],
			[\lfo1Amt4, -1, 1, \lin],

			[\lfo2Rate, 0.001, 20, \exp],
			[\lfo2Depth, 0, 1, \lin],
			[\lfo2Amt1, -1, 1, \lin],
			[\lfo2Amt2, -1, 1, \lin],
			[\lfo2Amt3, -1, 1, \lin],
			[\lfo2Amt4, -1, 1, \lin],

			[\modEnv1Atk, 0.001, 4, \exp],
			[\modEnv1Dec, 0.001, 4, \exp],
			[\modEnv1Sus, 0, 1, \lin],
			[\modEnv1Rel, 0.001, 6, \exp],
			[\modEnv1Depth, 0, 1, \lin],
			[\modEnv1Amt1, -1, 1, \lin],
			[\modEnv1Amt2, -1, 1, \lin],
			[\modEnv1Amt3, -1, 1, \lin],
			[\modEnv1Amt4, -1, 1, \lin],

			[\hpf, 20, 8000, \exp],
			[\lpf, 100, 20000, \exp]
		].do { |row|
			~granV21[\setSliderAndBox].value(row[0], p[row[0]], row[1], row[2], row[3]);
		};

		if(~granV21[\toggles][\aOn].notNil) { ~granV21[\toggles][\aOn].value = p[\aOn] };
		if(~granV21[\toggles][\bOn].notNil) { ~granV21[\toggles][\bOn].value = p[\bOn] };
		if(~granV21[\toggles][\oscOn].notNil) { ~granV21[\toggles][\oscOn].value = p[\oscOn] };
		if(~granV21[\toggles][\lfo1On].notNil) { ~granV21[\toggles][\lfo1On].value = p[\lfo1On] };
				if(~granV21[\toggles][\lfo2On].notNil) { ~granV21[\toggles][\lfo2On].value = p[\lfo2On] };

		if(~granV21[\menus][\oscWave].notNil) { ~granV21[\menus][\oscWave].value = p[\oscWave] };
		if(~granV21[\menus][\aScanMode].notNil) { ~granV21[\menus][\aScanMode].value = p[\aScanMode] ? 0 };
		if(~granV21[\menus][\bScanMode].notNil) { ~granV21[\menus][\bScanMode].value = p[\bScanMode] ? 0 };
		if(~granV21[\menus][\filter1Type].notNil) { ~granV21[\menus][\filter1Type].value = p[\filter1Type] ? 0 };
		if(~granV21[\menus][\filter2Type].notNil) { ~granV21[\menus][\filter2Type].value = p[\filter2Type] ? 0 };
		if(~granV21[\menus][\filterRouting].notNil) { ~granV21[\menus][\filterRouting].value = p[\filterRouting] ? 0 };
		if(~granV21[\menus][\lfo1Shape].notNil) { ~granV21[\menus][\lfo1Shape].value = p[\lfo1Shape] ? 0 };
		if(~granV21[\menus][\lfo1Dest1].notNil) { ~granV21[\menus][\lfo1Dest1].value = p[\lfo1Dest1] ? 0 };
		if(~granV21[\menus][\lfo1Dest2].notNil) { ~granV21[\menus][\lfo1Dest2].value = p[\lfo1Dest2] ? 0 };
		if(~granV21[\menus][\lfo1Dest3].notNil) { ~granV21[\menus][\lfo1Dest3].value = p[\lfo1Dest3] ? 0 };
		if(~granV21[\menus][\lfo1Dest4].notNil) { ~granV21[\menus][\lfo1Dest4].value = p[\lfo1Dest4] ? 0 };
				if(~granV21[\menus][\lfo2Shape].notNil) { ~granV21[\menus][\lfo2Shape].value = p[\lfo2Shape] ? 0 };
		if(~granV21[\menus][\lfo2Dest1].notNil) { ~granV21[\menus][\lfo2Dest1].value = p[\lfo2Dest1] ? 0 };
		if(~granV21[\menus][\lfo2Dest2].notNil) { ~granV21[\menus][\lfo2Dest2].value = p[\lfo2Dest2] ? 0 };
		if(~granV21[\menus][\lfo2Dest3].notNil) { ~granV21[\menus][\lfo2Dest3].value = p[\lfo2Dest3] ? 0 };
		if(~granV21[\menus][\lfo2Dest4].notNil) { ~granV21[\menus][\lfo2Dest4].value = p[\lfo2Dest4] ? 0 };

		if(~granV21[\menus][\modEnv1Dest1].notNil) { ~granV21[\menus][\modEnv1Dest1].value = p[\modEnv1Dest1] ? 0 };
		if(~granV21[\menus][\modEnv1Dest2].notNil) { ~granV21[\menus][\modEnv1Dest2].value = p[\modEnv1Dest2] ? 0 };
		if(~granV21[\menus][\modEnv1Dest3].notNil) { ~granV21[\menus][\modEnv1Dest3].value = p[\modEnv1Dest3] ? 0 };
		if(~granV21[\menus][\modEnv1Dest4].notNil) { ~granV21[\menus][\modEnv1Dest4].value = p[\modEnv1Dest4] ? 0 };

		if(~granV21[\toggles][\delayOn].notNil) { ~granV21[\toggles][\delayOn].value = p[\delayOn] };
		if(~granV21[\toggles][\reverbOn].notNil) { ~granV21[\toggles][\reverbOn].value = p[\reverbOn] };


		if(~granV21[\pathLabel].notNil) {~granV21[\pathLabel].string_(~granV21[\samplePath]); };

		if(~granV21[\waveView].notNil) { ~granV21[\waveView].refresh };

		if(~granV21[\miniView].notNil) { ~granV21[\miniView].refresh };

		if(~granV21[\xyView].notNil) { ~granV21[\xyView].refresh };

		if(~granV21[\refreshModLfoUi].notNil) { ~granV21[\refreshModLfoUi].value; };
	};


		~granV21[\refreshModLfoUi] = {
		var idx = ~granV21[\modUi][\lfoIndex] ? 1;
		var prefix, titleStr, routeTitleStr;

		prefix = if(idx == 1) { "lfo1" } { "lfo2" };
		titleStr = if(idx == 1) { "LFO 1" } { "LFO 2" };
		routeTitleStr = if(idx == 1) { "LFO 1 Routing" } { "LFO 2 Routing" };

		if(~granV21[\modLfoTitle].notNil) {
			~granV21[\modLfoTitle].string_(titleStr);
		};

		if(~granV21[\modLfoRoutingTitle].notNil) {
			~granV21[\modLfoRoutingTitle].string_(routeTitleStr);
		};

		if(~granV21[\modLfoToggleLabel].notNil) {
			~granV21[\modLfoToggleLabel].string_(if(idx == 1) { "Editing: LFO 1" } { "Editing: LFO 2" });
		};

		if(~granV21[\toggles][\modLfoOn].notNil) {
			~granV21[\toggles][\modLfoOn].value = ~granV21[\params][(prefix ++ "On").asSymbol];
		};

		if(~granV21[\menus][\modLfoShape].notNil) {
			~granV21[\menus][\modLfoShape].value = ~granV21[\params][(prefix ++ "Shape").asSymbol] ? 0;
		};

		if(~granV21[\menus][\modLfoDest1].notNil) {
			~granV21[\menus][\modLfoDest1].value = ~granV21[\params][(prefix ++ "Dest1").asSymbol] ? 0;
		};
		if(~granV21[\menus][\modLfoDest2].notNil) {
			~granV21[\menus][\modLfoDest2].value = ~granV21[\params][(prefix ++ "Dest2").asSymbol] ? 0;
		};
		if(~granV21[\menus][\modLfoDest3].notNil) {
			~granV21[\menus][\modLfoDest3].value = ~granV21[\params][(prefix ++ "Dest3").asSymbol] ? 0;
		};
		if(~granV21[\menus][\modLfoDest4].notNil) {
			~granV21[\menus][\modLfoDest4].value = ~granV21[\params][(prefix ++ "Dest4").asSymbol] ? 0;
		};

		if(~granV21[\sliders][\modLfoRate].notNil) {
			~granV21[\sliders][\modLfoRate].value = ~granV21[\params][(prefix ++ "Rate").asSymbol].explin(0.001, 20, 0, 1).clip(0, 1);
		};
		if(~granV21[\boxes][\modLfoRate].notNil) {
			~granV21[\boxes][\modLfoRate].value = ~granV21[\params][(prefix ++ "Rate").asSymbol];
		};

		if(~granV21[\sliders][\modLfoDepth].notNil) {
			~granV21[\sliders][\modLfoDepth].value = ~granV21[\params][(prefix ++ "Depth").asSymbol].clip(0, 1);
		};
		if(~granV21[\boxes][\modLfoDepth].notNil) {
			~granV21[\boxes][\modLfoDepth].value = ~granV21[\params][(prefix ++ "Depth").asSymbol];
		};

		if(~granV21[\sliders][\modLfoAmt1].notNil) {
			~granV21[\sliders][\modLfoAmt1].value = ~granV21[\params][(prefix ++ "Amt1").asSymbol].linlin(-1, 1, 0, 1).clip(0, 1);
		};
		if(~granV21[\boxes][\modLfoAmt1].notNil) {
			~granV21[\boxes][\modLfoAmt1].value = ~granV21[\params][(prefix ++ "Amt1").asSymbol];
		};

		if(~granV21[\sliders][\modLfoAmt2].notNil) {
			~granV21[\sliders][\modLfoAmt2].value = ~granV21[\params][(prefix ++ "Amt2").asSymbol].linlin(-1, 1, 0, 1).clip(0, 1);
		};
		if(~granV21[\boxes][\modLfoAmt2].notNil) {
			~granV21[\boxes][\modLfoAmt2].value = ~granV21[\params][(prefix ++ "Amt2").asSymbol];
		};

		if(~granV21[\sliders][\modLfoAmt3].notNil) {
			~granV21[\sliders][\modLfoAmt3].value = ~granV21[\params][(prefix ++ "Amt3").asSymbol].linlin(-1, 1, 0, 1).clip(0, 1);
		};
		if(~granV21[\boxes][\modLfoAmt3].notNil) {
			~granV21[\boxes][\modLfoAmt3].value = ~granV21[\params][(prefix ++ "Amt3").asSymbol];
		};

		if(~granV21[\sliders][\modLfoAmt4].notNil) {
			~granV21[\sliders][\modLfoAmt4].value = ~granV21[\params][(prefix ++ "Amt4").asSymbol].linlin(-1, 1, 0, 1).clip(0, 1);
		};
		if(~granV21[\boxes][\modLfoAmt4].notNil) {
			~granV21[\boxes][\modLfoAmt4].value = ~granV21[\params][(prefix ++ "Amt4").asSymbol];
		};
	};


	~granV21[\spawnVisualDots] = { |which|
	nil
};

~granV21[\decayVisualDots] = {
	~granV21[\grainDotsA].clear;
	~granV21[\grainDotsB].clear;
};

~granV21[\startVisualizer] = {
	if(~granV21[\visRunning] == true) { ^nil };

	~granV21[\visRunning] = true;

	AppClock.sched(0.05, {
		if(~granV21.isNil) { ^nil };
		if(~granV21[\visRunning] != true) { ^nil };

		~granV21[\visTime] = ~granV21[\visTime] + 0.05;
		~granV21[\decayVisualDots].value;
		~granV21[\spawnVisualDots].value(\a);
		~granV21[\spawnVisualDots].value(\b);

		if(~granV21[\waveView].notNil) {
			~granV21[\waveView].refresh;
		};

		0.05
	});
};

~granV21[\stopVisualizer] = {
	~granV21[\visRunning] = false;
};

	~granV21[\makeSliderRow] = { |parent, y, label, key, minVal, maxVal, spec=\lin, decimals=3|
		var lbl, sl, nb;

		lbl = StaticText(parent, Rect(12, y, 90, 20)).string_(label);

		sl = Slider(parent, Rect(105, y, 250, 20));
		nb = NumberBox(parent, Rect(365, y, 75, 20)).decimals_(decimals);

		sl.action_({
			var v = if(spec == \exp) {
				sl.value.linexp(0, 1, minVal, maxVal)
			} {
				sl.value.linlin(0, 1, minVal, maxVal)
			};

			~granV21[\params][key] = v;
			nb.value = v;
			~granV21[\updateAllVoices].value;
		});

		nb.action_({
			var v = nb.value.clip(minVal, maxVal);
			var norm = if(spec == \exp) {
				v.explin(minVal, maxVal, 0, 1)
			} {
				v.linlin(minVal, maxVal, 0, 1)
			};

			~granV21[\params][key] = v;
			sl.value = norm;
			~granV21[\updateAllVoices].value;
		});

		~granV21[\sliders][key] = sl;
		~granV21[\boxes][key] = nb;
		~granV21[\setSliderAndBox].value(key, ~granV21[\params][key], minVal, maxVal, spec);
	};

	~granV21[\makeToggleRow] = { |parent, y, label, key|
		var bt;
		StaticText(parent, Rect(12, y, 90, 20)).string_(label);

		bt = Button(parent, Rect(105, y, 80, 22))
			.states_([["Off"], ["On"]])
			.value_(~granV21[\params][key]);

		bt.action_({
			~granV21[\params][key] = bt.value.asInteger;
			~granV21[\updateAllVoices].value;
		});

		~granV21[\toggles][key] = bt;
	};

	// --------------------------------------------------------
	// build buffer + midi
	// --------------------------------------------------------
	~granV21[\allocLiveBuf].value;
	~granV21[\setupMIDI].value;

	// --------------------------------------------------------
	// GUI
	// --------------------------------------------------------
	~granV21[\win] = Window("Granular App V2.1", Rect(70, 50, 1120, 760), resizable: true);
	~granV21[\win].background = Color.white;

	~granV21[\win].onClose_({
		~granV21[\free].value;
	});

	// top bar
	Button(~granV21[\win], Rect(16, 14, 110, 28))
		.states_([["Load Sample"]])
		.action_({ ~granV21[\loadSample].value });

	Button(~granV21[\win], Rect(132, 14, 95, 28))
		.states_([["Save Preset"]])
		.action_({ ~granV21[\savePreset].value });

	Button(~granV21[\win], Rect(233, 14, 95, 28))
		.states_([["Load Preset"]])
		.action_({ ~granV21[\loadPreset].value });

	Button(~granV21[\win], Rect(334, 14, 85, 28))
		.states_([["Rec In"]])
		.action_({ ~granV21[\startRecording].value });

	Button(~granV21[\win], Rect(425, 14, 90, 28))
		.states_([["Stop Rec"]])
		.action_({ ~granV21[\stopRecording].value });

	~granV21[\playButton] = Button(~granV21[\win], Rect(521, 14, 80, 28))
	.states_([["Play"], ["Stop"]])
	.action_({ |bt|
		if(bt.value == 1) {
			~granV21[\previewOn].value;
		} {
			~granV21[\previewOff].value;
		};
	});

	Button(~granV21[\win], Rect(607, 14, 75, 28))
		.states_([["Panic"]])
		.action_({
			~granV21[\panic].value;
			if(~granV21[\win].notNil) { ~granV21[\win].refresh };
		});

	~granV21[\pathLabel] = StaticText(~granV21[\win], Rect(695, 14, 395, 28))
		.string_(~granV21[\samplePath])
		.align_(\left);

	// waveform
	~granV21[\waveView] = UserView(~granV21[\win], Rect(16, 56, 1088, 188))
	.background_(Color.white);

	~granV21[\miniView] = UserView(~granV21[\win], Rect(16, 248, 1088, 28))
	.background_(Color.white);


	~granV21[\waveView].drawFunc_({
	var data = ~granV21[\waveData];
	var p = ~granV21[\params];
	var v = ~granV21[\view];
	var b = ~granV21[\waveView].bounds;
	var w = b.width;
	var h = b.height;
	var mid = h * 0.5;

	var zoom = (v[\zoom] ? 1.0).clip(1.0, 64.0);
	var visibleFrac = (1.0 / zoom).clip(0.0001, 1.0);
	var maxScroll = (1.0 - visibleFrac).max(0.0);
	var scroll = (v[\scroll] ? 0.0).clip(0.0, 1.0) * maxScroll;
	var visStart = scroll;
	var visEnd = (scroll + visibleFrac).clip(0.0, 1.0);

	var xFromNorm, x1, x2, xpos, lx1, lx2;
	var startIndex, endIndex, visibleData;

	xFromNorm = { |norm|
		((norm - visStart) / visibleFrac * w).clip(0, w);
	};

	Pen.fillColor = Color.white;
	Pen.fillRect(Rect(0, 0, w, h));

	Pen.color = Color.gray(0.75);
	Pen.moveTo(Point(0, mid));
	Pen.lineTo(Point(w, mid));
	Pen.stroke;

	if(data.notNil and: { data.size > 1 }) {
		startIndex = (visStart * (data.size - 1)).floor.asInteger.clip(0, data.size - 1);
		endIndex = (visEnd * (data.size - 1)).ceil.asInteger.clip(startIndex + 1, data.size - 1);
		visibleData = data.copyRange(startIndex, endIndex);

		if(visibleData.notNil and: { visibleData.size > 1 }) {
			Pen.fillColor = Color(0.0, 0.45, 0.35);

			visibleData.do { |val, i|
				var normInView = i / (visibleData.size - 1).max(1);
				var x = normInView * w;
				var amp = (val.clip(0, 1).max(0.01)) * h * 0.42;

				Pen.fillRect(Rect(x, mid - amp, 1.0, amp * 2));
			};
		};
	};

	x1 = xFromNorm.value(p[\regionStart]);
x2 = xFromNorm.value(p[\regionEnd]);

lx1 = xFromNorm.value(v[\loopStart] ? 0.0);
lx2 = xFromNorm.value(v[\loopEnd] ? 1.0);

	// region highlight only if visible
	if((p[\regionEnd] > visStart) and: { p[\regionStart] < visEnd }) {
		Pen.fillColor = Color.yellow.alpha_(0.14);
		Pen.fillRect(Rect(x1, 0, (x2 - x1).max(1), h));
	};

	// region edges
	Pen.color = Color(0.8, 0.65, 0.0);
	if((p[\regionStart] >= visStart) and: { p[\regionStart] <= visEnd }) {
		Pen.moveTo(Point(x1, 0)); Pen.lineTo(Point(x1, h)); Pen.stroke;
	};
	if((p[\regionEnd] >= visStart) and: { p[\regionEnd] <= visEnd }) {
		Pen.moveTo(Point(x2, 0)); Pen.lineTo(Point(x2, h)); Pen.stroke;
	};



	// loop markers
	Pen.color = Color.blue(0.3, 0.55);
	if(((v[\loopStart] ? 0.0) >= visStart) and: { (v[\loopStart] ? 0.0) <= visEnd }) {
		Pen.moveTo(Point(lx1, 0)); Pen.lineTo(Point(lx1, h)); Pen.stroke;
	};
	if(((v[\loopEnd] ? 1.0) >= visStart) and: { (v[\loopEnd] ? 1.0) <= visEnd }) {
		Pen.moveTo(Point(lx2, 0)); Pen.lineTo(Point(lx2, h)); Pen.stroke;
	};

if(~granV21[\buf].notNil) {
	var loopStart = (v[\loopStart] ? p[\regionStart]).clip(p[\regionStart], p[\regionEnd] - 0.001);
	var loopEnd = (v[\loopEnd] ? p[\regionEnd]).clip(loopStart + 0.001, p[\regionEnd]);
	var loopLen = (loopEnd - loopStart).max(0.001);

	var aBasePos = p[\aPosition].clip(0, 1);
	var bBasePos = p[\bPosition].clip(0, 1);

	var aScan, bScan, aPosNorm, bPosNorm;
	var aAbsNorm, bAbsNorm, aX, bX;
	var aForwardNorm, bForwardNorm, aPingPongNorm, bPingPongNorm;
	var aMode, bMode;
	var aMinNorm, aMaxNorm, bMinNorm, bMaxNorm;
	var aMinAbs, aMaxAbs, bMinAbs, bMaxAbs;
	var aMinX, aMaxX, bMinX, bMaxX;

	var drawLaneRect, drawWrappedForwardLane;

	aMode = p[\aScanMode] ? 0;
	bMode = p[\bScanMode] ? 0;

	aScan = sin(~granV21[\visTime] * p[\aScanRate].max(0.001) * 2pi) * p[\aScanWidth].clip(0, 1);
	bScan = sin(~granV21[\visTime] * p[\bScanRate].max(0.001) * 2pi) * p[\bScanWidth].clip(0, 1);

	aForwardNorm = (aBasePos + (((~granV21[\visTime] * p[\aScanRate].max(0.001)) % 1.0) * p[\aScanWidth].clip(0, 1))).wrap(0, 1);
	bForwardNorm = (bBasePos + (((~granV21[\visTime] * p[\bScanRate].max(0.001)) % 1.0) * p[\bScanWidth].clip(0, 1))).wrap(0, 1);

	aPingPongNorm = (aBasePos + (sin(~granV21[\visTime] * p[\aScanRate].max(0.001) * pi) * p[\aScanWidth].clip(0, 1))).clip(0, 1);
	bPingPongNorm = (bBasePos + (sin(~granV21[\visTime] * p[\bScanRate].max(0.001) * pi) * p[\bScanWidth].clip(0, 1))).clip(0, 1);

	aPosNorm = if(aMode == 0) {
		(aBasePos + aScan).clip(0, 1)
	} {
		if(aMode == 1) {
			aForwardNorm
		} {
			aPingPongNorm
		}
	};

	bPosNorm = if(bMode == 0) {
		(bBasePos + bScan).clip(0, 1)
	} {
		if(bMode == 1) {
			bForwardNorm
		} {
			bPingPongNorm
		}
	};

	aMinNorm = if(aMode == 0) {
		(aBasePos - p[\aScanWidth].clip(0, 1)).clip(0, 1)
	} {
		if(aMode == 1) {
			aBasePos.clip(0, 1)
		} {
			(aBasePos - p[\aScanWidth].clip(0, 1)).clip(0, 1)
		}
	};

	aMaxNorm = if(aMode == 0) {
		(aBasePos + p[\aScanWidth].clip(0, 1)).clip(0, 1)
	} {
		if(aMode == 1) {
			(aBasePos + p[\aScanWidth].clip(0, 1)).clip(0, 1)
		} {
			(aBasePos + p[\aScanWidth].clip(0, 1)).clip(0, 1)
		}
	};

	bMinNorm = if(bMode == 0) {
		(bBasePos - p[\bScanWidth].clip(0, 1)).clip(0, 1)
	} {
		if(bMode == 1) {
			bBasePos.clip(0, 1)
		} {
			(bBasePos - p[\bScanWidth].clip(0, 1)).clip(0, 1)
		}
	};

	bMaxNorm = if(bMode == 0) {
		(bBasePos + p[\bScanWidth].clip(0, 1)).clip(0, 1)
	} {
		if(bMode == 1) {
			(bBasePos + p[\bScanWidth].clip(0, 1)).clip(0, 1)
		} {
			(bBasePos + p[\bScanWidth].clip(0, 1)).clip(0, 1)
		}
	};

	aAbsNorm = (loopStart + (aPosNorm * loopLen)).clip(0, 1);
	bAbsNorm = (loopStart + (bPosNorm * loopLen)).clip(0, 1);

	aMinAbs = (loopStart + (aMinNorm * loopLen)).clip(0, 1);
	aMaxAbs = (loopStart + (aMaxNorm * loopLen)).clip(0, 1);
	bMinAbs = (loopStart + (bMinNorm * loopLen)).clip(0, 1);
	bMaxAbs = (loopStart + (bMaxNorm * loopLen)).clip(0, 1);

	aX = xFromNorm.value(aAbsNorm);
	bX = xFromNorm.value(bAbsNorm);
	aMinX = xFromNorm.value(aMinAbs);
	aMaxX = xFromNorm.value(aMaxAbs);
	bMinX = xFromNorm.value(bMinAbs);
	bMaxX = xFromNorm.value(bMaxAbs);

	drawLaneRect = { |xStart, xEnd, yTop, laneH, fillColor, strokeColor|
		var left = xStart.min(xEnd);
		var width = (xEnd - xStart).abs.max(1);

		if((left + width) >= 0 and: { left <= w }) {
			Pen.fillColor = fillColor;
			Pen.fillRect(Rect(left, yTop, width, laneH));

			Pen.color = strokeColor;
			Pen.addRect(Rect(left, yTop, width, laneH));
			Pen.stroke;
		};
	};

	drawWrappedForwardLane = { |basePos, scanWidth, yTop, laneH, fillColor, strokeColor|
		var widthNorm = scanWidth.clip(0, 1);
		var endNorm = basePos + widthNorm;
		var firstStartAbs, firstEndAbs, secondStartAbs, secondEndAbs;
		var firstX1, firstX2, secondX1, secondX2;

		if(endNorm <= 1.0) {
			firstStartAbs = loopStart + (basePos * loopLen);
			firstEndAbs = loopStart + (endNorm * loopLen);

			firstX1 = xFromNorm.value(firstStartAbs.clip(0, 1));
			firstX2 = xFromNorm.value(firstEndAbs.clip(0, 1));

			drawLaneRect.value(firstX1, firstX2, yTop, laneH, fillColor, strokeColor);
		} {
			firstStartAbs = loopStart + (basePos * loopLen);
			firstEndAbs = loopEnd;

			secondStartAbs = loopStart;
			secondEndAbs = loopStart + (((endNorm - 1.0).clip(0, 1)) * loopLen);

			firstX1 = xFromNorm.value(firstStartAbs.clip(0, 1));
			firstX2 = xFromNorm.value(firstEndAbs.clip(0, 1));
			secondX1 = xFromNorm.value(secondStartAbs.clip(0, 1));
			secondX2 = xFromNorm.value(secondEndAbs.clip(0, 1));

			drawLaneRect.value(firstX1, firstX2, yTop, laneH, fillColor, strokeColor);
			drawLaneRect.value(secondX1, secondX2, yTop, laneH, fillColor, strokeColor);
		};
	};

	// Gran A scan lane
	if(aMode == 1) {
		drawWrappedForwardLane.value(
			aBasePos,
			p[\aScanWidth],
			h * 0.18,
			h * 0.20,
			Color.cyan.alpha_(0.10),
			Color.cyan.alpha_(0.28)
		);
	} {
		if((aMaxAbs >= visStart) and: { aMinAbs <= visEnd }) {
			drawLaneRect.value(
				aMinX,
				aMaxX,
				h * 0.18,
				h * 0.20,
				Color.cyan.alpha_(0.10),
				Color.cyan.alpha_(0.28)
			);
		};
	};

	// Gran B scan lane
	if(bMode == 1) {
		drawWrappedForwardLane.value(
			bBasePos,
			p[\bScanWidth],
			h * 0.62,
			h * 0.20,
			Color.magenta.alpha_(0.10),
			Color.magenta.alpha_(0.28)
		);
	} {
		if((bMaxAbs >= visStart) and: { bMinAbs <= visEnd }) {
			drawLaneRect.value(
				bMinX,
				bMaxX,
				h * 0.62,
				h * 0.20,
				Color.magenta.alpha_(0.10),
				Color.magenta.alpha_(0.28)
			);
		};
	};

	// playheads on top
	if((aAbsNorm >= visStart) and: { aAbsNorm <= visEnd }) {
		Pen.color = Color.cyan.alpha_(0.95);
		Pen.moveTo(Point(aX, h * 0.08));
		Pen.lineTo(Point(aX, h * 0.92));
		Pen.stroke;
	};

	if((bAbsNorm >= visStart) and: { bAbsNorm <= visEnd }) {
		Pen.color = Color.magenta.alpha_(0.95);
		Pen.moveTo(Point(bX, h * 0.12));
		Pen.lineTo(Point(bX, h * 0.88));
		Pen.stroke;
	};
};


});


	~granV21[\miniView].drawFunc_({
	var data = ~granV21[\waveData];
	var vw = ~granV21[\view];
	var b = ~granV21[\miniView].bounds;
	var w = b.width;
	var h = b.height;
	var mid = h * 0.5;

	var zoom = (vw[\zoom] ? 1.0).clip(1.0, 64.0);
	var visibleFrac = (1.0 / zoom).clip(0.0001, 1.0);
	var maxScroll = (1.0 - visibleFrac).max(0.0);
	var scroll = (vw[\scroll] ? 0.0).clip(0.0, 1.0) * maxScroll;
	var visStart = scroll;
	var visEnd = (scroll + visibleFrac).clip(0.0, 1.0);

	Pen.fillColor = Color.white;
	Pen.fillRect(Rect(0, 0, w, h));

	Pen.color = Color.gray(0.82);
	Pen.moveTo(Point(0, mid));
	Pen.lineTo(Point(w, mid));
	Pen.stroke;

	if(data.notNil and: { data.size > 1 }) {
		Pen.fillColor = Color(0.0, 0.45, 0.35);

		data.do { |val, i|
			var x = i.linlin(0, data.size - 1, 0, w);
			var amp = val.clip(0, 1) * h * 0.42;
			Pen.fillRect(Rect(x, mid - amp, 1.0, amp * 2));
		};
	};

	// viewport box
	Pen.fillColor = Color.gray(0.3).alpha_(0.15);
	Pen.fillRect(Rect(visStart * w, 0, ((visEnd - visStart) * w).max(2), h));

	Pen.color = Color.gray(0.25);
	Pen.addRect(Rect(visStart * w, 0, ((visEnd - visStart) * w).max(2), h));
	Pen.stroke;
});


	~granV21[\miniView].mouseDownAction_({ |view, x, y|
	var vw = ~granV21[\view];
	var w = view.bounds.width;

	var zoom = (vw[\zoom] ? 1.0).clip(1.0, 64.0);
	var visibleFrac = (1.0 / zoom).clip(0.0001, 1.0);
	var maxScroll = (1.0 - visibleFrac).max(0.0);

	var currentStart = ((vw[\scroll] ? 0.0).clip(0, 1)) * maxScroll;
	var currentWidth = visibleFrac;
	var boxX = currentStart * w;
	var boxW = (currentWidth * w).max(2);

	if((x >= boxX) and: { x <= (boxX + boxW) }) {
		~granV21[\miniDrag] = true;
		~granV21[\miniDragOffset] = x - boxX;
	} {
		if(maxScroll > 0) {
			var targetStart = ((x / w) - (visibleFrac * 0.5)).clip(0, maxScroll);
			vw[\scroll] = (targetStart / maxScroll).clip(0, 1);
		} {
			vw[\scroll] = 0.0;
		};

		if(~granV21[\waveView].notNil) { ~granV21[\waveView].refresh };
		view.refresh;
	};
});

~granV21[\miniView].mouseMoveAction_({ |view, x, y|
	var vw = ~granV21[\view];
	var w = view.bounds.width;

	var zoom = (vw[\zoom] ? 1.0).clip(1.0, 64.0);
	var visibleFrac = (1.0 / zoom).clip(0.0001, 1.0);
	var maxScroll = (1.0 - visibleFrac).max(0.0);

	if(~granV21[\miniDrag] == true) {
		if(maxScroll > 0) {
			var targetStart = ((x - (~granV21[\miniDragOffset] ? 0.0)) / w).clip(0, 1);
			targetStart = targetStart.clip(0, 1.0 - visibleFrac);
			vw[\scroll] = (targetStart / maxScroll).clip(0, 1);
		} {
			vw[\scroll] = 0.0;
		};

		if(~granV21[\waveView].notNil) { ~granV21[\waveView].refresh };
		view.refresh;
	};
});

~granV21[\miniView].mouseUpAction_({
	~granV21[\miniDrag] = false;
	~granV21[\miniDragOffset] = 0.0;
});


~granV21[\waveView].mouseDownAction_({ |view, x, y, modifiers, buttonNumber, clickCount|
	var p = ~granV21[\params];
	var vw = ~granV21[\view];
	var m = ~granV21[\getWaveMetrics].value(view);

	var normVisible = (x / m[\w]).clip(0, 1);
	var norm = (m[\visStart] + (normVisible * m[\visibleFrac])).clip(0, 1);

	var aDistPx = (x - m[\aX]).abs;
	var bDistPx = (x - m[\bX]).abs;
	var startDistPx = (x - m[\startX]).abs;
	var endDistPx = (x - m[\endX]).abs;

	var loopStartX = m[\xFromNorm].value(vw[\loopStart] ? 0.0);
	var loopEndX = m[\xFromNorm].value(vw[\loopEnd] ? 1.0);
	var loopStartDistPx = (x - loopStartX).abs;
	var loopEndDistPx = (x - loopEndX).abs;

	var playheadHitRadius = ~granV21[\playheadHitRadius] ? 24;
	var edgeHitPx = 12;
	var loopHitPx = 12;
	var mode = vw[\editMode] ? \region;

	if(clickCount >= 2) {
		switch(mode,
			\region, {
				p[\regionStart] = 0.0;
				p[\regionEnd] = 1.0;
				p[\aPosition] = 0.5;
				p[\bPosition] = 0.5;
			},
			\loop, {
				vw[\loopStart] = 0.0;
				vw[\loopEnd] = 1.0;
			},
			\scroll, {
				vw[\scroll] = 0.0;
				vw[\zoom] = 1.0;
			}
		);

		~granV21[\dragMode] = \none;
		~granV21[\dragTarget] = \none;
		~granV21[\updateAllVoices].value;

		{
			view.refresh;
			if(~granV21[\win].notNil) { ~granV21[\win].refresh };
		}.defer;

		^nil;
	};

	switch(mode,

		\region, {
			if((aDistPx <= playheadHitRadius) or: { bDistPx <= playheadHitRadius }) {
				if(aDistPx <= bDistPx) {
					~granV21[\dragMode] = \aPosition;
					~granV21[\dragTarget] = \aPosition;
				} {
					~granV21[\dragMode] = \bPosition;
					~granV21[\dragTarget] = \bPosition;
				};
			} {
				if(startDistPx <= edgeHitPx) {
					~granV21[\dragMode] = \regionStart;
					~granV21[\dragTarget] = \regionStart;
				} {
					if(endDistPx <= edgeHitPx) {
						~granV21[\dragMode] = \regionEnd;
						~granV21[\dragTarget] = \regionEnd;
					} {
						~granV21[\dragMode] = \none;
						~granV21[\dragTarget] = \none;
					};
				};
			};
		},

		\loop, {
			if(loopStartDistPx <= loopHitPx) {
				~granV21[\dragMode] = \loopStart;
				~granV21[\dragTarget] = \loopStart;
			} {
				if(loopEndDistPx <= loopHitPx) {
					~granV21[\dragMode] = \loopEnd;
					~granV21[\dragTarget] = \loopEnd;
				} {
					~granV21[\dragMode] = \none;
					~granV21[\dragTarget] = \none;
				};
			};
		},

		\scroll, {
			~granV21[\dragMode] = \scroll;
			~granV21[\dragTarget] = \scroll;
			~granV21[\dragScrollStart] = x;
			~granV21[\dragScrollOrigin] = vw[\scroll] ? 0.0;
		}
	);

	view.refresh;
});


	~granV21[\waveView].mouseMoveAction_({ |view, x, y|
	var p = ~granV21[\params];
	var vw = ~granV21[\view];
	var m = ~granV21[\getWaveMetrics].value(view);
	var normVisible = (x / m[\w]).clip(0, 1);
	var norm = (m[\visStart] + (normVisible * m[\visibleFrac])).clip(0, 1);

	var maxScroll;
	var deltaPx;
	var deltaNorm;

	switch(~granV21[\dragTarget],

		\regionStart, {
	p[\regionStart] = norm.clip(0, p[\regionEnd] - 0.01);

	vw[\loopStart] = (vw[\loopStart] ? p[\regionStart]).clip(p[\regionStart], p[\regionEnd] - 0.01);
	vw[\loopEnd] = (vw[\loopEnd] ? p[\regionEnd]).clip(vw[\loopStart] + 0.01, p[\regionEnd]);
},

\regionEnd, {
	p[\regionEnd] = norm.clip(p[\regionStart] + 0.01, 1.0);

	vw[\loopStart] = (vw[\loopStart] ? p[\regionStart]).clip(p[\regionStart], p[\regionEnd] - 0.01);
	vw[\loopEnd] = (vw[\loopEnd] ? p[\regionEnd]).clip(vw[\loopStart] + 0.01, p[\regionEnd]);
},

		\aPosition, {
	p[\aPosition] = ((norm - m[\loopStart]) / (m[\loopEnd] - m[\loopStart]).max(0.001)).clip(0, 1);
},

\bPosition, {
	p[\bPosition] = ((norm - m[\loopStart]) / (m[\loopEnd] - m[\loopStart]).max(0.001)).clip(0, 1);
},

		\loopStart, {
	vw[\loopStart] = norm.clip(p[\regionStart], (vw[\loopEnd] ? p[\regionEnd]) - 0.01);
},

\loopEnd, {
	vw[\loopEnd] = norm.clip((vw[\loopStart] ? p[\regionStart]) + 0.01, p[\regionEnd]);
},

		\scroll, {
			maxScroll = (1.0 - m[\visibleFrac]).max(0.0);

			if(maxScroll > 0) {
				deltaPx = x - (~granV21[\dragScrollStart] ? x);
				deltaNorm = deltaPx / m[\w];
				vw[\scroll] = ((~granV21[\dragScrollOrigin] ? 0.0) - (deltaNorm / maxScroll)).clip(0, 1);
			};
		}
	);

	~granV21[\updateAllVoices].value;
	view.refresh;
});

~granV21[\waveView].mouseUpAction_({
	~granV21[\dragMode] = \none;
	~granV21[\dragTarget] = \none;
	~granV21[\dragScrollStart] = 0.0;
	~granV21[\dragScrollOrigin] = 0.0;
});





	// tabs
	    ["Sample", "Gran A", "Gran B", "Osc", "Filters", "FX", "Mod", "Perform"].do { |name, i|
		var bt = Button(~granV21[\win], Rect(16 + (i * 118), 292, 108, 26))
			.states_([[name], [name]])
			.action_({ ~granV21[\showPage].value(i) });

		~granV21[\tabButtons].add(bt);
	};

	// page 1 - Sample
	{
		var page = CompositeView(~granV21[\win], Rect(16, 330, 1088, 410))
			.background_(Color.white);

		StaticText(page, Rect(12, 10, 380, 20)).string_("Sample / Region / Envelope / Recording");
		StaticText(page, Rect(12, 38, 980, 18)).string_("Edit Mode: region = drag yellow edges + cyan/magenta playheads | loop = drag blue markers | scroll = drag waveform to pan | double-click resets current mode.");

		StaticText(page, Rect(12, 68, 42, 18)).string_("Zoom");
Slider(page, Rect(58, 70, 180, 16))
	.value_(0.0)
	.action_({ |sl|
	~granV21[\view][\zoom] = sl.value.linexp(0, 1, 1, 32);
	if(~granV21[\waveView].notNil) { ~granV21[\waveView].refresh };
	if(~granV21[\miniView].notNil) { ~granV21[\miniView].refresh };
});

StaticText(page, Rect(255, 68, 42, 18)).string_("Scroll");
Slider(page, Rect(305, 70, 180, 16))
	.value_(0.0)
	.action_({ |sl|
	~granV21[\view][\scroll] = sl.value.clip(0, 1);
	if(~granV21[\waveView].notNil) { ~granV21[\waveView].refresh };
	if(~granV21[\miniView].notNil) { ~granV21[\miniView].refresh };
});

StaticText(page, Rect(505, 68, 68, 18)).string_("Edit Mode");
PopUpMenu(page, Rect(575, 66, 120, 20))
	.items_(["region", "loop", "scroll"])
	.value_(0)
	.action_({ |pm|
		~granV21[\view][\editMode] = [\region, \loop, \scroll][pm.value];
	});

		~granV21[\makeSliderRow].value(page, 108, "Master",  \masterAmp, 0, 1, \lin, 3);
~granV21[\makeSliderRow].value(page, 138, "Attack",  \atk, 0.001, 2, \exp, 3);
~granV21[\makeSliderRow].value(page, 168, "Release", \rel, 0.001, 4, \exp, 3);

StaticText(page, Rect(12, 215, 190, 20)).string_("Live Buffer Length (sec)");
NumberBox(page, Rect(205, 215, 90, 20))
			.value_(~granV21[\recordSeconds])
			.decimals_(2)
			.action_({ |nb|
				~granV21[\recordSeconds] = nb.value.clip(1.0, 60.0);
				~granV21[\allocLiveBuf].value;
			});

		StaticText(page, Rect(12, 260, 900, 120))
			.string_(
				"Version 2.1 notes:\n"
				++ "• MIDI note-on creates a new voice.\n"
				++ "• MIDI note-off releases that note's voice.\n"
				++ "• UI edits update all currently held notes.\n"
				++ "• Preview button plays a local test note without MIDI.\n"
				++ "• Panic kills all active voices if anything gets stuck."
			);

		~granV21[\pages].add(page);
	}.value;

	// page 2 - Gran A
	{
		var page = CompositeView(~granV21[\win], Rect(16, 330, 1088, 410))
			.background_(Color.white);

		StaticText(page, Rect(12, 10, 250, 20)).string_("Granulator A");
		~granV21[\makeToggleRow].value(page, 45, "A On", \aOn);
		~granV21[\makeSliderRow].value(page, 75,  "A Amp", \aAmp, 0, 1, \lin, 3);
~granV21[\makeSliderRow].value(page, 105, "A Pos", \aPosition, 0, 1, \lin, 3);
~granV21[\makeSliderRow].value(page, 135, "Density", \aDensity, 0.5, 80, \exp, 3);
~granV21[\makeSliderRow].value(page, 165, "Dur", \aDur, 0.005, 1.0, \exp, 4);
~granV21[\makeSliderRow].value(page, 195, "Jitter", \aJitter, 0, 1, \lin, 3);
~granV21[\makeSliderRow].value(page, 225, "RateMul", \aRateMul, -2, 2, \lin, 3);
~granV21[\makeSliderRow].value(page, 255, "RateRand", \aRateRand, 0, 1, \lin, 3);
~granV21[\makeSliderRow].value(page, 285, "ScanRate", \aScanRate, 0.001, 6, \exp, 3);
~granV21[\makeSliderRow].value(page, 315, "ScanWidth", \aScanWidth, 0, 1, \lin, 3);

StaticText(page, Rect(12, 345, 90, 20)).string_("Scan Mode");
~granV21[\menus][\aScanMode] = PopUpMenu(page, Rect(105, 345, 120, 20))
	.items_(["Center", "Forward", "PingPong"])
	.value_(~granV21[\params][\aScanMode] ? 0)
	.action_({ |pm|
		~granV21[\params][\aScanMode] = pm.value;
		~granV21[\updateAllVoices].value;
	});

		~granV21[\pages].add(page);
	}.value;

	// page 3 - Gran B
	{
		var page = CompositeView(~granV21[\win], Rect(16, 330, 1088, 410))
			.background_(Color.white);

		StaticText(page, Rect(12, 10, 250, 20)).string_("Granulator B");
		~granV21[\makeToggleRow].value(page, 45, "B On", \bOn);
		~granV21[\makeSliderRow].value(page, 75,  "B Amp", \bAmp, 0, 1, \lin, 3);
~granV21[\makeSliderRow].value(page, 105, "B Pos", \bPosition, 0, 1, \lin, 3);
~granV21[\makeSliderRow].value(page, 135, "Density", \bDensity, 0.5, 80, \exp, 3);
~granV21[\makeSliderRow].value(page, 165, "Dur", \bDur, 0.005, 1.0, \exp, 4);
~granV21[\makeSliderRow].value(page, 195, "Jitter", \bJitter, 0, 1, \lin, 3);
~granV21[\makeSliderRow].value(page, 225, "RateMul", \bRateMul, -2, 2, \lin, 3);
~granV21[\makeSliderRow].value(page, 255, "RateRand", \bRateRand, 0, 1, \lin, 3);
~granV21[\makeSliderRow].value(page, 285, "ScanRate", \bScanRate, 0.001, 6, \exp, 3);
~granV21[\makeSliderRow].value(page, 315, "ScanWidth", \bScanWidth, 0, 1, \lin, 3);

StaticText(page, Rect(12, 345, 90, 20)).string_("Scan Mode");
~granV21[\menus][\bScanMode] = PopUpMenu(page, Rect(105, 345, 120, 20))
	.items_(["Center", "Forward", "PingPong"])
	.value_(~granV21[\params][\bScanMode] ? 0)
	.action_({ |pm|
		~granV21[\params][\bScanMode] = pm.value;
		~granV21[\updateAllVoices].value;
	});

		~granV21[\pages].add(page);
	}.value;

	// page 4 - OSC
	{
		var page = CompositeView(~granV21[\win], Rect(16, 330, 1088, 410))
			.background_(Color.white);

		StaticText(page, Rect(12, 10, 250, 20)).string_("Oscillator / Tone");
		~granV21[\makeToggleRow].value(page, 45, "Osc On", \oscOn);
		~granV21[\makeSliderRow].value(page, 75,  "Osc Amp", \oscAmp, 0, 1, \lin, 3);
		~granV21[\makeSliderRow].value(page, 105, "Detune", \oscDetune, -24, 24, \lin, 2);
		~granV21[\makeSliderRow].value(page, 135, "Cutoff", \oscCutoff, 100, 18000, \exp, 1);
		~granV21[\makeSliderRow].value(page, 165, "Res", \oscRes, 0, 0.95, \lin, 3);
		~granV21[\makeSliderRow].value(page, 225, "HPF", \hpf, 20, 8000, \exp, 1);
		~granV21[\makeSliderRow].value(page, 255, "LPF", \lpf, 100, 20000, \exp, 1);

		StaticText(page, Rect(12, 195, 70, 20)).string_("Wave");
		~granV21[\menus][\oscWave] = PopUpMenu(page, Rect(105, 195, 120, 20))
			.items_(["Sine", "Saw", "Pulse", "Tri"])
			.value_(~granV21[\params][\oscWave])
			.action_({ |pm|
				~granV21[\params][\oscWave] = pm.value;
				~granV21[\updateAllVoices].value;
			});

		~granV21[\pages].add(page);
	}.value;



		// page 5 - Filter
	{
		var page = CompositeView(~granV21[\win], Rect(16, 330, 1088, 410))
			.background_(Color.white);

		StaticText(page, Rect(12, 10, 250, 20)).string_("Dual Filters");

		// Filter 1
		StaticText(page, Rect(12, 45, 120, 20)).string_("Filter 1 Type");
		~granV21[\menus][\filter1Type] = PopUpMenu(page, Rect(105, 45, 140, 20))
			.items_(["Bypass", "Lowpass", "Highpass", "Bandpass"])
			.value_(~granV21[\params][\filter1Type] ? 0)
			.action_({ |pm|
				~granV21[\params][\filter1Type] = pm.value;
				~granV21[\updateAllVoices].value;
			});

		~granV21[\makeSliderRow].value(page, 80,  "F1 Cutoff", \filter1Cutoff, 20, 20000, \exp, 1);
		~granV21[\makeSliderRow].value(page, 110, "F1 Res",    \filter1Res, 0, 0.95, \lin, 3);

		// Filter 2
		StaticText(page, Rect(12, 165, 120, 20)).string_("Filter 2 Type");
		~granV21[\menus][\filter2Type] = PopUpMenu(page, Rect(105, 165, 140, 20))
			.items_(["Bypass", "Lowpass", "Highpass", "Bandpass"])
			.value_(~granV21[\params][\filter2Type] ? 0)
			.action_({ |pm|
				~granV21[\params][\filter2Type] = pm.value;
				~granV21[\updateAllVoices].value;
			});

		~granV21[\makeSliderRow].value(page, 200, "F2 Cutoff", \filter2Cutoff, 20, 20000, \exp, 1);
		~granV21[\makeSliderRow].value(page, 230, "F2 Res",    \filter2Res, 0, 0.95, \lin, 3);

		// Routing
		StaticText(page, Rect(12, 290, 120, 20)).string_("Routing");
		~granV21[\menus][\filterRouting] = PopUpMenu(page, Rect(105, 290, 140, 20))
			.items_(["Series", "Parallel"])
			.value_(~granV21[\params][\filterRouting] ? 0)
			.action_({ |pm|
				~granV21[\params][\filterRouting] = pm.value;
				~granV21[\updateAllVoices].value;
			});

		StaticText(page, Rect(560, 45, 430, 180))
			.string_(
				"Filter routing:\n"
				++ "• Series = Filter 1 feeds Filter 2\n"
				++ "• Parallel = both filters process the raw signal, then are mixed\n\n"
				++ "Suggested settings:\n"
				++ "• LP -> LP in series for darker sculpted tones\n"
				++ "• HP + LP in parallel for band-limited texture\n"
				++ "• Bypass one filter to use the other on its own"
			);

		~granV21[\pages].add(page);
	}.value;


		// page 6 - FX
	{
		var page = CompositeView(~granV21[\win], Rect(16, 330, 1088, 410))
			.background_(Color.white);

		StaticText(page, Rect(12, 10, 250, 20)).string_("FX Bus");

		// Delay
		StaticText(page, Rect(12, 45, 120, 20)).string_("Delay");
		~granV21[\makeToggleRow].value(page, 70, "Delay On", \delayOn);
		~granV21[\makeSliderRow].value(page, 100, "Dly Mix",  \delayMix, 0, 1, \lin, 3);
		~granV21[\makeSliderRow].value(page, 130, "Dly Time", \delayTime, 0.001, 1.5, \exp, 3);
		~granV21[\makeSliderRow].value(page, 160, "Dly FB",   \delayFb, 0, 0.95, \lin, 3);

		// Reverb
		StaticText(page, Rect(12, 220, 120, 20)).string_("Reverb");
		~granV21[\makeToggleRow].value(page, 245, "Rev On",   \reverbOn);
		~granV21[\makeSliderRow].value(page, 275, "Rev Mix",  \reverbMix, 0, 1, \lin, 3);
		~granV21[\makeSliderRow].value(page, 305, "Room",     \reverbRoom, 0, 1, \lin, 3);
		~granV21[\makeSliderRow].value(page, 335, "Damp",     \reverbDamp, 0, 1, \lin, 3);

		// Order

		StaticText(page, Rect(560, 85, 430, 180))
			.string_(
				"Suggested FX use:\n"
				++ "• Short delay + medium reverb = spacious plucks\n"
				++ "• High feedback + low reverb = dubby looping texture\n"
				++ "• Reverb before delay = smeared ambient repeats\n"
				++ "• Delay before reverb = cleaner echoes into space"
			);

		~granV21[\pages].add(page);
	}.value;



		// page 7 - Mod
	{
		var page = CompositeView(~granV21[\win], Rect(16, 330, 1088, 410))
			.background_(Color.white);

		var destItems;
		var makeTinySliderRow, makeTinyMenuRow, makeTinyToggleRow;
		var col1X, col2X, col3X, col4X, topY;

		destItems = [
			"Gran A Position",
			"Gran B Position",
			"Filter 1 Cutoff",
			"Filter 2 Cutoff",
			"Delay Mix",
			"Gran A Density",
			"Gran B Density",
			"Gran A Scan Width",
			"Gran B Scan Width",
			"Osc Cutoff",
			"Master Amp"
		];

		col1X = 18;
		col2X = 286;
		col3X = 556;
		col4X = 826;
		topY = 38;

		makeTinySliderRow = { |parent, x, y, label, key, minVal, maxVal, spec=\lin, decimals=3|
			var lbl, sl, nb;

			lbl = StaticText(parent, Rect(x, y + 2, 46, 18)).string_(label);

			sl = Slider(parent, Rect(x + 50, y, 92, 20));
			nb = NumberBox(parent, Rect(x + 148, y, 54, 20)).decimals_(decimals);

			sl.action_({
				var v = if(spec == \exp) {
					sl.value.linexp(0, 1, minVal, maxVal)
				} {
					sl.value.linlin(0, 1, minVal, maxVal)
				};

				~granV21[\params][key] = v;
				nb.value = v;
				~granV21[\updateAllVoices].value;
			});

			nb.action_({
				var v = nb.value.clip(minVal, maxVal);
				var norm = if(spec == \exp) {
					v.explin(minVal, maxVal, 0, 1)
				} {
					v.linlin(minVal, maxVal, 0, 1)
				};

				~granV21[\params][key] = v;
				sl.value = norm;
				~granV21[\updateAllVoices].value;
			});

			~granV21[\sliders][key] = sl;
			~granV21[\boxes][key] = nb;
			~granV21[\setSliderAndBox].value(key, ~granV21[\params][key], minVal, maxVal, spec);
		};

		makeTinyMenuRow = { |parent, x, y, label, key|
			var lbl, pm;

			lbl = StaticText(parent, Rect(x, y + 2, 46, 18)).string_(label);

			pm = PopUpMenu(parent, Rect(x + 50, y, 152, 20))
				.items_(destItems)
				.value_(~granV21[\params][key] ? 0)
				.action_({ |menu|
					~granV21[\params][key] = menu.value;
					~granV21[\updateAllVoices].value;
				});

			~granV21[\menus][key] = pm;
		};

		makeTinyToggleRow = { |parent, x, y, label, key|
			var lbl, bt;

			lbl = StaticText(parent, Rect(x, y + 2, 46, 18)).string_(label);

			bt = Button(parent, Rect(x + 50, y, 74, 22))
				.states_([["Off"], ["On"]])
				.value_(~granV21[\params][key])
				.action_({ |b|
					~granV21[\params][key] = b.value.asInteger;
					~granV21[\updateAllVoices].value;
				});

			~granV21[\toggles][key] = bt;
		};

		StaticText(page, Rect(12, 10, 140, 20)).string_("Modulation");

		~granV21[\modLfoToggleLabel] = StaticText(page, Rect(180, 10, 120, 20))
			.string_("Editing: LFO 1");

		Button(page, Rect(306, 8, 92, 24))
			.states_([["LFO 1"], ["LFO 2"]])
			.value_(0)
			.action_({ |bt|
				~granV21[\modUi][\lfoIndex] = if(bt.value == 0) { 1 } { 2 };
				~granV21[\refreshModLfoUi].value;
			});

		// ------------------------------------------------
		// COLUMN 1 : DISPLAYED LFO CORE
		// ------------------------------------------------
		~granV21[\modLfoTitle] = StaticText(page, Rect(col1X, topY, 140, 20)).string_("LFO 1");

		StaticText(page, Rect(col1X, topY + 30, 46, 18)).string_("On");
		~granV21[\toggles][\modLfoOn] = Button(page, Rect(col1X + 50, topY + 28, 74, 22))
			.states_([["Off"], ["On"]])
			.value_(~granV21[\params][\lfo1On])
			.action_({ |b|
				var prefix = if((~granV21[\modUi][\lfoIndex] ? 1) == 1) { "lfo1" } { "lfo2" };
				~granV21[\params][(prefix ++ "On").asSymbol] = b.value.asInteger;
				~granV21[\updateAllVoices].value;
			});

		makeTinySliderRow.value(page, col1X, topY + 58, "Rate", \lfo1Rate, 0.001, 20, \exp, 3);
		~granV21[\sliders][\modLfoRate] = ~granV21[\sliders].removeAt(\lfo1Rate);
		~granV21[\boxes][\modLfoRate] = ~granV21[\boxes].removeAt(\lfo1Rate);

		~granV21[\sliders][\modLfoRate].action_({
			var prefix = if((~granV21[\modUi][\lfoIndex] ? 1) == 1) { "lfo1" } { "lfo2" };
			var v = ~granV21[\sliders][\modLfoRate].value.linexp(0, 1, 0.001, 20);
			~granV21[\params][(prefix ++ "Rate").asSymbol] = v;
			~granV21[\boxes][\modLfoRate].value = v;
			~granV21[\updateAllVoices].value;
		});
		~granV21[\boxes][\modLfoRate].action_({
			var prefix = if((~granV21[\modUi][\lfoIndex] ? 1) == 1) { "lfo1" } { "lfo2" };
			var v = ~granV21[\boxes][\modLfoRate].value.clip(0.001, 20);
			~granV21[\params][(prefix ++ "Rate").asSymbol] = v;
			~granV21[\sliders][\modLfoRate].value = v.explin(0.001, 20, 0, 1);
			~granV21[\updateAllVoices].value;
		});

		makeTinySliderRow.value(page, col1X, topY + 88, "Depth", \lfo1Depth, 0, 1, \lin, 3);
		~granV21[\sliders][\modLfoDepth] = ~granV21[\sliders].removeAt(\lfo1Depth);
		~granV21[\boxes][\modLfoDepth] = ~granV21[\boxes].removeAt(\lfo1Depth);

		~granV21[\sliders][\modLfoDepth].action_({
			var prefix = if((~granV21[\modUi][\lfoIndex] ? 1) == 1) { "lfo1" } { "lfo2" };
			var v = ~granV21[\sliders][\modLfoDepth].value.linlin(0, 1, 0, 1);
			~granV21[\params][(prefix ++ "Depth").asSymbol] = v;
			~granV21[\boxes][\modLfoDepth].value = v;
			~granV21[\updateAllVoices].value;
		});
		~granV21[\boxes][\modLfoDepth].action_({
			var prefix = if((~granV21[\modUi][\lfoIndex] ? 1) == 1) { "lfo1" } { "lfo2" };
			var v = ~granV21[\boxes][\modLfoDepth].value.clip(0, 1);
			~granV21[\params][(prefix ++ "Depth").asSymbol] = v;
			~granV21[\sliders][\modLfoDepth].value = v;
			~granV21[\updateAllVoices].value;
		});

		StaticText(page, Rect(col1X, topY + 120, 46, 18)).string_("Shape");
		~granV21[\menus][\modLfoShape] = PopUpMenu(page, Rect(col1X + 50, topY + 118, 126, 20))
			.items_(["Sine", "Tri", "Saw", "Pulse"])
			.value_(~granV21[\params][\lfo1Shape] ? 0)
			.action_({ |pm|
				var prefix = if((~granV21[\modUi][\lfoIndex] ? 1) == 1) { "lfo1" } { "lfo2" };
				~granV21[\params][(prefix ++ "Shape").asSymbol] = pm.value;
				~granV21[\updateAllVoices].value;
			});

		// ------------------------------------------------
		// COLUMN 2 : DISPLAYED LFO ROUTING
		// ------------------------------------------------
		~granV21[\modLfoRoutingTitle] = StaticText(page, Rect(col2X, topY, 160, 20)).string_("LFO 1 Routing");

		makeTinyMenuRow.value(page, col2X, topY + 28, "Dest 1", \lfo1Dest1);
		~granV21[\menus][\modLfoDest1] = ~granV21[\menus].removeAt(\lfo1Dest1);
		~granV21[\menus][\modLfoDest1].action_({ |menu|
			var prefix = if((~granV21[\modUi][\lfoIndex] ? 1) == 1) { "lfo1" } { "lfo2" };
			~granV21[\params][(prefix ++ "Dest1").asSymbol] = menu.value;
			~granV21[\updateAllVoices].value;
		});

		makeTinySliderRow.value(page, col2X, topY + 56, "Amt 1", \lfo1Amt1, -1, 1, \lin, 3);
		~granV21[\sliders][\modLfoAmt1] = ~granV21[\sliders].removeAt(\lfo1Amt1);
		~granV21[\boxes][\modLfoAmt1] = ~granV21[\boxes].removeAt(\lfo1Amt1);

		~granV21[\sliders][\modLfoAmt1].action_({
			var prefix = if((~granV21[\modUi][\lfoIndex] ? 1) == 1) { "lfo1" } { "lfo2" };
			var v = ~granV21[\sliders][\modLfoAmt1].value.linlin(0, 1, -1, 1);
			~granV21[\params][(prefix ++ "Amt1").asSymbol] = v;
			~granV21[\boxes][\modLfoAmt1].value = v;
			~granV21[\updateAllVoices].value;
		});
		~granV21[\boxes][\modLfoAmt1].action_({
			var prefix = if((~granV21[\modUi][\lfoIndex] ? 1) == 1) { "lfo1" } { "lfo2" };
			var v = ~granV21[\boxes][\modLfoAmt1].value.clip(-1, 1);
			~granV21[\params][(prefix ++ "Amt1").asSymbol] = v;
			~granV21[\sliders][\modLfoAmt1].value = v.linlin(-1, 1, 0, 1);
			~granV21[\updateAllVoices].value;
		});

		makeTinyMenuRow.value(page, col2X, topY + 96, "Dest 2", \lfo1Dest2);
		~granV21[\menus][\modLfoDest2] = ~granV21[\menus].removeAt(\lfo1Dest2);
		~granV21[\menus][\modLfoDest2].action_({ |menu|
			var prefix = if((~granV21[\modUi][\lfoIndex] ? 1) == 1) { "lfo1" } { "lfo2" };
			~granV21[\params][(prefix ++ "Dest2").asSymbol] = menu.value;
			~granV21[\updateAllVoices].value;
		});

		makeTinySliderRow.value(page, col2X, topY + 124, "Amt 2", \lfo1Amt2, -1, 1, \lin, 3);
		~granV21[\sliders][\modLfoAmt2] = ~granV21[\sliders].removeAt(\lfo1Amt2);
		~granV21[\boxes][\modLfoAmt2] = ~granV21[\boxes].removeAt(\lfo1Amt2);

		~granV21[\sliders][\modLfoAmt2].action_({
			var prefix = if((~granV21[\modUi][\lfoIndex] ? 1) == 1) { "lfo1" } { "lfo2" };
			var v = ~granV21[\sliders][\modLfoAmt2].value.linlin(0, 1, -1, 1);
			~granV21[\params][(prefix ++ "Amt2").asSymbol] = v;
			~granV21[\boxes][\modLfoAmt2].value = v;
			~granV21[\updateAllVoices].value;
		});
		~granV21[\boxes][\modLfoAmt2].action_({
			var prefix = if((~granV21[\modUi][\lfoIndex] ? 1) == 1) { "lfo1" } { "lfo2" };
			var v = ~granV21[\boxes][\modLfoAmt2].value.clip(-1, 1);
			~granV21[\params][(prefix ++ "Amt2").asSymbol] = v;
			~granV21[\sliders][\modLfoAmt2].value = v.linlin(-1, 1, 0, 1);
			~granV21[\updateAllVoices].value;
		});

		makeTinyMenuRow.value(page, col2X, topY + 164, "Dest 3", \lfo1Dest3);
		~granV21[\menus][\modLfoDest3] = ~granV21[\menus].removeAt(\lfo1Dest3);
		~granV21[\menus][\modLfoDest3].action_({ |menu|
			var prefix = if((~granV21[\modUi][\lfoIndex] ? 1) == 1) { "lfo1" } { "lfo2" };
			~granV21[\params][(prefix ++ "Dest3").asSymbol] = menu.value;
			~granV21[\updateAllVoices].value;
		});

		makeTinySliderRow.value(page, col2X, topY + 192, "Amt 3", \lfo1Amt3, -1, 1, \lin, 3);
		~granV21[\sliders][\modLfoAmt3] = ~granV21[\sliders].removeAt(\lfo1Amt3);
		~granV21[\boxes][\modLfoAmt3] = ~granV21[\boxes].removeAt(\lfo1Amt3);

		~granV21[\sliders][\modLfoAmt3].action_({
			var prefix = if((~granV21[\modUi][\lfoIndex] ? 1) == 1) { "lfo1" } { "lfo2" };
			var v = ~granV21[\sliders][\modLfoAmt3].value.linlin(0, 1, -1, 1);
			~granV21[\params][(prefix ++ "Amt3").asSymbol] = v;
			~granV21[\boxes][\modLfoAmt3].value = v;
			~granV21[\updateAllVoices].value;
		});
		~granV21[\boxes][\modLfoAmt3].action_({
			var prefix = if((~granV21[\modUi][\lfoIndex] ? 1) == 1) { "lfo1" } { "lfo2" };
			var v = ~granV21[\boxes][\modLfoAmt3].value.clip(-1, 1);
			~granV21[\params][(prefix ++ "Amt3").asSymbol] = v;
			~granV21[\sliders][\modLfoAmt3].value = v.linlin(-1, 1, 0, 1);
			~granV21[\updateAllVoices].value;
		});

		makeTinyMenuRow.value(page, col2X, topY + 232, "Dest 4", \lfo1Dest4);
		~granV21[\menus][\modLfoDest4] = ~granV21[\menus].removeAt(\lfo1Dest4);
		~granV21[\menus][\modLfoDest4].action_({ |menu|
			var prefix = if((~granV21[\modUi][\lfoIndex] ? 1) == 1) { "lfo1" } { "lfo2" };
			~granV21[\params][(prefix ++ "Dest4").asSymbol] = menu.value;
			~granV21[\updateAllVoices].value;
		});

		makeTinySliderRow.value(page, col2X, topY + 260, "Amt 4", \lfo1Amt4, -1, 1, \lin, 3);
		~granV21[\sliders][\modLfoAmt4] = ~granV21[\sliders].removeAt(\lfo1Amt4);
		~granV21[\boxes][\modLfoAmt4] = ~granV21[\boxes].removeAt(\lfo1Amt4);

		~granV21[\sliders][\modLfoAmt4].action_({
			var prefix = if((~granV21[\modUi][\lfoIndex] ? 1) == 1) { "lfo1" } { "lfo2" };
			var v = ~granV21[\sliders][\modLfoAmt4].value.linlin(0, 1, -1, 1);
			~granV21[\params][(prefix ++ "Amt4").asSymbol] = v;
			~granV21[\boxes][\modLfoAmt4].value = v;
			~granV21[\updateAllVoices].value;
		});
		~granV21[\boxes][\modLfoAmt4].action_({
			var prefix = if((~granV21[\modUi][\lfoIndex] ? 1) == 1) { "lfo1" } { "lfo2" };
			var v = ~granV21[\boxes][\modLfoAmt4].value.clip(-1, 1);
			~granV21[\params][(prefix ++ "Amt4").asSymbol] = v;
			~granV21[\sliders][\modLfoAmt4].value = v.linlin(-1, 1, 0, 1);
			~granV21[\updateAllVoices].value;
		});

		// ------------------------------------------------
		// COLUMN 3 : MOD ENV 1 CORE
		// ------------------------------------------------
		StaticText(page, Rect(col3X, topY, 160, 20)).string_("Mod Env 1");

		makeTinySliderRow.value(page, col3X, topY + 28,  "Atk",   \modEnv1Atk,   0.001, 4, \exp, 3);
		makeTinySliderRow.value(page, col3X, topY + 58,  "Dec",   \modEnv1Dec,   0.001, 4, \exp, 3);
		makeTinySliderRow.value(page, col3X, topY + 88,  "Sus",   \modEnv1Sus,   0, 1, \lin, 3);
		makeTinySliderRow.value(page, col3X, topY + 118, "Rel",   \modEnv1Rel,   0.001, 6, \exp, 3);
		makeTinySliderRow.value(page, col3X, topY + 148, "Depth", \modEnv1Depth, 0, 1, \lin, 3);

		// ------------------------------------------------
		// COLUMN 4 : MOD ENV 1 ROUTING
		// ------------------------------------------------
		StaticText(page, Rect(col4X, topY, 180, 20)).string_("Env 1 Routing");

		makeTinyMenuRow.value(page, col4X, topY + 28,  "Dest 1", \modEnv1Dest1);
		makeTinySliderRow.value(page, col4X, topY + 56, "Amt 1", \modEnv1Amt1, -1, 1, \lin, 3);

		makeTinyMenuRow.value(page, col4X, topY + 96,  "Dest 2", \modEnv1Dest2);
		makeTinySliderRow.value(page, col4X, topY + 124, "Amt 2", \modEnv1Amt2, -1, 1, \lin, 3);

		makeTinyMenuRow.value(page, col4X, topY + 164, "Dest 3", \modEnv1Dest3);
		makeTinySliderRow.value(page, col4X, topY + 192, "Amt 3", \modEnv1Amt3, -1, 1, \lin, 3);

		makeTinyMenuRow.value(page, col4X, topY + 232, "Dest 4", \modEnv1Dest4);
		makeTinySliderRow.value(page, col4X, topY + 260, "Amt 4", \modEnv1Amt4, -1, 1, \lin, 3);

		~granV21[\refreshModLfoUi].value;

		~granV21[\pages].add(page);
	}.value;


	// page 8 - Perform
	{
		var page = CompositeView(~granV21[\win], Rect(16, 330, 1088, 410))
			.background_(Color.white);
var targets = [
	[\aPosition, "aPosition"],
	[\bPosition, "bPosition"],
	[\regionStart, "regionStart"],
	[\regionEnd, "regionEnd"],
	[\aJitter, "aJitter"],
	[\bJitter, "bJitter"],
	[\aDensity, "aDensity"],
	[\bDensity, "bDensity"],
	[\aScanWidth, "aScanWidth"],
	[\bScanWidth, "bScanWidth"],
	[\rateA, "rateA"],
	[\rateB, "rateB"],
	[\lpf, "lpf"],
	[\hpf, "hpf"],
	[\oscCutoff, "oscCutoff"],
	[\masterAmp, "masterAmp"]
];

var targetSymbols = targets.collect { |pair| pair[0] };
var targetLabels = targets.collect { |pair| pair[1] };

		StaticText(page, Rect(12, 10, 250, 20)).string_("Perform / XY / MIDI");

		StaticText(page, Rect(12, 42, 80, 20)).string_("X Target");
PopUpMenu(page, Rect(95, 42, 160, 20))
	.items_(targetLabels)
	.value_(targetSymbols.indexOfEqual(~granV21[\params][\xyXTarget]) ? 0)
	.action_({ |pm|
		~granV21[\params][\xyXTarget] = targetSymbols[pm.value];
	});

StaticText(page, Rect(270, 42, 80, 20)).string_("Y Target");
PopUpMenu(page, Rect(352, 42, 160, 20))
	.items_(targetLabels)
	.value_(targetSymbols.indexOfEqual(~granV21[\params][\xyYTarget]) ? 0)
	.action_({ |pm|
		~granV21[\params][\xyYTarget] = targetSymbols[pm.value];
	});

		~granV21[\xyView] = UserView(page, Rect(12, 80, 360, 260))
			.background_(Color.black);

		~granV21[\xyView].drawFunc_({
			var p = ~granV21[\params];
			var b = ~granV21[\xyView].bounds;
			var x = p[\xyX] * b.width;
			var y = (1 - p[\xyY]) * b.height;

			Pen.fillColor = Color.black;
			Pen.fillRect(Rect(0, 0, b.width, b.height));

			Pen.color = Color.gray(0.25);
			Pen.moveTo(Point(b.width * 0.5, 0));
			Pen.lineTo(Point(b.width * 0.5, b.height));
			Pen.stroke;
			Pen.moveTo(Point(0, b.height * 0.5));
			Pen.lineTo(Point(b.width, b.height * 0.5));
			Pen.stroke;

			Pen.fillColor = Color.cyan.alpha_(0.85);
			Pen.fillOval(Rect.aboutPoint(Point(x, y), 8, 8));
		});

		~granV21[\xyView].mouseDownAction_({ |view, x, y|
			var p = ~granV21[\params];
			p[\xyX] = (x / view.bounds.width).clip(0, 1);
			p[\xyY] = (1 - (y / view.bounds.height)).clip(0, 1);
			~granV21[\applyXYTarget].value(p[\xyXTarget], p[\xyX]);
			~granV21[\applyXYTarget].value(p[\xyYTarget], p[\xyY]);
			view.refresh;
		});

		~granV21[\xyView].mouseMoveAction_({ |view, x, y|
			var p = ~granV21[\params];
			p[\xyX] = (x / view.bounds.width).clip(0, 1);
			p[\xyY] = (1 - (y / view.bounds.height)).clip(0, 1);
			~granV21[\applyXYTarget].value(p[\xyXTarget], p[\xyX]);
			~granV21[\applyXYTarget].value(p[\xyYTarget], p[\xyY]);
			view.refresh;
		});

		StaticText(page, Rect(400, 90, 620, 180))
			.string_(
				"MIDI behavior in 2.1:\n"
				++ "• note-on = create voice\n"
				++ "• note-off = release voice\n"
				++ "• overlapping notes can coexist\n"
				++ "• if a note retriggers, the old one is replaced cleanly\n\n"
				++ "Suggested XY assignments:\n"
				++ "• X position / Y aJitter\n"
				++ "• X position / Y lpf\n"
				++ "• X aDensity / Y bDensity\n"
				++ "• X regionStart / Y regionEnd"
			);

		~granV21[\pages].add(page);
	}.value;

	~granV21[\showPage].value(0);
~granV21[\win].front;
~granV21[\syncControls].value;
~granV21[\startVisualizer].value;

	// --------------------------------------------------------
	// free
	// --------------------------------------------------------
	~granV21[\free] = {
		try { ~granV21[\panic].value } { };
		~granV21[\stopVisualizer].value;

		if(~granV21[\recSynth].notNil) {
			try { ~granV21[\recSynth].free } { };
			~granV21[\recSynth] = nil;
		};

		if(~granV21[\sampleBuf].notNil) {
			try { ~granV21[\sampleBuf].free } { };
			~granV21[\sampleBuf] = nil;
		};

		if(~granV21[\liveBuf].notNil) {
			try { ~granV21[\liveBuf].free } { };
			~granV21[\liveBuf] = nil;
		};

		if(~granV21[\midiObjs].notNil) {
			~granV21[\midiObjs].do { |obj|
				try { obj.free } { };
			};
		};

		if(~granV21[\win].notNil) {
			try { ~granV21[\win].close } { };
		};
	};

});
)
