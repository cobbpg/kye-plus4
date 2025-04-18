.encoding "ascii"

.const START_ON_FIRE = false

#import "pseudo.asm"
#import "ted.asm"
#import "game-data.asm"

.segment Globals [start = $0002, virtual]

Tmp:
	.byte 0
TmpFlags:
	.byte 0

#import "music-globals.asm"
#import "game-globals.asm"

.segment Main [start = $1001, outPrg = "kye.prg"]

	.byte $0b, $10, $d3, $07, $9e
	.text "4109"
	.byte 0, 0, 0

Boot:
	sei
	sta TED.SetRam
	movb #Screen.ModeOff : TED.Config1
	movb #Colors.Border : TED.BorderColor
	movb #Colors.Background : TED.BackgroundColor
	movb #>CharSet : TED.CharsetAddress
	movb #>Screen.Colors : TED.ScreenAddress
	lda TED.Config2
	and #TED.Config2_Ntsc
	ora #TED.Config2_Wide | TED.Config2_FullChars
	sta TED.Config2
	ldx #0
	lda #Colors.Background
Clear:
	sta Screen.Colors,x
	sta Screen.Colors + $100,x
	sta Screen.Colors + $200,x
	sta Screen.Colors + $300,x
	dex
	bne Clear
	lda #$00
	sta TED.IrqControl

	.if (START_ON_FIRE) {
			lda #TED.InputLatch_None
			sta TED.KeyboardLatch
			lda #TED.InputLatch_Joy2
		!:	sta TED.InputLatch
			bit TED.InputLatch
			bmi !-
		!:	sta TED.InputLatch
			bit TED.InputLatch
			bpl !-
	}

	jsr Music.Init
	cli
	jmp InitGame

#import "music.asm"
#import "game.asm"