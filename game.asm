.const LEVEL_PACK_INDEX = 0
.const LEVEL_INDEX = 0
.const SHOW_TITLE_SCREEN = true
.const SHOW_LEVEL_PICKER = true

.macro SetCurrentColorPtr(screenPtr) {
		lda screenPtr
		sta ColorPtr
		lda screenPtr + 1
		eor #>(Screen.Address ^ Screen.Colors)
		sta ColorPtr + 1	
}

.macro SetScreenPtrRowY() {
		lda RowAddressesLow,y
		sta ScreenPtr
		lda RowAddressesHigh,y
		sta ScreenPtr + 1
}

.macro DisplayFixedText(textPtr, charX, charY, offsetX, spacing) {
		ldx #charX
		ldy #charY - 1
		jsr SetTargetCharPtrByPosition
		movw #textPtr : TextPtr
		ldx #offsetX
		ldy #spacing
		jsr DisplayText
}

.macro SetFixedTargetCharPtrByCode(code) {
		movw #(CharSet + code * 8) : TargetCharPtr
}

* = * "Game Main"

InitGame:
	lda #0
	sta Input.HorizontalState
	sta Input.VerticalState
	sta Menu.CurrentPane
	lda #LEVEL_PACK_INDEX
	sta Menu.PackIndex
	lda #LEVEL_INDEX
	sta Menu.LevelIndex

	.if (SHOW_TITLE_SCREEN) {
			jmp ShowTitleScreen
	} else .if (SHOW_LEVEL_PICKER) {
			jmp ShowLevelPicker
	} else {
			jmp StartLevel
	}

FrameInterrupt: {
		jsr ProcessInput
		inc FrameCounter
		lda Menu.Active
		beq InitGameFrame
		jmp Done
	InitGameFrame:
		dec Level.DiamondAnimationCounter
		bpl Done
		lda #(Frequency.DiamondAnimationFrames - 1)
		sta Level.DiamondAnimationCounter
		ldx Level.DiamondAnimationFrame
		inx
		cpx #DiamondFrameCount
		bcc !+
		ldx #0
	!:	stx Level.DiamondAnimationFrame
		txa
		asl
		asl
		asl
		tax
		lda DiamondFrames,x
		sta Text.DiamondBase
		lda DiamondFrames + 1,x
		sta Text.DiamondBase + 1
		lda DiamondFrames + 2,x
		sta Text.DiamondBase + 2
		lda DiamondFrames + 3,x
		sta Text.DiamondBase + 3
		lda DiamondFrames + 4,x
		sta Text.DiamondBase + 4
		lda DiamondFrames + 5,x
		sta Text.DiamondBase + 5
		lda DiamondFrames + 6,x
		sta Text.DiamondBase + 6
	Done:
		rts
}

// Skip over X strings at the beginning of the currently active level data and return the offset in Y.
SkipLevelDataText: {
		ldy #0
	Loop:
		lda (LevelPtr),y
		iny
		cmp #Text.Terminator
		bne Loop
		dex
		bne Loop
		rts
}

SetupScreen: {
		lda #0
		sta FrameCounter
		sta RandomIndex1
		sta RandomIndex2
		sta Level.DiamondAnimationFrame
		sta Level.DiamondAnimationCounter

		movw #(Screen.Address + Screen.Width) : ScreenPtr
		lda #Screen.Width
		ldx #Text.TitleBarBaseCode
		jsr PrepareTextArea
		SetFixedTargetCharPtrByCode(Text.TitleBarBaseCode)
		lda #Screen.Width
		jsr ClearTextArea
		ldx #1
		jsr SkipLevelDataText
		sty I
		clc
		lda LevelPtr
		adc I
		sta TextPtr
		lda LevelPtr + 1
		adc #0
		sta TextPtr + 1
		jsr MeasureText
		SetFixedTargetCharPtrByCode(Text.TitleBarBaseCode)
		center_x #320 : Text.Width
		ldy #0
		jsr DisplayText

		movw #StatusBarText : TextPtr
		jsr UpdateStatusBarText
		jsr UpdateDiamondCount
		jsr UpdateLivesCount

		rts
}

StartLevel: {
		jsr WaitForBottom
		movb #0 : TED.Config1

		jsr LoadLevel
		jsr InitObjects
		jsr SetupScreen
		
		jsr WaitForBottom
		movb #Screen.ModeText : TED.Config1
		lda #0
		sta PauseMenu.Active
		sta Menu.Active
		jsr ResetInput

	GameLoop:
		jsr Update
		jmp GameLoop
}

// Fill 1000 bytes at TargetPtr with the value in A.
FillScreenBuffer: {
		ldx #<1000
		ldy #>1000
}

// Fill YX bytes at TargetPtr with the value in A.
FillBuffer: {
		stx CountLow
		sty CountHigh
	.label CountHigh = * + 1
		ldx #0
		beq OuterDone
	Outer:
		ldy #0
	Inner:
		sta (TargetPtr),y
		iny
		bne Inner
		inc TargetPtr + 1
		dex
		bne Outer
	OuterDone:
	.label CountLow = * + 1
		ldy #0
		beq Done
	LastPage:
		dey
		sta (TargetPtr),y
		bne LastPage
	Done:
		rts
}

// Build active object list and lookup tables. Sets carry upon return if there are too many objects on the level.
InitObjects: {
		lda #3
		sta Player.Lives

		lda #Piece.Empty
		sta Level.TileUnderPlayer
		lda #PlayerSpawnPhase
		sta Player.DeathPhase

		lda #0
		sta Level.Diamonds
		sta Level.Diamonds + 1

		movw #Level.ObjectIndices : TargetPtr
		lda #Level.FreeObjectIndex
		jsr FillScreenBuffer

		lda #1
		ldx #0
		sta Counter
	CheckRows:
		ldy Counter
		lda RowAddressesLow,y
		sta ScreenPtr
		sta IndexPtr
		lda RowAddressesHigh,y
		sta ScreenPtr + 1
		lda ObjectIndexRowAddressesHigh,y
		sta IndexPtr + 1
		ldy #1
	CheckTiles:
		lda (ScreenPtr),y
		cmp #Piece.Active
		bcc Inactive
		sta Level.ObjectTypes,x
		txa
		sta (IndexPtr),y
		tya
		sta Level.ObjectXs,x
		lda Counter
		sta Level.ObjectYs,x
		lda #0
		sta Level.ObjectStates,x
		sty I
		ldy Level.ObjectTypes,x
		lda ActivePieceTimings - Piece.Active,y
		sta Level.ObjectCounters,x
		ldy I
		inx
		bne NextTile
		sec
		rts
	Inactive:
		cmp #Piece.Kye
		bne !+
		sty Player.X
		sty Player.StartX
		lda Counter
		sta Player.Y
		sta Player.StartY
		jmp NextTile
	!:	cmp #Piece.Diamond
		bne NextTile
		sed
		clc
		lda Level.Diamonds
		adc #1
		sta Level.Diamonds
		lda Level.Diamonds + 1
		adc #0
		sta Level.Diamonds + 1
		cld
	NextTile:
		iny
		cpy #Level.InnerWidth + 1
		bne CheckTiles
		inc Counter
		ldy Counter
		cpy #Level.InnerHeight + 1
		bne CheckRows
		// Terminator
		lda #Piece.Empty
		sta Level.ObjectTypes,x
		stx Level.ObjectCount

		movw #Level.StickerField : TargetPtr
		lda #0
		jsr FillScreenBuffer

		ldx #0
	InitStickerField:
		lda Level.ObjectTypes,x
		beq Done
		cmp #Piece.StickerLR
		bne CheckVertical
		stx L
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		tax
		jsr AddHorizontalStickerField
		ldx L
		jmp NextSticker
	CheckVertical:
		cmp #Piece.StickerTB
		bne NextSticker
		stx L
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		tax
		jsr AddVerticalStickerField
		ldx L
	NextSticker:
		inx
		bne InitStickerField

	Done:
		clc
		rts
}

WaitForFireRelease: {
	!:	bit Input.Buffer
		bpl !-
	!:	bit Input.Buffer
		bmi !-
		rts	
}

UpdatePauseMenu: {
		movw #(Screen.Colors + Screen.Width * (Level.ScreenY + Level.Height)) : ColorPtr
		ldx PauseMenu.Index
		lda PauseMenuXs,x
		clc
		adc ColorPtr
		sta ColorPtr
		ldx PauseMenu.BlinkPhase
		inx
		cpx #BlinkGradientSize
		bcc !+
		ldx #0
	!:	stx PauseMenu.BlinkPhase
		lda BlinkGradient,x
		tax
		lda #7
		jsr SetTextAreaColor

		bit Input.HorizontalTrigger
		bvc CheckFire
		bpl MoveRight
	MoveLeft:
		ldx PauseMenu.Index
		beq Done
		dex
		stx PauseMenu.Index
		lda #$00
		sta Input.HorizontalTrigger
		lda #7
		ldx BlinkGradient
		jsr SetTextAreaColor
		rts

	MoveRight:
		ldx PauseMenu.Index
		cpx #(PauseMenu.ItemsCount - 1)
		beq Done
		inx
		stx PauseMenu.Index
		lda #$00
		sta Input.HorizontalTrigger
		lda #7
		ldx BlinkGradient
		jsr SetTextAreaColor
		rts

	CheckFire:
		bit Input.Buffer
		bpl Done
		jsr WaitForFireRelease
		lda PauseMenu.Index
		beq Resume
		cmp #1
		beq Restart

	Quit:
		jsr WaitForBottom
		movb #Screen.ModeOff : TED.Config1
		jmp ShowLevelPicker

	Resume:
		jsr WaitForBottom
		lda #0
		sta PauseMenu.Active
		jsr FadeOutStatusBar
		movw #StatusBarText : TextPtr
		jsr UpdateStatusBarText
		jsr UpdateDiamondCount
		jsr UpdateLivesCount
		jsr FadeInStatusBar
		jsr ResetInput
		rts

	Restart:
		jsr WaitForBottom
		lda #0
		sta PauseMenu.Active
		jmp StartLevel

	Done:
		rts
}

Update: {
		lda PauseMenu.Active
		beq StepGame
		jsr UpdatePauseMenu
		jsr WaitForNextFrame
		rts

	StepGame:
		jsr UpdatePlayer
		jsr CheckPlayerAlive
		jsr UpdateLevel
		jsr CheckPlayerAlive

		lda Player.DeathPhase
		bne !+
		jmp HandleInput
	!:	ldx #Frequency.DeathTickFrames
		jsr WaitFrames
		ldx Player.DeathPhase
		bpl GetDeathColor
	GetSpawnColor:
		lda PlayerDeathColors - $100,x
		bpl UpdatePlayerColor
	GetDeathColor:
		lda PlayerDeathColors,x
	UpdatePlayerColor:
		tax
		lda Player.X
		ldy Player.Y
		SetScreenPtrRowY()
		SetCurrentColorPtr(ScreenPtr)
		ldy Player.X
		txa
		sta (ColorPtr),y
		lda Player.DeathPhase
		cmp #PlayerDeathLength - 1
		beq RevivePlayer
		inc Player.DeathPhase
		rts

	RevivePlayer:
		lda Player.Lives
		beq HandleInput

		ldy Player.Y
		SetScreenPtrRowY()
		ldy Player.X
		lda Level.TileUnderPlayer
		sta (ScreenPtr),y
		lda Player.X
		ldy Player.Y
		jsr RefreshTileColor

		// TODO try to find a free spot (the original game spirals counterclockwise starting from bottom left corners)
		lda Player.StartX
		sta Player.X
		ldy Player.StartY
		sty Player.Y
		SetScreenPtrRowY()
		ldy Player.X
		lda #Piece.Kye
		sta (ScreenPtr),y
		SetCurrentColorPtr(ScreenPtr)
		lda #Colors.Background
		sta (ColorPtr),y
		lda #PlayerSpawnPhase
		sta Player.DeathPhase
		lda #Piece.Empty
		sta Level.TileUnderPlayer
		jsr ResetInput

	HandleInput:
		jsr CheckEndGame
		jsr WaitForNextFrame
		rts
}

CheckPlayerAlive: {
		ldy Player.Y
		dey
		clc
		lda RowAddressesLow,y
		adc Player.X
		sta ScreenPtr
		lda RowAddressesHigh,y
		adc #0
		sta ScreenPtr + 1
		ldy #0
		lda (ScreenPtr),y
		tax
		lda PieceFlags,x
		and #$20
		bne KillPlayer
		ldy #(Screen.Width - 1)
		lda (ScreenPtr),y
		tax
		lda PieceFlags,x
		and #$20
		bne KillPlayer
		ldy #(Screen.Width + 1)
		lda (ScreenPtr),y
		tax
		lda PieceFlags,x
		and #$20
		bne KillPlayer
		ldy #(Screen.Width * 2)
		lda (ScreenPtr),y
		tax
		lda PieceFlags,x
		and #$20
		bne KillPlayer
		rts
}

KillPlayer: {
		lda Player.DeathPhase
		bne !+

		dec Player.Lives
		jsr UpdateLivesCount
		inc Player.DeathPhase
	!:	rts
}

UpdateLivesCount: {
		lda Player.Lives
		clc
		adc #Text.NumberCodeBase
		sta CountText
		lda #$ff
		sta CountText + 1

	DisplayCount:
		SetFixedTargetCharPtrByCode(Text.LivesBaseCode)
		lda #2
		jsr ClearTextArea
		movw #CountText : TextPtr
		SetFixedTargetCharPtrByCode(Text.LivesBaseCode)
		ldx #3
		ldy #0
		jsr DisplayText

		rts
}


UpdatePlayer: {
		lda #0
		lda Player.DeathPhase
		beq CheckMovement
		rts

	CheckMovement:
		lda #Piece.Empty
		sta Player.TargetTile

	CheckUp: {
			bit Input.VerticalTrigger
			bpl CheckDown
			bvc CheckDown
		!:	ldy Player.Y
			dey
			beq DoneVertical
			SetScreenPtrRowY()
			ldy Player.X
			lda (ScreenPtr),y
			beq Move
			cmp #Piece.Earth
			beq Move
			cmp #Piece.DoorDU
			bne !+
			sta Player.TargetTile
			jmp Move
		!:	cmp #Piece.Diamond
			bne CheckPush
			jsr EatDiamond
			jmp Move
		CheckPush:
			tay
			lda PieceFlags,y
			bmi Push
			cpy #Piece.Blackhole
			bcc DoneVertical
			cpy #Piece.Blackhole + 4
			bcs DoneVertical
			jmp KillPlayer
		Push:
			lda Player.X
			ldy Player.Y
			dey
			jsr PushTileUp
			bcc DoneVertical
		Move:
			lda Level.TileUnderPlayer
			sta Level.RevealedTile
			lda Player.X
			ldy Player.Y
			dec Player.Y
			jsr MoveTileUp
			lda Player.TargetTile
			sta Level.TileUnderPlayer
	}

	DoneVertical: {
			lda #Player.ForceUpdate
			sta FrameCounter
			lda #0
			sta Input.VerticalTrigger
			rts
	}

	CheckDown: {
			bmi CheckLeft
			bvc CheckLeft
		!:	ldy Player.Y
			cpy #Level.InnerHeight
			beq DoneVertical
			iny
			SetScreenPtrRowY()
			ldy Player.X
			lda (ScreenPtr),y
			beq Move
			cmp #Piece.Earth
			beq Move
			cmp #Piece.DoorUD
			bne !+
			sta Player.TargetTile
			jmp Move
		!:	cmp #Piece.Diamond
			bne CheckPush
			jsr EatDiamond
			jmp Move
		CheckPush:
			tay
			lda PieceFlags,y
			bmi Push
			cpy #Piece.Blackhole
			bcc DoneVertical
			cpy #Piece.Blackhole + 4
			bcs DoneVertical
			jmp KillPlayer
		Push:
			lda Player.X
			ldy Player.Y
			iny
			jsr PushTileDown
			bcc DoneVertical
		Move:
			lda Level.TileUnderPlayer
			sta Level.RevealedTile
			lda Player.X
			ldy Player.Y
			inc Player.Y
			jsr MoveTileDown
			lda Player.TargetTile
			sta Level.TileUnderPlayer
			jmp DoneVertical
	}

	CheckLeft: {
			bit Input.HorizontalTrigger
			bpl CheckRight
			bvc CheckRight
		!:	ldy Player.X
			dey
			beq DoneHorizontal
			ldy Player.Y
			SetScreenPtrRowY()
			ldy Player.X
			dey
			lda (ScreenPtr),y
			beq Move
			cmp #Piece.Earth
			beq Move
			cmp #Piece.DoorRL
			bne !+
			sta Player.TargetTile
			jmp Move
		!:	cmp #Piece.Diamond
			bne CheckPush
			jsr EatDiamond
			jmp Move
		CheckPush:
			tay
			lda PieceFlags,y
			bmi Push
			cpy #Piece.Blackhole
			bcc DoneHorizontal
			cpy #Piece.Blackhole + 4
			bcs DoneHorizontal
			jmp KillPlayer
		Push:
			lda Player.X
			ldy Player.Y
			sec
			sbc #1
			jsr PushTileLeft
			bcc DoneHorizontal
		Move:
			lda Level.TileUnderPlayer
			sta Level.RevealedTile
			lda Player.X
			ldy Player.Y
			dec Player.X
			jsr MoveTileLeft
			lda Player.TargetTile
			sta Level.TileUnderPlayer
	}

	DoneHorizontal: {
			lda #Player.ForceUpdate
			sta FrameCounter
			lda #0
			sta Input.HorizontalTrigger
			rts
	}

	CheckRight: {
			bmi CheckFire
			bvc CheckFire
		!:	ldy Player.X
			cpy #Level.InnerWidth
			beq DoneHorizontal
			ldy Player.Y
			SetScreenPtrRowY()
			ldy Player.X
			iny
			lda (ScreenPtr),y
			beq Move
			cmp #Piece.Earth
			beq Move
			cmp #Piece.DoorLR
			bne !+
			sta Player.TargetTile
			jmp Move
		!:	cmp #Piece.Diamond
			bne CheckPush
			jsr EatDiamond
			jmp Move
		CheckPush:
			tay
			lda PieceFlags,y
			bmi Push
			cpy #Piece.Blackhole
			bcc DoneHorizontal
			cpy #Piece.Blackhole + 4
			bcs DoneHorizontal
			jmp KillPlayer
		Push:
			lda Player.X
			ldy Player.Y
			clc
			adc #1
			jsr PushTileRight
			bcc DoneHorizontal
		Move:
			lda Level.TileUnderPlayer
			sta Level.RevealedTile
			lda Player.X
			ldy Player.Y
			inc Player.X
			jsr MoveTileRight
			lda Player.TargetTile
			sta Level.TileUnderPlayer
			jmp DoneHorizontal
	}

	CheckFire: {
			lda Input.Buffer
			bpl Done
			jsr WaitForFireRelease
			jsr FadeOutStatusBar
			movw #PauseMenuText : TextPtr
			jsr UpdateStatusBarText
			lda #0
			sta PauseMenu.Index
			sta PauseMenu.BlinkPhase
			jsr FadeInStatusBar
			jsr WaitForBottom
			lda #1
			sta PauseMenu.Active

		Done:
			rts
	}
}

CheckEndGame: {
		lda Level.Diamonds
		ora Level.Diamonds + 1
		beq Victory

		lda Player.Lives
		beq LevelLost

		rts

	LevelLost:
		movw #LostText : TextPtr
		jmp ShowFinalStatusMessage

	Victory:
		inc Menu.LevelIndex
		movw #VictoryText : TextPtr
		jmp ShowFinalStatusMessage
}

ShowFinalStatusMessage: {
		jsr FadeOutStatusBar
		jsr UpdateStatusBarText
		jsr FadeInStatusBar
		jsr WaitForFireRelease
		jmp StartLevel
}

* = * "Game Logic"

EatDiamond: {
		sed
		sec
		lda Level.Diamonds
		sbc #1
		sta Level.Diamonds
		lda Level.Diamonds + 1
		sbc #0
		sta Level.Diamonds + 1
		cld
		jmp UpdateDiamondCount
}

UpdateDiamondCount: {
		ldx #0

		lda Level.Diamonds + 1
		beq CheckTwoDigits

	ThreeDigits:
		clc
		adc #Text.NumberCodeBase
		sta CountText,x
		inx
		jmp TwoDigits

	CheckTwoDigits:
		lda Level.Diamonds
		cmp #$10
		bcc OneDigit

	TwoDigits:
		lda Level.Diamonds
		lsr
		lsr
		lsr
		lsr
		clc
		adc #Text.NumberCodeBase
		sta CountText,x
		inx

	OneDigit:
		lda Level.Diamonds
		and #$0f
		clc
		adc #Text.NumberCodeBase
		sta CountText,x
		inx
		lda #$ff
		sta CountText,x

	DisplayCount:
		SetFixedTargetCharPtrByCode(Text.DiamondsBaseCode)
		lda #4
		jsr ClearTextArea
		movw #CountText : TextPtr
		SetFixedTargetCharPtrByCode(Text.DiamondsBaseCode)
		ldx #1
		ldy #0
		jsr DisplayText

		rts
}

UpdateLevel: {
		ldx FrameCounter
		lda Input.HorizontalState
		ora Input.VerticalState
		bne CheckIfJustMoved
		cpx #Frequency.IdleTickFrames
		bcs Update
	SkipUpdate:
		rts

	CheckIfJustMoved:
		cpx #Player.ForceUpdate
		bne SkipUpdate

	Update:
		ldx #0
		stx FrameCounter
		stx Level.DefragNeeded
		lda #Piece.Empty
		sta Level.RevealedTile		
	ProcessObjects:
		lda Level.ObjectTypes,x
		beq ObjectsDone
		bmi ProcessNext
		dec Level.ObjectCounters,x
		beq ProcessObject
	ProcessNext:
		inx
		bne ProcessObjects

	ObjectsDone:
		lda Level.DefragNeeded
		beq Done
		ldx #0
	DefragStart:
		lda Level.ObjectTypes,x
		bmi FoundFirstDead
		inx
		bne DefragStart
	FoundFirstDead:
		txa
		tay
	Defrag:
		lda Level.ObjectTypes,y
		bpl Copy
		bne DefragNext
	Copy:
		lda	Level.ObjectTypes,y
		sta	Level.ObjectTypes,x
		beq Done
		lda	Level.ObjectCounters,y
		sta	Level.ObjectCounters,x
		lda	Level.ObjectStates,y
		sta	Level.ObjectStates,x
		lda	Level.ObjectXs,y
		sta	Level.ObjectXs,x
		sta PX
		lda	Level.ObjectYs,y
		sta	Level.ObjectYs,x
		sty I
		tay
		lda RowAddressesLow,y
		sta IndexPtr
		lda ObjectIndexRowAddressesHigh,y
		sta IndexPtr + 1
		ldy PX
		txa
		sta (IndexPtr),y
		ldy I
		inx
	DefragNext:
		iny
		bne Defrag
	Done:
		stx Level.ObjectCount
		rts

	ProcessObject:
		stx Level.ObjectIndex
		ldy Level.ObjectTypes,x
		lda ActivePieceTimings - Piece.Active,y
		sta Level.ObjectCounters,x
		lda UpdateAddressesLow - Piece.Active,y
		sta UpdateJump + 1
		lda UpdateAddressesHigh - Piece.Active,y
		sta UpdateJump + 2
	UpdateJump:
		jmp NextObject
	@NextObject:
		ldx Level.ObjectIndex
		jmp ProcessNext
}

// Increment horizontal sticker field around (X,Y).
AddHorizontalStickerField: {
		sec
		lda RowAddressesLow,y
		sbc #2
		sta Loop + 1
		lda StickerFieldRowAddressesHigh,y
		sbc #0
		sta Loop + 2
		txa
		clc
		adc #5
		sta I
	Loop:
		inc Level.StickerField,x
		inx
		cpx I
		bne Loop
		rts
}

// Decrement horizontal sticker field around (X,Y).
RemoveHorizontalStickerField: {
		sec
		lda RowAddressesLow,y
		sbc #2
		sta Loop + 1
		lda StickerFieldRowAddressesHigh,y
		sbc #0
		sta Loop + 2
		txa
		clc
		adc #5
		sta I
	Loop:
		dec Level.StickerField,x
		inx
		cpx I
		bne Loop
		rts
}

// Increment vertical sticker field around (X,Y).
AddVerticalStickerField: {
		stx I
		sec
		lda #(Screen.Width * 2)
		sbc I
		sta I
		sec
		lda RowAddressesLow,y
		sbc I
		sta Loop + 1
		lda StickerFieldRowAddressesHigh,y
		sbc #0
		sta Loop + 2
		ldx #0
	Loop:
		inc Level.StickerField,x
		txa
		clc
		adc #Screen.Width
		tax
		cpx #(Screen.Width * 5)
		bne Loop
		rts
}

// Decrement vertical sticker field around (X,Y).
RemoveVerticalStickerField: {
		stx I
		sec
		lda #(Screen.Width * 2)
		sbc I
		sta I
		sec
		lda RowAddressesLow,y
		sbc I
		sta Loop + 1
		lda StickerFieldRowAddressesHigh,y
		sbc #0
		sta Loop + 2
		ldx #0
	Loop:
		dec Level.StickerField,x
		txa
		clc
		adc #Screen.Width
		tax
		cpx #(Screen.Width * 5)
		bne Loop
		rts
}

// Find object at (A,Y), and return its index in X. Sets Z flag if there's no active object on the tile.
FindObjectByPosition: {
		sta I
		lda RowAddressesLow,y
		sta IndexPtr
		lda ObjectIndexRowAddressesHigh,y
		sta IndexPtr + 1
		ldy I
		lda (IndexPtr),y
		tax
		cpx #Level.FreeObjectIndex
		rts
}

// Create a new object of type A and place it at (X,Y). Doesn't handle stickers correctly.
AddNewObject: {
		stx I
		ldx Level.ObjectCount
		inc Level.ObjectCount
		bne Add
		dec Level.ObjectCount
		rts

	Add:
		sta Level.ObjectTypes,x
		sta J
		lda #0
		sta Level.ObjectTypes + 1,x
		tya
		sta Level.ObjectYs,x
		lda I
		sta Level.ObjectXs,x
		sty I
		ldy J
		lda ActivePieceTimings - Piece.Active,y
		clc
		adc #1
		sta Level.ObjectCounters,x

		ldy I
		lda RowAddressesLow,y
		sta ScreenPtr
		sta ColorPtr
		sta IndexPtr
		lda RowAddressesHigh,y
		sta ScreenPtr + 1
		eor #>(Screen.Address ^ Level.ObjectIndices)
		sta IndexPtr + 1
		eor #>(Screen.Colors ^ Level.ObjectIndices)
		sta ColorPtr + 1
		lda Level.ObjectTypes,x
		ldy Level.ObjectXs,x
		sta (ScreenPtr),y
		sta I
		txa
		sta (IndexPtr),y
		ldx I
		lda CharColors,x
		sta (ColorPtr),y

		rts
}

// Set C if the tile at (A,Y) can be pushed by the bouncers. Preserves A and Y.
CheckIfTileBounceable: {
		sta I
		sty J
		SetScreenPtrRowY()
		ldy I
		lda (ScreenPtr),y
		tay
		lda PieceFlags,y
		asl
		asl
		lda I
		ldy J
		rts
}

// Change the type of object X to A and reflect it on the screen too. Colour is not adjusted.
UpdateObjectType: {
		sta Level.ObjectTypes,x
		ldy Level.ObjectYs,x
		SetScreenPtrRowY()
		ldy Level.ObjectXs,x
		lda Level.ObjectTypes,x
		sta (ScreenPtr),y
		rts
}

// Clear the tile at (A,Y) and the mark the underlying object as dead if there is one.
ClearTile: {
		sta I
		lda RowAddressesLow,y
		sta ScreenPtr
		sta IndexPtr
		lda RowAddressesHigh,y
		sta ScreenPtr + 1
		eor #>(Screen.Address ^ Level.ObjectIndices)
		sta IndexPtr + 1
		ldy I
		lda #Piece.Empty
		sta (ScreenPtr),y
		lda (IndexPtr),y
		cmp #Level.FreeObjectIndex
		beq Done
		tax
		lda #Level.FreeObjectIndex
		sta (IndexPtr),y
		ldy Level.ObjectTypes,x
		lda #Piece.Dead
		sta Level.ObjectTypes,x
		sta Level.DefragNeeded
		cpy #Piece.StickerLR
		bne !+
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		tax
		jsr RemoveHorizontalStickerField
	!:	cpy #Piece.StickerTB
		bne Done
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		tax
		jsr RemoveVerticalStickerField
	Done:
		rts
}

// Refresh the colour of the tile at (A,Y) with the correct value.
RefreshTileColor: {
		sta I
		lda RowAddressesLow,y
		sta ScreenPtr
		sta ColorPtr
		lda RowAddressesHigh,y
		sta ScreenPtr + 1
		eor #>(Screen.Address ^ Screen.Colors)
		sta ColorPtr + 1
		ldy I
		lda (ScreenPtr),y
		tax
		lda CharColors,x
		sta (ColorPtr),y
		rts
}

// Move tile at (A,Y) upwards, including the underlying object if there is one.
MoveTileUp: {
		sty UY
		sta I
		lsr
		sta UX
		sec
		lda #Screen.Width
		sbc I
		sta I
		sec
		lda RowAddressesLow,y
		sbc I
		sta ScreenPtr
		sta IndexPtr
		sta ColorPtr
		lda RowAddressesHigh,y
		sbc #0
		sta ScreenPtr + 1
		eor #>(Screen.Address ^ Level.ObjectIndices)
		sta IndexPtr + 1
		eor #>(Screen.Colors ^ Level.ObjectIndices)
		sta ColorPtr + 1

	UpdateScreen:
		ldy #Screen.Width
		lda (ScreenPtr),y
		sta I
		lda Level.RevealedTile
		sta (ScreenPtr),y
		lda (ColorPtr),y
		sta J
		lda #Colors.Door
		sta (ColorPtr),y
		lda J
		ldy #0
		sta (ColorPtr),y
		lda I
		sta (ScreenPtr),y

	UpdateObject:
		ldy #Screen.Width
		lda (IndexPtr),y
		cmp #Level.FreeObjectIndex
		bne MoveObject
		rts

	MoveObject:
		tax
		dec Level.ObjectYs,x
		lda #Level.FreeObjectIndex
		sta (IndexPtr),y		
		ldy #0
		txa
		sta (IndexPtr),y

		lda Level.ObjectTypes,x
		cmp #Piece.StickerLR
		bne !+
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		tax
		stx J
		sty K
		iny
		jsr RemoveHorizontalStickerField
		ldx J
		ldy K
		jsr AddHorizontalStickerField
		rts
	!:	cmp #Piece.StickerTB
		bne Done
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		tax
		stx J
		sty K
		iny
		jsr RemoveVerticalStickerField
		ldx J
		ldy K
		jsr AddVerticalStickerField
		bne Done
	Done:
		rts
}

// Push tile at (A,Y) upwards if possible, and handle its consumption by a black hole.
// Set carry if the push succeeded. If the push failed, A contains the type of the blocker.
PushTileUp: {
		sta PX
		sty PY

		dey
		SetScreenPtrRowY()

		ldy PX
		lda (ScreenPtr),y
		beq Push
		cmp #Piece.Blackhole
		bcc Stay
		cmp #Piece.Blackhole + 4
		bcs Stay

	Consume:
		lda PX
		ldy PY
		jsr ClearTile
		lda PX
		ldy PY
		dey
		jsr FindObjectByPosition
		lda #Piece.BlackholeFull
		jsr UpdateObjectType
		lda PX
		ldy PY
		dey
		jsr RefreshTileColor
		lsr PX
		sec
		rts

	Push:
		lda PX
		ldy PY
		jsr MoveTileUp
		sec
		rts

	Stay:
		clc
		rts
}

// Move tile at (A,Y) downwards, including the underlying object if there is one.
MoveTileDown: {
		sty UY
		sta I
		lsr
		sta UX
		clc
		lda RowAddressesLow,y
		adc I
		sta ScreenPtr
		sta IndexPtr
		sta ColorPtr
		lda RowAddressesHigh,y
		adc #0
		sta ScreenPtr + 1
		eor #>(Screen.Address ^ Level.ObjectIndices)
		sta IndexPtr + 1
		eor #>(Screen.Colors ^ Level.ObjectIndices)
		sta ColorPtr + 1

	UpdateScreen:
		ldy #0
		lda (ScreenPtr),y
		sta I
		lda Level.RevealedTile
		sta (ScreenPtr),y
		lda (ColorPtr),y
		sta J
		lda #Colors.Door
		sta (ColorPtr),y
		lda J
		ldy #Screen.Width
		sta (ColorPtr),y
		lda I
		sta (ScreenPtr),y

	UpdateObject:
		ldy #0
		lda (IndexPtr),y
		cmp #Level.FreeObjectIndex
		bne MoveObject
		rts

	MoveObject:
		tax
		inc Level.ObjectYs,x
		lda #Level.FreeObjectIndex
		sta (IndexPtr),y		
		ldy #Screen.Width
		txa
		sta (IndexPtr),y

		lda Level.ObjectTypes,x
		cmp #Piece.StickerLR
		bne !+
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		tax
		stx J
		sty K
		dey
		jsr RemoveHorizontalStickerField
		ldx J
		ldy K
		jsr AddHorizontalStickerField
		rts
	!:	cmp #Piece.StickerTB
		bne Done
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		tax
		stx J
		sty K
		dey
		jsr RemoveVerticalStickerField
		ldx J
		ldy K
		jsr AddVerticalStickerField
		bne Done
	Done:
		rts
}

// Push tile at (A,Y) downwards if possible, and handle its consumption by a black hole.
// Set carry if the push succeeded. If the push failed, A contains the type of the blocker.
PushTileDown: {
		sta PX
		sty PY

		iny
		SetScreenPtrRowY()

		ldy PX
		lda (ScreenPtr),y
		beq Push
		cmp #Piece.Blackhole
		bcc Stay
		cmp #Piece.Blackhole + 4
		bcs Stay

	Consume:
		lda PX
		ldy PY
		jsr ClearTile
		lda PX
		ldy PY
		iny
		jsr FindObjectByPosition
		lda #Piece.BlackholeFull
		jsr UpdateObjectType
		lda PX
		ldy PY
		iny
		jsr RefreshTileColor
		lsr PX
		sec
		rts

	Push:
		lda PX
		ldy PY
		jsr MoveTileDown
		sec
		rts

	Stay:
		clc
		rts
}

// Move tile at (A,Y) leftwards, including the underlying object if there is one.
MoveTileLeft: {
		sty UY
		sta I
		sta UX
		dec I
		clc
		lda RowAddressesLow,y
		adc I
		sta ScreenPtr
		sta IndexPtr
		sta ColorPtr
		lda RowAddressesHigh,y
		adc #0
		sta ScreenPtr + 1
		eor #>(Screen.Address ^ Level.ObjectIndices)
		sta IndexPtr + 1
		eor #>(Screen.Colors ^ Level.ObjectIndices)
		sta ColorPtr + 1

	UpdateScreen:
		ldy #1
		lda (ScreenPtr),y
		sta I
		lda Level.RevealedTile
		sta (ScreenPtr),y
		lda (ColorPtr),y
		sta J
		lda #Colors.Door
		sta (ColorPtr),y
		lda J
		ldy #0
		sta (ColorPtr),y
		lda I
		sta (ScreenPtr),y

	UpdateObject:
		ldy #1
		lda (IndexPtr),y
		cmp #Level.FreeObjectIndex
		bne MoveObject
		rts

	MoveObject:
		tax
		dec Level.ObjectXs,x
		lda #Level.FreeObjectIndex
		sta (IndexPtr),y		
		ldy #0
		txa
		sta (IndexPtr),y

		lda Level.ObjectTypes,x
		cmp #Piece.StickerLR
		bne !+
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		tax
		stx J
		sty K
		inx
		jsr RemoveHorizontalStickerField
		ldx J
		ldy K
		jsr AddHorizontalStickerField
		rts
	!:	cmp #Piece.StickerTB
		bne Done
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		tax
		stx J
		sty K
		inx
		jsr RemoveVerticalStickerField
		ldx J
		ldy K
		jsr AddVerticalStickerField
		bne Done
	Done:
		rts
}

// Push tile at (A,Y) leftwards if possible, and handle its consumption by a black hole.
// Set carry if the push succeeded. If the push failed, A contains the type of the blocker.
PushTileLeft: {
		sta PX
		sty PY

		SetScreenPtrRowY()

		ldy PX
		dey
		lda (ScreenPtr),y
		beq Push
		cmp #Piece.Blackhole
		bcc Stay
		cmp #Piece.Blackhole + 4
		bcs Stay

	Consume:
		lda PX
		ldy PY
		jsr ClearTile
		lda PX
		ldy PY
		sec
		sbc #1
		jsr FindObjectByPosition
		lda #Piece.BlackholeFull
		jsr UpdateObjectType
		lda PX
		ldy PY
		sec
		sbc #1
		jsr RefreshTileColor
		lsr PX
		sec
		rts

	Push:
		lda PX
		ldy PY
		jsr MoveTileLeft
		sec
		rts

	Stay:
		clc
		rts
}

// Move tile at (A,Y) rightwards, including the underlying object if there is one.
MoveTileRight: {
		sty UY
		sta I
		sta UX
		clc
		lda RowAddressesLow,y
		adc I
		sta ScreenPtr
		sta IndexPtr
		sta ColorPtr
		lda RowAddressesHigh,y
		adc #0
		sta ScreenPtr + 1
		eor #>(Screen.Address ^ Level.ObjectIndices)
		sta IndexPtr + 1
		eor #>(Screen.Colors ^ Level.ObjectIndices)
		sta ColorPtr + 1

	UpdateScreen:
		ldy #0
		lda (ScreenPtr),y
		sta I
		lda Level.RevealedTile
		sta (ScreenPtr),y
		lda (ColorPtr),y
		sta J
		lda #Colors.Door
		sta (ColorPtr),y
		lda J
		ldy #1
		sta (ColorPtr),y
		lda I
		sta (ScreenPtr),y

	UpdateObject:
		ldy #0
		lda (IndexPtr),y
		cmp #Level.FreeObjectIndex
		bne MoveObject
		rts

	MoveObject:
		tax
		inc Level.ObjectXs,x
		lda #Level.FreeObjectIndex
		sta (IndexPtr),y		
		ldy #1
		txa
		sta (IndexPtr),y

		lda Level.ObjectTypes,x
		cmp #Piece.StickerLR
		bne !+
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		tax
		stx J
		sty K
		dex
		jsr RemoveHorizontalStickerField
		ldx J
		ldy K
		jsr AddHorizontalStickerField
		rts
	!:	cmp #Piece.StickerTB
		bne Done
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		tax
		stx J
		sty K
		dex
		jsr RemoveVerticalStickerField
		ldx J
		ldy K
		jsr AddVerticalStickerField
		bne Done
	Done:
		rts
}

// Push tile at (A,Y) rightwards if possible, and handle its consumption by a black hole.
// Set carry if the push succeeded. If the push failed, A contains the type of the blocker.
PushTileRight: {
		sta PX
		sty PY

		SetScreenPtrRowY()

		ldy PX
		iny
		lda (ScreenPtr),y
		beq Push
		cmp #Piece.Blackhole
		bcc Stay
		cmp #Piece.Blackhole + 4
		bcs Stay

	Consume:
		lda PX
		ldy PY
		jsr ClearTile
		lda PX
		ldy PY
		clc
		adc #1
		jsr FindObjectByPosition
		lda #Piece.BlackholeFull
		jsr UpdateObjectType
		lda PX
		ldy PY
		clc
		adc #1
		jsr RefreshTileColor
		lsr PX
		sec
		rts

	Push:
		lda PX
		ldy PY
		jsr MoveTileRight
		sec
		rts

	Stay:
		clc
		rts
}

// Check stickers acting on object X, and set the carry on return if it's stuck to one.
CheckNearbyStickers: {
		ldy Level.ObjectYs,x
		lda RowAddressesLow,y
		sta StickerFieldPtr
		lda StickerFieldRowAddressesHigh,y
		sta StickerFieldPtr + 1
		ldy Level.ObjectXs,x
		lda (StickerFieldPtr),y
		bne StickerNearby
		clc
		rts

	StickerNearby:
		ldy Level.ObjectYs,x
		sec
		lda RowAddressesLow,y
		sbc #Level.StickerOrigin
		sta ScreenPtr
		lda RowAddressesHigh,y
		sbc #0
		sta ScreenPtr + 1
		clc
		lda ScreenPtr
		adc Level.ObjectXs,x
		sta ScreenPtr
		lda ScreenPtr + 1
		adc #0
		sta ScreenPtr + 1

	CheckMoveDown:
		ldy #(Level.StickerOrigin + Screen.Width)
		lda (ScreenPtr),y
		bne CheckMoveUp
		ldy #(Level.StickerOrigin + Screen.Width * 2)
		lda (ScreenPtr),y
		cmp #Piece.StickerTB
		bne CheckMoveUp
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		jsr MoveTileDown
		sec
		rts

	CheckMoveUp:
		ldy #(Level.StickerOrigin - Screen.Width)
		lda (ScreenPtr),y
		bne CheckMoveRight
		ldy #(Level.StickerOrigin - Screen.Width * 2)
		lda (ScreenPtr),y
		cmp #Piece.StickerTB
		bne CheckMoveRight
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		jsr MoveTileUp
		sec
		rts

	CheckMoveRight:
		ldy #(Level.StickerOrigin + 1)
		lda (ScreenPtr),y
		bne CheckMoveLeft
		iny
		lda (ScreenPtr),y
		cmp #Piece.StickerLR
		bne CheckMoveLeft
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		jsr MoveTileRight
		sec
		rts

	CheckMoveLeft:
		ldy #(Level.StickerOrigin - 1)
		lda (ScreenPtr),y
		bne CheckDown
		dey
		lda (ScreenPtr),y
		cmp #Piece.StickerLR
		bne CheckDown
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		jsr MoveTileLeft
		sec
		rts

	CheckDown:
		ldy #(Level.StickerOrigin + Screen.Width)
		lda (ScreenPtr),y
		cmp #Piece.StickerTB
		beq Stuck

	CheckUp:
		ldy #(Level.StickerOrigin - Screen.Width)
		lda (ScreenPtr),y
		cmp #Piece.StickerTB
		beq Stuck

	CheckRight:
		ldy #(Level.StickerOrigin + 1)
		lda (ScreenPtr),y
		cmp #Piece.StickerLR
		beq Stuck

	CheckLeft:
		ldy #(Level.StickerOrigin - 1)
		lda (ScreenPtr),y
		cmp #Piece.StickerLR
		beq Stuck

	Free:
		clc
		rts

	Stuck:
		sec
		rts
}

UpdateSliderUp: {
		jsr CheckNearbyStickers
		bcs Done
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		jsr PushTileUp
		bcc UpdateSliderCommon
	Done:
		jmp NextObject
}

UpdateSliderDown: {
		jsr CheckNearbyStickers
		bcs Done
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		jsr PushTileDown
		bcc UpdateSliderCommon
	Done:
		jmp NextObject
}

UpdateSliderLeft: {
		jsr CheckNearbyStickers
		bcs Done
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		jsr PushTileLeft
		bcc UpdateSliderCommon
	Done:
		jmp NextObject
}

UpdateSliderRight: {
		jsr CheckNearbyStickers
		bcs Done
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		jsr PushTileRight
		bcc UpdateSliderCommon
	Done:
		jmp NextObject
}

UpdateSliderCommon: {
		ldx Level.ObjectIndex
		cmp #Piece.Clocker
		bne !+
		ldy Level.ObjectTypes,x
		lda PiecesRotatedAntiClockwise - Piece.Active,y
		jsr UpdateObjectType
		jmp NextObject
	!:	cmp #Piece.AntiClocker
		bne Done
		ldy Level.ObjectTypes,x
		lda PiecesRotatedClockwise - Piece.Active,y
		jsr UpdateObjectType
	Done:
		jmp NextObject	
}

UpdateRockyUp: {
		jsr CheckNearbyStickers
		bcs Done
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		jsr PushTileUp
		bcs Done
		jsr UpdateRockyCommon
		bne Roll

	Done:
		jmp NextObject

	Roll:
		tay
		lda PieceFlags,y
		and #%1100
		beq Done

		sta RollDirs
		ldx Level.ObjectIndex
		lda #(Screen.Width + 1)
		sec
		sbc Level.ObjectXs,x
		sta I
		ldy Level.ObjectYs,x
		sec
		lda RowAddressesLow,y
		sbc I
		sta ScreenPtr
		lda RowAddressesHigh,y
		sbc #0
		sta ScreenPtr + 1

	CheckLeft:
		ldy #Screen.Width
		lda (ScreenPtr),y
		bne LeftBlocked
		ldy #0
		lda (ScreenPtr),y
		beq CheckRight
	LeftBlocked:
		lda RollDirs
		and #%1000
		beq Done
		sta RollDirs
	CheckRight:
		ldy #(Screen.Width + 2)
		lda (ScreenPtr),y
		bne RightBlocked
		ldy #2
		lda (ScreenPtr),y
		beq PickRoll
	RightBlocked:
		lda RollDirs
		and #%0100
		beq Done
		sta RollDirs

	PickRoll:
		lda RollDirs
		cmp #%0100
		beq RollLeft
		cmp #%1000
		beq RollRight
		inc Level.RockySide
		lda Level.RockySide
		ror
		bcc RollLeft
		bcs RollRight

	RollLeft:
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		sta RX
		sty RY
		jsr MoveTileLeft
		dec RX
		lda RX
		ldy RY
		jsr MoveTileUp
		jmp NextObject

	RollRight:
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		sta RX
		sty RY
		jsr MoveTileRight
		inc RX
		lda RX
		ldy RY
		jsr MoveTileUp
		jmp NextObject
}

UpdateRockyDown: {
		jsr CheckNearbyStickers
		bcs Done
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		jsr PushTileDown
		bcs Done
		jsr UpdateRockyCommon
		bne Roll

	Done:
		jmp NextObject

	Roll:
		tay
		lda PieceFlags,y
		and #%0011
		beq Done

		sta RollDirs
		ldx Level.ObjectIndex
		lda #(Screen.Width + 1)
		sec
		sbc Level.ObjectXs,x
		sta I
		ldy Level.ObjectYs,x
		sec
		lda RowAddressesLow,y
		sbc I
		sta ScreenPtr
		lda RowAddressesHigh,y
		sbc #0
		sta ScreenPtr + 1

	CheckLeft:
		ldy #Screen.Width
		lda (ScreenPtr),y
		bne LeftBlocked
		ldy #(Screen.Width * 2)
		lda (ScreenPtr),y
		beq CheckRight
	LeftBlocked:
		lda RollDirs
		and #%0010
		beq Done
		sta RollDirs
	CheckRight:
		ldy #(Screen.Width + 2)
		lda (ScreenPtr),y
		bne RightBlocked
		ldy #(Screen.Width * 2 + 2)
		lda (ScreenPtr),y
		beq PickRoll
	RightBlocked:
		lda RollDirs
		and #%0001
		beq Done
		sta RollDirs

	PickRoll:
		lda RollDirs
		cmp #%0001
		beq RollLeft
		cmp #%0010
		beq RollRight
		inc Level.RockySide
		lda Level.RockySide
		ror
		bcc RollLeft
		bcs RollRight

	RollLeft:
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		sta RX
		sty RY
		jsr MoveTileLeft
		dec RX
		lda RX
		ldy RY
		jsr MoveTileDown
		jmp NextObject

	RollRight:
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		sta RX
		sty RY
		jsr MoveTileRight
		inc RX
		lda RX
		ldy RY
		jsr MoveTileDown
		jmp NextObject
}

UpdateRockyLeft: {
		jsr CheckNearbyStickers
		bcs Done
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		jsr PushTileLeft
		bcs Done
		jsr UpdateRockyCommon
		bne Roll

	Done:
		jmp NextObject

	Roll:
		tay
		lda PieceFlags,y
		and #%1010
		beq Done

		sta RollDirs
		ldx Level.ObjectIndex
		lda #(Screen.Width + 1)
		sec
		sbc Level.ObjectXs,x
		sta I
		ldy Level.ObjectYs,x
		sec
		lda RowAddressesLow,y
		sbc I
		sta ScreenPtr
		lda RowAddressesHigh,y
		sbc #0
		sta ScreenPtr + 1

	CheckUp:
		ldy #1
		lda (ScreenPtr),y
		bne UpBlocked
		ldy #0
		lda (ScreenPtr),y
		beq CheckDown
	UpBlocked:
		lda RollDirs
		and #%1000
		beq Done
		sta RollDirs
	CheckDown:
		ldy #(Screen.Width * 2 + 1)
		lda (ScreenPtr),y
		bne DownBlocked
		ldy #(Screen.Width * 2)
		lda (ScreenPtr),y
		beq PickRoll
	DownBlocked:
		lda RollDirs
		and #%0010
		beq Done
		sta RollDirs

	PickRoll:
		lda RollDirs
		cmp #%0010
		beq RollUp
		cmp #%1000
		beq RollDown
		inc Level.RockySide
		lda Level.RockySide
		ror
		bcc RollUp
		bcs RollDown

	RollUp:
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		sta RX
		sty RY
		jsr MoveTileUp
		lda RX
		ldy RY
		dey
		jsr MoveTileLeft
		jmp NextObject

	RollDown:
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		sta RX
		sty RY
		jsr MoveTileDown
		lda RX
		ldy RY
		iny
		jsr MoveTileLeft
		jmp NextObject
}

UpdateRockyRight: {
		jsr CheckNearbyStickers
		bcs Done
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		jsr PushTileRight
		bcs Done
		jsr UpdateRockyCommon
		bne Roll

	Done:
		jmp NextObject

	Roll:
		tay
		lda PieceFlags,y
		and #%0101
		beq Done

		sta RollDirs
		ldx Level.ObjectIndex
		lda #(Screen.Width + 1)
		sec
		sbc Level.ObjectXs,x
		sta I
		ldy Level.ObjectYs,x
		sec
		lda RowAddressesLow,y
		sbc I
		sta ScreenPtr
		lda RowAddressesHigh,y
		sbc #0
		sta ScreenPtr + 1

	CheckUp:
		ldy #1
		lda (ScreenPtr),y
		bne UpBlocked
		ldy #2
		lda (ScreenPtr),y
		beq CheckDown
	UpBlocked:
		lda RollDirs
		and #%0100
		beq Done
		sta RollDirs
	CheckDown:
		ldy #(Screen.Width * 2 + 1)
		lda (ScreenPtr),y
		bne DownBlocked
		ldy #(Screen.Width * 2 + 2)
		lda (ScreenPtr),y
		beq PickRoll
	DownBlocked:
		lda RollDirs
		and #%0001
		beq Done
		sta RollDirs

	PickRoll:
		lda RollDirs
		cmp #%0001
		beq RollUp
		cmp #%0100
		beq RollDown
		inc Level.RockySide
		lda Level.RockySide
		ror
		bcc RollUp
		bcs RollDown

	RollUp:
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		sta RX
		sty RY
		jsr MoveTileUp
		lda RX
		ldy RY
		dey
		jsr MoveTileRight
		jmp NextObject

	RollDown:
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		sta RX
		sty RY
		jsr MoveTileDown
		lda RX
		ldy RY
		iny
		jsr MoveTileRight
		jmp NextObject
}

UpdateRockyCommon: {
		ldx Level.ObjectIndex
		cmp #Piece.Clocker
		bne !+
		ldy Level.ObjectTypes,x
		lda PiecesRotatedAntiClockwise - Piece.Active,y
		jsr UpdateObjectType
		lda #0
		rts
	!:	cmp #Piece.AntiClocker
		bne Done
		ldy Level.ObjectTypes,x
		lda PiecesRotatedClockwise - Piece.Active,y
		jsr UpdateObjectType
		lda #0
	Done:
		rts
}

UpdateBouncerUp: {
		jsr CheckNearbyStickers
		bcs Done
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		jsr PushTileUp
		bcc Bounce
		jmp NextObject
	Bounce:
		ldx Level.ObjectIndex
		lda #Piece.BouncerDown
		jsr UpdateObjectType
		ldx Level.ObjectIndex
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		dey
		jsr CheckIfTileBounceable
		bcc Done
		jsr PushTileUp
	Done:
		jmp NextObject
}

UpdateBouncerDown: {
		jsr CheckNearbyStickers
		bcs Done
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		jsr PushTileDown
		bcc Bounce
		jmp NextObject
	Bounce:
		ldx Level.ObjectIndex
		lda #Piece.BouncerUp
		jsr UpdateObjectType
		ldx Level.ObjectIndex
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		iny
		jsr CheckIfTileBounceable
		bcc Done
		jsr PushTileDown
	Done:
		jmp NextObject
}

UpdateBouncerLeft: {
		jsr CheckNearbyStickers
		bcs Done
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		jsr PushTileLeft
		bcc Bounce
		jmp NextObject
	Bounce:
		ldx Level.ObjectIndex
		lda #Piece.BouncerRight
		jsr UpdateObjectType
		ldx Level.ObjectIndex
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		sec
		sbc #1
		jsr CheckIfTileBounceable
		bcc Done
		jsr PushTileLeft
	Done:
		jmp NextObject
}

UpdateBouncerRight: {
		jsr CheckNearbyStickers
		bcs Done
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		jsr PushTileRight
		bcc Bounce
		jmp NextObject
	Bounce:
		ldx Level.ObjectIndex
		lda #Piece.BouncerLeft
		jsr UpdateObjectType
		ldx Level.ObjectIndex
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		clc
		adc #1
		jsr CheckIfTileBounceable
		bcc Done
		jsr PushTileRight
	Done:
		jmp NextObject
}

UpdateEmptyBlackhole: {
		iny
		cpy #Piece.Blackhole + 4
		bcc !+
		ldy #Piece.Blackhole
	!:	tya
		jsr UpdateObjectType
		jmp NextObject
}

UpdateFullBlackhole: {
		iny
		cpy #Piece.BlackholeFull + 4
		bcc !+
		ldy #Piece.Blackhole
	!:	tya
		jsr UpdateObjectType
		SetCurrentColorPtr(ScreenPtr)
		ldy Level.ObjectTypes,x
		lda CharColors,y
		ldy Level.ObjectXs,x
		sta (ColorPtr),y
		jmp NextObject
}

UpdateTimer: {
		iny
		cpy #Piece.Timer0 + 1
		bcc !+
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		jsr ClearTile
		jmp NextObject
	!:	tya
		jsr UpdateObjectType
		jmp NextObject
}

UpdateMonster: {
		tya
		eor #1
		jsr UpdateObjectType
		jsr CheckNearbyStickers
		bcs Stay
		jsr NextRandom
		bmi Wander

	Chase:
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		cpy Player.Y
		beq ChaseHorizontally

	ChaseVertically:
		bcc !+
		jsr PushTileUp
		ldx Level.ObjectIndex
		lda Level.ObjectXs,x
		bcc ChaseHorizontally
		jmp NextObject
	!:	jsr PushTileDown
		ldx Level.ObjectIndex
		lda Level.ObjectXs,x
		bcc ChaseHorizontally
		jmp NextObject

	ChaseHorizontally:	
		ldy Level.ObjectXs,x
		cpy Player.X
		ldy Level.ObjectYs,x
		bcc !+
		jsr PushTileLeft
		jmp NextObject
	!:	jsr PushTileRight
		jmp NextObject

	Wander:
		asl
		sta I
		and #$07
		beq Stay
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		bit I
		bmi WanderHorizontally

	WanderVertically:
		bvc !+
		jsr PushTileUp
		jmp NextObject
	!:	jsr PushTileDown
	Stay:
		jmp NextObject

	WanderHorizontally:
		bvc !+
		jsr PushTileLeft
		jmp NextObject
	!:	jsr PushTileRight
		jmp NextObject
}

UpdateStickerLR: {
		ldy Level.ObjectYs,x
		SetScreenPtrRowY()

	CheckLeft:
		ldy Level.ObjectXs,x
		dey
		lda (ScreenPtr),y
		bne CheckRight
		dey
		lda (ScreenPtr),y
		cmp #Piece.StickerLR
		beq CheckRight
		cmp #Piece.Kye
		bne PullFromLeft
	PullToPlayerLeft:
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		sta PX
		inc PX
		sty PY
		jsr MoveTileLeft
		ldy PY
		SetScreenPtrRowY()
		ldy PX
		lda (ScreenPtr),y
		cmp #Piece.StickerLR
		beq !+
		tay
		lda PieceFlags,y
		bpl !+
		lda PX
		ldy PY
		jsr MoveTileLeft
	!:	jmp NextObject		
	PullFromLeft:
		tay
		lda PieceFlags,y
		bpl CheckRight
		movw ScreenPtr : ScreenPtrBackup
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		sec
		sbc #2
		jsr MoveTileRight
		ldx Level.ObjectIndex
		movw ScreenPtrBackup : ScreenPtr

	CheckRight:
		ldy Level.ObjectXs,x
		iny
		lda (ScreenPtr),y
		bne Done
		iny
		lda (ScreenPtr),y
		cmp #Piece.StickerLR
		beq Done
		cmp #Piece.Kye
		bne PullFromRight
	PullToPlayerRight:
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		sta PX
		dec PX
		sty PY
		jsr MoveTileRight
		ldy PY
		SetScreenPtrRowY()
		ldy PX
		lda (ScreenPtr),y
		cmp #Piece.StickerLR
		beq !+
		tay
		lda PieceFlags,y
		bpl !+
		lda PX
		ldy PY
		jsr MoveTileRight
	!:	jmp NextObject		
	PullFromRight:
		tay
		lda PieceFlags,y
		bpl Done
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		clc
		adc #2
		jsr MoveTileLeft

	Done:
		jmp NextObject	
}

UpdateStickerTB: {
		lda #(Screen.Width * 2)
		sec
		sbc Level.ObjectXs,x
		sta I
		ldy Level.ObjectYs,x
		sec
		lda RowAddressesLow,y
		sbc I
		sta ScreenPtr
		lda RowAddressesHigh,y
		sbc #0
		sta ScreenPtr + 1

	CheckUp:
		ldy #Screen.Width
		lda (ScreenPtr),y
		bne CheckDown
		ldy #0
		lda (ScreenPtr),y
		cmp #Piece.StickerTB
		beq CheckDown
		cmp #Piece.Kye
		bne PullFromUp
	PullToPlayerUp:
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		sta PX
		sty PY
		inc PY
		jsr MoveTileUp
		ldy PY
		SetScreenPtrRowY()
		ldy PX
		lda (ScreenPtr),y
		cmp #Piece.StickerTB
		beq !+
		tay
		lda PieceFlags,y
		bpl !+
		lda PX
		ldy PY
		jsr MoveTileUp
	!:	jmp NextObject		
	PullFromUp:
		tay
		lda PieceFlags,y
		bpl CheckDown
		movw ScreenPtr : ScreenPtrBackup
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		dey
		dey
		jsr MoveTileDown
		ldx Level.ObjectIndex
		movw ScreenPtrBackup : ScreenPtr

	CheckDown:
		ldy #(Screen.Width * 3)
		lda (ScreenPtr),y
		bne Done
		ldy #(Screen.Width * 4)
		lda (ScreenPtr),y
		cmp #Piece.StickerTB
		beq Done
		cmp #Piece.Kye
		bne PullFromDown
	PullToPlayerDown:
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		sta PX
		sty PY
		dec PY
		jsr MoveTileDown
		ldy PY
		SetScreenPtrRowY()
		ldy PX
		lda (ScreenPtr),y
		cmp #Piece.StickerTB
		beq !+
		tay
		lda PieceFlags,y
		bpl !+
		lda PX
		ldy PY
		jsr MoveTileDown
	!:	jmp NextObject		
	PullFromDown:
		tay
		lda PieceFlags,y
		bpl Done
		lda Level.ObjectXs,x
		ldy Level.ObjectYs,x
		iny
		iny
		jsr MoveTileUp

	Done:
		jmp NextObject	
}

UpdateAutoSlider: {
		lda #Piece.Sliders
		jmp UpdateAutoCommon
}

UpdateAutoRocky: {
		lda #Piece.Rockies
		jmp UpdateAutoCommon
}

UpdateAutoCommon: {
		sta K
		lda PiecesRotatedAntiClockwise - Piece.Active,y
		jsr UpdateObjectType
		ldy Level.ObjectStates,x
		bmi !+
		iny
	!:	tya
		sta Level.ObjectStates,x
		cmp Level.ObjectYs,x
		beq !+
		bcs Armed
	!:	jmp NextObject

	Armed:
		ldy Level.ObjectYs,x
		dey
		clc
		lda RowAddressesLow,y
		adc Level.ObjectXs,x
		sta ScreenPtr
		lda RowAddressesHigh,y
		adc #0
		sta ScreenPtr + 1
		lda Level.ObjectTypes,x
		and #$03

	CheckRight:
		sta I
		bne CheckDown
		ldy #(Screen.Width + 1)
		lda (ScreenPtr),y
		bne Done
		ldy Level.ObjectYs,x
		lda Level.ObjectXs,x
		tax
		inx
		lda K
		jmp Shoot

	CheckDown:
		dec I
		bne CheckLeft
		ldy #(Screen.Width * 2)
		lda (ScreenPtr),y
		bne Done
		ldy Level.ObjectYs,x
		lda Level.ObjectXs,x
		tax
		iny
		lda K
		ora #$01
		jmp Shoot

	CheckLeft:
		dec I
		bne CheckUp
		ldy #(Screen.Width - 1)
		lda (ScreenPtr),y
		bne Done
		ldy Level.ObjectYs,x
		lda Level.ObjectXs,x
		tax
		dex
		lda K
		ora #$02
		jmp Shoot

	CheckUp:
		dec I
		bne CheckLeft
		ldy #0
		lda (ScreenPtr),y
		bne Done
		ldy Level.ObjectYs,x
		lda Level.ObjectXs,x
		tax
		dey
		lda K
		ora #$03

	Shoot:
		stx UX
		sty UY
		jsr AddNewObject
		lda #0
		ldx Level.ObjectIndex
		sta Level.ObjectStates,x
	
	Done:
		jmp NextObject
}

* = * "Frame Routines"

WaitForNextFrame: {
		lda FrameCounter
	Wait:
		cmp FrameCounter
		beq Wait
		rts
}

WaitFrames: {
	!:	jsr WaitForNextFrame
		dex
		bne !-
		rts	
}

WaitForBottom: {
		lda #210
	Wait:
		cmp TED.VerticalScanLo
		bcs Wait
		rts
}

ProcessInput: {
		lda #TED.InputLatch_None
		sta TED.KeyboardLatch
		lda #TED.InputLatch_Joy2
		sta TED.InputLatch
		lda TED.InputLatch
		eor #$ff // %F000RLDU
		sta Input.Buffer

	Horizontal: {
			lda #%00001100
			and Input.Buffer
			bne CheckChange

		Reset:
			// If there's no horizontal input, reset to idle state
			lda #Input.StateIdle
			sta Input.HorizontalState
			jmp Done

		CheckChange:
			// If we're idle or the direction changed since last time, immediately start the first trigger in the new direction
			ldx Input.HorizontalState
			cpx #Input.StateIdle
			beq StartFirstTrigger
			lsr
			lsr
			lsr
			ror
			eor Input.HorizontalState
			bmi StartFirstTrigger

		Continue:
			// Execute the state machine to emit repeated triggers in the current active direction
			lda Input.HorizontalState
			and #Input.StateMask
			cmp #Input.StateFirstTrigger
			bcc StartFirstTrigger
			cmp #Input.StateNextTrigger
			bcc FirstTrigger

		NextTrigger:
			cmp #(Input.StateNextTrigger + Frequency.MoveTickFrames)
			bcc AdvanceTrigger
		StartNextTrigger:
			lda Input.HorizontalState
			and #Input.DirectionMask
			ora #(Input.StateNextTrigger - 1)
			sta Input.HorizontalState
			sta Input.HorizontalTrigger
		AdvanceTrigger:
			inc Input.HorizontalState
			jmp Done

		FirstTrigger:
			cmp #(Input.StateFirstTrigger + Frequency.StartMoveTickFrames)
			bcc AdvanceTrigger
			bcs StartNextTrigger

		StartFirstTrigger:
			lda Input.Buffer
			lsr
			lsr
			lsr
			ror
			and #Input.DirectionMask
			ora #Input.StateFirstTrigger
			sta Input.HorizontalState
			sta Input.HorizontalTrigger

		Done:
	}

	Vertical: {
			lda #%00000011
			and Input.Buffer
			bne CheckChange

		Reset:
			// If there's no vertical input, reset to idle state
			lda #Input.StateIdle
			sta Input.VerticalState
			jmp Done

		CheckChange:
			// If we're idle or the direction changed since last time, immediately start the first trigger in the new direction
			ldx Input.VerticalState
			cpx #Input.StateIdle
			beq StartFirstTrigger
			lsr
			ror
			eor Input.VerticalState
			bmi StartFirstTrigger

		Continue:
			// Execute the state machine to emit repeated triggers in the current active direction
			lda Input.VerticalState
			and #Input.StateMask
			cmp #Input.StateFirstTrigger
			bcc StartFirstTrigger
			cmp #Input.StateNextTrigger
			bcc FirstTrigger

		NextTrigger:
			cmp #(Input.StateNextTrigger + Frequency.MoveTickFrames)
			bcc AdvanceTrigger
		StartNextTrigger:
			lda Input.VerticalState
			and #Input.DirectionMask
			ora #(Input.StateNextTrigger - 1)
			sta Input.VerticalState
			sta Input.VerticalTrigger
		AdvanceTrigger:
			inc Input.VerticalState
			jmp Done

		FirstTrigger:
			cmp #(Input.StateFirstTrigger + Frequency.StartMoveTickFrames)
			bcc AdvanceTrigger
			bcs StartNextTrigger

		StartFirstTrigger:
			lda Input.Buffer
			lsr
			ror
			and #Input.DirectionMask
			ora #Input.StateFirstTrigger
			sta Input.VerticalState
			sta Input.VerticalTrigger

		Done:
	}

		rts
}

ResetInput: {
		lda #Input.StateIdle
		sta Input.HorizontalState
		sta Input.VerticalState
		sta Input.HorizontalTrigger
		sta Input.VerticalTrigger
		rts
}

* = * "Status Bar"

FadeInStatusBar: {
		lda #$00
		sta FadeStatusBar.FadeDirection
		beq FadeStatusBar
}

FadeOutStatusBar: {
		lda #$80
		sta FadeStatusBar.FadeDirection
}

FadeStatusBar: {
		lda #0
		sta Counter
	Loop:
		lda Counter
		ldx FadeDirection: #0
		bpl Fade
		lda #MenuGradientSize - 1
		sec
		sbc Counter
	Fade:
		tax
		lda MenuGradient,x
		tax
		movw #(Screen.Colors + Screen.Width * (Level.ScreenY + Level.Height) + (Screen.Width - Text.StatusBarWidth) / 2) : ColorPtr
		lda #Text.StatusBarWidth
		jsr SetTextAreaColor
		jsr WaitForNextFrame
		inc Counter
		lda Counter
		cmp #MenuGradientSize
		bcc Loop		
		rts
}

UpdateStatusBarText: {
		movw #(Screen.Address + Screen.Width * (Level.ScreenY + Level.Height) + (Screen.Width - Text.StatusBarWidth) / 2) : ScreenPtr
		lda #Text.StatusBarWidth
		ldx #Text.StatusBarBaseCode
		jsr PrepareTextArea
		SetFixedTargetCharPtrByCode(Text.StatusBarBaseCode)
		lda #Text.StatusBarWidth
		jsr ClearTextArea
		jsr MeasureText
		SetFixedTargetCharPtrByCode(Text.StatusBarBaseCode)
		center_x #(Text.StatusBarWidth * 8) : Text.Width
		ldy #0
		jmp DisplayText
}

* = * "Load Level"

// Store the address of level pack A to LevelPackPtr
SetLevelPackPtr: {
		asl
		tay
		movw LevelPacks + 1,y : LevelPackPtr
		rts
}

// Update LevelPackPtr to point after the string it's currently pointing to
SkipLevelPackName: {
		ldy #0
	Loop:
		lda (LevelPackPtr),y
		iny
		cmp #Text.Terminator
		bne Loop
		sty I
		clc
		lda LevelPackPtr
		adc I
		sta LevelPackPtr
		lda LevelPackPtr + 1
		adc #0
		sta LevelPackPtr + 1
		rts
}

LoadLevel: {
		movw #Screen.Address : TargetPtr
		lda #0
		jsr FillScreenBuffer

		lda Menu.PackIndex
		jsr SetLevelPackPtr
		jsr SkipLevelPackName

		lda Menu.LevelIndex
		ldy #0
		cmp (LevelPackPtr),y
		bcc ValidIndex
		lda (LevelPackPtr),y
		sta Menu.LevelIndex
		dec Menu.LevelIndex
		jmp ShowLevelPicker

	ValidIndex:
		asl
		tay
		iny
		lda (LevelPackPtr),y
		sta LevelPtr
		iny
		lda (LevelPackPtr),y
		sta LevelPtr + 1		

		ldx #2
		jsr SkipLevelDataText
		sty I
		clc
		lda LevelPtr
		adc I
		sta SourcePtr
		lda LevelPtr + 1
		adc #0
		sta SourcePtr + 1
		lda #>Screen.Address
		sta CharScreenPtr + 1
		lda #(Level.ScreenOffset + Screen.Width + 1)
		sta CharScreenPtr
		ldy #0
		sty Counter
		lda #Level.InnerHeight
		sta PY
	FillRows:
		lda #Level.InnerWidth
		sta PX
	FillRow:
		lda Counter
		beq ReadNext
		dec Counter
		ldx Tile
		jmp Write
	ReadNext:
		lda (SourcePtr),y
		iny
		bne !+
		inc SourcePtr + 1
	!:	tax
		asl
		bcc Write
		bpl EmptyRun
		lda (SourcePtr),y
		sta Tile
		iny
		bne !+
		inc SourcePtr + 1
	!:	jmp SetCounter
	EmptyRun:
		lda #0
		sta Tile
	SetCounter:
		txa
		and #$3f
		clc
		adc #1
		sta Counter
		ldx Tile
	Write:
	.label CharScreenPtr = * + 1
		stx $ffff
		inc CharScreenPtr
		bne Next
		inc CharScreenPtr + 1
	Next:
		dec PX
		bne FillRow
		clc
		lda CharScreenPtr
		adc #(Screen.Width - Level.InnerWidth)
		sta CharScreenPtr
		lda CharScreenPtr + 1
		adc #0
		sta CharScreenPtr + 1
		dec PY
		bne FillRows

		lda #5
		sta Screen.Address + Level.ScreenOffset + Level.Width - 1
		sta Screen.Address + Level.ScreenOffset + Screen.Width + Level.Width - 1

		ldx #Level.InnerWidth
	FillTopBottom:
		ldy #6
		lda Screen.Address + Level.ScreenOffset + Screen.Width,x
		cmp #Piece.WallStart
		bcc EmitTopWall
		cmp #Piece.WallEnd
		bcs EmitTopWall
		ldy #4
		lda Screen.Address + Level.ScreenOffset + Screen.Width + 1,x
		cmp #Piece.WallStart
		bcc EmitTopWall
		cmp #Piece.WallEnd
		bcs EmitTopWall
		ldy #3
	EmitTopWall:
		tya
		sta Screen.Address + Level.ScreenOffset,x
		lda #6
		sta Screen.Address + Level.ScreenOffset + (Level.Height - 1) * Screen.Width,x
		dex
		bne FillTopBottom

		movw #(Screen.Address + Level.ScreenOffset) : ScreenPtr

		lda #(Level.Height - 1)
		sta Counter
	FillSides:
		ldx #5
		ldy #1
		lda (ScreenPtr),y
		cmp #Piece.WallStart
		bcc EmitLeftWall
		cmp #Piece.WallEnd
		bcs EmitLeftWall
		ldx #4
		ldy #(Screen.Width + 1)
		lda (ScreenPtr),y
		cmp #Piece.WallStart
		bcc EmitLeftWall
		cmp #Piece.WallEnd
		bcs EmitLeftWall
		ldx #3
	EmitLeftWall:
		txa
		ldy #0
		sta (ScreenPtr),y
		lda #5
		ldy #Level.Width - 1
		sta (ScreenPtr),y
		clc
		lda ScreenPtr
		adc #Screen.Width
		sta ScreenPtr
		bcc NextRow
		inc ScreenPtr + 1
	NextRow:
		dec Counter
		bne FillSides

		lda #6
		sta Screen.Address + Level.ScreenOffset + (Level.Height - 1) * Screen.Width
		lda #7
		sta Screen.Address + Level.ScreenOffset + (Level.Height - 1) * Screen.Width + Level.Width - 1

		movw #Screen.Colors : TargetPtr
		lda #0
		jsr FillScreenBuffer

		movb CharColors + Piece.Kye : KyeColor
		movb #Colors.Background : CharColors + Piece.Kye
		movw #(Screen.Address + Level.ScreenY * Screen.Width + Level.ScreenX) : SourcePtr
		movw #(Screen.Colors + Level.ScreenY * Screen.Width + Level.ScreenX) : TargetPtr
		movb #Level.Height : Counter
	SetColorRows:
		ldy #(Level.Width - 1)
	SetColors:
		lda (SourcePtr),y
		tax
		lda CharColors,x
		sta (TargetPtr),y
		dey
		bpl SetColors
		clc
		lda SourcePtr
		adc #Screen.Width
		sta SourcePtr
		sta TargetPtr
		bcc !+
		inc SourcePtr + 1
		inc TargetPtr + 1
	!:	dec Counter
		bne SetColorRows
		lda KyeColor: #0
		sta CharColors + Piece.Kye

		rts		
}

* = * "Text Routines"

// Point TargetCharPtr at the bitmap position (X,Y), i.e. Menu.Bitmap + Y * 320 + X * 8
SetTargetCharPtrByPosition: {
		txa
		asl
		asl
		sta PX
		lda #(>Menu.Bitmap >> 1)
		asl PX
		rol
		sta UX
		sty PY
		tya
		asl
		asl
		clc
		adc PY
		sta UY
		lda #0
		lsr UY
		ror
		lsr UY
		ror
		adc PX
		sta TargetCharPtr
		lda UX
		adc UY
		sta TargetCharPtr + 1
		rts
}

// Point ColorPtr at characer position (X,Y), i.e. Menu.Colors + Y * 40 + X
SetMenuColorPtr: {
		sty PY
		tya
		asl
		asl
		clc
		adc PY
		asl
		asl
		rol PY
		asl
		rol PY
		clc
		stx PX
		adc PX
		sta ColorPtr
		lda PY
		and #3
		adc #0
		adc #>Menu.Colors
		sta ColorPtr + 1
		rts
}

// Prepare an area of the screen for showing text starting from code X for a width of A chars at ScreenPtr.
PrepareTextArea: {
		sta LoopCount
		clc
		lda ScreenPtr
		adc #Screen.Width
		sta FarScreenPtr
		lda ScreenPtr + 1
		adc #0
		sta FarScreenPtr + 1
		ldy #0
	Fill:
		txa
		sta (ScreenPtr),y
		clc
		adc #Screen.Width
		sta (FarScreenPtr),y
		inx
		iny
	Next:
	.label LoopCount = * + 1
		cpy #0
		bne Fill
		rts	
}

// Clear an A*8 x 16 pixel bitmap area at TargetCharPtr.
ClearTextArea: {
		sta Counter
		clc
		lda TargetCharPtr
		adc #<320
		sta TargetCharBottomPtr
		lda TargetCharPtr + 1
		adc #>320
		sta TargetCharBottomPtr + 1
	Loop:
		ldy #0
		tya
		ldx Counter
		cpx #$20
		bcs Clear
		txa
		asl
		asl
		asl
		tay
		lda #0
	Clear:
		dey
		sta (TargetCharPtr),y
		sta (TargetCharBottomPtr),y
		bne Clear
		inc TargetCharPtr + 1
		inc TargetCharBottomPtr + 1
		sec
		lda Counter
		sbc #$20
		sta Counter
		bpl Loop
		rts
}

// Set the color of an A x 2 character area at ColorPtr to X for the ink and Y for the paper.
SetBitmapAreaColor: {
		sta Width1
		sta Width2
		stx Ink
		txa
		lsr
		lsr
		lsr
		lsr
		sta InkLuma
		sty Paper
		tya
		and #$f0
		ora InkLuma: #0
		sta Luma
		lda Ink: #0
		asl
		asl
		asl
		asl
		sta InkChroma
		lda Paper: #0
		and #$0f
		ora InkChroma: #0
		sta Chroma
		lda Width1: #0
		ldx Luma: #0
		jsr SetTextAreaColor
		lda ColorPtr + 1
		eor #>(Menu.Chroma ^ Menu.Luma)
		sta ColorPtr + 1
		lda Width2: #0
		ldx Chroma: #0
		jsr SetTextAreaColor
		rts
}

// Set the color of an A x 2 character area at ColorPtr to X.
SetTextAreaColor: {
		sta Count
		txa
		ldy #0
	TopLoop:
		sta (ColorPtr),y
		iny
		cpy Count: #0
		bcc TopLoop
		clc
		tya
		adc #(Screen.Width - 1)
		tay
		txa
	BottomLoop:
		sta (ColorPtr),y
		dey
		cpy #Screen.Width
		bcs BottomLoop
		rts
}


// Measure the width of the text at TextPtr in pixels and store it in Text.Width.
MeasureText: {	
		lda TextPtr
		sta TextSourcePtr
		lda TextPtr + 1
		sta TextSourcePtr + 1
		ldx #0
		stx Text.Width
		stx Text.Width + 1
	Loop:
	.label TextSourcePtr = * + 1
		ldy $ffff,x
		bmi Done
		inx
		clc
		lda Text.Width
		adc TextCharWidths,y
		sta Text.Width
		bcc Loop
		inc Text.Width + 1
		jmp Loop
	Done:
		rts
}

// Display the text at TextPtr with bitwise OR in the screen area pointed by TargetCharPtr with a pixel offset of X and character spacing of Y.
DisplayText: {
		sty CharacterSpacing
		txa
		and #$07
		sta Text.CurrentShift
		txa
		and #$f8
		sta OffsetX

		lda TextPtr
		sta TextSourcePtr1
		sta TextSourcePtr2
		lda TextPtr + 1
		sta TextSourcePtr1 + 1
		sta TextSourcePtr2 + 1

		clc
		lda TargetCharLeftPtr
	.label OffsetX = * + 1
		adc #0
		sta TargetCharLeftPtr
		lda TargetCharLeftPtr + 1
		adc #0
		sta TargetCharLeftPtr + 1
		//clc
		lda TargetCharLeftPtr
		adc #8
		sta TargetCharRightPtr
		lda TargetCharLeftPtr + 1
		adc #0
		sta TargetCharRightPtr + 1
		lda #0
		sta Counter
	Write:
		ldx Counter
	.label TextSourcePtr1 = * + 1
		lda $ffff,x
		bpl WriteChar
		rts
	WriteChar:
		sta Text.CharOffsetHigh
		lda #0
		lsr Text.CharOffsetHigh
		ror
		lsr Text.CharOffsetHigh
		ror
		lsr Text.CharOffsetHigh
		ror
		lsr Text.CharOffsetHigh
		ror
		adc #<TextCharSet
		sta SourceCharTopPtr
		lda Text.CharOffsetHigh
		adc #>TextCharSet		
		sta SourceCharTopPtr + 1
		//sec
		lda SourceCharTopPtr
		//sbc #$38
		sbc #$37 // Subtract $38
		sta SourceCharBottomPtr
		lda SourceCharTopPtr + 1
		sbc #0
		sta SourceCharBottomPtr + 1
		ldy #2
	CopyCharTop: {
			lda #0
			sta Text.RightByte
		.label @SourceCharTopPtr = * + 1
			lda $ffff,y
			ldx Text.CurrentShift
		ShiftByte:
			dex
			bmi ShiftDone
			lsr
			ror Text.RightByte
			jmp ShiftByte
		ShiftDone:
			ora (TargetCharLeftPtr),y
			sta (TargetCharLeftPtr),y
			lda Text.RightByte
			ora (TargetCharRightPtr),y
			sta (TargetCharRightPtr),y
		Next:
			iny
			cpy #8
			bne CopyCharTop
	}
		inc TargetCharLeftPtr + 1
		inc TargetCharRightPtr + 1
		ldy #$40
	CopyCharBottom: {
			lda #0
			sta Text.RightByte
		.label @SourceCharBottomPtr = * + 1
			lda $ffff,y
			ldx Text.CurrentShift
		ShiftByte:
			dex
			bmi ShiftDone
			lsr
			ror Text.RightByte
			jmp ShiftByte
		ShiftDone:
			ora (TargetCharLeftPtr),y
			sta (TargetCharLeftPtr),y
			lda Text.RightByte
			ora (TargetCharRightPtr),y
			sta (TargetCharRightPtr),y
		Next:
			iny
			cpy #$47
			bne CopyCharBottom
	}
		dec TargetCharLeftPtr + 1
		dec TargetCharRightPtr + 1
	Advance:
		ldx Counter
	.label TextSourcePtr2 = * + 1
		lda $ffff,x
		tax
		clc
		lda Text.CurrentShift
		adc TextCharWidths,x
		clc
	.label CharacterSpacing = * + 1
		adc #0
	CheckAdvance:
		sta Text.CurrentShift
		cmp #8
		bcc NextChar
		clc
		lda TargetCharRightPtr
		sta TargetCharLeftPtr
		adc #8
		sta TargetCharRightPtr
		lda TargetCharRightPtr + 1
		sta TargetCharLeftPtr + 1
		adc #0
		sta TargetCharRightPtr + 1
		lda Text.CurrentShift
		sbc #7 // Subtract 8, as carry is always 0 at this point
		jmp CheckAdvance
	NextChar:
		inc Counter
		jmp Write
}

DisplayBoldText: {
		lda TextPtr
		sta TextPtrLow
		lda TextPtr + 1
		sta TextPtrHigh
		lda TargetCharPtr
		sta CharPtrLow
		lda TargetCharPtr + 1
		sta CharPtrHigh
		stx XOffset
		sty CharSpacing
		jsr DisplayText
	.label TextPtrLow = * + 1
		lda #0
		sta TextPtr
	.label TextPtrHigh = * + 1
		lda #0
		sta TextPtr + 1
	.label CharPtrLow = * + 1
		lda #0
		sta TargetCharPtr
	.label CharPtrHigh = * + 1
		lda #0
		sta TargetCharPtr + 1
	.label XOffset = * + 1
		ldx #0
		inx
	.label CharSpacing = * + 1
		ldy #0
		jmp DisplayText
}

* = * "Menu"

FadeInContents: {
		lda #$07
		sta FadeContents.FadeDirection
		bne FadeContents
}

FadeOutContents: {
		lda #$00
		sta FadeContents.FadeDirection
}

FadeContents: {
		movb #0 : Counter
	Loop:
		movw #(Menu.Luma + Menu.TitleSize) : TargetPtr
		jsr WaitForBottom
		lda Counter
		eor FadeDirection: #0
		sta UpdateInstructionsLumas.Phase
		ora #$f0
		ldx #<Menu.ContentsSize
		ldy #>Menu.ContentsSize
		jsr FillBuffer

		bit Menu.Active
		bpl Next
		jsr UpdateInstructionsLumas

	Next:
		inc Counter
		lda Counter
		cmp #8
		bcc Loop		
		rts
}

UpdateInstructionsLumas: {
		movw #InstructionsLumas : Source
		movw #(Menu.Luma + Screen.Width * 13 + 4) : Target
		movb #6 : I
	DrawRows:
		ldx #2
	SetRowChromas:
		lda Source: $ffff,x
		ora Phase: #0
		tay
		lda MenuFadeLumas,y
		sta Target: $ffff,x
		dex
		bpl SetRowChromas
		clc
		lda Source
		adc #3
		sta Source
		lda Target
		adc #Screen.Width
		sta Target
		bcc !+
		inc Target + 1
	!:	dec I
		bne DrawRows
		rts
}

ClearScreenAndDrawTitle: {
		movw #Menu.Luma : TargetPtr
		lda #GetBitmapLuma(Colors.Text, Colors.Background)
		ldx #<Menu.TitleSize
		ldy #>Menu.TitleSize
		jsr FillBuffer

		movw #Menu.Chroma : TargetPtr
		lda #GetBitmapChroma(Colors.Text, Colors.Background)
		ldx #<Menu.TitleSize
		ldy #>Menu.TitleSize
		jsr FillBuffer

		movw #(Menu.Luma + Menu.TitleSize) : TargetPtr
		lda #GetBitmapLuma(Colors.Background, Colors.Background)
		ldx #<Menu.PaddedContentsSize
		ldy #>Menu.PaddedContentsSize
		jsr FillBuffer

		movw #(Menu.Chroma + Menu.TitleSize) : TargetPtr
		lda #GetBitmapChroma(Colors.Background, Colors.Background)
		ldx #<Menu.PaddedContentsSize
		ldy #>Menu.PaddedContentsSize
		jsr FillBuffer

		movw #Menu.Bitmap : TargetPtr
		lda #0
		ldx #<7680
		ldy #>7680
		jsr FillBuffer

		jsr DrawTitle
		jsr WaitForBottom
		rts
}

DrawTitle: {
		ldx #12
		ldy #0
		jsr SetTargetCharPtrByPosition
		lda #0
		sta Counter
		lda #5
		sta I
	DrawRows:
		lda #16
		sta J
		ldy #0
	DrawBlocks:
		ldx Counter
		lda TitleMap,x
		asl
		asl
		asl
		rol K
		clc
		adc #<TitleBlocks
		sta BlockBase
		lda K
		and #1
		adc #>TitleBlocks
		sta BlockBase + 1
		ldx #0
	DrawBlock:
	.label BlockBase = * + 1
		lda $ffff,x
		sta (TargetCharPtr),y
		iny
		inx
		cpx #8
		bcc DrawBlock
		inc Counter
		dec J
		bne DrawBlocks
		clc
		lda TargetCharPtr
		adc #<320
		sta TargetCharPtr
		lda TargetCharPtr + 1
		adc #>320
		sta TargetCharPtr + 1
		dec I
		bne DrawRows

	.label KyeLogoLuma = Menu.Luma + Screen.Width * 1 + 13
	.label KyeLogoChroma = Menu.Chroma + Screen.Width * 1 + 13
		lda #GetBitmapLuma(Colors.KyeOutline, Colors.Kye)
		sta KyeLogoLuma
		sta KyeLogoLuma + 1
		sta KyeLogoLuma + 2
		sta KyeLogoLuma + Screen.Width
		sta KyeLogoLuma + Screen.Width + 1
		sta KyeLogoLuma + Screen.Width + 2
		sta KyeLogoLuma + Screen.Width * 2
		sta KyeLogoLuma + Screen.Width * 2 + 1
		sta KyeLogoLuma + Screen.Width * 2 + 2
		lda #GetBitmapChroma(Colors.KyeOutline, Colors.Kye)
		sta KyeLogoChroma
		sta KyeLogoChroma + 1
		sta KyeLogoChroma + 2
		sta KyeLogoChroma + Screen.Width
		sta KyeLogoChroma + Screen.Width + 1
		sta KyeLogoChroma + Screen.Width + 2
		sta KyeLogoChroma + Screen.Width * 2
		sta KyeLogoChroma + Screen.Width * 2 + 1
		sta KyeLogoChroma + Screen.Width * 2 + 2
		rts
}

DrawInstructions: {
		movw #InstructionsBlocks : Source
		movw #(Menu.Bitmap + 320 * 13 + 8 * 4) : Target
		movw #InstructionsChromas : ChromaSource
		movw #(Menu.Chroma + Screen.Width * 13 + 4) : ChromaTarget
		ldy #6
	DrawRows:
		ldx #23
	DrawRow:
		lda Source: $ffff,x
		sta Target: $ffff,x
		dex
		bpl DrawRow
		clc
		lda Source
		adc #24
		sta Source
		bcc !+
		inc Source + 1
	!:	clc
		lda Target
		adc #<320
		sta Target
		lda Target + 1
		adc #>320
		sta Target + 1
		ldx #2
	SetRowChromas:
		lda ChromaSource: $ffff,x
		sta ChromaTarget: $ffff,x
		dex
		bpl SetRowChromas
		clc
		lda ChromaSource
		adc #3
		sta ChromaSource
		lda ChromaTarget
		adc #Screen.Width
		sta ChromaTarget
		bcc !+
		inc ChromaTarget + 1
	!:	dey
		bne DrawRows
		rts
}

ShowTitleScreen: {
		movb #$81 : Menu.Active

		jsr ClearScreenAndDrawTitle
		jsr DrawInstructions

		DisplayFixedText(InstructionsText1, 8, 14, 0, 0)
		DisplayFixedText(InstructionsText2, 8, 16, 0, 0)
		DisplayFixedText(InstructionsText3, 8, 18, 0, 0)
		DisplayFixedText(StartText, 0, 22, 103, 0)
		DisplayFixedText(TitleText2, 0, 10, 27, 0)
		DisplayFixedText(TitleText1, 0, 8, 23, 0)

		movw #ColinGarbuttText : TextPtr
		ldx #6
		ldy #1
		jsr DisplayBoldText

		movb #Screen.ModeBitmap : TED.Config1

		jsr FadeInContents
		jsr WaitForFireRelease
		jsr FadeOutContents

		lda #GetBitmapChroma(Colors.Text, Colors.Background)
		ldx #0
	ResetChroma:
		sta Menu.Chroma + Screen.Width * 13,x
		dex
		bne ResetChroma

		.if (SHOW_LEVEL_PICKER) {
				jmp ShowLevelPicker
		} else {
				jmp StartLevel
		}
}

PrintNames: {
		stx X
		sty Y
		movw Names : Names2
		movw Names : MaxCount
		lda #0
		sta Index
	Loop:
	.label Index = * + 1
		lda #0
	.label Count = * + 1
		cmp #0
		bcs Done
		clc
	.label Start = * + 1
		adc #0
	.label MaxCount = * + 1
		cmp $ffff
		bcs Done
		asl
		tay
		iny
	.label Names = * + 1
		lda $ffff,y
		sta TextPtr
		iny
	.label Names2 = * + 1
		lda $ffff,y
		sta TextPtr + 1
		lda Index
		asl
		clc
	.label Y = * + 1
		adc #0
		tay
	.label X = * + 1
		ldx #0
	.label TargetPtrLogic = * + 1
		jsr SetTargetCharPtrByPosition
		ldx #2
		ldy #0
		jsr DisplayText
		inc Index
		jmp Loop

	Done:
		rts
}

SetListItemActive: {
		movb #$71 : SetListItemColor.Ink
		movb #$1d : SetListItemColor.Paper
		bne SetListItemColor
}

SetListItemInactive: {
		movb #$71 : SetListItemColor.Ink
		movb #$41 : SetListItemColor.Paper
		bne SetListItemColor
}

ResetListItem: {
		movb #$01 : SetListItemColor.Ink
		movb #$71 : SetListItemColor.Paper
}

SetListItemColor: {
		lda Menu.CurrentPane
		bne UpdateLevelPane

	UpdateLevelPackPane:
		movb #Menu.PackTitleWidth : ItemWidth
		ldx #Menu.LevelPacksX
		lda Menu.PackIndex
		bpl Update

	UpdateLevelPane:
		movb #Menu.LevelTitleWidth : ItemWidth
		ldx #Menu.LevelsX
		lda Menu.LevelIndex
		jsr WrapListIndex

	Update:
		asl
		clc
		adc #Menu.LevelsY
		tay
		jsr SetMenuColorPtr
		lda ItemWidth: #0
		ldx Ink: #0
		ldy Paper: #0
		jmp SetBitmapAreaColor
}

// Compute A mod Menu.LevelsCount
WrapListIndex: {
	Loop:
		cmp #Menu.LevelsCount
		bcs Next
		rts
	Next:
		sbc #Menu.LevelsCount
		jmp Loop
}

// Get the index of the first level shown in the list
GetFirstVisibleIndex: {
		lda Menu.LevelIndex
		jsr WrapListIndex
		eor #$ff
		sec
		adc Menu.LevelIndex
		rts
}

SwitchPackLevelList: {
		movb #0 : Menu.LevelIndex
}

RefreshPackLevelList: {
		lda Menu.PackIndex
		jsr SetLevelPackPtr
		jsr SkipLevelPackName
		sec
}

// Trigger level list update downwards if the carry is set, or upwards if it is cleared
UpdateLevelList: {
		lda #0
		ldx #Menu.LevelsCount
		bcs !+
		txa
		ldx #0
	!:	sta Menu.RefreshingLevelIndex
		stx Menu.RefreshingLevelTargetIndex

	UpdateScrollArrows:
		ldy #GetBitmapLuma(Colors.Background, Colors.Background)
		jsr GetFirstVisibleIndex
		beq CheckLastPosition
		ldy #GetBitmapLuma(Colors.Text, Colors.Background)
	CheckLastPosition:
		sty Menu.Luma + (Menu.LevelsY) * Screen.Width + Menu.LevelsX + Menu.LevelTitleWidth
		clc
		adc #Menu.LevelsCount
		ldy #0
		ldx #GetBitmapLuma(Colors.Background, Colors.Background)
		cmp (LevelPackPtr),y
		bcs Done
		ldx #GetBitmapLuma(Colors.Text, Colors.Background)
	Done:
		stx Menu.Luma + (Menu.LevelsY + Menu.LevelsCount * 2 - 1) * Screen.Width + Menu.LevelsX + Menu.LevelTitleWidth

		rts
}

ShowLevelPicker: {
		jsr ResetInput
		ldx #$ff
		txs
		movb #$01 : Menu.Active

		.if (SHOW_TITLE_SCREEN) {
				lda Menu.CurrentPane
				beq ClearContents
				jsr ClearScreenAndDrawTitle
				jmp Setup

			ClearContents:
				movw #(Menu.Bitmap + 320 * Menu.ContentsY) : TargetPtr
				lda #0
				ldx #<(7680 - 320 * Menu.ContentsY)
				ldy #>(7680 - 320 * Menu.ContentsY)
				jsr FillBuffer
		} else {
				jsr ClearScreenAndDrawTitle
		}

	Setup:
		ldx #Menu.LevelsCount
	InitFadeStates:
		dex
		sta Menu.LevelFadeStates,x
		bne InitFadeStates

		ldx #Menu.LevelPacksX
		ldy #Menu.ContentsY
		jsr SetTargetCharPtrByPosition
		movw #LevelPacksText : TextPtr
		ldx #2
		ldy #2
		jsr DisplayBoldText

		ldx #Menu.LevelsX
		ldy #Menu.ContentsY
		jsr SetTargetCharPtrByPosition
		movw #LevelsText : TextPtr
		ldx #2
		ldy #2
		jsr DisplayBoldText

		movw #LevelPacks : PrintNames.Names
		movb #0 : PrintNames.Start
		movb #Menu.LevelsCount : PrintNames.Count
		ldx #Menu.LevelPacksX
		ldy #Menu.LevelsY
		jsr PrintNames

		movb #Screen.ModeBitmap : TED.Config1

		jsr FadeInContents
		jsr RefreshPackLevelList

	DrawScrollArrows: {
			ldy #5
			ldx #0
		Loop:
			lda ScrollArrowImage,y
			sta Menu.Bitmap + Menu.LevelsY * 320 + (Menu.LevelsX + Menu.LevelTitleWidth) * 8,y
			sta Menu.Bitmap + (Menu.LevelsY + Menu.LevelsCount * 2 - 1) * 320 + (Menu.LevelsX + Menu.LevelTitleWidth) * 8,x
			inx
			dey
			bpl Loop
	}

		lda Menu.CurrentPane
		beq !+
		dec Menu.CurrentPane
		jsr SetListItemInactive
		inc Menu.CurrentPane
	!:	jsr SetListItemActive

	MenuLoop:
		lda FrameCounter
		cmp #1
		bcs !+
		jmp CheckInput
	!:	movb #0 : FrameCounter

	UpdateFadeStates: {
			lda Menu.LevelIndex
			jsr WrapListIndex
			sta CurrentIndex
			ldy #0
		Loop:
			sty YBackup
			ldx Menu.LevelFadeStates,y
			cpx #MenuGradientSize - 1
			bcs Next
			inx
			stx Menu.LevelFadeStates,y
			lda Menu.CurrentPane
			beq Fade
		.label CurrentIndex = * + 1
			cpy #0
			beq Next
		Fade:
			lda MenuGradient,x
			sta Ink
			ldx #Menu.LevelsX
			tya
			asl
			adc #Menu.LevelsY
			tay
			jsr SetMenuColorPtr
			lda #Menu.LevelTitleWidth
			ldx Ink: #0
			ldy #Colors.Background
			jsr SetBitmapAreaColor
		Next:
			ldy YBackup: #0
			iny
			cpy #Menu.LevelsCount
			bcc Loop
	}

		lda Menu.RefreshingLevelIndex
		cmp Menu.RefreshingLevelTargetIndex
		beq CheckInput
		bcc UpdateRefreshingLevel
		dec Menu.RefreshingLevelIndex

	UpdateRefreshingLevel: {
			ldx Menu.RefreshingLevelIndex
			lda #0
			sta Menu.LevelFadeStates,x
			jsr GetFirstVisibleIndex
			clc
			adc Menu.RefreshingLevelIndex
			sta LevelIndex
			asl
			tay
			iny
			lda (LevelPackPtr),y
			sta TextPtr
			iny
			lda (LevelPackPtr),y
			sta TextPtr + 1
			ldx #Menu.LevelsX
			lda Menu.RefreshingLevelIndex
			asl
			adc #Menu.LevelsY
			tay
			jsr SetTargetCharPtrByPosition
			jsr SetMenuColorPtr
			movw TargetCharPtr : TargetCharRightPtr
			lda Menu.LevelIndex
			cmp LevelIndex
			beq !+
			lda #Menu.LevelTitleWidth
			ldx #Colors.Background
			ldy #Colors.Background
			jsr SetBitmapAreaColor
		!:	lda #Menu.LevelTitleWidth
			jsr ClearTextArea
			lda LevelIndex: #$ff
			ldy #0
			cmp (LevelPackPtr),y
			bcs Done
			movw TargetCharRightPtr : TargetCharPtr
			ldx #2
			jsr DisplayText
		Done:
			lda Menu.RefreshingLevelTargetIndex
			beq CheckInput
			inc Menu.RefreshingLevelIndex
	}

	CheckInput:

	CheckUp: {
			bit Input.VerticalTrigger
			bpl CheckDown
			bvc CheckDown
			lda Menu.CurrentPane
			bne CheckLevelUp

		CheckLevelPackUp:
			lda Menu.PackIndex
			beq Done
			jsr ResetListItem
			dec Menu.PackIndex
			jsr SetListItemActive
			jsr SwitchPackLevelList
			jmp Done

		CheckLevelUp:
			lda Menu.LevelIndex
			beq Done
			jsr ResetListItem
			lda Menu.LevelIndex
			dec Menu.LevelIndex
			jsr WrapListIndex
			cmp #0
			bne HighlightLevel
			clc
			jsr UpdateLevelList

		HighlightLevel:
			jsr SetListItemActive

		Done:
			lda #0
			sta Input.VerticalTrigger
			jmp MenuLoop
	}

	CheckDown: {
			bmi CheckLeft
			bvc CheckLeft
			lda Menu.CurrentPane
			bne CheckLevelDown

		CheckLevelPackDown:
			lda LevelPacks
			clc
			sbc Menu.PackIndex
			beq Done
			jsr ResetListItem
			inc Menu.PackIndex
			jsr SetListItemActive
			jsr SwitchPackLevelList
			jmp Done

		CheckLevelDown:
			ldy #0
			lda (LevelPackPtr),y
			clc
			sbc Menu.LevelIndex
			beq Done
			jsr ResetListItem
			inc Menu.LevelIndex
			lda Menu.LevelIndex
			jsr WrapListIndex
			cmp #0
			bne HighlightLevel
			sec
			jsr UpdateLevelList

		HighlightLevel:
			jsr SetListItemActive

		Done:
			lda #0
			sta Input.VerticalTrigger
			jmp MenuLoop
	}

	CheckLeft: {
			bit Input.HorizontalTrigger
			bpl CheckRight
			bvc CheckRight
			lda Menu.CurrentPane
			beq Done
			jsr SetListItemInactive
			dec Menu.CurrentPane
			jsr SetListItemActive

		Done:
			lda #0
			sta Input.HorizontalTrigger
			jmp MenuLoop
	}

	CheckRight: {
			bmi CheckFire
			bvc CheckFire
			lda Menu.CurrentPane
			bne Done
			jsr SetListItemInactive
			inc Menu.CurrentPane
			jsr SetListItemActive

		Done:
			lda #0
			sta Input.HorizontalTrigger
			jmp MenuLoop
	}

	CheckFire: {
			lda Input.Buffer
			bpl Done
			lda Menu.CurrentPane
			beq Done
			jsr WaitForFireRelease
			jmp StartLevel

		Done:
			jmp MenuLoop
	}
}

NextRandom: {
		inc RandomIndex1
		bne !+
		inc RandomIndex2
	!:	ldy RandomIndex1
		lda Random,y
		ldy RandomIndex2
		eor Random + $100,y
		rts
}

* = * "Pause Menu Data"

CountText:
	MakeString("999")

StatusBarText:
	MakeString("Diamonds:                Lives: 3")

VictoryText:
	MakeString("Well done!")

LostText:
	MakeString("Have another go!")

PauseMenuText:
	MakeString("Resume       Restart       Quit")

PauseMenuXs:
	.byte 10, 18, 26

* = * "Main Menu Data"

LevelPacksText:
	MakeString("Level Packs")

LevelsText:
	MakeString("Levels")

ScrollArrowImage:
	.byte %00001000
	.byte %00011100
	.byte %00111110
	.byte %00111110
	.byte %01110111
	.byte %01100011

* = * "Title Screen"

TitleBlocks:
	.import binary "graphics/kye-title - Chars.bin"

TitleMap:
	.import binary "graphics/kye-title - (8bpc, 16x5) Map.bin"

TitleText1:
	MakeString("An original concept (c) 1992 by")

ColinGarbuttText:
	MakeString("Colin Garbutt")

TitleText2:
	MakeString("Adapted to @ Plus/4 by Patai Gergely in 2025")

InstructionsBlocks:
	.import binary "graphics/kye-instructions - Chars.bin"

InstructionsText1:
	MakeString("You are Kye, the green circle thing.")

InstructionsText2:
	MakeString("Collect all the diamonds!")

InstructionsText3:
	MakeString("Don't get stuck or eaten by monsters!")

StartText:
	MakeString("Press fire to start!")

MenuFadeLumas:
	.for (var i = 0; i < 8; i++) {
		.for (var j = 0; j < 8; j++) {
			.byte (i + ((7 - i) * j) / 7) | (Colors.Background & $f0)
		}
	}

* = * "Small Display Tables"

.var instructionsLumas = LoadBinary("graphics/kye-instructions - CharAttribs_L1.bin")
InstructionsLumas:
	.fill instructionsLumas.getSize(), (instructionsLumas.uget(i) & $07) << 3

InstructionsChromas:
	.import binary "graphics/kye-instructions - CharAttribs_L2.bin"

PlayerSpawnColors:
	.byte $71, $7f, $7f, $6f, $6f, $5f, $5f
.label PlayerSpawnPhase = <(PlayerSpawnColors - *)

PlayerDeathColors:
	.byte $4f, $3f, $2f, $1a, $07, $09, $08, $12, $22, $32, $42, $52, $62, $72, $71
.label PlayerDeathLength = * - PlayerDeathColors

MenuGradient:
	.byte $71, $7f, $6f, $5a, $4a, $37, $27, $19, $09, $01
.label MenuGradientSize = * - MenuGradient

BlinkGradient:
	.byte $00, $0f, $1f, $2f, $3f, $4f, $5f, $6f, $7f, $5f, $3f, $2f, $1f, $0f, $00
.label BlinkGradientSize = * - BlinkGradient

DiamondFrames:
	.fill DiamondFrameCount << 3, charSet.get(i + (InGameCharacters << 3))

RowAddressesLow:
	.for (var i = 0; i <= Level.Height; i++) {
		.byte <(Screen.Address + Level.ScreenOffset + i * Screen.Width)
	}

RowAddressesHigh:
	.for (var i = 0; i <= Level.Height; i++) {
		.byte >(Screen.Address + Level.ScreenOffset + i * Screen.Width)
	}

ObjectIndexRowAddressesHigh:
	.for (var i = 0; i <= Level.Height; i++) {
		.byte >(Level.ObjectIndices + Level.ScreenOffset + i * Screen.Width)
	}

StickerFieldRowAddressesHigh:
	.for (var i = 0; i <= Level.Height; i++) {
		.byte >(Level.StickerField + Level.ScreenOffset + i * Screen.Width)
	}

TextCharWidths:
	.fill textCharWidths.size(), textCharWidths.get(i)

* = * "Free"

.align $800

* = * "Character Set"

CharSet:
	.fill InGameCharacters << 3, charSet.get(i)

.align $800

* = * "Aligned Tables"

Random:
	.var random = List()
	.for (var i = 0; i < 256; i++) {
		.eval random.add(i)
	}
	.eval random.shuffle()
	.fill $100, random.get(i)
	.eval random.shuffle()
	.fill $100, random.get(i)

CharColors:
	.fill $80, i < charColors.getSize() ? charColors.get(i) : $00

// Each piece has the following flag bits:
// - bit 0: the piece has a round top left corner
// - bit 1: the piece has a round top right corner
// - bit 2: the piece has a round bottom left corner
// - bit 3: the piece has a round bottom right corner
// - bit 5: touching this piece kills the player
// - bit 6: a bouncer can push this piece
// - bit 7: this piece is generally movable (the player can push it and stickers can pull it)
PieceFlags:
	.for (var i = 0; i < $80; i++) {
		.var flags = 0
		.if (i == Piece.BlockRound || (i >= Piece.Rockies && i < Piece.Rockies + 4)) {
			.eval flags = flags | $0f
		}
		.if (i >= 3 && i <= 24) {
			.var ch = i << 3
			.if ((charSet.get(ch) & $80) == 0) {
				.eval flags = flags | 1
			}
			.if ((charSet.get(ch) & $02) == 0) {
				.eval flags = flags | 2
			}
			.if ((charSet.get(ch + 6) & $80) == 0) {
				.eval flags = flags | 4
			}
			.if ((charSet.get(ch + 6) & $02) == 0) {
				.eval flags = flags | 8
			}
		}
		.if (i >= Piece.Monsters && i < Piece.Monsters + 10) {
			.eval flags = flags | $20
		}
		.if (pushablePieces.containsKey(i)) {
			.eval flags = flags | $40
			.if (i < Piece.BlackholeFull || i >= Piece.BlackholeFull + 4) {
				.eval flags = flags | $80
			}
		}
		.byte flags
	}

TextCharSet:
	.fill textCharSet.getSize(), textCharSet.get(i)

* = * "Small Gameplay Tables"

PiecesRotatedClockwise:
	.for (var i = Piece.Active; i < Piece.Blackhole; i++) {
		.byte (i & $fc) | ((i + 1) & $03)
	}

PiecesRotatedAntiClockwise:
	.for (var i = Piece.Active; i < Piece.Blackhole; i++) {
		.byte (i & $fc) | ((i - 1) & $03)
	}

ActivePieceTimings:
	.for (var i = Piece.Active; i < Piece.Unused; i++) {
		.byte pieceTimings.get(i)
	}

.define updateAddresses {
	.var updateAddresses = Hashtable()

	.eval updateAddresses.put(Piece.Timer0, UpdateTimer)
	.eval updateAddresses.put(Piece.Timer1, UpdateTimer)
	.eval updateAddresses.put(Piece.Timer2, UpdateTimer)
	.eval updateAddresses.put(Piece.Timer3, UpdateTimer)
	.eval updateAddresses.put(Piece.Timer4, UpdateTimer)
	.eval updateAddresses.put(Piece.Timer5, UpdateTimer)
	.eval updateAddresses.put(Piece.Timer6, UpdateTimer)
	.eval updateAddresses.put(Piece.Timer7, UpdateTimer)
	.eval updateAddresses.put(Piece.Timer8, UpdateTimer)
	.eval updateAddresses.put(Piece.Timer9, UpdateTimer)

	.eval updateAddresses.put(Piece.Twister, UpdateMonster)
	.eval updateAddresses.put(Piece.Twister + 1, UpdateMonster)
	.eval updateAddresses.put(Piece.Gnasher, UpdateMonster)
	.eval updateAddresses.put(Piece.Gnasher + 1, UpdateMonster)
	.eval updateAddresses.put(Piece.Blob, UpdateMonster)
	.eval updateAddresses.put(Piece.Blob + 1, UpdateMonster)
	.eval updateAddresses.put(Piece.Virus, UpdateMonster)
	.eval updateAddresses.put(Piece.Virus + 1, UpdateMonster)
	.eval updateAddresses.put(Piece.Spike, UpdateMonster)
	.eval updateAddresses.put(Piece.Spike + 1, UpdateMonster)

	.eval updateAddresses.put(Piece.Blackhole, UpdateEmptyBlackhole)
	.eval updateAddresses.put(Piece.Blackhole + 1, UpdateEmptyBlackhole)
	.eval updateAddresses.put(Piece.Blackhole + 2, UpdateEmptyBlackhole)
	.eval updateAddresses.put(Piece.Blackhole + 3, UpdateEmptyBlackhole)
	.eval updateAddresses.put(Piece.BlackholeFull, UpdateFullBlackhole)
	.eval updateAddresses.put(Piece.BlackholeFull + 1, UpdateFullBlackhole)
	.eval updateAddresses.put(Piece.BlackholeFull + 2, UpdateFullBlackhole)
	.eval updateAddresses.put(Piece.BlackholeFull + 3, UpdateFullBlackhole)

	.eval updateAddresses.put(Piece.SliderUp, UpdateSliderUp)
	.eval updateAddresses.put(Piece.SliderLeft, UpdateSliderLeft)
	.eval updateAddresses.put(Piece.SliderDown, UpdateSliderDown)
	.eval updateAddresses.put(Piece.SliderRight, UpdateSliderRight)

	.eval updateAddresses.put(Piece.RockyUp, UpdateRockyUp)
	.eval updateAddresses.put(Piece.RockyLeft, UpdateRockyLeft)
	.eval updateAddresses.put(Piece.RockyDown, UpdateRockyDown)
	.eval updateAddresses.put(Piece.RockyRight, UpdateRockyRight)

	.eval updateAddresses.put(Piece.BouncerUp, UpdateBouncerUp)
	.eval updateAddresses.put(Piece.BouncerDown, UpdateBouncerDown)
	.eval updateAddresses.put(Piece.BouncerLeft, UpdateBouncerLeft)
	.eval updateAddresses.put(Piece.BouncerRight, UpdateBouncerRight)

	.eval updateAddresses.put(Piece.StickerLR, UpdateStickerLR)
	.eval updateAddresses.put(Piece.StickerTB, UpdateStickerTB)

	.eval updateAddresses.put(Piece.AutoSlider, UpdateAutoSlider)
	.eval updateAddresses.put(Piece.AutoSlider + 1, UpdateAutoSlider)
	.eval updateAddresses.put(Piece.AutoSlider + 2, UpdateAutoSlider)
	.eval updateAddresses.put(Piece.AutoSlider + 3, UpdateAutoSlider)

	.eval updateAddresses.put(Piece.AutoRocky, UpdateAutoRocky)
	.eval updateAddresses.put(Piece.AutoRocky + 1, UpdateAutoRocky)
	.eval updateAddresses.put(Piece.AutoRocky + 2, UpdateAutoRocky)
	.eval updateAddresses.put(Piece.AutoRocky + 3, UpdateAutoRocky)
}

UpdateAddressesLow:
	.for (var i = Piece.Active; i < Piece.Unused; i++) {
		.byte updateAddresses.containsKey(i) ? <updateAddresses.get(i) : <NextObject
	}

UpdateAddressesHigh:
	.for (var i = Piece.Active; i < Piece.Unused; i++) {
		.byte updateAddresses.containsKey(i) ? >updateAddresses.get(i) : >NextObject
	}

* = * "Level Data"

IncludeLevelPack("Default", "levels/default.kye")
IncludeLevelPack("Sampler", "levels/sampler.kye")
IncludeLevelPack("Plus 2", "levels/plus2.kye")
IncludeLevelPack("New Kye", "levels/newkye.kye")
IncludeLevelPack("Shapes & Monsters", "levels/shapes-monsters.kye")
IncludeLevelPack("Danish", "levels/danish.kye")

LevelPacks: IncludeLevelPackPointers()