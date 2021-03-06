; Part 6: text scroller
	.include "gvars.asm"

SDMCTL = $22f
SDLSTL = $230
GPRIOR = $26f
COLOR  = $2c0

SCROLL_SPEED = 3.55 ; please don't exceed 16
TEXT_Y = 65 ; starting y position of text
	
*	= partEntry
start
	mwa #dlist, SDLSTL
	mva #$0f, COLOR
	sta COLOR+1
	sta COLOR+2
	sta COLOR+3
	mva #0, COLOR+4
	sta COLOR+5
	sta COLOR+6
	mva #12, rHSCROL
	mva >#(player0-$200), rPMBASE
	mva #$01, rPRIOR ; all players above pf
	mva #$02, rGRACTL ; turn on player
	
	; in this case, the grid has max scrolling range of 96 and xpos of 63
	mva >#QSTable, zARG0
	mva #160, zARG1
	jsr initQSTable
	
	; the current function for character x position table is
	; (x/128)³*32+x/2+124 for x = [-128,-127,..,128]
	; since (x/128)³*32 always increase by only 0 and 1 for this range of x
	; and x/2 increases constantly as repeating {0,1} sequence
	; we can compress the change of this function in bit table format
	; (-1 or 2 results can be smoothed out to the adjacent change)
	lda #28 ; f(-128)
	ldx #1 ; force getting the first byte for the first time
	ldy #0
-	dex
	bne +
	ldx chrxLUT_packed
_bs = *-2
	stx zTMP0
	inc _bs
	.if pagecross(chrxLUT_packed)
	bne _sk
	inc _bs+1
_sk	
	.fi
	ldx #4
+	asl zTMP0
	adc #0
	sta chrxLUT,y
	iny
	asl zTMP0
	adc #1
	sta chrxLUT,y
	iny
	bne -
	
	; unpack bounceLUT
	lda #111 ; f(0)
	ldx #0
-	sub bounceLUT,x ; apply delta
	sta bounceLUT,x
	inx
	cpx #67
	bne -
	ldy #65 ; loop back
-	lda bounceLUT,y
	sta bounceLUT,x
	inx
	dey
	cpy #10
	bne -
	
	; build dlist
	mva #$70, dlist ; 8 blank lines
	mva #0, dlist_grid ; 1 blank line
	tax
	mva #$41, dlist_grid+1+55*3 ; jvb
	mwa #dlist, dlist_grid+1+55*3+1
	lda #$cd ; lms + dli
-	sta dlist_grid+1,x
	inx
	inx
	inx
	cpx #55*3
	bne -
	
	; generate scrolled copies of grid
	ldy #0
_copyloop
	lda gridaddrs,y
	add >#(size(grid0))
	sta _src+1
	lda gridaddrs+1,y
	add >#(size(grid0))
	sta _dst+1
	sta _dst2+1
	sty zTMP0
	ldx <#size(grid0)
	ldy >#size(grid0)
	clc
-	txa
	bne +
	dec _src+1
	dec _dst+1
	dey
	bmi ++
+	dex
	lda grid0,x
_src = *-2
	rol a
	sta grid1,x
_dst = *-2
	jmp -
	; shift left by another 1 bit
+	ldx <#size(grid0)
	ldy >#size(grid0)
	clc
-	txa
	bne +
	dec _dst2+1
	dey
	bmi ++
+	dex
	rol grid1,x
_dst2 = *-2
	jmp -
+	ldy zTMP0
	iny
	cpy #3
	bne _copyloop
	
	; clear player data
	lda #0
	ldx #127
-	sta player0,x
	sta player1,x
	sta player2,x
	sta player3,x
	dex
	bpl -
	
	; patch the extended memory amout to the scroller text
	lda z64ksOfGay
	beq intro ; = 0k
	ldx #4
	cmp #2
	bcc + ; <= 64k
	ldx #9
	cmp #5
	bcc + ; <= 256k
	ldx #14
	cmp #9
	bcc + ; <= 512k
	ldx #19 ; > 512k
+	ldy #4
-	mva exmemtexts,x, text+37,y
	dex
	dey
	bpl -
	
intro
	lda #5
_st	= *-1
	cmp #65
	beq _done
-	cmp rVCOUNT
	bne -
	sta rWSYNC
	sta rWSYNC
	mva #$0f, rCOLBK ; white
	lda #123
_en	= *-1
-	cmp rVCOUNT
	bne -
	sta rWSYNC
	sta rWSYNC
	mva #$00, rCOLBK ; black
	inc _st
	inc _st
	dec _en
	dec _en
	gne intro
_done
	
	mwa #wordloopadj(size(text)), chrc
	jsr disnmi
	mwa #vbi, rNMI
	mva #$2a, SDMCTL ; enable player and dlist dma, normal pf, double line player
	mva #$40, rNMIEN
	
loop
	inc framecnt
; battleOf logo
	lda #63 ; wait until it's not upper part
-	cmp rVCOUNT
	bne -
	sta rWSYNC
	sta rWSYNC
	mva #$0f, rCOLBK ; draw a white line
	lda #$00
gridcol1 = *-1
	sta rCOLPF0
	sta rWSYNC
	sta rWSYNC
	mva #$00, rCOLBK
	mwa #dli1, VDSLST ; load text scroller dli
	jsr scene0 ; update scene-specific variables
scefunc = *-2
	
	lda #$10
logoh = *-1
	add #0
colcy = *-1
	bne +
	lda #$10
+	sta logoh
	sta logocol+3
	adc #2
	sta logocol+2
	adc #4
	sta logocol+1
	adc #8
	sta logocol
	
	; init layers
	dec bcnt
	bne _skipall
	lda #10
bspdD = *-1
	sta bcnt
	
	ldx #4
-	lda logoi-1,x
	cmp #122
	bcc + ; not delay
	inc logoi-1,x
	lda #-1
	sta logobeg-1,x
	gmi _skip
+	
	add #1
bspdM = *-1
	cmp #122
	bcc +
	lda #10
+	sta logoi-1,x
+	tay
	lda bounceLUT,y
	sta logopos-1,x
	sta logobeg-1,x
	add #32
	cmp #112
	bcc +
	lda #112
+	sta logoend-1,x
_skip
	dex
	bne -
	; flatten layers
	ldx #2 ; upper
	ldy #3 ; lower
-	lda logobeg,x
	bmi _skip3 ; hidden
-	lda logobeg,y
	bmi _skip2 ; hidden
	cmp logobeg,x
	bcc +
	cmp logoend,x
	bcs +
	lda logoend,x
	sta logobeg,y
+	lda logoend,y
	cmp logoend,x
	bcs _skip2
	cmp logobeg,x
	bcc _skip2
	lda logobeg,x
	sta logoend,y
_skip2
	iny
	cpy #4
	bne -
_skip3
	dex
	txa
	tay
	iny
	cpx #-1
	bne --
	; check for completely covered layer (end <= begin)
	ldx #4
-	lda logobeg-1,x
	bmi + ; already hidden
	cmp logoend-1,x
	bcc +
	lda #-1
	sta logobeg-1,x
+	dex
	bne -
	; sort layers
	; any completely covered layers will have begin pos of -1 (=255)
	; and get moved to the very right
	ldx #0
	ldy #1
-	lda logobeg,y
	cmp logobeg,x
	bcs + ; no swapping
	sta zTMP3 ; zTMP0-2 are currently used by an interrupt
	lda logopos,y
	sta zTMP4
	lda logoend,y
	sta zTMP5
	lda logocol,y
	sta zTMP6
	lda logobeg,x
	sta logobeg,y
	lda logopos,x
	sta logopos,y
	lda logoend,x
	sta logoend,y
	lda logocol,x
	sta logocol,y
	lda zTMP3
	sta logobeg,x
	lda zTMP4
	sta logopos,x
	lda zTMP5
	sta logoend,x
	lda zTMP6
	sta logocol,x
+	iny
	cpy #4
	bne -
	inx
	txa
	tay
	iny
	cpx #3
	bne -
	; generate dlist
	mva #0, zTMP3
	tax
	tay
-	lda logobeg,x
	bmi _done ; covered layer found
	sub zTMP3
	beq +
	stx zTMP3 ; back up x
	jsr battleOf_blank
	ldx zTMP3
+	lda #$4c ; lms
	sta dlist_battleOf,y
	iny
	mva #0, zTMP4
	lda logobeg,x
	sbc logopos,x
	beq +
	; since the logo height is 32 lines, it's safe to omit
	; the upper 2 bits for initial x5 multiplication
	sta zTMP3
	asl a ; x2
	asl a ; x4
	adc zTMP3 ; x5
	asl a ; x10
	rol zTMP4
	asl a ; x20
	rol zTMP4
+	add <#battleOf
	sta dlist_battleOf,y
	iny
	lda zTMP4
	adc >#battleOf
	sta dlist_battleOf,y
	iny
	lda logoend,x
	sta zTMP3
	sub logobeg,x
	sbc #1 ; lms already drawn one line
	bne +
	; special case: only one line is drawn
	lda #$cc ; lms + dli
	sta dlist_battleOf-3,y
	bne ++
+	sta zTMP4
	lda #$0c
-	sta dlist_battleOf,y
	iny
	dec zTMP4
	bne -
	lda #$8c ; put dli on the last line
	sta dlist_battleOf-1,y
+	inx
	cpx #4
	bne --
_done
	lda #112 ; logo area height
	sub zTMP3
	beq +
	jsr battleOf_blank
+	lda #$01 ; jump
	sta dlist_battleOf,y
	iny
	lda <#dlist_grid
	sta dlist_battleOf,y
	iny
	lda >#dlist_grid
	sta dlist_battleOf,y
_skipall
	
	jsr updateMusic
; text scroller
	lda #120 ; wait until out of screen
-	cmp rVCOUNT
	bne -
	mva logocol, COLOR+4
	mva <#(logocol+1), dliB_idx
	mwa #dliB, VDSLST ; load battleOf logo dli
	mva <#rHPOSP0, pyrdst1
	mva <#rHPOSP3, pyrdst2
	mva #0,zTMP2
	mva #$c0, rNMIEN
	lda framecnt
	and #63
	tax
	lda chryLUT,x
	ldx chry ; save for text shifting
	sta chry
	sta zTMP1
	add #TEXT_Y+1
	sta pyrY
	lda #0
_frac = *-1
	sub #(SCROLL_SPEED*256)%256
	sta _frac
	lda chrx
	sbc #SCROLL_SPEED
	sta zTMP0
	sta chrx
	
shifttext
	txa ; get old y pos back
	sub chry
	beq placetext ; no y shifting
	bmi _down
	sta zTMP4 ; save for zero filling
	ldy chry
	mva #$e8, _cmd1 ; inx
	lda #$c8 ; iny
	jmp _skip
_down
	eor #$ff ; make offset positive
	sta zTMP4
	inc zTMP4
	txa
	add #39
	tax
	lda chry
	adc #39
	tay
	mva #$ca, _cmd1 ; dex
	lda #$88 ; dey
_skip
	sta _cmd2
	sta _cmd3
	mva #40, zTMP3
-	lda player0+TEXT_Y,x
	sta player0+TEXT_Y,y
	lda player1+TEXT_Y,x
	sta player1+TEXT_Y,y
	lda player2+TEXT_Y,x
	sta player2+TEXT_Y,y
	lda player3+TEXT_Y,x
	sta player3+TEXT_Y,y
	inx
_cmd1 = *-1
	iny
_cmd2 = *-1
	dec zTMP3
	bne -
	ldx zTMP4
	lda #0
-	sta player0+TEXT_Y,y
	sta player1+TEXT_Y,y
	sta player2+TEXT_Y,y
	sta player3+TEXT_Y,y
	iny
_cmd3 = *-1
	dex
	bne -
	
placetext
	lda #0
_frac = *-1
	sub #(SCROLL_SPEED*256)%256
	sta _frac
	lda txtcnt
	sbc #SCROLL_SPEED
	sta txtcnt
	bcs updategrid
	adc #16
	sta txtcnt
	mva >#player0, pyrdst+1
	mva #0, pyrdst
	lda chrx
	eor #$ff
	add #1
	bpl +
	inc pyrdst+1 ; use last two players
	lda chrx ; get negative value back
	add #16
+	lsr a
	lsr a
	and #$fc
	tax
	and #4 ; odd tile?
	beq +
	mva #$80, pyrdst
+	txa
	add #0
pyrY = *-1
	tax
	lda chrc+1
	beq ++
	lda text
txtptr = *-2
	inc txtptr
	bne +
	inc txtptr+1
+	dec chrc
	bne +
	dec chrc+1
+	mvy #0, zTMP4
	.rept 3
	asl a
	rol zTMP4
	.next
	tay
	lda zTMP4
	add >#font
	sta zTMP4
	mva <#font, zTMP3
	mva #8, zTMP5
-	lda (zTMP3),y
	sta player0,x
pyrdst = *-2
	inx
	iny
	dec zTMP5
	bne -
	
updategrid
	;      x
	;     -|-
	;    =====  z
	; y /--|--\ |dz
	;  ======== v
	; -----|----
	lda #0
gridx = *-1
	add #3 ; griddx
	and #63
	sta gridx
	lda #0
gridy = *-1
	add #7
	sta gridy
	sta zTMP7
	cmp #30
	lda #$80
gridzLo = *-1
	sta zTMP3
	ldx #0
	ldy #0
gridzHi = *-1
	sty zTMP4
	bcc _horline
-	sty zTMP5
	iny
	tya
	asl a ; grid width is 2(x+1) the current line
	ldy gridx
	; calculate x*y/64 using QSTable
	sta zARG2
	neg
	sta zARG3
	lda (zARG2),y
	sub (zARG3),y
	sta zTMP6
	; get the correct shifted gfx pointer
	lsr zTMP5
	ror a
	lsr zTMP5
	ror a
	sta dlist_grid+2,x
	lda zTMP6
	and #3
	tay
	lda gridaddrs,y
	add zTMP5
_done
	inx
	sta dlist_grid+2,x
	inx
	inx ; skip lms command
	; add dz to z and dy to y
	lda zTMP3
	adc #48*256/55
griddz = *-1
	sta zTMP3
	bcc +
	inc zTMP4
+	ldy zTMP4
	lda zTMP7
	bcc +
	sbc zTMP4 ; this should be enough to fake foreshortening
	add #48
	clc
+	adc gridysteps,y
	cmp zTMP7 ; did it overflow (after is less than before)
	sta zTMP7
	bcc +
	cmp #30 ; line thickness
	bcc +
	cpx #55*3
	bne -
	jmp loop
+	cpx #55*3
	bne _horline
	jmp loop
_horline
	; force line 0 xpos 0 (horizontal line)
	lda <#grid0
	sta dlist_grid+2,x
	lda >#grid0
	clc
	gcc _done
	
	
logoi	.char -1, -6, -12, -17 ; also doubles as a delay
logopos	.fill 4
logobeg	.fill 4
logoend	.fill 4
	.page
logocol	.fill 4
	.endp
chrx	.byte 0
chry	.byte 9
chrc	.word 0
framecnt	.byte 0
txtcnt	.byte 0
bcnt    .byte 1

scene0
	dec _cnt
	bne _skip
	mva #6, _cnt
	lda #11
	sub _cnt2
	ora #$90
	sta COLOR+6
	dec _cnt2
	bne _skip
	mva #$20, COLOR+5
	mva #$70, gridcol1
	mwa #scene1, scefunc
_skip
	rts
_cnt .byte 11
_cnt2 .byte 11

scene1
	lda logoi
	cmp #66
	bcc _skip
	mva #0, bspdM
	mva #-1, bcnt
	lda zCurMsxRow
	cmp #$3c
	bcc _skip
	mva #1, bspdD
	sta bcnt
	mva #4, bspdM
	mva #$10, colcy
	mwa #scene2, scefunc
_skip
	rts

scene2
	lda zCurMsxOrd
	cmp #$22
	bcc _skip
	lda zCurMsxRow
	bne _skip
	mwa #scene3, scefunc
_skip
	rts
	
scene3
	lda zCurMsxRow
	cmp #$3c
	bcc +
	lda #0
	sta rGRACTL
	sta rHPOSP0
	sta rHPOSP1
	sta rHPOSP2
	sta rHPOSP3
	pla ; pop return address so the stack points 
	pla ; to the loader's return address instead
+	rts

battleOf_blank
	ldx #$70 ; 8 blank lines
-	sub #8
	bcc +
	pha
	txa
	sta dlist_battleOf,y
	pla
	iny
	bcs -
+	adc #8
	beq +
	tax
	lda dlistblankcodes-1,x
	sta dlist_battleOf,y
	iny
+	rts

dliB
	lda rVCOUNT
	cmp #64
	bcs skipdli ; don't do the last line
	lda logocol+1
dliB_idx = *-2
	inc dliB_idx
	sta rWSYNC
	sta rCOLPF0
	jmp skipdli

dli1
	dec zTMP1
	bpl skipdli
	mva #3,zTMP1
	mwa #dli2, VDSLST
	stx nmiX
	ldx zTMP0
	lda chrxLUT,x
	sta rHPOSP0
	jmp dli2_
	
dli2
	dec zTMP1
	bpl skipdli
	mva #3,zTMP1
	stx nmiX
	lda pyrdst1
	eor #1
	sta pyrdst1
	ora #2
	sta pyrdst2
	lda zTMP0
	add	zTMP2
	tax
	lda chrxLUT,x
	sta rHPOSP1
pyrdst1 = *-2
	lda zTMP0
	sub	zTMP2
	tax
	lda chrxLUT,x
	sta rHPOSP3
pyrdst2 = *-2
dli2_
	lda zTMP2
	add #16
	bvc + ; = 128
	mwa #dli3, VDSLST
+	sta zTMP2
skipdli_x
	ldx nmiX
skipdli
	lda nmiA
	rti

dli3
	dec zTMP1
	bpl skipdli
	mva #$40, rNMIEN ; no more tiles below
	stx nmiX
	lda zTMP0
	add #128
	tax
	lda chrxLUT,x
	sta rHPOSP2
	jmp skipdli_x
	
vbi
	sta nmiA
	bit rNMIST
	bpl +
	jmp dli1
VDSLST = *-2
+	stx nmiX
	mwa SDLSTL, rDLISTL
	mva SDMCTL, rDMACTL
	ldx #7
-	mva COLOR,x, rCOLPM0,x
	dex
	bpl -
	lda nmiA
	ldx nmiX
	rti
	
dlistblankcodes
	.byte $00, $10, $20, $30, $40, $50, $60 ; still faster than left shifting 4 times
		
gridaddrs
	.byte >grid0, >grid1, >grid2, >grid3
	
	.union
	.struct
bounceLUT	.block
	; (66-x)²*80/56² stored in a delta form instead to allow more compression
	.byte 0, 4, 3, 3, 3, 4, 3, 3, 3, 3, 2, 3, 3, 3, 3, 2
	.byte 3, 2, 3, 2, 3, 2, 2, 2, 2, 3, 2, 2, 2, 2, 1, 2
	.byte 2, 2, 1, 2, 2, 1, 1, 2, 1, 2, 1, 1, 1, 1, 1, 1
	.byte 1, 1, 1, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0
	.bend

chrxLUT_packed	.block
	.byte %10111010, %11101010, %10101010, %10101010, %10101000, %10100010, %00100010, %00100010
	.byte %00001000, %00100000, %00000010, %00000000, %00000000, %00000000, %00000000, %00000010
	.byte %00000000, %00000000, %00000000, %00000000, %00000000, %10000000, %00100000, %00100010
	.byte %00001000, %10001000, %10100010, %10001010, %10101010, %10101010, %10101110, %10111010
	.bend
	.ends
	.fill size(bounceLUT)+56
	.endu
	
chryLUT .block
_x := 0
	.rept 64
	.byte (sin(rad(_x*360.0/64.0))+1.0)*8
_x := _x + 1
	.next
	.bend
	
gridysteps	.block
	.byte 255
_x := 2
	.rept 47
	.byte 256/_x+0.5
_x := _x + 1
	.next
	.bend

exmemtexts
	.byte 0,0,8,2,9 ; '  64K'
	.byte 0,6,7,3,9 ; ' 256K'
	.byte 0,7,5,1,9 ; ' 512K'
	.byte 5,4,6,2,9 ; '1024K'
	
text	.binary "scroller/data.bin"
font	.binary "scroller/font_gen.1bpp"
battleOf	.binary "gfx/battleOf.1bpp"
	.align $100
grid0	.binary "gfx/grid.2bpp"

chrxLUT	.fill 256
QSTable	.fill 512

	.align $800
	; this part is auto-generated
dlist_grid	.fill 1+55*3+3 ; 1 blank line + 55 display + jvb
dlist	.fill 1 ; 8 blank lines
dlist_battleOf

	.align $200
player0	.fill $80
player1	.fill $80
player2	.fill $80
player3	.fill $80
	.warn format("Part 6's memory usage: %#04x - %#04x", start, *)
	
*	= $c000
grid1	.fill size(grid0)
*	= $e000
grid2	.fill size(grid0)
grid3	.fill size(grid0)
