; entry point of this demo
	.include "gvars.asm"
	
; os memory stuff before we completely ditch it
DOSVEC = $0a
CH     = $2fc
ICCMD  = $342
ICBA   = $344
ICBL   = $348
CIOV   = $e456

*	= $02e0
	.word xexStart
	
*	= xexStart
	sei
	mva #0, rNMIEN
	lda #123 ; wait until out of screen
-	cmp rVCOUNT
	bcs -
	lda rPORTB
	pha
	and #$fe ; disable os rom
	ora #$02 ; disable internal basic
	sta rPORTB
	; 64k xl/xe test
	mva #$72, CIOV
	cmp CIOV ; should be #$72 instead of #$4c (jmp) or #$ff
	bne notEnoughRam
	sta $bffc
	lda $bffc ; should be #$72 instead of #$00
	beq removeCart
	lda rPAL
	and #$e ; region check
	bne ntscSystem
	pla
	sta rPORTB ; resore os rom for a while so blank charset won't flash while decompressing
	; move decompress routine
	_x := 0
	ldx #0
-	.rept >len(decompress_unmoved)
	lda decompress_unmoved+_x,x
	sta decompress+_x,x
	_x := _x + $100
	.next
	cpx #<len(decompress_unmoved)
	bcs +
	lda decompress_unmoved+_x,x
	sta decompress+_x,x
+	inx
	bne -
	; move compressedPartAddresses table
	ldx #NUM_PARTS*4
-	lda cpa_unmoved-1,x
	sta compressedPartAddresses-1,x
	dex
	bne	-
	; decompress part loader and jump to that
	mwa #part0_compressed, zARG0
	mwa #runDemo, zARG1
	jsr decompress
	jmp runDemo

notEnoughRam
	mwa #notEnoughRamText, ICBA
	mva #<size(notEnoughRamText), ICBL
	jmp putChar
	
removeCart
	mwa #removeCartText, ICBA
	mva #<size(removeCartText), ICBL
	jmp putChar
	
ntscSystem
	mwa #ntscSystemText, ICBA
	mva #<size(ntscSystemText), ICBL
	jmp putChar
	
putChar
	mva #0, ICBL+1
	mva #$0b, ICCMD ; put characters
	pla
	sta rPORTB ; resore os rom and intterrupts
	mva #$40, rNMIEN
	cli
	ldx #0
	jsr CIOV
	lda #$ff
	sta CH
-	cmp CH
	beq -
	jmp (DOSVEC) ; bye
	
	.enc "atascii"
notEnoughRamText .text "Whoops! This demo needs 64k XL to run!"
removeCartText   .text "BOTB STRONG REMOVE CARTRIDGES\n"
ntscSystemText	.text "This release doesn't support NTSC yet!"

decompress_unmoved	.logical decompress
	.include "decomp.asm"
	.here

cpa_unmoved	.logical compressedPartAddresses
	; not including part 0
	.word part1_compressed, partEntry
	.word part2_compressed, partEntry
	.word part3_compressed, partEntry_3
	.word part4_compressed, partEntry
	.word part5_compressed, partEntry
	.word part6_compressed, partEntry
	.word part7_compressed, partEntry_7
	.word part8_compressed, partEntry
	.word part9_compressed, partEntry
	.here
	.cerror size(cpa_unmoved) != NUM_PARTS*4, "Number of cpa_unmoved entries and NUM_PARTS mismatch"

part0_compressed .binary "0_loader_music.lz"
	.warn format("Part 1: %#04x", *)
part1_compressed .binary "1_botb_logo.lz"
	.warn format("Part 2: %#04x", *)
part2_compressed .binary "2_parallax.lz"
	.warn format("Part 3: %#04x", *)
part3_compressed .binary "3_title.lz"
	.warn format("Part 4: %#04x", *)
part4_compressed .binary "4_twister.lz"
	.warn format("Part 5: %#04x", *)
part5_compressed .binary "5_metaballs.lz"
	.warn format("Part 6: %#04x", *)
part6_compressed .binary "6_scroller.lz"
	.warn format("Part 7: %#04x", *)
part7_compressed .binary "7_mecha_grill.lz"
	.warn format("Part 8: %#04x", *)
part8_compressed .binary "8_greets.lz"
	.warn format("Part 9: %#04x", *)
part9_compressed .binary "9_credits.lz"
