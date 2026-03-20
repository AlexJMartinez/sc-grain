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
	~granV21[\recordSeconds] = 8.0;
	~granV21[\dragMode] = \none;
	~granV21[\dragTarget] = \none;
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
		bPanWidth: 0.8,

		oscOn: 0,
		oscAmp: 0.18,
		oscWave: 0,
		oscDetune: 0.0,
		oscCutoff: 8000,
		oscRes: 0.15,

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
		regionStart=0.0, regionEnd=1.0, position=0.5, aPosition=0.5, bPosition=0.5,

		aOn=1, aAmp=0.9, aDensity=18, aDur=0.11, aJitter=0.04, aRateMul=1.0, aRateRand=0.05, aScanRate=0.08, aScanWidth=0.08, aPanWidth=0.55,
		bOn=1, bAmp=0.65, bDensity=8, bDur=0.20, bJitter=0.08, bRateMul=0.5, bRateRand=0.04, bScanRate=0.03, bScanWidth=0.15, bPanWidth=0.8,

		oscOn=0, oscAmp=0.18, oscWave=0, oscDetune=0.0, oscCutoff=8000, oscRes=0.15,
		hpf=20, lpf=18000, atk=0.01, rel=0.35|

		var env, bufDur, regStartSec, regEndSec, regLen, aBasePosNorm, bBasePosNorm;
		var trigA, trigB, posA, posB, rateA, rateB, panA, panB, sigA, sigB;
		var freq, osc, sig, scanA, scanB, ratioLag;

		bufDur = BufDur.kr(bufnum).max(0.001);

		regStartSec = regionStart.clip(0, 1) * bufDur;
		regEndSec = regionEnd.clip(0, 1) * bufDur;
		regEndSec = max(regEndSec, regStartSec + 0.001);
		regLen = (regEndSec - regStartSec).max(0.001);

		ratioLag = Lag.kr(pitchRatio, glide.max(0.001));

aBasePosNorm = aPosition.clip(0, 1);
bBasePosNorm = bPosition.clip(0, 1);

		// ---------------- Gran A ----------------
				trigA = Dust.kr(aDensity.max(0.1));
		scanA = SinOsc.kr(aScanRate.max(0.001), 0, aScanWidth.clip(0, 1));
		posA = (aBasePosNorm + scanA + TRand.kr(0 - aJitter.clip(0,1), aJitter.clip(0,1), trigA)).clip(0, 1);
		rateA = (ratioLag * aRateMul) + TRand.kr(0 - aRateRand, aRateRand, trigA);
		panA = TRand.kr(0 - aPanWidth.clip(0,1), aPanWidth.clip(0,1), trigA);

		sigA = GrainBuf.ar(
			numChannels: 2,
			trigger: trigA,
			dur: aDur.max(0.005),
			sndbuf: bufnum,
			rate: rateA,
			pos: ((regStartSec + (posA * regLen)) / bufDur).clip(0, 1),
			interp: 4,
			pan: panA
		) * aAmp * aOn;

		// ---------------- Gran B ----------------
				trigB = Dust.kr(bDensity.max(0.1));
		scanB = SinOsc.kr(bScanRate.max(0.001), 0, bScanWidth.clip(0, 1));
		posB = (bBasePosNorm + scanB + TRand.kr(0 - bJitter.clip(0,1), bJitter.clip(0,1), trigB)).clip(0, 1);
		rateB = (ratioLag * bRateMul) + TRand.kr(0 - bRateRand, bRateRand, trigB);
		panB = TRand.kr(0 - bPanWidth.clip(0,1), bPanWidth.clip(0,1), trigB);

		sigB = GrainBuf.ar(
			numChannels: 2,
			trigger: trigB,
			dur: bDur.max(0.005),
			sndbuf: bufnum,
			rate: rateB,
			pos: ((regStartSec + (posB * regLen)) / bufDur).clip(0, 1),
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
			oscCutoff.clip(80, 18000),
			(1 - oscRes.clip(0, 0.98)).max(0.02)
		) * oscAmp * oscOn;

		sig = sigA + sigB + osc;
		sig = HPF.ar(sig, hpf.max(20));
		sig = LPF.ar(sig, lpf.clip(50, 20000));

		env = EnvGen.kr(
			Env.asr(atk.max(0.001), 1.0, rel.max(0.001)),
			gate,
			doneAction: 2
		);

		Out.ar(out, sig * masterAmp * env);
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
			\aPosition, p[\aPosition],
			\bPosition, p[\bPosition],

			\aOn, p[\aOn], \aAmp, p[\aAmp], \aDensity, p[\aDensity], \aDur, p[\aDur],
			\aJitter, p[\aJitter], \aRateMul, p[\aRateMul], \aRateRand, p[\aRateRand],
			\aScanRate, p[\aScanRate], \aScanWidth, p[\aScanWidth], \aPanWidth, p[\aPanWidth],

			\bOn, p[\bOn], \bAmp, p[\bAmp], \bDensity, p[\bDensity], \bDur, p[\bDur],
			\bJitter, p[\bJitter], \bRateMul, p[\bRateMul], \bRateRand, p[\bRateRand],
			\bScanRate, p[\bScanRate], \bScanWidth, p[\bScanWidth], \bPanWidth, p[\bPanWidth],

			\oscOn, p[\oscOn], \oscAmp, p[\oscAmp], \oscWave, p[\oscWave],
			\oscDetune, p[\oscDetune], \oscCutoff, p[\oscCutoff], \oscRes, p[\oscRes],

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

	var aAbsNorm = (regStart + (p[\aPosition].clip(0, 1) * regLen)).clip(0, 1);
	var bAbsNorm = (regStart + (p[\bPosition].clip(0, 1) * regLen)).clip(0, 1);

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

			[\hpf, 20, 8000, \exp],
			[\lpf, 100, 20000, \exp]
		].do { |row|
			~granV21[\setSliderAndBox].value(row[0], p[row[0]], row[1], row[2], row[3]);
		};

		if(~granV21[\toggles][\aOn].notNil) { ~granV21[\toggles][\aOn].value = p[\aOn] };
		if(~granV21[\toggles][\bOn].notNil) { ~granV21[\toggles][\bOn].value = p[\bOn] };
		if(~granV21[\toggles][\oscOn].notNil) { ~granV21[\toggles][\oscOn].value = p[\oscOn] };

		if(~granV21[\menus][\oscWave].notNil) { ~granV21[\menus][\oscWave].value = p[\oscWave] };

		~granV21[\playButton] = nil;

		if(~granV21[\pathLabel].notNil) {
	~granV21[\pathLabel].string_(~granV21[\samplePath]);
};
		if(~granV21[\waveView].notNil) { ~granV21[\waveView].refresh };
		if(~granV21[\xyView].notNil) { ~granV21[\xyView].refresh };
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
	~granV21[\waveView] = UserView(~granV21[\win], Rect(16, 56, 1088, 220))
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
	var regStart = p[\regionStart];
	var regEnd = p[\regionEnd];
	var regLen = (regEnd - regStart).max(0.001);
	var aBasePos = p[\aPosition].clip(0, 1);
	var bBasePos = p[\bPosition].clip(0, 1);

	var aScan, bScan, aPosNorm, bPosNorm;
	var aAbsNorm, bAbsNorm, aX, bX;
	var trailCount = 6;

	aScan = sin(~granV21[\visTime] * p[\aScanRate].max(0.001) * 2pi) * p[\aScanWidth].clip(0, 1);
	bScan = sin(~granV21[\visTime] * p[\bScanRate].max(0.001) * 2pi) * p[\bScanWidth].clip(0, 1);

	aPosNorm = (aBasePos + aScan).clip(0, 1);
	bPosNorm = (bBasePos + bScan).clip(0, 1);

	aAbsNorm = (regStart + (aPosNorm * regLen)).clip(0, 1);
	bAbsNorm = (regStart + (bPosNorm * regLen)).clip(0, 1);

	aX = xFromNorm.value(aAbsNorm);
	bX = xFromNorm.value(bAbsNorm);

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


~granV21[\waveView].mouseDownAction_({ |view, x, y, modifiers, buttonNumber, clickCount|
	var p = ~granV21[\params];
	var m = ~granV21[\getWaveMetrics].value(view);
	var normVisible = (x / m[\w]).clip(0, 1);
	var norm = (m[\visStart] + (normVisible * m[\visibleFrac])).clip(0, 1);

	var aDistPx = (x - m[\aX]).abs;
	var bDistPx = (x - m[\bX]).abs;
	var startDistPx = (x - m[\startX]).abs;
	var endDistPx = (x - m[\endX]).abs;

	var playheadHitRadius = ~granV21[\playheadHitRadius] ? 24;
	var edgeHitPx = 12;

	if(clickCount >= 2) {
		p[\regionStart] = 0.0;
		p[\regionEnd] = 1.0;
		p[\aPosition] = 0.5;
		p[\bPosition] = 0.5;
		~granV21[\dragMode] = \none;
		~granV21[\dragTarget] = \none;
		~granV21[\updateAllVoices].value;
		{
			view.refresh;
			if(~granV21[\win].notNil) { ~granV21[\win].refresh };
		}.defer;
		^nil;
	};

	// First priority: whichever playhead is closest, if within radius
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

	view.refresh;
});


	~granV21[\waveView].mouseMoveAction_({ |view, x, y|
	var p = ~granV21[\params];
	var m = ~granV21[\getWaveMetrics].value(view);
	var normVisible = (x / m[\w]).clip(0, 1);
	var norm = (m[\visStart] + (normVisible * m[\visibleFrac])).clip(0, 1);

	switch(~granV21[\dragTarget],

		\regionStart, {
			p[\regionStart] = norm.clip(0, p[\regionEnd] - 0.01);
		},

		\regionEnd, {
			p[\regionEnd] = norm.clip(p[\regionStart] + 0.01, 1.0);
		},

		\aPosition, {
			p[\aPosition] = ((norm - p[\regionStart]) / (p[\regionEnd] - p[\regionStart]).max(0.001)).clip(0, 1);
		},

		\bPosition, {
			p[\bPosition] = ((norm - p[\regionStart]) / (p[\regionEnd] - p[\regionStart]).max(0.001)).clip(0, 1);
		}
	);

	~granV21[\updateAllVoices].value;
	view.refresh;
});

~granV21[\waveView].mouseUpAction_({
	~granV21[\dragMode] = \none;
	~granV21[\dragTarget] = \none;
});





	// tabs
	["Sample", "Gran A", "Gran B", "Osc/FX", "Perform"].do { |name, i|
		var bt = Button(~granV21[\win], Rect(16 + (i * 118), 292, 108, 26))
			.states_([[name], [name]])
			.action_({ ~granV21[\showPage].value(i) });

		~granV21[\tabButtons].add(bt);
	};

	// page 1
	{
		var page = CompositeView(~granV21[\win], Rect(16, 330, 1088, 410))
			.background_(Color.white);

		StaticText(page, Rect(12, 10, 380, 20)).string_("Sample / Region / Envelope / Recording");
		StaticText(page, Rect(12, 38, 900, 18)).string_("Drag yellow edges = region. Drag cyan/magenta lines = Gran A / Gran B positions. Double-click waveform = reset region + engine positions.");

		StaticText(page, Rect(12, 68, 42, 18)).string_("Zoom");
Slider(page, Rect(58, 70, 180, 16))
	.value_(0.0)
	.action_({ |sl|
		~granV21[\view][\zoom] = sl.value.linexp(0, 1, 1, 32);
		if(~granV21[\waveView].notNil) { ~granV21[\waveView].refresh };
	});

StaticText(page, Rect(255, 68, 42, 18)).string_("Scroll");
Slider(page, Rect(305, 70, 180, 16))
	.value_(0.0)
	.action_({ |sl|
		~granV21[\view][\scroll] = sl.value.clip(0, 1);
		if(~granV21[\waveView].notNil) { ~granV21[\waveView].refresh };
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

	// page 2
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

		~granV21[\pages].add(page);
	}.value;

	// page 3
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

		~granV21[\pages].add(page);
	}.value;

	// page 4
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

	// page 5
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
