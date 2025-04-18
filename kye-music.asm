#define MUSIC_ONLY

.const INITIAL_DELAY = false

#import "pseudo.asm"
#import "ted.asm"

.segment Globals [start = $0002, virtual]

Tmp:
	.byte 0
TmpFlags:
	.byte 0

#import "music-globals.asm"

.segment Main [start = $1001, outPrg = "kye-music.prg"]

	.byte $0b, $10, $d3, $07, $9e
	.text "4109"
	.byte 0, 0, 0

Boot:
	sei
	sta TED.SetRom
	ldx #0
Print:
	lda Message,x
	beq Start
	jsr $ffd2
	inx
	bne Print
Start:
	sta TED.SetRam
	.if (INITIAL_DELAY) {
			ldx #0
			ldy #0
		Delay:
			inc $ff3d
			inx
			bne Delay
			iny
			bne Delay
	}
	lda #$00
	sta TED.IrqControl
	jsr Music.Init
	cli
	jmp *

.encoding "petscii_mixed"

Message:
	.byte $0e, $93 // Mixed case, clear screen
	.text @"Title: Green Circle Thing (a.k.a. Kye)\nAuthor: Patai Gergely\nYear: 2025"
	.byte 0

.encoding "ascii"

#import "music.asm"
