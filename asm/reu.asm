reu_status   = $DF00
reu_command  = $DF01
reu_c64base  = $DF02
reu_reubase  = $DF04
reu_translen = $DF07
reu_irqmask  = $DF09
reu_control  = $DF0A

reu_start
	lda #0
	ldx reu_c64base
	inc reu_c64base
	inx
	cpx reu_c64base
	bne .no_reu
; REU detected
	lda #>use_reu_question
	ldx #<use_reu_question
	jsr printstring_raw
-	jsr kernal_getchar
    beq -
	cmp #89
	bne .no_reu
; Use REU	
;	inc $d020

; Perform initial copy of data to REU here?	

	
	lda #$ff
.no_reu
	sta use_reu
	rts

use_reu_question
    !pet "Use REU? (Y/N) ",0


	