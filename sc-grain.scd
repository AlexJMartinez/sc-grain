(
// ============================================================
// LEMONDROP-STYLE GRANULAR APP V3.0
// - 4 voice polyphony with deterministic voice stealing
// - independent GR1 / GR2 file or live-history sources
// - dual granular engines + waveform oscillator
// - ENV/LFO/SEQ/X/Y/MIDI/CC modulation matrix, three slots per target
// - Lemondrop-style FX1/FX2 bus with compressor
// - schema-versioned presets with V2.1 migration
// - GUI controls for every user-facing engine feature
// - Auto Drone mode for immediate sample granulation without external MIDI
// ============================================================

s.options.memSize = 2.pow(20);
s.options.numWireBufs = 1024;
// Uncomment if you want to force a specific output device.
// Server.default.options.outDevice_("Scarlett Solo 4th Gen");

s.waitForBoot({
	var app, modTargetCount, slotCount;
	var makeMenuRow, makeToggleRow, makeSliderRow;
	var makeSmallSliderRow, makeSmallMenuRow, makeModButton;
	var makeGranPage, makeLfoBlock, makeSeqStepControls;
	var sourceItems, waveItems, filterItems, fx1Items, fx2Items;
	var lfoShapeItems, syncDivItems, modSourceItems;
	var pageNames;

	if(~lemonV3.notNil) {
		try { ~lemonV3[\free].value } { };
	};

	~lemonV3 = IdentityDictionary.new;
	app = ~lemonV3;
	app[\schemaVersion] = 3;
	app[\maxVoices] = 4;
	app[\voiceSerial] = 0;
	app[\droneKey] = \autoDroneVoice;
	app[\selectedGran] = 1;
	app[\selectedModTarget] = \gr1Position;
	app[\learnSlotIndex] = nil;
	app[\midiClockCount] = 0;
	app[\midiClockStart] = nil;
	app[\waveData] = FloatArray.newClear(0);
	app[\midiObjs] = List.new;
	app[\voices] = IdentityDictionary.new;
	app[\ccValues] = Array.fill(128, 0.0);
	app[\polyAftertouch] = IdentityDictionary.new;
	app[\pages] = List.new;
	app[\tabButtons] = List.new;
	app[\sliders] = IdentityDictionary.new;
	app[\sliderSpecs] = IdentityDictionary.new;
	app[\boxes] = IdentityDictionary.new;
	app[\toggles] = IdentityDictionary.new;
	app[\menus] = IdentityDictionary.new;
	app[\labels] = IdentityDictionary.new;
	app[\modIndicators] = IdentityDictionary.new;
	app[\seqStepControls] = List.new;
	app[\seqStepLabels] = List.new;
	app[\seqGuiPhase] = 0.0;
	app[\seqGuiStep] = nil;
	app[\seqGuiOffset] = 0;
	app[\grainDots1] = List.new;
	app[\grainDots2] = List.new;
	app[\visTime] = 0.0;
	app[\visRunning] = false;
	app[\presetStatus] = "Preset: V3 initialized";
	app[\deferGui] = { |func|
		AppClock.sched(0, {
			if(app.notNil and: { app[\win].notNil }) { func.value };
			nil
		});
	};

	sourceItems = ["File", "Live History"];
	waveItems = ["Sine", "Saw", "Pulse", "Triangle", "Noise"];
	filterItems = ["Bypass", "Lowpass", "Highpass", "Bandpass", "Notch"];
	fx1Items = ["Off", "Flanger+Dist", "Chorus", "Phaser"];
	fx2Items = ["Off", "Delay", "Reverb", "Delay + Reverb"];
	lfoShapeItems = ["Saw", "Rev Saw", "Triangle", "Pos Tri", "Sine", "Pos Sine", "Square", "Pos Square", "Random"];
	syncDivItems = ["1/16", "1/8", "1/4", "1/2", "1 Bar", "2 Bars", "4 Bars"];
	modSourceItems = ["Off", "ENV1", "ENV2", "LFO1", "LFO2", "SEQ", "X", "Y", "Velocity", "Mod Wheel", "Aftertouch", "Pitch Bend", "CC"];

	app[\modTargets] = [
		\gr1Position, \gr2Position,
		\gr1Density, \gr2Density,
		\gr1GrainSize, \gr2GrainSize,
		\gr1Pitch, \gr2Pitch,
		\gr1Amp, \gr2Amp,
		\oscAmp, \oscPitch, \oscCutoff,
		\filter1Cutoff, \filter2Cutoff,
		\fx1Mix, \delayMix, \reverbMix,
		\masterAmp, \gr1PanRand, \gr2PanRand,
		\seqDepth
	];
	app[\modTargetLabels] = [
		"GR1 Position", "GR2 Position",
		"GR1 Density", "GR2 Density",
		"GR1 Grain Size", "GR2 Grain Size",
		"GR1 Pitch", "GR2 Pitch",
		"GR1 Level", "GR2 Level",
		"OSC Level", "OSC Pitch", "OSC Cutoff",
		"Filter 1 Cutoff", "Filter 2 Cutoff",
		"FX1 Mix", "Delay Mix", "Reverb Mix",
		"Master Level", "GR1 Pan Random", "GR2 Pan Random",
		"SEQ Depth"
	];

	modTargetCount = app[\modTargets].size;
	slotCount = modTargetCount * 3;
	app[\slotCount] = slotCount;

	app[\params] = (
		schemaVersion: 3,
		masterAmp: 0.35,
		rootMidi: 60,
		glide: 0.03,
		bpm: 120.0,
		clockSource: 0,       // 0 internal, 1 MIDI clock follow
		midiChannel: 0,       // 0 omni, 1-16 channels
		bendRange: 2.0,
		autoDrone: 1,
		droneNote: 60,
		droneVelocity: 100,
		pitchBend: 0.0,
		modWheel: 0.0,
		aftertouch: 0.0,
		sustainOn: 0,
		xyX: 0.5,
		xyY: 0.5,
		xyXTarget: \gr1Position,
		xyYTarget: \gr1Jitter,
		grainDotsOn: 1,

		gr1On: 1, gr1Source: 0, gr1Amp: 0.9, gr1Pitch: 0.0, gr1Detune: 0.0,
		gr1Position: 0.5, gr1LivePosition: 0.85, gr1Density: 16.0, gr1GrainCount: 16,
		gr1GrainSize: 0.11, gr1Window: 0.5, gr1Jitter: 0.04, gr1PanRand: 0.55,
		gr1Rate: 1.0, gr1RateSync: 0, gr1RateDiv: 4, gr1PlayMode: 0, gr1LoopMode: 1,
		gr1PreserveAttack: 0, gr1Pattern: 0, gr1RegionStart: 0.0, gr1RegionEnd: 1.0,
		gr1LoopStart: 0.0, gr1LoopEnd: 1.0,

		gr2On: 1, gr2Source: 0, gr2Amp: 0.65, gr2Pitch: -12.0, gr2Detune: 0.0,
		gr2Position: 0.5, gr2LivePosition: 0.75, gr2Density: 8.0, gr2GrainCount: 16,
		gr2GrainSize: 0.20, gr2Window: 0.5, gr2Jitter: 0.08, gr2PanRand: 0.8,
		gr2Rate: 0.5, gr2RateSync: 0, gr2RateDiv: 4, gr2PlayMode: 0, gr2LoopMode: 1,
		gr2PreserveAttack: 0, gr2Pattern: 1, gr2RegionStart: 0.0, gr2RegionEnd: 1.0,
		gr2LoopStart: 0.0, gr2LoopEnd: 1.0,

		oscOn: 0, oscAmp: 0.18, oscWave: 0, oscPitch: 0.0, oscDetune: 0.0,
		oscPulseWidth: 0.45, oscCutoff: 8000, oscRes: 0.15,

		filter1Type: 1, filter1Cutoff: 12000, filter1Res: 0.15, filter1Width: 0.5,
		filter2Type: 0, filter2Cutoff: 8000, filter2Res: 0.15, filter2Width: 0.5,
		filterRouting: 0,

		env1Atk: 0.01, env1Dec: 0.12, env1Sus: 0.8, env1Rel: 0.35, env1Vel: 0.35,
		env2Atk: 0.01, env2Dec: 0.22, env2Sus: 0.0, env2Rel: 0.30, env2Depth: 0.5,

		lfo1On: 0, lfo1Shape: 4, lfo1Rate: 0.35, lfo1Sync: 0, lfo1Div: 4, lfo1Depth: 0.25, lfo1Reset: 1,
		lfo2On: 0, lfo2Shape: 2, lfo2Rate: 0.18, lfo2Sync: 0, lfo2Div: 5, lfo2Depth: 0.25, lfo2Reset: 1,

		seqOn: 0, seqSteps: 16, seqRate: 4.0, seqSync: 1, seqDiv: 2, seqKeyTrig: 1, seqQuantize: 0, seqDepth: 0.5,

		fx1Type: 0, fx1Mix: 0.35, fx1Rate: 0.25, fx1Depth: 0.55, fx1Drive: 0.25,
		fx2Type: 1, fx2Order: 0, delayMix: 0.20, delayTime: 0.28, delaySync: 0, delayDiv: 3,
		delayFb: 0.30, delayFilter: 9000, delayPingPong: 0,
		reverbMix: 0.18, reverbPreDelay: 0.02, reverbDecay: 0.75, reverbDamp: 0.35,
		liveInputToFx: 0.0, compressorAmt: 0.25, compressorOut: 1.0
	);

	32.do { |i|
		app[\params][("seqStep" ++ (i + 1)).asSymbol] = if(i.even) { 0.35 } { -0.25 };
	};

	app[\view] = (
		zoom: 1.0,
		scroll: 0.0,
		editMode: \position,
		waveSource: 0
	);

	app[\samplePaths] = (
		gr1: nil,
		gr2: nil
	);

	app[\sampleLabels] = (
		gr1: "GR1: Silent file buffer",
		gr2: "GR2: Silent file buffer"
	);

	app[\makeDefaultSlots] = {
		var slots = IdentityDictionary.new;
		app[\modTargets].do { |target|
			slots[target] = Array.fill(3, { (source: 0, amount: 0.0, cc: 1) });
		};
		slots
	};
	app[\modSlots] = app[\makeDefaultSlots].value;

	// --------------------------------------------------------
	// SynthDefs
	// --------------------------------------------------------
	SynthDef(\lemonLiveRecorderV3, { |bufnum=0, in=0, recLevel=1.0|
		RecordBuf.ar(SoundIn.ar(in), bufnum, recLevel: recLevel, preLevel: 0.0, loop: 1);
	}).add;

	SynthDef(\lemonVoiceV3, {
		|out=0, gate=1, gr1Bufnum=0, gr2Bufnum=0, liveBufnum=0,
		masterAmp=0.35, rootRatio=1.0, glide=0.03, velocity=1.0, pitchBend=0.0, bendRange=2.0,
		modWheel=0.0, aftertouch=0.0, xyX=0.5, xyY=0.5, bpm=120.0,

		gr1On=1, gr1Source=0, gr1Amp=0.9, gr1Pitch=0.0, gr1Detune=0.0, gr1Position=0.5, gr1LivePosition=0.85,
		gr1Density=16, gr1GrainCount=16, gr1GrainSize=0.11, gr1Window=0.5, gr1Jitter=0.04, gr1PanRand=0.55,
		gr1Rate=1.0, gr1RateSync=0, gr1RateDiv=4, gr1PlayMode=0, gr1LoopMode=1, gr1PreserveAttack=0, gr1Pattern=0,
		gr1RegionStart=0, gr1RegionEnd=1, gr1LoopStart=0, gr1LoopEnd=1,

		gr2On=1, gr2Source=0, gr2Amp=0.65, gr2Pitch=(-12), gr2Detune=0.0, gr2Position=0.5, gr2LivePosition=0.75,
		gr2Density=8, gr2GrainCount=16, gr2GrainSize=0.20, gr2Window=0.5, gr2Jitter=0.08, gr2PanRand=0.8,
		gr2Rate=0.5, gr2RateSync=0, gr2RateDiv=4, gr2PlayMode=0, gr2LoopMode=1, gr2PreserveAttack=0, gr2Pattern=1,
		gr2RegionStart=0, gr2RegionEnd=1, gr2LoopStart=0, gr2LoopEnd=1,

		oscOn=0, oscAmp=0.18, oscWave=0, oscPitch=0, oscDetune=0, oscPulseWidth=0.45, oscCutoff=8000, oscRes=0.15,
		filter1Type=1, filter1Cutoff=12000, filter1Res=0.15, filter1Width=0.5,
		filter2Type=0, filter2Cutoff=8000, filter2Res=0.15, filter2Width=0.5, filterRouting=0,
		env1Atk=0.01, env1Dec=0.12, env1Sus=0.8, env1Rel=0.35, env1Vel=0.35,
		env2Atk=0.01, env2Dec=0.22, env2Sus=0.0, env2Rel=0.30, env2Depth=0.5,
		lfo1On=0, lfo1Shape=4, lfo1Rate=0.35, lfo1Sync=0, lfo1Div=4, lfo1Depth=0.25, lfo1Reset=1,
		lfo2On=0, lfo2Shape=2, lfo2Rate=0.18, lfo2Sync=0, lfo2Div=5, lfo2Depth=0.25, lfo2Reset=1,
		seqOn=0, seqSteps=16, seqRate=4.0, seqSync=1, seqDiv=2, seqKeyTrig=1, seqQuantize=0, seqDepth=0.5,
		fx1Type=0, fx1Mix=0.35, fx1Rate=0.25, fx1Depth=0.55, fx1Drive=0.25,
		fx2Type=1, fx2Order=0, delayMix=0.20, delayTime=0.28, delaySync=0, delayDiv=3, delayFb=0.30, delayFilter=9000, delayPingPong=0,
		reverbMix=0.18, reverbPreDelay=0.02, reverbDecay=0.75, reverbDamp=0.35,
		liveInputToFx=0.0, compressorAmt=0.25, compressorOut=1.0|

		var modSrc, modAmt, modCcVal, seqVals;
		var env1, env2, velAmp, bendRatio, ratioLag;
		var divBeats, lfoRate1, lfoRate2, seqRateHz, lfoPhase1, lfoPhase2;
		var lfo1, lfo2, seqTrig, seqIndex, seqOffset, seqRaw, seq;
		var sourceFor, modFor, applyFilter, makeGrain;
		var gr1, gr2, oscFreq, osc, raw, f1, f2, series, parallel, sig;
		var fx1Wet, fx2Wet, fx2Dry, delTime, liveFx;
		var delayStage, reverbStage, delayOnly, reverbOnly, delayThenReverb, reverbThenDelay;
		var threshold;

		modSrc = NamedControl.kr(\modSrc, Array.fill(66, 0));
		modAmt = NamedControl.kr(\modAmt, Array.fill(66, 0));
		modCcVal = NamedControl.kr(\modCcVal, Array.fill(66, 0));
		seqVals = NamedControl.kr(\seqVals, Array.fill(32, 0));

		divBeats = Select.kr(lfo1Div.clip(0, 6), [0.25, 0.5, 1, 2, 4, 8, 16]);
		lfoRate1 = Select.kr(lfo1Sync.clip(0, 1), [lfo1Rate.max(0.001), (bpm / 60) / divBeats.max(0.001)]);
		divBeats = Select.kr(lfo2Div.clip(0, 6), [0.25, 0.5, 1, 2, 4, 8, 16]);
		lfoRate2 = Select.kr(lfo2Sync.clip(0, 1), [lfo2Rate.max(0.001), (bpm / 60) / divBeats.max(0.001)]);

		lfoPhase1 = Select.kr(lfo1Reset.clip(0, 1), [Rand(0, 2pi), 0]);
		lfoPhase2 = Select.kr(lfo2Reset.clip(0, 1), [Rand(0, 2pi), 0]);

		env1 = EnvGen.kr(
			Env.adsr(env1Atk.max(0.001), env1Dec.max(0.001), env1Sus.clip(0, 1), env1Rel.max(0.001)),
			gate,
			doneAction: 2
		);

		env2 = EnvGen.kr(
			Env.adsr(env2Atk.max(0.001), env2Dec.max(0.001), env2Sus.clip(0, 1), env2Rel.max(0.001)),
			gate
		) * env2Depth.clip(0, 1);

		lfo1 = Select.kr(lfo1Shape.clip(0, 8), [
			LFSaw.kr(lfoRate1, lfoPhase1 / 2pi),
			LFSaw.kr(lfoRate1, lfoPhase1 / 2pi).neg,
			LFTri.kr(lfoRate1, lfoPhase1 / 2pi),
			LFTri.kr(lfoRate1, lfoPhase1 / 2pi).linlin(-1, 1, 0, 1),
			SinOsc.kr(lfoRate1, lfoPhase1),
			SinOsc.kr(lfoRate1, lfoPhase1).linlin(-1, 1, 0, 1),
			LFPulse.kr(lfoRate1, 0, 0.5).linlin(0, 1, -1, 1),
			LFPulse.kr(lfoRate1, 0, 0.5),
			LFNoise0.kr(lfoRate1)
		]) * lfo1Depth.clip(0, 1) * lfo1On.clip(0, 1);

		lfo2 = Select.kr(lfo2Shape.clip(0, 8), [
			LFSaw.kr(lfoRate2, lfoPhase2 / 2pi),
			LFSaw.kr(lfoRate2, lfoPhase2 / 2pi).neg,
			LFTri.kr(lfoRate2, lfoPhase2 / 2pi),
			LFTri.kr(lfoRate2, lfoPhase2 / 2pi).linlin(-1, 1, 0, 1),
			SinOsc.kr(lfoRate2, lfoPhase2),
			SinOsc.kr(lfoRate2, lfoPhase2).linlin(-1, 1, 0, 1),
			LFPulse.kr(lfoRate2, 0, 0.5).linlin(0, 1, -1, 1),
			LFPulse.kr(lfoRate2, 0, 0.5),
			LFNoise0.kr(lfoRate2)
		]) * lfo2Depth.clip(0, 1) * lfo2On.clip(0, 1);

		divBeats = Select.kr(seqDiv.clip(0, 6), [0.25, 0.5, 1, 2, 4, 8, 16]);
		seqRateHz = Select.kr(seqSync.clip(0, 1), [seqRate.max(0.001), (bpm / 60) / divBeats.max(0.001)]);
		seqTrig = Impulse.kr(seqRateHz.max(0.001));
		seqOffset = Select.kr(seqKeyTrig.clip(0, 1), [Rand(0, 31), 0]);
		seqIndex = (PulseCount.kr(seqTrig) + seqOffset) % seqSteps.clip(1, 32);
		seqRaw = Select.kr(seqIndex.clip(0, 31), seqVals);
		seq = Select.kr(seqQuantize.clip(0, 1), [seqRaw, seqRaw.round(0.25)]) * seqDepth.clip(0, 1) * seqOn.clip(0, 1);

		sourceFor = { |src, ccVal|
			Select.kr(src.clip(0, 12), [
				0,
				env1,
				env2,
				lfo1,
				lfo2,
				seq,
				xyX.linlin(0, 1, -1, 1),
				xyY.linlin(0, 1, -1, 1),
				velocity.clip(0, 1).linlin(0, 1, -1, 1),
				modWheel.clip(0, 1).linlin(0, 1, -1, 1),
				aftertouch.clip(0, 1).linlin(0, 1, -1, 1),
				pitchBend.clip(-1, 1),
				ccVal.clip(0, 1).linlin(0, 1, -1, 1)
			])
		};

		modFor = { |targetIndex|
			var base = targetIndex * 3;
			(
				sourceFor.value(modSrc[base], modCcVal[base]) * modAmt[base].clip(-1, 1)
				+ (sourceFor.value(modSrc[base + 1], modCcVal[base + 1]) * modAmt[base + 1].clip(-1, 1))
				+ (sourceFor.value(modSrc[base + 2], modCcVal[base + 2]) * modAmt[base + 2].clip(-1, 1))
			).clip(-1, 1)
		};

		applyFilter = { |inSig, type, cutoff, res, width|
			var rq = (1.0 - res.clip(0, 0.98)).max(0.02);
			SelectX.ar(type.clip(0, 4), [
				inSig,
				RLPF.ar(inSig, cutoff.clip(20, 20400), rq),
				RHPF.ar(inSig, cutoff.clip(20, 20400), rq),
				BPF.ar(inSig, cutoff.clip(20, 20400), width.linlin(0, 1, 0.05, 1.0).clip(0.02, 1.0)),
				BRF.ar(inSig, cutoff.clip(20, 20400), width.linlin(0, 1, 0.05, 1.0).clip(0.02, 1.0))
			])
		};

		bendRatio = (pitchBend.clip(-1, 1) * bendRange.clip(0, 12)).midiratio;
		ratioLag = Lag.kr(rootRatio * bendRatio, glide.max(0.001));
		velAmp = velocity.clip(0, 1).linlin(0, 1, (1 - env1Vel.clip(0, 1)), 1);

		makeGrain = { |on, sourceMode, fileBuf, liveBuf, amp, pitch, detune, position, livePosition,
			density, grainCount, grainSize, window, jitter, panRand, rate, rateSync, rateDiv,
			playMode, loopMode, preserveAttack, pattern, regionStart, regionEnd, loopStart, loopEnd,
			modPos, modDensity, modSize, modPitch, modAmp, modPan|

			var playBuf, bdur, regStart, regEnd, lpStart, lpEnd, lpLen;
			var basePos, moving, ping, usePos, sourcePos, rateMul, syncedRate;
			var dur, maxDensity, trigDensity, trig, pan, grainRate, sig, attackSig;

			playBuf = Select.kr(sourceMode.clip(0, 1), [fileBuf, liveBuf]);
			bdur = BufDur.kr(playBuf).max(0.001);

			regStart = regionStart.clip(0, 0.999);
			regEnd = regionEnd.clip(regStart + 0.001, 1);
			lpStart = loopStart.clip(regStart, regEnd - 0.001);
			lpEnd = loopEnd.clip(lpStart + 0.001, regEnd);
			lpLen = (lpEnd - lpStart).max(0.001);

			basePos = Select.kr(sourceMode.clip(0, 1), [position, livePosition]);
			basePos = (basePos + (modPos * 0.5)).clip(0, 1);

			syncedRate = Select.kr(rateDiv.clip(0, 6), [4, 2, 1, 0.5, 0.25, 0.125, 0.0625]) * (bpm / 120);
			rateMul = Select.kr(rateSync.clip(0, 1), [rate, syncedRate]);

			moving = Wrap.kr(basePos + LFSaw.kr(rateMul.abs.max(0.001) * 0.1).range(0, 1), 0, 1);
			ping = (basePos + LFTri.kr(rateMul.abs.max(0.001) * 0.1).range(-0.5, 0.5)).clip(0, 1);
			usePos = Select.kr(playMode.clip(0, 1), [basePos, Select.kr(loopMode.clip(0, 2), [basePos, moving, ping])]);
			sourcePos = (lpStart + (usePos * lpLen)).clip(0, 1);

			dur = (grainSize * window.linlin(0, 1, 0.55, 1.45)).clip(0.005, 2.0);
			maxDensity = (grainCount.clip(1, 16) / dur.max(0.005)).clip(0.1, 200);
			trigDensity = (density * (modDensity.linexp(-1, 1, 0.25, 4.0))).clip(0.1, maxDensity);
			trig = Select.kr(pattern.clip(0, 2), [
				Impulse.kr(trigDensity),
				Dust.kr(trigDensity),
				Impulse.kr(trigDensity) + Dust.kr(trigDensity * 0.35)
			]);

			pan = TRand.kr(0 - (panRand + (modPan * 0.5)).clip(0, 1), (panRand + (modPan * 0.5)).clip(0, 1), trig);
			grainRate = ratioLag
				* ((pitch + detune + (modPitch * 24)).clip(-48, 48)).midiratio
				* rateMul
				+ TRand.kr(0 - jitter.clip(0, 1), jitter.clip(0, 1), trig);

			sig = GrainBuf.ar(
				numChannels: 2,
				trigger: trig,
				dur: dur,
				sndbuf: playBuf,
				rate: grainRate,
				pos: sourcePos,
				interp: 4,
				pan: pan
			);

			attackSig = HPF.ar(PlayBuf.ar(1, playBuf, grainRate, trig, sourcePos * BufFrames.kr(playBuf), loop: 0) ! 2, 1200) * 0.15;
			(sig + (attackSig * preserveAttack.clip(0, 1))) * amp * (modAmp.linexp(-1, 1, 0.25, 2.0)) * on.clip(0, 1)
		};

		gr1 = makeGrain.value(
			gr1On, gr1Source, gr1Bufnum, liveBufnum, gr1Amp, gr1Pitch, gr1Detune, gr1Position, gr1LivePosition,
			gr1Density, gr1GrainCount, gr1GrainSize, gr1Window, gr1Jitter, gr1PanRand, gr1Rate, gr1RateSync, gr1RateDiv,
			gr1PlayMode, gr1LoopMode, gr1PreserveAttack, gr1Pattern, gr1RegionStart, gr1RegionEnd, gr1LoopStart, gr1LoopEnd,
			modFor.value(0), modFor.value(2), modFor.value(4), modFor.value(6), modFor.value(8), modFor.value(19)
		);

		gr2 = makeGrain.value(
			gr2On, gr2Source, gr2Bufnum, liveBufnum, gr2Amp, gr2Pitch, gr2Detune, gr2Position, gr2LivePosition,
			gr2Density, gr2GrainCount, gr2GrainSize, gr2Window, gr2Jitter, gr2PanRand, gr2Rate, gr2RateSync, gr2RateDiv,
			gr2PlayMode, gr2LoopMode, gr2PreserveAttack, gr2Pattern, gr2RegionStart, gr2RegionEnd, gr2LoopStart, gr2LoopEnd,
			modFor.value(1), modFor.value(3), modFor.value(5), modFor.value(7), modFor.value(9), modFor.value(20)
		);

		oscFreq = 60.midicps * ratioLag * ((oscPitch + oscDetune + (modFor.value(11) * 24)).clip(-48, 48)).midiratio;
		osc = Select.ar(oscWave.clip(0, 4), [
			SinOsc.ar(oscFreq),
			Saw.ar(oscFreq),
			Pulse.ar(oscFreq, oscPulseWidth.clip(0.05, 0.95)),
			LFTri.ar(oscFreq),
			PinkNoise.ar(0.55)
		]);
		osc = RLPF.ar(osc ! 2, (oscCutoff * modFor.value(12).linexp(-1, 1, 0.25, 4.0)).clip(80, 20400), (1 - oscRes.clip(0, 0.98)).max(0.02));
		osc = osc * oscAmp * modFor.value(10).linexp(-1, 1, 0.25, 2.0) * oscOn.clip(0, 1);

		raw = (gr1 + gr2 + osc) * env1 * velAmp;
		liveFx = SoundIn.ar(0) ! 2 * liveInputToFx.clip(0, 1);
		raw = raw + liveFx;

		f1 = applyFilter.value(raw, filter1Type, filter1Cutoff * modFor.value(13).linexp(-1, 1, 0.25, 4.0), filter1Res, filter1Width);
		f2 = applyFilter.value(raw, filter2Type, filter2Cutoff * modFor.value(14).linexp(-1, 1, 0.25, 4.0), filter2Res, filter2Width);
		series = applyFilter.value(f1, filter2Type, filter2Cutoff * modFor.value(14).linexp(-1, 1, 0.25, 4.0), filter2Res, filter2Width);
		parallel = (f1 + f2) * 0.5;
		sig = SelectX.ar(filterRouting.clip(0, 1), [series, parallel]);

		fx1Wet = Select.ar(fx1Type.clip(0, 3), [
			sig,
			(DelayC.ar(sig, 0.03, SinOsc.kr(fx1Rate.max(0.01)).range(0.001, fx1Depth.linlin(0, 1, 0.004, 0.024))) * (1 + (fx1Drive * 12))).tanh,
			sig + DelayC.ar(sig, 0.05, SinOsc.kr(fx1Rate.max(0.01)).range(0.006, fx1Depth.linlin(0, 1, 0.010, 0.040))) * 0.65,
			AllpassC.ar(sig, 0.04, SinOsc.kr(fx1Rate.max(0.01)).range(0.001, fx1Depth.linlin(0, 1, 0.006, 0.034)), 0.22)
		]);
		sig = SelectX.ar((fx1Mix + (modFor.value(15) * 0.5)).clip(0, 1), [sig, fx1Wet]);

		divBeats = Select.kr(delayDiv.clip(0, 6), [0.25, 0.5, 1, 2, 4, 8, 16]);
		delTime = Select.kr(delaySync.clip(0, 1), [delayTime.clip(0.001, 4), ((60 / bpm.max(1)) * divBeats).clip(0.001, 4)]);
		fx2Dry = sig;
		delayStage = { |inSig|
			var wet = CombC.ar(inSig, 4.0, delTime, (delayFb.clip(0, 0.95) * 7.0).max(0.001));
			wet = SelectX.ar(delayPingPong.clip(0, 1), [wet, [wet[1], wet[0]]]);
			wet = LPF.ar(wet, delayFilter.clip(80, 20400));
			SelectX.ar((delayMix + (modFor.value(16) * 0.5)).clip(0, 1), [inSig, wet])
		};
		reverbStage = { |inSig|
			var revIn, wet;
			revIn = DelayC.ar(inSig, 0.5, reverbPreDelay.clip(0, 0.5));
			wet = FreeVerb2.ar(revIn[0], revIn[1], 1.0, reverbDecay.clip(0, 1), reverbDamp.clip(0, 1));
			SelectX.ar((reverbMix + (modFor.value(17) * 0.5)).clip(0, 1), [inSig, wet])
		};
		delayOnly = delayStage.value(fx2Dry);
		reverbOnly = reverbStage.value(fx2Dry);
		delayThenReverb = reverbStage.value(delayOnly);
		reverbThenDelay = delayStage.value(reverbOnly);
		fx2Wet = Select.ar(fx2Type.clip(0, 3), [
			fx2Dry,
			delayOnly,
			reverbOnly,
			Select.ar(fx2Order.clip(0, 1), [delayThenReverb, reverbThenDelay])
		]);

		threshold = compressorAmt.linexp(0, 1, 1.0, 0.18);
		sig = Compander.ar(fx2Wet, fx2Wet, thresh: threshold, slopeBelow: 1, slopeAbove: 0.45, clampTime: 0.01, relaxTime: 0.16);
		sig = sig * masterAmp * modFor.value(18).linexp(-1, 1, 0.25, 2.0) * compressorOut;
		Out.ar(out, Limiter.ar(sig, 0.98));
	}).add;

	s.sync;

	// --------------------------------------------------------
	// Buffers
	// --------------------------------------------------------
	app[\emptyBuf] = Buffer.alloc(s, s.sampleRate.asInteger.max(44100), 1);
	app[\gr1Buf] = app[\emptyBuf];
	app[\gr2Buf] = app[\emptyBuf];
	app[\liveBuf] = Buffer.alloc(s, (s.sampleRate * 30).asInteger.max(44100), 1);
	app[\liveRecorder] = Synth(\lemonLiveRecorderV3, [\bufnum, app[\liveBuf], \in, 0]);

	// --------------------------------------------------------
	// Helpers: modulation and voice args
	// --------------------------------------------------------
	app[\slotArrays] = {
		var src = Array.fill(slotCount, 0);
		var amt = Array.fill(slotCount, 0.0);
		var ccVal = Array.fill(slotCount, 0.0);

		app[\modTargets].do { |target, ti|
			var slots = app[\modSlots][target];
			3.do { |si|
				var idx = (ti * 3) + si;
				var slot = slots[si];
				var cc = (slot[\cc] ? 1).asInteger.clip(0, 127);
				src[idx] = (slot[\source] ? 0).asFloat;
				amt[idx] = (slot[\amount] ? 0.0).asFloat;
				ccVal[idx] = app[\ccValues][cc] ? 0.0;
			};
		};

		(src: src, amt: amt, ccVal: ccVal)
	};

	app[\seqArray] = {
		Array.fill(32, { |i| app[\params][("seqStep" ++ (i + 1)).asSymbol] ? 0.0 })
	};

	app[\voiceArgs] = { |note|
		var p = app[\params];
		var slotArrays = app[\slotArrays].value;
		var info = app[\voices][note];
		var isDrone = note == app[\droneKey];
		var actualNote = if(isDrone) {
			(p[\droneNote] ? p[\rootMidi]).asInteger.clip(0, 127)
		} {
			if(info.notNil and: { info[\note].notNil }) { info[\note] } { note }
		};
		var velocity = if(isDrone) {
			((p[\droneVelocity] ? 100) / 127).clip(0.0, 1.0)
		} {
			if(info.notNil) { info[\velocity] ? 1.0 } { 1.0 }
		};
		var noteAfter = if(isDrone.not and: { app[\polyAftertouch][actualNote].notNil }) { app[\polyAftertouch][actualNote] } { p[\aftertouch] };
		var rootRatio = (actualNote - p[\rootMidi]).midiratio;

		[
			\gr1Bufnum, app[\gr1Buf],
			\gr2Bufnum, app[\gr2Buf],
			\liveBufnum, app[\liveBuf],
			\masterAmp, p[\masterAmp],
			\rootRatio, rootRatio,
			\glide, p[\glide],
			\velocity, velocity,
			\pitchBend, p[\pitchBend],
			\bendRange, p[\bendRange],
			\modWheel, p[\modWheel],
			\aftertouch, noteAfter,
			\xyX, p[\xyX],
			\xyY, p[\xyY],
			\bpm, p[\bpm],

			\gr1On, p[\gr1On], \gr1Source, p[\gr1Source], \gr1Amp, p[\gr1Amp], \gr1Pitch, p[\gr1Pitch], \gr1Detune, p[\gr1Detune],
			\gr1Position, p[\gr1Position], \gr1LivePosition, p[\gr1LivePosition], \gr1Density, p[\gr1Density], \gr1GrainCount, p[\gr1GrainCount],
			\gr1GrainSize, p[\gr1GrainSize], \gr1Window, p[\gr1Window], \gr1Jitter, p[\gr1Jitter], \gr1PanRand, p[\gr1PanRand],
			\gr1Rate, p[\gr1Rate], \gr1RateSync, p[\gr1RateSync], \gr1RateDiv, p[\gr1RateDiv], \gr1PlayMode, p[\gr1PlayMode],
			\gr1LoopMode, p[\gr1LoopMode], \gr1PreserveAttack, p[\gr1PreserveAttack], \gr1Pattern, p[\gr1Pattern],
			\gr1RegionStart, p[\gr1RegionStart], \gr1RegionEnd, p[\gr1RegionEnd], \gr1LoopStart, p[\gr1LoopStart], \gr1LoopEnd, p[\gr1LoopEnd],

			\gr2On, p[\gr2On], \gr2Source, p[\gr2Source], \gr2Amp, p[\gr2Amp], \gr2Pitch, p[\gr2Pitch], \gr2Detune, p[\gr2Detune],
			\gr2Position, p[\gr2Position], \gr2LivePosition, p[\gr2LivePosition], \gr2Density, p[\gr2Density], \gr2GrainCount, p[\gr2GrainCount],
			\gr2GrainSize, p[\gr2GrainSize], \gr2Window, p[\gr2Window], \gr2Jitter, p[\gr2Jitter], \gr2PanRand, p[\gr2PanRand],
			\gr2Rate, p[\gr2Rate], \gr2RateSync, p[\gr2RateSync], \gr2RateDiv, p[\gr2RateDiv], \gr2PlayMode, p[\gr2PlayMode],
			\gr2LoopMode, p[\gr2LoopMode], \gr2PreserveAttack, p[\gr2PreserveAttack], \gr2Pattern, p[\gr2Pattern],
			\gr2RegionStart, p[\gr2RegionStart], \gr2RegionEnd, p[\gr2RegionEnd], \gr2LoopStart, p[\gr2LoopStart], \gr2LoopEnd, p[\gr2LoopEnd],

			\oscOn, p[\oscOn], \oscAmp, p[\oscAmp], \oscWave, p[\oscWave], \oscPitch, p[\oscPitch], \oscDetune, p[\oscDetune],
			\oscPulseWidth, p[\oscPulseWidth], \oscCutoff, p[\oscCutoff], \oscRes, p[\oscRes],

			\filter1Type, p[\filter1Type], \filter1Cutoff, p[\filter1Cutoff], \filter1Res, p[\filter1Res], \filter1Width, p[\filter1Width],
			\filter2Type, p[\filter2Type], \filter2Cutoff, p[\filter2Cutoff], \filter2Res, p[\filter2Res], \filter2Width, p[\filter2Width],
			\filterRouting, p[\filterRouting],

			\env1Atk, p[\env1Atk], \env1Dec, p[\env1Dec], \env1Sus, p[\env1Sus], \env1Rel, p[\env1Rel], \env1Vel, p[\env1Vel],
			\env2Atk, p[\env2Atk], \env2Dec, p[\env2Dec], \env2Sus, p[\env2Sus], \env2Rel, p[\env2Rel], \env2Depth, p[\env2Depth],

			\lfo1On, p[\lfo1On], \lfo1Shape, p[\lfo1Shape], \lfo1Rate, p[\lfo1Rate], \lfo1Sync, p[\lfo1Sync],
			\lfo1Div, p[\lfo1Div], \lfo1Depth, p[\lfo1Depth], \lfo1Reset, p[\lfo1Reset],
			\lfo2On, p[\lfo2On], \lfo2Shape, p[\lfo2Shape], \lfo2Rate, p[\lfo2Rate], \lfo2Sync, p[\lfo2Sync],
			\lfo2Div, p[\lfo2Div], \lfo2Depth, p[\lfo2Depth], \lfo2Reset, p[\lfo2Reset],

			\seqOn, p[\seqOn], \seqSteps, p[\seqSteps], \seqRate, p[\seqRate], \seqSync, p[\seqSync],
			\seqDiv, p[\seqDiv], \seqKeyTrig, p[\seqKeyTrig], \seqQuantize, p[\seqQuantize], \seqDepth, p[\seqDepth],

			\fx1Type, p[\fx1Type], \fx1Mix, p[\fx1Mix], \fx1Rate, p[\fx1Rate], \fx1Depth, p[\fx1Depth], \fx1Drive, p[\fx1Drive],
			\fx2Type, p[\fx2Type], \fx2Order, p[\fx2Order], \delayMix, p[\delayMix], \delayTime, p[\delayTime], \delaySync, p[\delaySync], \delayDiv, p[\delayDiv],
			\delayFb, p[\delayFb], \delayFilter, p[\delayFilter], \delayPingPong, p[\delayPingPong],
			\reverbMix, p[\reverbMix], \reverbPreDelay, p[\reverbPreDelay], \reverbDecay, p[\reverbDecay], \reverbDamp, p[\reverbDamp],
			\liveInputToFx, p[\liveInputToFx], \compressorAmt, p[\compressorAmt], \compressorOut, p[\compressorOut],

			\modSrc, slotArrays[\src],
			\modAmt, slotArrays[\amt],
			\modCcVal, slotArrays[\ccVal],
			\seqVals, app[\seqArray].value
		]
	};

	app[\updateStatus] = {
		app[\deferGui].value({
			var p, txt;
			p = app[\params];
			txt = "Voices: " ++ app[\voices].size ++ "/" ++ app[\maxVoices]
				++ "    Sustain: " ++ if((p[\sustainOn] ? 0) == 1) { "ON" } { "OFF" }
				++ "    PB: " ++ p[\pitchBend].round(0.01)
				++ "    MW: " ++ p[\modWheel].round(0.01)
				++ "    AT: " ++ p[\aftertouch].round(0.01)
				++ "    BPM: " ++ p[\bpm].round(0.1);

			if(app[\labels][\status].notNil) { app[\labels][\status].string_(txt) };
			if(app[\labels][\presetStatus].notNil) { app[\labels][\presetStatus].string_(app[\presetStatus]) };
			if(app[\labels][\gr1Path].notNil) { app[\labels][\gr1Path].string_(app[\sampleLabels][\gr1]) };
			if(app[\labels][\gr2Path].notNil) { app[\labels][\gr2Path].string_(app[\sampleLabels][\gr2]) };
			if(app[\labels][\voiceCount].notNil) { app[\labels][\voiceCount].string_("Active voices: " ++ app[\voices].size) };
		});
	};

	app[\updateModIndicators] = {
		app[\deferGui].value({
			app[\modIndicators].keysValuesDo { |target, label|
				var active = app[\modSlots][target].any { |slot| ((slot[\source] ? 0) != 0) and: { (slot[\amount] ? 0.0).abs > 0.0001 } };
				label.string_(if(active) { "MOD" } { "---" });
				label.stringColor_(if(active) { Color(0.85, 0.62, 0.0) } { Color.gray(0.55) });
			};
			if(app[\refreshModEditor].notNil) { app[\refreshModEditor].value };
		});
	};

	app[\updateAllVoices] = {
		app[\voices].keysValuesDo { |note, info|
			if(info[\synth].notNil) {
				info[\synth].set(*app[\voiceArgs].value(note));
			};
		};
		app[\updateStatus].value;
		app[\updateModIndicators].value;
		app[\deferGui].value({
			if(app[\waveView].notNil) { app[\waveView].refresh };
			if(app[\xyView].notNil) { app[\xyView].refresh };
		});
	};

	app[\resetSeqPlayhead] = {
		if((app[\params][\seqKeyTrig] ? 1) == 1) {
			app[\seqGuiPhase] = 0.0;
			app[\seqGuiOffset] = 0;
		};
	};

	app[\seqRateHz] = {
		var p = app[\params];
		var divs = [0.25, 0.5, 1, 2, 4, 8, 16];
		var div = divs[(p[\seqDiv] ? 2).asInteger.clip(0, 6)];
		if((p[\seqSync] ? 1) == 1) {
			((p[\bpm] ? 120) / 60) / div.max(0.001)
		} {
			(p[\seqRate] ? 4.0).max(0.001)
		}
	};

	app[\updateSeqPlayhead] = { |dt=0.05|
		var p = app[\params];
		var steps = (p[\seqSteps] ? 16).asInteger.clip(2, 32);
		var active = (p[\seqOn] ? 0) == 1;
		var step;
		if(active) {
			app[\seqGuiPhase] = (app[\seqGuiPhase] ? 0.0) + (dt * app[\seqRateHz].value);
			step = (((app[\seqGuiPhase].floor.asInteger) + (app[\seqGuiOffset] ? 0)) % steps).clip(0, steps - 1);
			app[\seqGuiStep] = step;
		} {
			app[\seqGuiStep] = nil;
			step = nil;
		};
		app[\deferGui].value({
			32.do { |i|
				var ctl = app[\seqStepControls][i];
				var label = app[\seqStepLabels][i];
				var isActive = active and: { i == step };
				var isEnabled = i < steps;
				if(ctl.notNil) {
					ctl.enabled_(isEnabled);
					ctl.background_(if(isActive) {
						Color(1.0, 0.86, 0.22)
					} {
						if(isEnabled) { Color.white } { Color.gray(0.86) }
					});
				};
				if(label.notNil) {
					label.stringColor_(if(isActive) {
						Color(0.0, 0.45, 0.35)
					} {
						if(isEnabled) { Color.black } { Color.gray(0.55) }
					});
				};
			};
			if(app[\labels][\seqStatus].notNil) {
				app[\labels][\seqStatus].string_(
					if(active) {
						"Current Step: " ++ (step + 1) ++ "/" ++ steps
					} {
						"Current Step: Off"
					}
				);
			};
		});
	};

	app[\releaseVoice] = { |note|
		var info = app[\voices][note];
		if(info.notNil) {
			try { info[\synth].set(\gate, 0) } { };
			app[\voices].removeAt(note);
		};
		app[\updateStatus].value;
	};

	app[\stealIfNeeded] = {
		if(app[\voices].size >= app[\maxVoices]) {
			var oldestNote, oldestSerial = 999999999;
			app[\voices].keysValuesDo { |note, info|
				if(note != app[\droneKey] and: { (info[\serial] ? 0) < oldestSerial }) {
					oldestSerial = info[\serial];
					oldestNote = note;
				};
			};
			if(oldestNote.isNil) {
				app[\voices].keysValuesDo { |note, info|
					if((info[\serial] ? 0) < oldestSerial) {
						oldestSerial = info[\serial];
						oldestNote = note;
					};
				};
			};
			if(oldestNote.notNil) { app[\releaseVoice].value(oldestNote) };
		};
	};

	app[\noteOn] = { |note, vel=100|
		var sy, info;
		app[\resetSeqPlayhead].value;
		if(app[\voices][note].notNil) { app[\releaseVoice].value(note) };
		app[\stealIfNeeded].value;
		app[\voiceSerial] = app[\voiceSerial] + 1;
		info = (synth: nil, note: note, velocity: (vel / 127).clip(0.0, 1.0), held: true, sustained: false, serial: app[\voiceSerial]);
		app[\voices][note] = info;
		sy = Synth(\lemonVoiceV3, app[\voiceArgs].value(note));
		info[\synth] = sy;
		app[\voices][note] = info;
		app[\updateStatus].value;
	};

	app[\noteOff] = { |note|
		var info = app[\voices][note];
		if(info.notNil) {
			info[\held] = false;
			if((app[\params][\sustainOn] ? 0) == 1) {
				info[\sustained] = true;
				app[\voices][note] = info;
			} {
				app[\releaseVoice].value(note);
			};
		};
	};

	app[\startDrone] = {
		var p, key, note, vel, info, sy;
		app[\resetSeqPlayhead].value;
		p = app[\params];
		key = app[\droneKey];
		note = (p[\droneNote] ? p[\rootMidi]).asInteger.clip(0, 127);
		vel = ((p[\droneVelocity] ? 100) / 127).clip(0.0, 1.0);

		if(app[\voices][key].isNil) {
			app[\stealIfNeeded].value;
			app[\voiceSerial] = app[\voiceSerial] + 1;
			info = (synth: nil, note: note, velocity: vel, held: true, sustained: false, serial: app[\voiceSerial], drone: true);
			app[\voices][key] = info;
			sy = Synth(\lemonVoiceV3, app[\voiceArgs].value(key));
			info[\synth] = sy;
			app[\voices][key] = info;
		} {
			info = app[\voices][key];
			info[\note] = note;
			info[\velocity] = vel;
			app[\voices][key] = info;
			if(info[\synth].notNil) { info[\synth].set(*app[\voiceArgs].value(key)) };
		};

		app[\presetStatus] = "Auto Drone running: note " ++ note ++ " velocity " ++ (p[\droneVelocity] ? 100).asInteger;
		app[\updateStatus].value;
	};

	app[\stopDrone] = {
		if(app[\voices][app[\droneKey]].notNil) {
			app[\releaseVoice].value(app[\droneKey]);
			app[\presetStatus] = "Auto Drone stopped";
			app[\updateStatus].value;
		};
	};

	app[\maintainDrone] = {
		if((app[\params][\autoDrone] ? 0) == 1) {
			app[\startDrone].value;
		} {
			app[\stopDrone].value;
		};
	};

	app[\panic] = {
		app[\voices].keysValuesDo { |note, info| try { info[\synth].set(\gate, 0) } { } };
		app[\voices].clear;
		app[\params][\autoDrone] = 0;
		app[\syncControls].value;
		app[\updateStatus].value;
	};

	app[\channelOk] = { |chan|
		var wanted = app[\params][\midiChannel] ? 0;
		(wanted == 0) or: { chan == (wanted - 1) }
	};

	app[\setupMIDI] = {
		var onFunc, offFunc, ccFunc, bendFunc, touchFunc, polyFunc, clockFunc, progFunc;
		MIDIClient.init;
		MIDIIn.connectAll;

		onFunc = MIDIFunc.noteOn({ |vel, note, chan, src|
			{
				if(app[\channelOk].value(chan)) {
					if(vel > 0) { app[\noteOn].value(note, vel) } { app[\noteOff].value(note) };
				};
			}.defer;
		});

		offFunc = MIDIFunc.noteOff({ |vel, note, chan, src|
			{ if(app[\channelOk].value(chan)) { app[\noteOff].value(note) } }.defer;
		});

		ccFunc = MIDIFunc.cc({ |val, num, chan, src|
			{
				if(app[\channelOk].value(chan)) {
					app[\ccValues][num.clip(0, 127)] = (val / 127).clip(0, 1);
					if(num == 1) { app[\params][\modWheel] = (val / 127).clip(0, 1) };
					if(num == 64) {
						app[\params][\sustainOn] = if(val >= 64) { 1 } { 0 };
						if(val < 64) {
							var releaseNotes = List.new;
							app[\voices].keysValuesDo { |note, info|
								if((info[\sustained] ? false) and: { (info[\held] ? false).not }) {
									releaseNotes.add(note);
								};
							};
							releaseNotes.do { |note| app[\releaseVoice].value(note) };
						};
					};
					if(app[\learnSlotIndex].notNil) {
						var target = app[\selectedModTarget];
						var si = app[\learnSlotIndex];
						app[\modSlots][target][si][\source] = 12;
						app[\modSlots][target][si][\cc] = num.clip(0, 127);
						app[\learnSlotIndex] = nil;
						app[\presetStatus] = "Learned CC " ++ num ++ " for " ++ target.asString ++ " slot " ++ (si + 1);
					};
					app[\updateAllVoices].value;
				};
			}.defer;
		});

		bendFunc = MIDIFunc.bend({ |val, chan, src|
			{
				if(app[\channelOk].value(chan)) {
					app[\params][\pitchBend] = ((val - 8192) / 8192).clip(-1, 1);
					app[\updateAllVoices].value;
				};
			}.defer;
		});

		touchFunc = MIDIFunc.touch({ |val, chan, src|
			{
				if(app[\channelOk].value(chan)) {
					app[\params][\aftertouch] = (val / 127).clip(0, 1);
					app[\updateAllVoices].value;
				};
			}.defer;
		});

		polyFunc = MIDIFunc.polytouch({ |val, note, chan, src|
			{
				if(app[\channelOk].value(chan)) {
					app[\polyAftertouch][note] = (val / 127).clip(0, 1);
					app[\updateAllVoices].value;
				};
			}.defer;
		});

		try {
			clockFunc = MIDIFunc.midiClock({
				{
					if((app[\params][\clockSource] ? 0) == 1) {
						var now = SystemClock.seconds;
						if(app[\midiClockStart].isNil) {
							app[\midiClockStart] = now;
							app[\midiClockCount] = 0;
						};
						app[\midiClockCount] = app[\midiClockCount] + 1;
						if(app[\midiClockCount] >= 24) {
							var elapsed = (now - app[\midiClockStart]).max(0.001);
							app[\params][\bpm] = (60 / elapsed).clip(40, 250);
							app[\midiClockStart] = now;
							app[\midiClockCount] = 0;
							app[\updateAllVoices].value;
						};
					};
				}.defer;
			});
			app[\midiObjs].add(clockFunc);
		} { };

		try {
			progFunc = MIDIFunc.program({ |val, chan, src|
				{ app[\presetStatus] = "Program Change received: " ++ val ++ " (preset browsing not mapped)"; app[\updateStatus].value }.defer;
			});
			app[\midiObjs].add(progFunc);
		} { };

		[onFunc, offFunc, ccFunc, bendFunc, touchFunc, polyFunc].do { |obj| app[\midiObjs].add(obj) };
	};

	// --------------------------------------------------------
	// File / preset helpers
	// --------------------------------------------------------
	app[\loadGranulatorPath] = { |which, path|
		var key = if(which == 1) { \gr1 } { \gr2 };
		var bufKey = if(which == 1) { \gr1Buf } { \gr2Buf };
		var sourceKey = ("gr" ++ which ++ "Source").asSymbol;
		path = path.asString.standardizePath;
		Buffer.readChannel(s, path, channels: [0], action: { |buf|
			if(app[bufKey].notNil and: { app[bufKey] != app[\emptyBuf] }) { try { app[bufKey].free } { } };
			app[bufKey] = buf;
			app[\samplePaths][key] = path;
			app[\sampleLabels][key] = "GR" ++ which ++ ": " ++ PathName(path).fileName;
			app[\params][sourceKey] = 0;
			app[\presetStatus] = "Loaded " ++ app[\sampleLabels][key];
			app[\refreshWaveData].value;
			app[\syncControls].value;
			app[\updateAllVoices].value;
			app[\maintainDrone].value;
		});
	};

	app[\loadGranulator] = { |which|
		Dialog.openPanel({ |path|
			if(path.notNil) { app[\loadGranulatorPath].value(which, path) };
		});
	};

	app[\captureLiveToSelected] = {
		Routine({
			var which = app[\selectedGran] ? 1;
			var bufKey = if(which == 1) { \gr1Buf } { \gr2Buf };
			var key = if(which == 1) { \gr1 } { \gr2 };
			var newBuf = Buffer.alloc(s, app[\liveBuf].numFrames, 1);
			s.sync;
			app[\liveBuf].copyData(newBuf, numSamples: app[\liveBuf].numFrames);
			s.sync;
			if(app[bufKey].notNil and: { app[bufKey] != app[\emptyBuf] }) { try { app[bufKey].free } { } };
			app[bufKey] = newBuf;
			app[\samplePaths][key] = nil;
			app[\sampleLabels][key] = "GR" ++ which ++ ": Captured live history";
			app[\params][("gr" ++ which ++ "Source").asSymbol] = 0;
			app[\presetStatus] = "Captured live history into GR" ++ which;
			app[\refreshWaveData].value;
			app[\syncControls].value;
			app[\updateAllVoices].value;
			app[\maintainDrone].value;
		}).play(SystemClock);
	};

	app[\presetObject] = {
		(
			schemaVersion: app[\schemaVersion],
			params: app[\params].copy,
			modSlots: app[\modSlots].deepCopy,
			samplePaths: app[\samplePaths].copy,
			sampleLabels: app[\sampleLabels].copy,
			view: app[\view].copy,
			selectedGran: app[\selectedGran]
		)
	};

	app[\savePreset] = {
		Dialog.savePanel({ |path|
			if(path.notNil) {
				app[\presetObject].value.writeArchive(path);
				app[\presetStatus] = "Saved V3 preset: " ++ PathName(path).fileName;
				app[\updateStatus].value;
			};
		});
	};

	app[\loadPresetObject] = { |obj|
		var p = app[\params];
		if(obj.isNil) { ^nil };

		if(obj[\schemaVersion] == 3) {
			obj[\params].keysValuesDo { |k, v| p[k] = v };
			if(obj[\modSlots].notNil) { app[\modSlots] = obj[\modSlots] };
			if(obj[\samplePaths].notNil) { app[\samplePaths] = obj[\samplePaths] };
			if(obj[\sampleLabels].notNil) { app[\sampleLabels] = obj[\sampleLabels] };
			if(obj[\view].notNil) { app[\view] = obj[\view] };
			if(obj[\selectedGran].notNil) { app[\selectedGran] = obj[\selectedGran] };
			app[\presetStatus] = "Loaded V3 preset";

			if(app[\samplePaths][\gr1].notNil) { app[\loadGranulatorPath].value(1, app[\samplePaths][\gr1]) };
			if(app[\samplePaths][\gr2].notNil) { app[\loadGranulatorPath].value(2, app[\samplePaths][\gr2]) };
		} {
			obj.keysValuesDo { |k, v|
				switch(k,
					\aOn, { p[\gr1On] = v }, \aAmp, { p[\gr1Amp] = v }, \aDensity, { p[\gr1Density] = v },
					\aDur, { p[\gr1GrainSize] = v }, \aJitter, { p[\gr1Jitter] = v }, \aPosition, { p[\gr1Position] = v },
					\aPanWidth, { p[\gr1PanRand] = v }, \aRateMul, { p[\gr1Rate] = v },
					\bOn, { p[\gr2On] = v }, \bAmp, { p[\gr2Amp] = v }, \bDensity, { p[\gr2Density] = v },
					\bDur, { p[\gr2GrainSize] = v }, \bJitter, { p[\gr2Jitter] = v }, \bPosition, { p[\gr2Position] = v },
					\bPanWidth, { p[\gr2PanRand] = v }, \bRateMul, { p[\gr2Rate] = v },
					\oscOn, { p[\oscOn] = v }, \oscAmp, { p[\oscAmp] = v }, \oscWave, { p[\oscWave] = v },
					\oscDetune, { p[\oscDetune] = v }, \oscCutoff, { p[\oscCutoff] = v }, \oscRes, { p[\oscRes] = v },
					\filter1Type, { p[\filter1Type] = v }, \filter1Cutoff, { p[\filter1Cutoff] = v }, \filter1Res, { p[\filter1Res] = v },
					\filter2Type, { p[\filter2Type] = v }, \filter2Cutoff, { p[\filter2Cutoff] = v }, \filter2Res, { p[\filter2Res] = v },
					\filterRouting, { p[\filterRouting] = v },
					\delayMix, { p[\delayMix] = v }, \delayTime, { p[\delayTime] = v }, \delayFb, { p[\delayFb] = v },
					\reverbMix, { p[\reverbMix] = v }, \reverbRoom, { p[\reverbDecay] = v }, \reverbDamp, { p[\reverbDamp] = v },
					\masterAmp, { p[\masterAmp] = v }, \rootMidi, { p[\rootMidi] = v }, \glide, { p[\glide] = v },
					\atk, { p[\env1Atk] = v }, \rel, { p[\env1Rel] = v }
				);
			};
			app[\presetStatus] = "Migrated legacy V2.1 archive into V3 controls";
		};

		app[\syncControls].value;
		app[\refreshWaveData].value;
		app[\updateAllVoices].value;
		app[\maintainDrone].value;
	};

	app[\loadPreset] = {
		Dialog.openPanel({ |path|
			var obj;
			if(path.notNil) {
				obj = Object.readArchive(path);
				app[\loadPresetObject].value(obj);
			};
		});
	};

	// --------------------------------------------------------
	// Waveform data and visualization
	// --------------------------------------------------------
	app[\selectedPrefix] = { "gr" ++ (app[\selectedGran] ? 1) };
	app[\selectedBuffer] = {
		var p = app[\params];
		var source = p[(app[\selectedPrefix].value ++ "Source").asSymbol] ? 0;
		if(source == 1) { app[\liveBuf] } {
			if((app[\selectedGran] ? 1) == 1) { app[\gr1Buf] } { app[\gr2Buf] }
		}
	};

	app[\refreshWaveData] = {
		var b = app[\selectedBuffer].value;
		if(b.isNil) { app[\waveData] = FloatArray.newClear(0); ^nil };
		b.loadToFloatArray(action: { |arr|
			var targetSize = 2200;
			var step, reduced, maxPeak;
			if(arr.notNil and: { arr.size > 0 }) {
				step = (arr.size / targetSize).max(1).asInteger;
				reduced = FloatArray.newClear((arr.size / step).ceil.asInteger);
				reduced.size.do { |i|
					var start = i * step;
					var stop = (start + step - 1).clip(start, arr.size - 1);
					var peak = 0.0;
					start.to(stop).do { |j| peak = peak.max(arr[j].abs) };
					reduced[i] = peak;
				};
				maxPeak = reduced.maxItem ? 0.0;
				if(maxPeak > 0.000001) { reduced = reduced.collect { |v| (v / maxPeak).clip(0, 1) } };
				app[\waveData] = reduced;
			} {
				app[\waveData] = FloatArray.newClear(0);
			};
			app[\deferGui].value({ if(app[\waveView].notNil) { app[\waveView].refresh } });
		});
	};

	app[\spawnVisualDots] = { |which|
		var p = app[\params];
		var prefix = "gr" ++ which;
		var dots = if(which == 1) { app[\grainDots1] } { app[\grainDots2] };
		var density = p[(prefix ++ "Density").asSymbol] ? 0.0;
		var count = ((density / 12).ceil.asInteger).clip(1, 6);
		var pos = p[(prefix ++ "Position").asSymbol] ? 0.5;
		var jitter = p[(prefix ++ "Jitter").asSymbol] ? 0.0;
		var loopStart = p[(prefix ++ "LoopStart").asSymbol] ? 0.0;
		var loopEnd = p[(prefix ++ "LoopEnd").asSymbol] ? 1.0;
		var loopLen = (loopEnd - loopStart).max(0.001);
		if((p[\grainDotsOn] ? 1) == 1 and: { (p[(prefix ++ "On").asSymbol] ? 0) == 1 }) {
			count.do {
				dots.add((
					x: (loopStart + (((pos + rrand(0 - jitter, jitter)).wrap(0, 1)) * loopLen)).clip(0, 1),
					y: rrand(0.15, 0.85),
					life: 1.0
				));
			};
			while { dots.size > 80 } { dots.removeAt(0) };
		};
	};

	app[\decayVisualDots] = {
		[app[\grainDots1], app[\grainDots2]].do { |dots|
			var remove = List.new;
			dots.do { |dot, i|
				dot[\life] = (dot[\life] - 0.16).max(0);
				if(dot[\life] <= 0) { remove.add(i) };
			};
			remove.reverseDo { |i| dots.removeAt(i) };
		};
	};

	app[\startVisualizer] = {
		if(app[\visRunning] == true) { ^nil };
		app[\visRunning] = true;
		AppClock.sched(0.05, {
			if(app.isNil or: { app[\visRunning] != true }) { ^nil };
			app[\visTime] = app[\visTime] + 0.05;
			app[\updateSeqPlayhead].value(0.05);
			app[\decayVisualDots].value;
			app[\spawnVisualDots].value(1);
			app[\spawnVisualDots].value(2);
			if(app[\waveView].notNil) { app[\waveView].refresh };
			0.05
		});
	};
	app[\stopVisualizer] = { app[\visRunning] = false };

	// --------------------------------------------------------
	// GUI helpers
	// --------------------------------------------------------
	makeModButton = { |parent, x, y, target|
		var bt, label;
		bt = Button(parent, Rect(x, y, 38, 20))
			.states_([["Edit"]])
			.action_({
				app[\selectedModTarget] = target;
				if(app[\menus][\modTargetSelect].notNil) {
					app[\menus][\modTargetSelect].value = app[\modTargets].indexOfEqual(target) ? 0;
				};
				app[\showPage].value(8);
				if(app[\refreshModEditor].notNil) { app[\refreshModEditor].value };
			});
		label = StaticText(parent, Rect(x + 42, y + 2, 34, 18)).string_("---").align_(\center);
		app[\modIndicators][target] = label;
	};

	makeSliderRow = { |parent, x, y, label, key, minVal, maxVal, spec=\lin, decimals=3, modTarget=nil|
		var sl, nb, norm;
		StaticText(parent, Rect(x, y + 2, 108, 18)).string_(label);
		sl = Slider(parent, Rect(x + 112, y, 210, 20));
		nb = NumberBox(parent, Rect(x + 328, y, 72, 20)).decimals_(decimals);
		norm = if(spec == \exp) {
			app[\params][key].explin(minVal, maxVal, 0, 1).clip(0, 1)
		} {
			app[\params][key].linlin(minVal, maxVal, 0, 1).clip(0, 1)
		};
		sl.value_(norm);
		nb.value_(app[\params][key]);
		sl.action_({
			var v = if(spec == \exp) { sl.value.linexp(0, 1, minVal, maxVal) } { sl.value.linlin(0, 1, minVal, maxVal) };
			if(decimals == 0) { v = v.round(1).asInteger };
			app[\params][key] = v;
			nb.value = v;
			app[\updateAllVoices].value;
		});
		nb.action_({
			var v = nb.value.clip(minVal, maxVal);
			if(decimals == 0) { v = v.round(1).asInteger };
			app[\params][key] = v;
			sl.value = if(spec == \exp) { v.explin(minVal, maxVal, 0, 1) } { v.linlin(minVal, maxVal, 0, 1) };
			app[\updateAllVoices].value;
		});
		app[\sliders][key] = sl;
		app[\sliderSpecs][key] = (min: minVal, max: maxVal, spec: spec);
		app[\boxes][key] = nb;
		if(modTarget.notNil) { makeModButton.value(parent, x + 408, y, modTarget) };
	};

	makeSmallSliderRow = { |parent, x, y, label, key, minVal, maxVal, spec=\lin, decimals=3, modTarget=nil|
		var sl, nb;
		StaticText(parent, Rect(x, y + 2, 72, 18)).string_(label);
		sl = Slider(parent, Rect(x + 76, y, 110, 20));
		nb = NumberBox(parent, Rect(x + 192, y, 58, 20)).decimals_(decimals);
		sl.value_(if(spec == \exp) { app[\params][key].explin(minVal, maxVal, 0, 1).clip(0, 1) } { app[\params][key].linlin(minVal, maxVal, 0, 1).clip(0, 1) });
		nb.value_(app[\params][key]);
		sl.action_({
			var v = if(spec == \exp) { sl.value.linexp(0, 1, minVal, maxVal) } { sl.value.linlin(0, 1, minVal, maxVal) };
			if(decimals == 0) { v = v.round(1).asInteger };
			app[\params][key] = v;
			nb.value = v;
			app[\updateAllVoices].value;
		});
		nb.action_({
			var v = nb.value.clip(minVal, maxVal);
			if(decimals == 0) { v = v.round(1).asInteger };
			app[\params][key] = v;
			sl.value = if(spec == \exp) { v.explin(minVal, maxVal, 0, 1) } { v.linlin(minVal, maxVal, 0, 1) };
			app[\updateAllVoices].value;
		});
		app[\sliders][key] = sl;
		app[\sliderSpecs][key] = (min: minVal, max: maxVal, spec: spec);
		app[\boxes][key] = nb;
		if(modTarget.notNil) { makeModButton.value(parent, x + 258, y, modTarget) };
	};

	makeToggleRow = { |parent, x, y, label, key|
		var bt;
		StaticText(parent, Rect(x, y + 2, 108, 18)).string_(label);
		bt = Button(parent, Rect(x + 112, y, 76, 22))
			.states_([["Off"], ["On"]])
			.value_(app[\params][key] ? 0)
			.action_({ |b|
				app[\params][key] = b.value.asInteger;
				if(key == \autoDrone) { app[\maintainDrone].value };
				if(key == \sustainOn and: { b.value == 0 }) {
					var releaseNotes = List.new;
					app[\voices].keysValuesDo { |note, info|
						if((info[\sustained] ? false) and: { (info[\held] ? false).not }) {
							releaseNotes.add(note);
						};
					};
					releaseNotes.do { |note| app[\releaseVoice].value(note) };
				};
				app[\updateAllVoices].value;
			});
		app[\toggles][key] = bt;
	};

	makeMenuRow = { |parent, x, y, label, key, items|
		var pm;
		StaticText(parent, Rect(x, y + 2, 108, 18)).string_(label);
		pm = PopUpMenu(parent, Rect(x + 112, y, 160, 20))
			.items_(items)
			.value_(app[\params][key] ? 0)
			.action_({ |menu|
				app[\params][key] = menu.value;
				app[\refreshWaveData].value;
				app[\updateAllVoices].value;
			});
		app[\menus][key] = pm;
	};

	makeSmallMenuRow = { |parent, x, y, label, key, items|
		var pm;
		StaticText(parent, Rect(x, y + 2, 72, 18)).string_(label);
		pm = PopUpMenu(parent, Rect(x + 76, y, 134, 20))
			.items_(items)
			.value_(app[\params][key] ? 0)
			.action_({ |menu|
				app[\params][key] = menu.value;
				app[\updateAllVoices].value;
			});
		app[\menus][key] = pm;
	};

	app[\syncControls] = {
		app[\deferGui].value({
			var p = app[\params];
			app[\sliders].keysValuesDo { |key, sl|
				var nb = app[\boxes][key];
				var val = p[key];
				if(val.notNil) {
					var meta = app[\sliderSpecs][key];
					if(meta.notNil) {
						sl.value = if(meta[\spec] == \exp) {
							val.explin(meta[\min], meta[\max], 0, 1).clip(0, 1)
						} {
							val.linlin(meta[\min], meta[\max], 0, 1).clip(0, 1)
						};
					};
					if(nb.notNil) { nb.value = val };
				};
			};
			app[\toggles].keysValuesDo { |key, bt| if(p[key].notNil) { bt.value = p[key] } };
			app[\menus].keysValuesDo { |key, pm| if(p[key].notNil and: { key != \modTargetSelect }) { pm.value = p[key] } };
			app[\updateSeqPlayhead].value(0);
			32.do { |i|
				var key = ("seqStep" ++ (i + 1)).asSymbol;
				var ctl = app[\seqStepControls][i];
				if(ctl.notNil) { ctl.value_(p[key].linlin(-1, 1, 0, 1).clip(0, 1)) };
			};
			if(app[\menus][\xyXTargetMenu].notNil and: { app[\xyTargetSymbols].notNil }) {
				app[\menus][\xyXTargetMenu].value = app[\xyTargetSymbols].indexOfEqual(p[\xyXTarget]) ? 0;
			};
			if(app[\menus][\xyYTargetMenu].notNil and: { app[\xyTargetSymbols].notNil }) {
				app[\menus][\xyYTargetMenu].value = app[\xyTargetSymbols].indexOfEqual(p[\xyYTarget]) ? 0;
			};
			if(app[\menus][\waveGranSelect].notNil) {
				app[\menus][\waveGranSelect].value = (app[\selectedGran] ? 1) - 1;
			};
			app[\updateStatus].value;
			app[\updateModIndicators].value;
		});
	};

	// --------------------------------------------------------
	// GUI layout
	// --------------------------------------------------------
	app[\win] = Window("Lemondrop Clone V3", Rect(60, 40, 1180, 820), resizable: false);
	app[\win].background = Color.white;
	app[\win].onClose_({ app[\free].value });

	Button(app[\win], Rect(14, 12, 96, 26)).states_([["Load GR1"]]).action_({ app[\loadGranulator].value(1) });
	Button(app[\win], Rect(116, 12, 96, 26)).states_([["Load GR2"]]).action_({ app[\loadGranulator].value(2) });
	Button(app[\win], Rect(218, 12, 128, 26)).states_([["Capture Live -> GR"]]).action_({ app[\captureLiveToSelected].value });
	Button(app[\win], Rect(352, 12, 94, 26)).states_([["Save Preset"]]).action_({ app[\savePreset].value });
	Button(app[\win], Rect(452, 12, 94, 26)).states_([["Load Preset"]]).action_({ app[\loadPreset].value });
	Button(app[\win], Rect(552, 12, 74, 26)).states_([["Panic"]]).action_({ app[\panic].value });
	app[\labels][\status] = StaticText(app[\win], Rect(642, 13, 520, 20)).align_(\left);

	app[\labels][\gr1Path] = StaticText(app[\win], Rect(14, 42, 540, 18)).align_(\left);
	app[\labels][\gr2Path] = StaticText(app[\win], Rect(570, 42, 540, 18)).align_(\left);

	app[\waveView] = UserView(app[\win], Rect(14, 66, 1148, 170)).background_(Color.white);
	app[\waveView].drawFunc_({
		var data = app[\waveData];
		var p = app[\params];
		var v = app[\view];
		var b = app[\waveView].bounds;
		var w, h, mid;
		var zoom, visibleFrac, maxScroll, visStart, visEnd;
		var prefix, regStart, regEnd, loopStart, loopEnd, pos;
		var xFromNorm;

		w = b.width;
		h = b.height;
		mid = h * 0.5;
		zoom = (v[\zoom] ? 1.0).clip(1, 64);
		visibleFrac = (1 / zoom).clip(0.0001, 1);
		maxScroll = (1 - visibleFrac).max(0);
		visStart = ((v[\scroll] ? 0).clip(0, 1) * maxScroll);
		visEnd = (visStart + visibleFrac).clip(0, 1);
		prefix = app[\selectedPrefix].value;
		regStart = p[(prefix ++ "RegionStart").asSymbol] ? 0.0;
		regEnd = p[(prefix ++ "RegionEnd").asSymbol] ? 1.0;
		loopStart = p[(prefix ++ "LoopStart").asSymbol] ? regStart;
		loopEnd = p[(prefix ++ "LoopEnd").asSymbol] ? regEnd;
		pos = p[(prefix ++ "Position").asSymbol] ? 0.5;
		xFromNorm = { |n| ((n - visStart) / visibleFrac * w).clip(0, w) };

		Pen.fillColor = Color.white; Pen.fillRect(Rect(0, 0, w, h));
		Pen.color = Color.gray(0.75); Pen.moveTo(Point(0, mid)); Pen.lineTo(Point(w, mid)); Pen.stroke;

		if(data.notNil and: { data.size > 1 }) {
			var startIndex = (visStart * (data.size - 1)).floor.asInteger.clip(0, data.size - 1);
			var endIndex = (visEnd * (data.size - 1)).ceil.asInteger.clip(startIndex + 1, data.size - 1);
			var visible = data.copyRange(startIndex, endIndex);
			Pen.fillColor = Color(0.0, 0.45, 0.35);
			visible.do { |val, i|
				var x = i.linlin(0, visible.size - 1, 0, w);
				var amp = val.clip(0, 1) * h * 0.42;
				Pen.fillRect(Rect(x, mid - amp, 1.0, amp * 2));
			};
		};

		Pen.fillColor = Color.yellow.alpha_(0.14);
		Pen.fillRect(Rect(xFromNorm.value(regStart), 0, (xFromNorm.value(regEnd) - xFromNorm.value(regStart)).max(1), h));
		Pen.fillColor = Color(0.35, 0.7, 1.0).alpha_(0.12);
		Pen.fillRect(Rect(xFromNorm.value(loopStart), 0, (xFromNorm.value(loopEnd) - xFromNorm.value(loopStart)).max(1), h));

		Pen.color = if(app[\selectedGran] == 1) { Color.cyan } { Color.magenta };
		Pen.moveTo(Point(xFromNorm.value(loopStart + (pos * (loopEnd - loopStart).max(0.001))), 0));
		Pen.lineTo(Point(xFromNorm.value(loopStart + (pos * (loopEnd - loopStart).max(0.001))), h));
		Pen.stroke;

		[[app[\grainDots1], Color.cyan], [app[\grainDots2], Color.magenta]].do { |pair|
			pair[0].do { |dot|
				var x = xFromNorm.value(dot[\x]);
				var y = dot[\y] * h;
				Pen.fillColor = pair[1].alpha_(dot[\life].clip(0, 1));
				Pen.fillOval(Rect.aboutPoint(Point(x, y), 4, 4));
			};
		};
	});

	app[\waveView].mouseDownAction_({ |view, x, y, modifiers, buttonNumber, clickCount|
		var p, v, prefix, w, zoom, visibleFrac, maxScroll, norm, mode;

		p = app[\params];
		v = app[\view];
		prefix = app[\selectedPrefix].value;
		w = view.bounds.width;
		zoom = (v[\zoom] ? 1.0).clip(1, 64);
		visibleFrac = (1 / zoom).clip(0.0001, 1);
		maxScroll = (1 - visibleFrac).max(0);
		norm = (((v[\scroll] ? 0) * maxScroll) + ((x / w).clip(0, 1) * visibleFrac)).clip(0, 1);
		mode = v[\editMode] ? \position;
		if(clickCount >= 2) {
			p[(prefix ++ "RegionStart").asSymbol] = 0.0; p[(prefix ++ "RegionEnd").asSymbol] = 1.0;
			p[(prefix ++ "LoopStart").asSymbol] = 0.0; p[(prefix ++ "LoopEnd").asSymbol] = 1.0;
			p[(prefix ++ "Position").asSymbol] = 0.5;
		} {
			switch(mode,
				\region, {
					if(norm < ((p[(prefix ++ "RegionStart").asSymbol] + p[(prefix ++ "RegionEnd").asSymbol]) * 0.5)) {
						p[(prefix ++ "RegionStart").asSymbol] = norm.clip(0, p[(prefix ++ "RegionEnd").asSymbol] - 0.01);
					} {
						p[(prefix ++ "RegionEnd").asSymbol] = norm.clip(p[(prefix ++ "RegionStart").asSymbol] + 0.01, 1);
					};
				},
				\loop, {
					if(norm < ((p[(prefix ++ "LoopStart").asSymbol] + p[(prefix ++ "LoopEnd").asSymbol]) * 0.5)) {
						p[(prefix ++ "LoopStart").asSymbol] = norm.clip(p[(prefix ++ "RegionStart").asSymbol], p[(prefix ++ "LoopEnd").asSymbol] - 0.01);
					} {
						p[(prefix ++ "LoopEnd").asSymbol] = norm.clip(p[(prefix ++ "LoopStart").asSymbol] + 0.01, p[(prefix ++ "RegionEnd").asSymbol]);
					};
				},
				\scroll, { v[\scroll] = norm.clip(0, 1) },
				{
					var ls = p[(prefix ++ "LoopStart").asSymbol] ? 0;
					var le = p[(prefix ++ "LoopEnd").asSymbol] ? 1;
					p[(prefix ++ "Position").asSymbol] = ((norm - ls) / (le - ls).max(0.001)).clip(0, 1);
				}
			);
		};
		app[\syncControls].value;
		app[\updateAllVoices].value;
	});

	// Wave controls
	StaticText(app[\win], Rect(14, 242, 86, 18)).string_("Wave GR");
	app[\menus][\waveGranSelect] = PopUpMenu(app[\win], Rect(84, 240, 70, 20)).items_(["GR1", "GR2"]).value_(0).action_({ |pm|
		app[\selectedGran] = pm.value + 1;
		app[\refreshWaveData].value;
	});
	StaticText(app[\win], Rect(164, 242, 42, 18)).string_("Mode");
	PopUpMenu(app[\win], Rect(204, 240, 104, 20)).items_(["position", "region", "loop", "scroll"]).value_(0).action_({ |pm|
		app[\view][\editMode] = [\position, \region, \loop, \scroll][pm.value];
	});
	StaticText(app[\win], Rect(318, 242, 42, 18)).string_("Zoom");
	Slider(app[\win], Rect(358, 242, 140, 16)).value_(0).action_({ |sl|
		app[\view][\zoom] = sl.value.linexp(0, 1, 1, 32);
		app[\waveView].refresh;
	});
	StaticText(app[\win], Rect(508, 242, 44, 18)).string_("Scroll");
	Slider(app[\win], Rect(552, 242, 140, 16)).value_(0).action_({ |sl|
		app[\view][\scroll] = sl.value.clip(0, 1);
		app[\waveView].refresh;
	});
	makeToggleRow.value(app[\win], 720, 238, "Grain Dots", \grainDotsOn);
	app[\labels][\presetStatus] = StaticText(app[\win], Rect(920, 240, 240, 20)).align_(\left);

	pageNames = ["Sample", "GR1", "GR2", "OSC", "Filters", "ENV", "LFO/SEQ", "FX", "Mod Matrix", "MIDI/Perform"];
	pageNames.do { |name, i|
		var bt = Button(app[\win], Rect(14 + (i * 114), 270, 108, 26))
			.states_([[name], [name]])
			.action_({ app[\showPage].value(i) });
		app[\tabButtons].add(bt);
	};

	app[\showPage] = { |index|
		app[\pages].do { |page, i| page.visible = (i == index) };
		app[\tabButtons].do { |bt, i| bt.value = if(i == index) { 1 } { 0 } };
	};

	// Sample page
	{
		var page = CompositeView(app[\win], Rect(14, 306, 1148, 500)).background_(Color.white);
		StaticText(page, Rect(12, 8, 460, 20)).string_("Sample / Global / Live History");
		makeSliderRow.value(page, 12, 42, "Master", \masterAmp, 0, 1, \lin, 3, \masterAmp);
		makeSliderRow.value(page, 12, 72, "Root MIDI", \rootMidi, 24, 96, \lin, 0);
		makeSliderRow.value(page, 12, 102, "Glide", \glide, 0.001, 1.0, \exp, 3);
		makeSliderRow.value(page, 12, 132, "BPM", \bpm, 40, 250, \lin, 1);
		makeMenuRow.value(page, 12, 162, "Clock", \clockSource, ["Internal", "MIDI Clock"]);
		makeToggleRow.value(page, 12, 202, "Auto Drone", \autoDrone);
		makeSliderRow.value(page, 12, 232, "Drone Note", \droneNote, 24, 96, \lin, 0);
		makeSliderRow.value(page, 12, 262, "Drone Vel", \droneVelocity, 1, 127, \lin, 0);
		Button(page, Rect(520, 42, 120, 26)).states_([["Load GR1 File"]]).action_({ app[\loadGranulator].value(1) });
		Button(page, Rect(650, 42, 120, 26)).states_([["Load GR2 File"]]).action_({ app[\loadGranulator].value(2) });
		Button(page, Rect(780, 42, 168, 26)).states_([["Capture Live to Selected"]]).action_({ app[\captureLiveToSelected].value });
		StaticText(page, Rect(520, 88, 530, 70))
			.string_("Live history records continuously into a 30 second buffer. Set GR1 or GR2 Source to Live History to granulate the incoming signal, or capture the history into the selected file buffer.");
		StaticText(page, Rect(520, 164, 530, 56))
			.string_("Auto Drone starts one sustained voice when a sample is loaded or live history is captured. Turn it off for strict MIDI-triggered behavior.");
		StaticText(page, Rect(12, 334, 1020, 90))
			.string_("V3 preset schema saves params, per-granulator sample paths, modulation slots, MIDI settings, sequencer steps, tempo, and visible GUI state. Legacy V2.1 archives are migrated by mapping A/B granulator, oscillator, filters, delay, reverb, master, root, glide, attack, and release settings into the new controls.");
		app[\pages].add(page);
	}.value;

	makeGranPage = { |which|
		var page = CompositeView(app[\win], Rect(14, 306, 1148, 500)).background_(Color.white);
		var prefix = "gr" ++ which;
		var x1, x2;
		x1 = 12;
		x2 = 565;
		StaticText(page, Rect(12, 8, 220, 20)).string_("Granulator " ++ which);
		Button(page, Rect(250, 8, 108, 24)).states_([["Load File"]]).action_({ app[\loadGranulator].value(which) });
		Button(page, Rect(368, 8, 150, 24)).states_([["Select Waveform"]]).action_({
			app[\selectedGran] = which;
			app[\refreshWaveData].value;
		});
		makeToggleRow.value(page, x1, 42, "On", (prefix ++ "On").asSymbol);
		makeMenuRow.value(page, x1, 72, "Source", (prefix ++ "Source").asSymbol, sourceItems);
		makeSliderRow.value(page, x1, 102, "Level", (prefix ++ "Amp").asSymbol, 0, 1, \lin, 3, (prefix ++ "Amp").asSymbol);
		makeSliderRow.value(page, x1, 132, "Pitch", (prefix ++ "Pitch").asSymbol, -36, 36, \lin, 2, (prefix ++ "Pitch").asSymbol);
		makeSliderRow.value(page, x1, 162, "Detune", (prefix ++ "Detune").asSymbol, -1, 1, \lin, 3);
		makeSliderRow.value(page, x1, 192, "Position", (prefix ++ "Position").asSymbol, 0, 1, \lin, 3, (prefix ++ "Position").asSymbol);
		makeSliderRow.value(page, x1, 222, "Live Pos", (prefix ++ "LivePosition").asSymbol, 0, 1, \lin, 3);
		makeSliderRow.value(page, x1, 252, "Density", (prefix ++ "Density").asSymbol, 0.5, 120, \exp, 3, (prefix ++ "Density").asSymbol);
		makeSliderRow.value(page, x1, 282, "Grain Count", (prefix ++ "GrainCount").asSymbol, 1, 16, \lin, 0);
		makeSliderRow.value(page, x1, 312, "Grain Size", (prefix ++ "GrainSize").asSymbol, 0.005, 1.5, \exp, 4, (prefix ++ "GrainSize").asSymbol);
		makeSliderRow.value(page, x1, 342, "Window", (prefix ++ "Window").asSymbol, 0, 1, \lin, 3);
		makeSliderRow.value(page, x2, 42, "Jitter", (prefix ++ "Jitter").asSymbol, 0, 1, \lin, 3);
		makeSliderRow.value(page, x2, 72, "Pan Random", (prefix ++ "PanRand").asSymbol, 0, 1, \lin, 3, (prefix ++ "PanRand").asSymbol);
		makeSliderRow.value(page, x2, 102, "Rate", (prefix ++ "Rate").asSymbol, -2, 2, \lin, 3);
		makeMenuRow.value(page, x2, 132, "Rate Sync", (prefix ++ "RateSync").asSymbol, ["Free", "Sync"]);
		makeMenuRow.value(page, x2, 162, "Rate Div", (prefix ++ "RateDiv").asSymbol, syncDivItems);
		makeMenuRow.value(page, x2, 192, "Play Mode", (prefix ++ "PlayMode").asSymbol, ["Fixed", "Moving"]);
		makeMenuRow.value(page, x2, 222, "Loop Mode", (prefix ++ "LoopMode").asSymbol, ["Off", "Forward", "PingPong"]);
		makeToggleRow.value(page, x2, 252, "Preserve Atk", (prefix ++ "PreserveAttack").asSymbol);
		makeMenuRow.value(page, x2, 282, "Pattern", (prefix ++ "Pattern").asSymbol, ["Even", "Random", "Burst"]);
		makeSliderRow.value(page, x2, 322, "Region Start", (prefix ++ "RegionStart").asSymbol, 0, 1, \lin, 3);
		makeSliderRow.value(page, x2, 352, "Region End", (prefix ++ "RegionEnd").asSymbol, 0, 1, \lin, 3);
		makeSliderRow.value(page, x2, 382, "Loop Start", (prefix ++ "LoopStart").asSymbol, 0, 1, \lin, 3);
		makeSliderRow.value(page, x2, 412, "Loop End", (prefix ++ "LoopEnd").asSymbol, 0, 1, \lin, 3);
		app[\pages].add(page);
	};
	makeGranPage.value(1);
	makeGranPage.value(2);

	// OSC page
	{
		var page = CompositeView(app[\win], Rect(14, 306, 1148, 500)).background_(Color.white);
		StaticText(page, Rect(12, 8, 220, 20)).string_("Waveform Oscillator");
		makeToggleRow.value(page, 12, 42, "OSC On", \oscOn);
		makeMenuRow.value(page, 12, 72, "Wave", \oscWave, waveItems);
		makeSliderRow.value(page, 12, 102, "Level", \oscAmp, 0, 1, \lin, 3, \oscAmp);
		makeSliderRow.value(page, 12, 132, "Pitch", \oscPitch, -36, 36, \lin, 2, \oscPitch);
		makeSliderRow.value(page, 12, 162, "Detune", \oscDetune, -1, 1, \lin, 3);
		makeSliderRow.value(page, 12, 192, "Pulse Width", \oscPulseWidth, 0.05, 0.95, \lin, 3);
		makeSliderRow.value(page, 12, 222, "Cutoff", \oscCutoff, 80, 20000, \exp, 1, \oscCutoff);
		makeSliderRow.value(page, 12, 252, "Resonance", \oscRes, 0, 0.95, \lin, 3);
		app[\pages].add(page);
	}.value;

	// Filters page
	{
		var page = CompositeView(app[\win], Rect(14, 306, 1148, 500)).background_(Color.white);
		StaticText(page, Rect(12, 8, 220, 20)).string_("Dual Filters");
		makeMenuRow.value(page, 12, 42, "Filter 1 Type", \filter1Type, filterItems);
		makeSliderRow.value(page, 12, 72, "F1 Cutoff", \filter1Cutoff, 20, 20400, \exp, 1, \filter1Cutoff);
		makeSliderRow.value(page, 12, 102, "F1 Res", \filter1Res, 0, 0.95, \lin, 3);
		makeSliderRow.value(page, 12, 132, "F1 Width", \filter1Width, 0, 1, \lin, 3);
		makeMenuRow.value(page, 12, 192, "Filter 2 Type", \filter2Type, filterItems);
		makeSliderRow.value(page, 12, 222, "F2 Cutoff", \filter2Cutoff, 20, 20400, \exp, 1, \filter2Cutoff);
		makeSliderRow.value(page, 12, 252, "F2 Res", \filter2Res, 0, 0.95, \lin, 3);
		makeSliderRow.value(page, 12, 282, "F2 Width", \filter2Width, 0, 1, \lin, 3);
		makeMenuRow.value(page, 560, 42, "Routing", \filterRouting, ["Series", "Parallel"]);
		StaticText(page, Rect(560, 88, 460, 110)).string_("Series sends Filter 1 into Filter 2. Parallel processes the raw signal through both filters and mixes the outputs.");
		app[\pages].add(page);
	}.value;

	// ENV page
	{
		var page = CompositeView(app[\win], Rect(14, 306, 1148, 500)).background_(Color.white);
		StaticText(page, Rect(12, 8, 220, 20)).string_("ENV1 Amp / ENV2 Mod");
		makeSliderRow.value(page, 12, 42, "ENV1 Attack", \env1Atk, 0.001, 4, \exp, 3);
		makeSliderRow.value(page, 12, 72, "ENV1 Decay", \env1Dec, 0.001, 4, \exp, 3);
		makeSliderRow.value(page, 12, 102, "ENV1 Sustain", \env1Sus, 0, 1, \lin, 3);
		makeSliderRow.value(page, 12, 132, "ENV1 Release", \env1Rel, 0.001, 8, \exp, 3);
		makeSliderRow.value(page, 12, 162, "ENV1 Velocity", \env1Vel, 0, 1, \lin, 3);
		makeSliderRow.value(page, 560, 42, "ENV2 Attack", \env2Atk, 0.001, 4, \exp, 3);
		makeSliderRow.value(page, 560, 72, "ENV2 Decay", \env2Dec, 0.001, 4, \exp, 3);
		makeSliderRow.value(page, 560, 102, "ENV2 Sustain", \env2Sus, 0, 1, \lin, 3);
		makeSliderRow.value(page, 560, 132, "ENV2 Release", \env2Rel, 0.001, 8, \exp, 3);
		makeSliderRow.value(page, 560, 162, "ENV2 Depth", \env2Depth, 0, 1, \lin, 3);
		app[\pages].add(page);
	}.value;

	// LFO / SEQ page
	{
		var page = CompositeView(app[\win], Rect(14, 306, 1148, 500)).background_(Color.white);
		StaticText(page, Rect(12, 8, 220, 20)).string_("LFO / Bar Sequencer");
		makeLfoBlock = { |x, y, idx|
			var prefix = "lfo" ++ idx;
			StaticText(page, Rect(x, y, 110, 20)).string_("LFO " ++ idx);
			makeSmallMenuRow.value(page, x, y + 30, "Shape", (prefix ++ "Shape").asSymbol, lfoShapeItems);
			makeSmallSliderRow.value(page, x, y + 60, "Rate", (prefix ++ "Rate").asSymbol, 0.001, 20, \exp, 3);
			makeSmallMenuRow.value(page, x, y + 90, "Sync", (prefix ++ "Sync").asSymbol, ["Free", "Sync"]);
			makeSmallMenuRow.value(page, x, y + 120, "Div", (prefix ++ "Div").asSymbol, syncDivItems);
			makeSmallSliderRow.value(page, x, y + 150, "Depth", (prefix ++ "Depth").asSymbol, 0, 1, \lin, 3);
			makeToggleRow.value(page, x, y + 180, "Reset", (prefix ++ "Reset").asSymbol);
			makeToggleRow.value(page, x, y + 210, "On", (prefix ++ "On").asSymbol);
		};
		makeLfoBlock.value(12, 38, 1);
		makeLfoBlock.value(330, 38, 2);
		makeToggleRow.value(page, 650, 42, "SEQ On", \seqOn);
		makeSliderRow.value(page, 650, 72, "Steps", \seqSteps, 2, 32, \lin, 0);
		makeSliderRow.value(page, 650, 102, "Rate", \seqRate, 0.1, 32, \exp, 3);
		makeMenuRow.value(page, 650, 132, "Sync", \seqSync, ["Free", "Sync"]);
		makeMenuRow.value(page, 650, 162, "Div", \seqDiv, syncDivItems);
		makeToggleRow.value(page, 650, 192, "Key Trigger", \seqKeyTrig);
		makeToggleRow.value(page, 650, 222, "Quantize", \seqQuantize);
		makeSliderRow.value(page, 650, 252, "SEQ Depth", \seqDepth, 0, 1, \lin, 3, \seqDepth);
		app[\labels][\seqStatus] = StaticText(page, Rect(650, 286, 260, 20)).string_("Current Step: Off").align_(\left);
		StaticText(page, Rect(12, 310, 220, 20)).string_("Sequencer Steps");
		makeSeqStepControls = {
			32.do { |i|
				var x = 12 + ((i % 16) * 69);
				var y = 340 + (((i / 16).floor.asInteger) * 62);
				var key = ("seqStep" ++ (i + 1)).asSymbol;
				var sl, label;
				label = StaticText(page, Rect(x, y, 34, 16)).string_((i + 1).asString);
				sl = Slider(page, Rect(x, y + 18, 52, 16)).value_(app[\params][key].linlin(-1, 1, 0, 1));
				sl.action_({
					app[\params][key] = sl.value.linlin(0, 1, -1, 1);
					app[\updateAllVoices].value;
				});
				app[\seqStepLabels].add(label);
				app[\seqStepControls].add(sl);
			};
		};
		makeSeqStepControls.value;
		app[\pages].add(page);
	}.value;

	// FX page
	{
		var page = CompositeView(app[\win], Rect(14, 306, 1148, 500)).background_(Color.white);
		StaticText(page, Rect(12, 8, 220, 20)).string_("FX1 -> FX2 -> Compressor");
		makeMenuRow.value(page, 12, 42, "FX1 Type", \fx1Type, fx1Items);
		makeSliderRow.value(page, 12, 72, "FX1 Mix", \fx1Mix, 0, 1, \lin, 3, \fx1Mix);
		makeSliderRow.value(page, 12, 102, "FX1 Rate", \fx1Rate, 0.01, 8, \exp, 3);
		makeSliderRow.value(page, 12, 132, "FX1 Depth", \fx1Depth, 0, 1, \lin, 3);
		makeSliderRow.value(page, 12, 162, "FX1 Drive", \fx1Drive, 0, 1, \lin, 3);
		makeMenuRow.value(page, 560, 42, "FX2 Type", \fx2Type, fx2Items);
		makeMenuRow.value(page, 560, 72, "FX2 Order", \fx2Order, ["Delay -> Reverb", "Reverb -> Delay"]);
		makeSliderRow.value(page, 560, 102, "Delay Mix", \delayMix, 0, 1, \lin, 3, \delayMix);
		makeSliderRow.value(page, 560, 132, "Delay Time", \delayTime, 0.001, 4, \exp, 3);
		makeMenuRow.value(page, 560, 162, "Delay Sync", \delaySync, ["Free", "Sync"]);
		makeMenuRow.value(page, 560, 192, "Delay Div", \delayDiv, syncDivItems);
		makeSliderRow.value(page, 560, 222, "Delay FB", \delayFb, 0, 0.95, \lin, 3);
		makeSliderRow.value(page, 560, 252, "Delay Filter", \delayFilter, 80, 20000, \exp, 1);
		makeToggleRow.value(page, 560, 282, "Ping Pong", \delayPingPong);
		makeSliderRow.value(page, 12, 232, "Reverb Mix", \reverbMix, 0, 1, \lin, 3, \reverbMix);
		makeSliderRow.value(page, 12, 262, "Pre Delay", \reverbPreDelay, 0, 0.5, \lin, 3);
		makeSliderRow.value(page, 12, 292, "Decay", \reverbDecay, 0, 1, \lin, 3);
		makeSliderRow.value(page, 12, 322, "Damp", \reverbDamp, 0, 1, \lin, 3);
		makeSliderRow.value(page, 560, 352, "Live -> FX", \liveInputToFx, 0, 1, \lin, 3);
		makeSliderRow.value(page, 560, 382, "Compressor", \compressorAmt, 0, 1, \lin, 3);
		makeSliderRow.value(page, 560, 412, "Comp Output", \compressorOut, 0, 2, \lin, 3);
		app[\pages].add(page);
	}.value;

	// Mod Matrix page
	{
		var page = CompositeView(app[\win], Rect(14, 306, 1148, 500)).background_(Color.white);
		var slotMenus = Array.newClear(3);
		var slotAmts = Array.newClear(3);
		var slotBoxes = Array.newClear(3);
		var slotCcs = Array.newClear(3);
		StaticText(page, Rect(12, 8, 220, 20)).string_("Modulation Matrix");
		StaticText(page, Rect(12, 42, 90, 20)).string_("Target");
		app[\menus][\modTargetSelect] = PopUpMenu(page, Rect(106, 42, 220, 20))
			.items_(app[\modTargetLabels])
			.value_(0)
			.action_({ |pm|
				app[\selectedModTarget] = app[\modTargets][pm.value];
				app[\refreshModEditor].value;
			});
		3.do { |si|
			var y = 86 + (si * 70);
			StaticText(page, Rect(12, y, 80, 20)).string_("Slot " ++ (si + 1));
			slotMenus[si] = PopUpMenu(page, Rect(106, y, 150, 20)).items_(modSourceItems);
			slotAmts[si] = Slider(page, Rect(270, y, 180, 20));
			slotBoxes[si] = NumberBox(page, Rect(460, y, 60, 20)).decimals_(3);
			slotCcs[si] = NumberBox(page, Rect(590, y, 56, 20)).decimals_(0);
			StaticText(page, Rect(535, y + 2, 46, 18)).string_("CC");
			Button(page, Rect(660, y, 92, 22)).states_([["Learn CC"]]).action_({
				app[\learnSlotIndex] = si;
				app[\presetStatus] = "Move a MIDI CC for " ++ app[\selectedModTarget].asString ++ " slot " ++ (si + 1);
				app[\updateStatus].value;
			});
			slotMenus[si].action_({ |pm|
				app[\modSlots][app[\selectedModTarget]][si][\source] = pm.value;
				app[\updateAllVoices].value;
			});
			slotAmts[si].action_({
				var v = slotAmts[si].value.linlin(0, 1, -1, 1);
				app[\modSlots][app[\selectedModTarget]][si][\amount] = v;
				slotBoxes[si].value = v;
				app[\updateAllVoices].value;
			});
			slotBoxes[si].action_({
				var v = slotBoxes[si].value.clip(-1, 1);
				app[\modSlots][app[\selectedModTarget]][si][\amount] = v;
				slotAmts[si].value = v.linlin(-1, 1, 0, 1);
				app[\updateAllVoices].value;
			});
			slotCcs[si].action_({
				app[\modSlots][app[\selectedModTarget]][si][\cc] = slotCcs[si].value.asInteger.clip(0, 127);
				app[\updateAllVoices].value;
			});
		};
		app[\labels][\activeMods] = StaticText(page, Rect(12, 320, 1050, 150)).align_(\left);
		app[\refreshModEditor] = {
			app[\deferGui].value({
				var target = app[\selectedModTarget];
				var activeLines = List.new;
				if(app[\menus][\modTargetSelect].notNil) {
					app[\menus][\modTargetSelect].value = app[\modTargets].indexOfEqual(target) ? 0;
				};
				3.do { |si|
					var slot = app[\modSlots][target][si];
					slotMenus[si].value = slot[\source] ? 0;
					slotAmts[si].value = (slot[\amount] ? 0.0).linlin(-1, 1, 0, 1);
					slotBoxes[si].value = slot[\amount] ? 0.0;
					slotCcs[si].value = slot[\cc] ? 1;
				};
				app[\modTargets].do { |t, ti|
					app[\modSlots][t].do { |slot, si|
						if(((slot[\source] ? 0) != 0) and: { (slot[\amount] ? 0.0).abs > 0.0001 }) {
							activeLines.add(app[\modTargetLabels][ti] ++ " slot " ++ (si + 1) ++ ": " ++ modSourceItems[slot[\source] ? 0] ++ " amt " ++ (slot[\amount] ? 0.0).round(0.001) ++ " cc " ++ (slot[\cc] ? 1));
						};
					};
				};
				if(app[\labels][\activeMods].notNil) {
					app[\labels][\activeMods].string_("Active routings:\n" ++ if(activeLines.size == 0) { "None" } { activeLines.asArray.join("\n") });
				};
			});
		};
		app[\pages].add(page);
	}.value;

	// MIDI / Perform page
	{
		var page = CompositeView(app[\win], Rect(14, 306, 1148, 500)).background_(Color.white);
		var targets = [
			[\gr1Position, "GR1 Position"], [\gr2Position, "GR2 Position"],
			[\gr1Jitter, "GR1 Jitter"], [\gr2Jitter, "GR2 Jitter"],
			[\gr1Density, "GR1 Density"], [\gr2Density, "GR2 Density"],
			[\filter1Cutoff, "F1 Cutoff"], [\filter2Cutoff, "F2 Cutoff"],
			[\oscCutoff, "OSC Cutoff"], [\masterAmp, "Master"]
		];
		var targetSyms = targets.collect { |x| x[0] };
		var targetLabels = targets.collect { |x| x[1] };
		app[\xyTargetSymbols] = targetSyms;
		StaticText(page, Rect(12, 8, 220, 20)).string_("MIDI / Perform");
		app[\labels][\voiceCount] = StaticText(page, Rect(12, 36, 220, 20)).string_("Active voices: 0");
		makeSliderRow.value(page, 12, 68, "MIDI Channel", \midiChannel, 0, 16, \lin, 0);
		makeSliderRow.value(page, 12, 98, "Bend Range", \bendRange, 1, 12, \lin, 0);
		makeToggleRow.value(page, 12, 128, "Sustain", \sustainOn);
		makeSliderRow.value(page, 12, 158, "Mod Wheel", \modWheel, 0, 1, \lin, 3);
		makeSliderRow.value(page, 12, 188, "Aftertouch", \aftertouch, 0, 1, \lin, 3);
		StaticText(page, Rect(560, 42, 80, 20)).string_("X Target");
		app[\menus][\xyXTargetMenu] = PopUpMenu(page, Rect(640, 42, 160, 20)).items_(targetLabels).value_(0).action_({ |pm| app[\params][\xyXTarget] = targetSyms[pm.value] });
		StaticText(page, Rect(820, 42, 80, 20)).string_("Y Target");
		app[\menus][\xyYTargetMenu] = PopUpMenu(page, Rect(900, 42, 160, 20)).items_(targetLabels).value_(2).action_({ |pm| app[\params][\xyYTarget] = targetSyms[pm.value] });
		app[\xyView] = UserView(page, Rect(560, 82, 360, 250)).background_(Color.black);
		app[\applyXY] = { |x, y|
			var p = app[\params];
			var applyTarget = { |target, value|
				switch(target,
					\gr1Position, { p[\gr1Position] = value.clip(0, 1) },
					\gr2Position, { p[\gr2Position] = value.clip(0, 1) },
					\gr1Jitter, { p[\gr1Jitter] = value.clip(0, 1) },
					\gr2Jitter, { p[\gr2Jitter] = value.clip(0, 1) },
					\gr1Density, { p[\gr1Density] = value.linexp(0, 1, 0.5, 120) },
					\gr2Density, { p[\gr2Density] = value.linexp(0, 1, 0.5, 120) },
					\filter1Cutoff, { p[\filter1Cutoff] = value.linexp(0, 1, 20, 20400) },
					\filter2Cutoff, { p[\filter2Cutoff] = value.linexp(0, 1, 20, 20400) },
					\oscCutoff, { p[\oscCutoff] = value.linexp(0, 1, 80, 20000) },
					\masterAmp, { p[\masterAmp] = value.clip(0, 1) }
				);
			};
			p[\xyX] = x.clip(0, 1);
			p[\xyY] = y.clip(0, 1);
			applyTarget.value(p[\xyXTarget], p[\xyX]);
			applyTarget.value(p[\xyYTarget], p[\xyY]);
			app[\syncControls].value;
			app[\updateAllVoices].value;
		};
		app[\xyView].drawFunc_({
			var p, b;
			p = app[\params];
			b = app[\xyView].bounds;
			Pen.fillColor = Color.black; Pen.fillRect(Rect(0, 0, b.width, b.height));
			Pen.color = Color.gray(0.25);
			Pen.moveTo(Point(b.width * 0.5, 0)); Pen.lineTo(Point(b.width * 0.5, b.height)); Pen.stroke;
			Pen.moveTo(Point(0, b.height * 0.5)); Pen.lineTo(Point(b.width, b.height * 0.5)); Pen.stroke;
			Pen.fillColor = Color.cyan.alpha_(0.85);
			Pen.fillOval(Rect.aboutPoint(Point(p[\xyX] * b.width, (1 - p[\xyY]) * b.height), 8, 8));
		});
		app[\xyView].mouseDownAction_({ |view, x, y| app[\applyXY].value(x / view.bounds.width, 1 - (y / view.bounds.height)); view.refresh });
		app[\xyView].mouseMoveAction_({ |view, x, y| app[\applyXY].value(x / view.bounds.width, 1 - (y / view.bounds.height)); view.refresh });
		StaticText(page, Rect(560, 350, 480, 80)).string_("MIDI support: Note On/Off, channel filter, sustain CC64, mod wheel CC1, pitch bend, channel/poly aftertouch, learned CC modulation slots, program change monitor, and MIDI clock tempo follow.");
		app[\pages].add(page);
	}.value;

	// Boot UI
	app[\setupMIDI].value;
	app[\showPage].value(0);
	app[\refreshWaveData].value;
	app[\syncControls].value;
	app[\startVisualizer].value;
	app[\win].front;

	// --------------------------------------------------------
	// Cleanup
	// --------------------------------------------------------
	app[\free] = {
		try { app[\panic].value } { };
		try { app[\stopVisualizer].value } { };
		if(app[\liveRecorder].notNil) { try { app[\liveRecorder].free } { } };
		[\gr1Buf, \gr2Buf].do { |key|
			if(app[key].notNil and: { app[key] != app[\emptyBuf] }) { try { app[key].free } { } };
		};
		if(app[\liveBuf].notNil) { try { app[\liveBuf].free } { } };
		if(app[\emptyBuf].notNil) { try { app[\emptyBuf].free } { } };
		if(app[\midiObjs].notNil) { app[\midiObjs].do { |obj| try { obj.free } { } } };
		if(app[\win].notNil) {
			var w = app[\win];
			app[\win] = nil;
			try { w.onClose_({}) } { };
			try { w.close } { };
		};
	};
});
)
