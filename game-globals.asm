RandomIndex1:	.byte 0
RandomIndex2:	.byte 0
I:	.byte 0
J:	.byte 0
K:	.byte 0
L:	.byte 0
UX:	.byte 0
UY:	.byte 0
RX:	.byte 0
RY:	.byte 0
PX:	.byte 0
PY:	.byte 0
Tile:	.byte 0
RollDirs:	.byte 0
Counter:	.byte 0
FrameCounter:	.byte 0

LevelPackPtr:	.word 0
LevelPtr:	.word 0
ScreenPtr:	.word 0
ScreenPtrBackup:	.word 0
ColorPtr:	.word 0
SourcePtr:	.word 0
TargetPtr:	.word 0
FarScreenPtr:	.word 0
IndexPtr:	.word 0
StickerFieldPtr:	.word 0
TextPtr:	.word 0
TargetCharLeftPtr:
TargetCharPtr:	.word 0
TargetCharBottomPtr:	.word 0
TargetCharRightPtr:	.word 0

.namespace Text {
	CurrentShift:	.byte 0
	LeftByte:	.byte 0
	RightByte:	.byte 0
	CharOffsetHigh:	.byte 0
	Width:	.word 0

	.label StatusBarWidth = 20

	.label TitleBarBaseCode = Piece.Unused
	.label StatusBarBaseCode = TitleBarBaseCode + 80
	.label DiamondsBaseCode = StatusBarBaseCode + 8
	.label LivesBaseCode = StatusBarBaseCode + 18

	.label DiamondBase = CharSet + (Piece.Diamond << 3)

	.label BitShiftTables = $b000
}

.namespace Screen {
	.label Address = $0c00
	.label Colors = $0800
	.label Width = 40
	.label Height = 25

	.label ModeOff = $00
	.label ModeText = TED.Config1_Tall | TED.Config1_EnableDisplay
	.label ModeBitmap = TED.Config1_Tall | TED.Config1_EnableDisplay | TED.Config1_BitmapMode | 3
}

.namespace Level {
	.label ScreenX = 5
	.label ScreenY = 3
	.label Width = 30
	.label Height = 20
	.label InnerWidth = Width - 2
	.label InnerHeight = Height - 2
	.label ScreenOffset = ScreenY * Screen.Width + ScreenX
	.label StickerOrigin = Screen.Width * 2 + 2
	.label FreeObjectIndex = $ff

	ObjectCount:	.byte 0
	ObjectIndex:	.byte 0
	DefragNeeded:	.byte 0
	Diamonds:	.word 0
	RockySide:	.byte 0
	TileUnderPlayer:	.byte 0
	RevealedTile:	.byte 0

	DiamondAnimationFrame:	.byte 0
	DiamondAnimationCounter:	.byte 0

	.label State = $e000

	.label ObjectIndices = State
	.label StickerField = State + $400

	.label ObjectCounters = State + $800
	.label ObjectTypes = State + $900
	.label ObjectXs = State + $a00
	.label ObjectYs = State + $b00
	.label ObjectStates = State + $c00
}

.namespace Input {
	.label StateMask = $7f
	.label CounterMask = $1f
	.label DirectionMask = $80
	.label TriggerMask = $40
	.label RepeatMask = $20

	.label StateIdle = $00
	.label StateFirstTrigger = TriggerMask
	.label StateNextTrigger = TriggerMask | RepeatMask

	Buffer:	.byte 0
	// State bits: %btfccccc, where b = direction, t = trigger, f = first/next, c = frame counter
	HorizontalState:	.byte 0
	VerticalState:	.byte 0
	// Copies of the state made on trigger frames (c = 0), acknowledged by update logic so no input is missed
	HorizontalTrigger:	.byte 0
	VerticalTrigger:	.byte 0
}

.namespace Player {
	X:	.byte 0
	Y:	.byte 0
	StartX:	.byte 0
	StartY:	.byte 0
	Lives:	.byte 0
	TargetTile:	.byte 0
	DeathPhase:	.byte 0

	.label ForceUpdate = $ff
}

.namespace PauseMenu {
	.label SpriteY = 232
	.label ItemsCount = 3

	Active:	.byte 0
	Index:	.byte 0
	BlinkPhase:	.byte 0
}

.namespace Menu {
	.label Sprites = $da80
	.label Colors = $0800
	.label Luma = $0800
	.label Chroma = $0c00
	.label Bitmap = $e000
	.label ContentsY = 7
	.label LevelPacksX = 4
	.label LevelsX = 24
	.label LevelsY = ContentsY + 2
	.label LevelsCount = 7
	.label PackTitleWidth = 18
	.label LevelTitleWidth = 14

	.label TitleSize = Screen.Width * Menu.ContentsY
	.label ContentsSize = Screen.Width * (Screen.Height - Menu.ContentsY - 2)
	.label PaddedContentsSize = Screen.Width * (Screen.Height - Menu.ContentsY)

	Active:	.byte 0
	PackIndex:	.byte 0
	LevelIndex:	.byte 0
	CurrentPane:	.byte 0
	ScrollIndicators:	.byte 0

	RefreshingLevelIndex:	.byte 0
	RefreshingLevelTargetIndex:	.byte 0
	LevelFadeStates:	.fill LevelsCount, 0
}
