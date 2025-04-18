// - Pattern (per row):
//   - feature mask:
//     - top bit 0 (command): %0xxxxxxx: skip x lines; 0 is the pattern end marker
//     - top bit 1 (notes): %1ddininb: bass timer, ch1 base note, ch1 instrument, ch2 base note, ch2 instrument, drum
//   - bass timer: on with 48 different values or off + sync on each rising edge
//   - pulse notes: note off + 64 different pitches
//   - instrument offset (retriggered for each note when not given)
//   - drum: 00 - none, 01 - bass drum, 10 - hihat, 11 - snare drum
// - Instrument (per tick):
//   - pitch adjustment
//     - relative note: 0..+31
//     - some absolute notes: full amp, half amp, drum pitches
//     - adjust current pitch: -100..+100
//     - jump offset given in wave control byte
//   - wave control:
//     - bit 7: sync (just turn it on for a moment)
//     - bit 6: bass modulation (we zero out the channel during the second halves of the period)
//     - bit 5: noise (counts as pulse for channel 1)
//     - bit 4: pulse
//     - bits 0-3: volume (we take the minimum/maximum/average of the two values)

.macro AddRow(bass, note1, ins1, note2, ins2, drum) {
	.byte $80 | (bass == null ? 0 : $01) | (note1 == null ? 0 : $02) | (ins1 == null ? 0 : $04) | (note2 == null ? 0 : $08) | (ins2 == null ? 0 : $10) | (drum << 5)
	.if (bass != null) .byte bass
	.if (note1 != null) .byte note1
	.if (ins1 != null) .byte ins1
	.if (note2 != null) .byte note2
	.if (ins2 != null) .byte ins2
}

.const ascii = @" !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~"

.function GetLineString(codes, offset, maxLength) {
	.var result = ""
	.for (var i = offset; codes.uget(i) >= ' ' && i < offset + maxLength; i++) {
		.eval result += ascii.charAt(codes.uget(i) - ' ')
	}
	.return result
}

.function GetLineString(codes, offset) {
	.return GetLineString(codes, offset, $100)
}

.struct Pattern { name, rows }
.struct PatternRow { note1, ins1, note2, ins2, bassNote, drum }

.const noteValues = List()
.eval noteValues.add(9, 11, 0, 2, 4, 5, 7)

.const accidentals = Hashtable()
.eval accidentals.put('-', 0, '#', 1, 'b', -1)

.function GetNote(codes, offset) {
	.if (codes.uget(offset) == '.') {
		.return null
	}
	.if (codes.uget(offset) == '=') {
		.return 32
	}
	.if (codes.uget(offset) == '#') {
		.return 97
	}
	.const base = noteValues.get(codes.uget(offset) - 'A')
	.const accidental = accidentals.get(ascii.charAt(codes.uget(offset + 1) - ' '))
	.const octave = codes.uget(offset + 2) - '0'
	.return base + accidental + octave * 12
}

.function LoadPatterns(tuneName) {	
	.const result = List()
	.const offsets = List()
	.const codes = LoadBinary(tuneName + "-patterns.txt")

	.eval offsets.add(0)
	.for (var i = 1; i < codes.getSize(); i++) {
		.if (codes.uget(i - 1) == 10) .eval offsets.add(i)
	}
	.const lineCount = offsets.size()

	.var newPatternComing = true
	.var currentPatternData
	.for (var i = 0; i < lineCount; i++) {
		.const lineOffset = offsets.get(i)
		.if (newPatternComing) {
			.const patternName = GetLineString(codes, lineOffset)
			.eval newPatternComing = false
			.eval currentPatternData = List()
			.eval result.add(Pattern(patternName, currentPatternData))
		} else {
			.if (i < lineCount - 1 && (offsets.get(i + 1) - offsets.get(i)) < 4) {
				.eval newPatternComing = true
			} else {
				.const note1 = GetNote(codes, lineOffset + 0)
				.const ins1 = GetLineString(codes, lineOffset + 4, 2)
				.const note2 = GetNote(codes, lineOffset + 7)
				.const ins2 = GetLineString(codes, lineOffset + 11, 2)
				.const bassNote = GetNote(codes, lineOffset + 14)
				.const drum = GetLineString(codes, lineOffset + 18)
				.eval currentPatternData.add(PatternRow(note1, ins1, note2, ins2, bassNote, drum))
			}
		}
	}

	.return result
}

.function LoadOrder(tuneName) {
	.const result = List()
	.const codes = LoadBinary(tuneName + "-order.txt")

	.for (var i = 0; i < codes.getSize(); i++) {
		.if (codes.uget(i) > ' ') {
			.const line = GetLineString(codes, i)
			.if (line.size() > 0 && line.charAt(0) != '#') {
				.eval result.add(line)
			}
			.eval i += line.size()
		}
	}

	.return result
}

.macro ImportTune(name) {
	.const patterns = LoadPatterns(name)
	.const order = LoadOrder(name)
	.const FunkyBend = -30

	* = * "Free"

	.align $100

	* = * "Tune Data"

	Instruments: {
		None:
			.byte 0
		Mute:
			.byte 0, %00001000, Jump, 0
		ShortLead:
			.byte 0, %00011000, 0, %00010111, 0, %00010110, 0, %00010101, 0, %00010100, 0, %00010100
			.byte Jump, Mute
		ShortLeadReverb:
			.byte 0, %00011000, 0, %00010111, 0, %00010110, 0, %00010101, 0, %00010100
			.byte Repeat, 4, 0, %00001000, Repeat, 4, 0, %00010011
			.byte Repeat, 4, 0, %00001000, Repeat, 4, 0, %00010010
			.byte Jump, Mute
		LongLead:
			.byte Repeat, 3, 0, %00011000, Repeat, 3, 0, %00010111, Repeat, 3, 0, %00010110, Repeat, 3, 0, %00010101
			.byte 0, %00010100, Jump, 0
		FunkyLead:
			.byte Repeat, 3, 0, %00011000, Repeat, 3, 0, %00010111, Repeat, 3, PitchMid + FunkyBend, %00010110, Repeat, 3, PitchMid + FunkyBend, %00010101
			.byte 0, %00010100, Jump, 0
		Bass:
			//.byte FullAmp, %11011000, Repeat, 4, FullAmp, %01011000, Repeat, 5, HalfAmp, %01011000
			.byte FullAmp, %11011000, Repeat, 9, FullAmp, %01011000
			.byte Jump, Mute
		LongBass:
			//.byte FullAmp, %11011000, Repeat, 9, FullAmp, %01011000, Repeat, 5, HalfAmp, %01011000
			.byte FullAmp, %11011000, Repeat, 14, FullAmp, %01011000
			.byte Jump, Mute
	}

	Drums: {
			.byte *, BassDrum - *, HiHat - *, Snare - *

		BassDrum:
			.word $200
			.word $180
			.word $8000
		HiHat:
			.word $3f1
			.word $8000
		Snare:
			.word $3f8
			.word $3f0
			.word $3e8
			.word $3e0
			.word $8000
	}

	.const instruments = Hashtable()
	.eval instruments.put("SL", <Instruments.ShortLead)
	.eval instruments.put("RL", <Instruments.ShortLeadReverb)
	.eval instruments.put("LL", <Instruments.LongLead)
	.eval instruments.put("FL", <Instruments.FunkyLead)
	.eval instruments.put("B1", <Instruments.Bass)
	.eval instruments.put("B2", <Instruments.Bass)
	.eval instruments.put("B3", <Instruments.LongBass)

	.const drums = Hashtable()
	.eval drums.put("**", 1)
	.eval drums.put("--", 2)
	.eval drums.put("##", 3)

	.const patternPtrs = Hashtable()

	Patterns:

	.for (var i = 0; i < patterns.size(); i++) {
		.const pattern = patterns.get(i)
		.const rows = pattern.rows
		.eval patternPtrs.put(pattern.name, *)
		.var emptyCount = 0
		.for (var j = 0; j < rows.size(); j++) {
			.const row = rows.get(j)
			.const note1 = row.note1
			.const ins1 = instruments.get(row.ins1)
			.const note2 = row.note2
			.const ins2 = instruments.get(row.ins2)
			.const bassNote = row.bassNote
			.const drum = drums.get(row.drum)
			.if (note1 == null && ins1 == null && note2 == null && ins2 == null && bassNote == null && drum == null) {
				.eval emptyCount++
			} else {
				.if (emptyCount > 0) {
					.byte emptyCount
					.eval emptyCount = 0
				}
				AddRow(
					bassNote != null ? bassNote - 8 : null,
					note1 != null ? note1 - $20 : null,
					ins1,
					note2 != null ? note2 - $20 : null,
					ins2,
					drum != null ? drum : 0
				)
			}
		}
		.if (emptyCount > 0) {
			.byte emptyCount
		}
		.byte 0
	}

	.print "Patterns: " + (* - Patterns)

	.const orderPtrs = List()
	.for (var i = 0; i < order.size(); i++) {
		.eval orderPtrs.add(patternPtrs.get(order.get(i)))
	}

	Order: {
		PtrLo:
			.fill orderPtrs.size(), <orderPtrs.get(i)
			.byte 0
		PtrHi:
			.fill orderPtrs.size(), >orderPtrs.get(i)
			.byte 0
	}
}

Tune: ImportTune("tune")

.label Instruments = Tune.Instruments
.label Drums = Tune.Drums
.label Order = Tune.Order
.label OrderPtrLo = Tune.Order.PtrLo
.label OrderPtrHi = Tune.Order.PtrHi