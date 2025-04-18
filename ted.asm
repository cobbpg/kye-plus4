.namespace TED {
	.label KeyboardLatch = $fd30

	.label Timer1FreqLo = $ff00
	.label Timer1FreqHi = $ff01
	.label Timer2FreqLo = $ff02
	.label Timer2FreqHi = $ff03
	.label Timer3FreqLo = $ff04
	.label Timer3FreqHi = $ff05
	.label Config1 = $ff06
	.label Config2 = $ff07
	.label InputLatch = $ff08
	.label IrqStatus = $ff09
	.label IrqControl = $ff0a
	.label IrqRaster = $ff0b
	.label Sound1FreqLo = $ff0e
	.label Sound2FreqLo = $ff0f
	.label Sound2FreqHi = $ff10
	.label SoundControl = $ff11
	.label Sound1FreqHi = $ff12 // Other bits can be constant throughout the game!
	.label CharsetAddress = $ff13
	.label ScreenAddress = $ff14
	.label BackgroundColor = $ff15
	.label CommonColor1 = $ff16
	.label CommonColor2 = $ff17
	.label CommonColor3 = $ff18
	.label BorderColor = $ff19
	.label BitmapOffsetHi = $ff1a
	.label BitmapOffsetLo = $ff1b
	.label VerticalScanHi = $ff1c
	.label VerticalScanLo = $ff1d
	.label HorizontalScanHi = $ff1e
	.label CharRaster = $ff1f
	.label SetRom = $ff3e
	.label SetRam = $ff3f

	.label Config1_Tall = $08
	.label Config1_EnableDisplay = $10
	.label Config1_BitmapMode = $20
	.label Config1_ExtendedColorMode = $40
	.label Config1_Test = $80

	.label Config2_Wide = $08
	.label Config2_Multicolor = $10
	.label Config2_TedOff = $20
	.label Config2_Ntsc = $40
	.label Config2_FullChars = $80

	.label InputLatch_None = $ff
	.label InputLatch_Joy1 = $fb
	.label InputLatch_Joy2 = $fd

	.label IrqFlag_Raster = $02
	.label IrqFlag_Timer1 = $08
	.label IrqFlag_Timer2 = $10
	.label IrqFlag_Timer3 = $40

	.label Sound_Square1 = $10
	.label Sound_Square2 = $20
	.label Sound_Noise2 = $40
	.label Sound_Reset = $80

	.label Sound_FullAmp = $3fe
	.label Sound_HalfAmp = $3fd

	.label CharsetAddress_SingleClock = $02
}
