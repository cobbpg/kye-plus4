.namespace Music {
	GlobalsStart:

	Tempo:
		.byte 0
	Tick:
		.byte 0
	OrderIndex:
		.byte 0
	PatternPtr:
		.word 0
	PatternOfs:
		.byte 0
	PatternWait:
		.byte 0
	BassNote:
		.byte 0 // Bit 7: sync on phase 0, bits 0-6: 0-48, 0 means timer off
	BassPhase:
		.byte 0 // Bit 7: flip for every interrupt
	BassMask:
		.byte 0 // %1bba1111 - a = 0 when channel 1 is modulated, b = 0 when channel 2 is modulated
	ForceSync:
		.byte 0
	Drum:
		.byte 0

	FreqChanged:
		.byte 0 // %000000ba - a/b set when channel 1/2 frequency changed
	BassChannels:
		.byte 0 // %000000ba - a/b set when channel 1/2 needs to be masked for the bass

	InsStartOfs:
		.byte 0, 0
	InsOfs:
		.byte 0, 0 // 0 means static state
	InsRepeat:
		.byte 0, 0
	BaseNote:
		.byte 0, 0 // 0-64, 0 means off
	FinalNote:
		.byte 0, 0 // 0-66+, 0 means off, includes full amp, half amp and drum pitches
	FreqLo:
		.byte 0, 0
	FreqHi:
		.byte 0, 0
	Volume:
		.byte 0, 0

	WaveControl:
		.byte 0 // Bits 4-6 of $ff11
	FinalControl:
		.byte 0 // The value written to $ff11 without the bass mask applied

	GlobalsEnd:
}

.const FullAmp = $20
.const HalfAmp = $21
.const Repeat = $fe
.const Jump = $ff
.const PitchMid = 140

#if MUSIC_ONLY
.const SoundFreq1HighBits = $04 // Characters from ROM
#else
.const SoundFreq1HighBits = $38 // Bitmap at $e000, characters from RAM
#endif
