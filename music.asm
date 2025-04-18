.struct Freq { osc, timer }
.var freqs = List()
.for (var i = 0; i < 88; i++) {
	.var freq = 27.5 * pow(2, i / 12)
	.var osc = round(1023 - 110840.46875 / freq)
	.var timer = 4089 - osc * 4
	.eval freqs.add(Freq(osc, timer))
}
.eval freqs.add(Freq(TED.Sound_FullAmp, 0))
.eval freqs.add(Freq(TED.Sound_HalfAmp, 0))

#import "tune.asm"

* = * "Music Player Small Tables"

ChannelOnMask:
	.byte $01, $02
ChannelOffMask:
	.byte $fe, $fd

ChannelControlOnMask:
	.byte 0, 0, TED.Sound_Square1, TED.Sound_Square2, TED.Sound_Square1, TED.Sound_Noise2, TED.Sound_Square1, TED.Sound_Square2
ChannelControlOffMask:
	.byte ~TED.Sound_Square1, ~(TED.Sound_Square2 | TED.Sound_Noise2)

BassMasks:
	.byte ~0, ~TED.Sound_Square1, ~(TED.Sound_Square2 | TED.Sound_Noise2), ~(TED.Sound_Square1 | TED.Sound_Square2 | TED.Sound_Noise2)

* = * "Free"

.align $100

* = * "Music Player Frequency Tables"

NoteOscFreqLo:
	.byte <TED.Sound_FullAmp
	.fill freqs.size() - 24, <freqs.get(i + 24).osc
NoteOscFreqHi:
	.byte >TED.Sound_FullAmp
	.fill freqs.size() - 24, >freqs.get(i + 24).osc
NoteTimerFreqLo:
	.fill $30, <freqs.get(i).timer
NoteTimerFreqHi:
	.fill $30, >freqs.get(i).timer

* = * "Music Player"

.namespace Music {
	Init: {
			ldx #GlobalsEnd - GlobalsStart
			lda #0
		!:	dex
			sta GlobalsStart,x
			bne !-

			lda #$94 // PAL
			bit TED.Config2
			bvc !+
			lda #$b5 // NTSC
		!:	sta Tempo
			lda OrderPtrLo
			sta PatternPtr
			lda OrderPtrHi
			sta PatternPtr + 1
			lda #$ff
			sta BassMask
			lda #8
			sta Volume
			sta Volume + 1
			lda #<TED.Sound_FullAmp
			sta TED.Sound1FreqLo
			sta TED.Sound2FreqLo
			lda #>TED.Sound_FullAmp
			sta TED.Sound2FreqHi
			ora #SoundFreq1HighBits
			sta TED.Sound1FreqHi
			lda #TED.Sound_Reset
			sta TED.SoundControl
			lda #0
			sta TED.SoundControl
			lda #<Irq
			sta $fffe
			lda #>Irq
			sta $ffff
			lda #TED.IrqFlag_Raster
			sta TED.IrqControl
			lda #204
			sta TED.IrqRaster
			rts
	}

	Play: {
			dec Tick
			bmi ProcessPattern
			jmp ProcessTick

		ProcessPattern: {
				lda PatternWait
				beq ProcessRow
				dec PatternWait
				beq ProcessRow
				jmp ResetTick

			ProcessRow:
				ldy PatternOfs
				lda (PatternPtr),y
				sta TmpFlags
				bpl ProcessCommand
			ProcessNote:
				lsr TmpFlags
				bcc CheckChannels

			ReadBassTimer:
				iny
				lda (PatternPtr),y
				sta BassNote
				and #$7f
				beq DisableBassTimer
			SetBassTimer:
				tax
				lda NoteTimerFreqLo - 1,x
				sta TED.Timer1FreqLo
				lda NoteTimerFreqHi - 1,x
				sta TED.Timer1FreqHi
				lda #0
				sta BassPhase
				lda TED.IrqControl
				ora #TED.IrqFlag_Timer1
				sta TED.IrqControl
				bne CheckChannels
			DisableBassTimer:
				lda TED.IrqControl
				and #~TED.IrqFlag_Timer1
				sta TED.IrqControl

			CheckChannels:
				ldx #0
			ProcessChannels:
				lsr TmpFlags
				bcc CheckInstrument
			SetBaseNote:
				iny
				lda (PatternPtr),y
				sta BaseNote,x
				bne RetriggerInstrument
				lda #1 // Mute
				bne InitInstrument
			RetriggerInstrument:
				lda InsStartOfs,x
			InitInstrument:
				sta InsOfs,x
				lda #0
				sta InsRepeat,x
			CheckInstrument:
				lsr TmpFlags
				bcc NextChannel
			SetInstrument:
				iny
				lda (PatternPtr),y
				sta InsStartOfs,x
				sta InsOfs,x
				lda #0
				sta InsRepeat,x
			NextChannel:
				inx
				cpx #2
				bcc ProcessChannels
				lda TmpFlags
				and #$03
				tax
				lda Drums,x
				sta Drum
				bpl Done

			ProcessCommand:
				beq HandlePatternEnd
			SetWait:
				sta PatternWait
				bne Done
			HandlePatternEnd:
				inc OrderIndex
				ldx OrderIndex
				lda OrderPtrHi,x
				bne SetPatternPtr
				sta OrderIndex
				tax
			SetPatternPtr:
				lda OrderPtrLo,x
				sta PatternPtr
				lda OrderPtrHi,x
				sta PatternPtr + 1
				lda #0
				sta PatternOfs
				jmp ProcessRow

			Done:
				iny
				sty PatternOfs
		}

		ResetTick: {
				lda Tempo
				asl
				adc #$80
				rol
				asl
				adc #$80
				rol
				sta Tempo
				and #$0f
				sta Tick
		}

		ProcessTick: {
				ldx #0
				stx ForceSync

			ProcessChannels:
				ldy InsOfs,x
				bne !+
				jmp NextChannel

			!:	lda Instruments,y
				cmp #$20
				bcs !+
			SetRelativeNote:
				adc BaseNote,x // carry clear
				sta FinalNote,x
				jmp GetFinalNoteFreq
			!:	cmp #$28
				bcs !+
			SetAbsoluteNote:
				adc #$21 // carry clear
				sta FinalNote,x
				bne GetFinalNoteFreq
			!:  cmp #Jump
				bcc !+
			PerformJump:
				lda Instruments + 1,y
				sta InsOfs,x
				lda #0
				sta InsRepeat,x
				beq ProcessChannels
			!:	cmp #Repeat
				bcc !+
			SetupRepeat:
				lda Instruments + 1,y
				sta InsRepeat,x
				iny
				iny
				sty InsOfs,x
				bne ProcessChannels
			!:	sbc #(PitchMid - 1) // carry reset
				clc
				bpl IncreasePitch
			DecreasePitch:
				adc FreqLo,x
				sta FreqLo,x
				lda FreqHi,x
				adc #$ff
				sta FreqHi,x
				jmp CheckControl
			IncreasePitch:
				adc FreqLo,x
				sta FreqLo,x
				lda FreqHi,x
				adc #$00
				sta FreqHi,x
				jmp CheckControl
			GetFinalNoteFreq:
				tay
				lda NoteOscFreqLo,y
				sta FreqLo,x
				lda NoteOscFreqHi,y
				sta FreqHi,x

			CheckControl:
				ldy InsOfs,x
				lda Instruments + 1,y
				sta TmpFlags
				and #$0f
				sta Volume,x
				lda InsRepeat,x
				beq AdvanceInstrument
				dec InsRepeat,x
				bne ProcessControl
			AdvanceInstrument:
				iny
				iny
				sty InsOfs,x
			ProcessControl:
				bit TmpFlags
				bpl UpdateBassChannels
				lda #TED.Sound_Reset
				sta ForceSync
			UpdateBassChannels:
				lda BassChannels
				and ChannelOffMask,x
				bit TmpFlags
				bvc !+
				ora ChannelOnMask,x
			!:	sta BassChannels
			UpdateWaveControl:
				lda WaveControl
				and ChannelControlOffMask,x
				sta WaveControl
				lda FinalNote,x
				beq NextChannel
				lda TmpFlags
				and #$30
				lsr
				lsr
				lsr
				stx Tmp
				ora Tmp
				tay
				lda WaveControl
				ora ChannelControlOnMask,y
				sta WaveControl

			NextChannel:
				inx
				cpx #2
				bcs SetRegisters
				jmp ProcessChannels

			SetRegisters:
				lda Volume
				cmp Volume + 1
				bcc StoreVolume
				lda Volume + 1
			StoreVolume:
				ora WaveControl
				sei
				sta FinalControl
				bit ForceSync
				bpl UpdateRegisters
				jsr PerformSync
			UpdateRegisters:
				ldx BassChannels
				lda BassMasks,x
				sta BassMask
				lda FinalControl
				bit BassPhase
				bmi UpdateControl
				and BassMask
			UpdateControl:
				sta TED.SoundControl
				lda FreqLo
				sta TED.Sound1FreqLo
				lda FreqHi
				ora #SoundFreq1HighBits
				sta TED.Sound1FreqHi
				ldx Drum
				beq SetNormalFreq
				lda Drums+1,x
				bpl PlayDrum
				asl
				sta Drum
				jsr PerformSync
				lda FreqLo
				sta TED.Sound1FreqLo
				lda FreqHi
				ora #SoundFreq1HighBits
				sta TED.Sound1FreqHi
				jmp SetNormalFreq
			PlayDrum:
				sta TED.Sound2FreqHi
				lda Drums,x
				sta TED.Sound2FreqLo
				inx
				inx
				stx Drum
				lda FinalControl
				and #~TED.Sound_Square2
				ora #TED.Sound_Noise2
				sta FinalControl
				sta TED.SoundControl
				bne Done
			SetNormalFreq:
				lda FreqLo + 1
				sta TED.Sound2FreqLo
				lda FreqHi + 1
				sta TED.Sound2FreqHi
			Done:
				cli
		}

			rts

		// Make sure both oscillators are active
		PerformSync: {
				lda #<TED.Sound_HalfAmp
				sta TED.Sound1FreqLo
				sta TED.Sound2FreqLo
				lda #>TED.Sound_HalfAmp
				sta TED.Sound2FreqHi
				ora #SoundFreq1HighBits
				sta TED.Sound1FreqHi
				lda FinalControl
				tax
				ora #TED.Sound_Reset
				sta TED.SoundControl
				stx TED.SoundControl
				sta TED.SoundControl
				lda #<TED.Sound_FullAmp
				sta TED.Sound1FreqLo
				sta TED.Sound2FreqLo
				stx TED.SoundControl
				rts
		}
	}

	Irq: {
			pha
			lda #TED.IrqFlag_Raster
			bit TED.IrqStatus
			beq HandleTimer
		HandleRaster:
			ora #$80
			sta TED.IrqStatus
			cld
			cli
			txa
			pha
			tya
			pha
			jsr Play
#if !MUSIC_ONLY
			jsr FrameInterrupt
#endif
			pla
			tay
			pla
			tax
			pla
			rti
		HandleTimer:
			lda #TED.IrqFlag_Timer1 | $80
			sta TED.IrqStatus
			lda Music.FinalControl
			bit Music.BassPhase
			bpl !+
			and Music.BassMask
		!:	sta TED.SoundControl
			lda Music.Drum
			beq !+
			lda TED.SoundControl
			ora #TED.Sound_Noise2
			sta TED.SoundControl
			lda Music.BassNote
			bit Music.BassPhase
			beq !+
			lda TED.SoundControl
			ora #TED.Sound_Reset
			sta TED.SoundControl
			and #~TED.Sound_Reset
			sta TED.SoundControl
		!:	lda Music.BassPhase
			eor #$80
			sta Music.BassPhase
			pla
			rti
	}
}
