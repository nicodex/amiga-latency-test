; SPDX-FileCopyrightText: 2024 Nico Bendlin <nico@nicode.net>
; SPDX-License-Identifier: CC0-1.0
;
;	Latency Test ROM - OCS PAL interlaced
;
;	> vasmm68k_mot -Fbin -o latocspi.rom latocspi-rom.asm
;	> romtool copy --fix-checksum latocspi.rom latocspi.rom
;	> vasmm68k_mot -Fbin -o -DROM_256K latocspi-a1k.rom latocspi-rom.asm
;	> romtool copy --fix-checksum latocspi-a1k.rom latocspi-a1k.rom
;
	IDNT	latocspi.rom

	MACHINE	68000
	FPU	0
	FAR
	OPT	P+  ; position independent code
	OPT	A-  ; absolute to PC-relative
	OPT	D-  ; debug symbols
	OPT	O-  ; all optimizations
	OPT	OW+ ; show optimizations

	IFND	ROM_256K
ROM_BASE	SET	$00F80000
	ELSE
ROM_BASE	SET	$00FC0000
	ENDC
ROM_SIZE	SET	$01000000-ROM_BASE
ROM_ID11	EQU	$11114EF9   ; 256K ROM ID + JMP (xxx).L
ROM_ID14	EQU	$11144EF9   ; 512K ROM ID + JMP (xxx).L
ROM_FILL	EQU	~0

	SECTION	latocspi,CODE
	ORG	ROM_BASE

;
; CPU vector table (OVL) / Kickstart ROM header (dummy)
;
RomBase:
	IFEQ	ROM_SIZE-$080000
		dc.l	ROM_ID14            ; [VEC_RESETSP] cold RESET SP / ID
	ELSE
		dc.l	ROM_ID11
	ENDC
		dc.l	ColdStart           ; [VEC_RESETPC] cold RESET PC
		dc.l	ColdReset           ; [VEC_BUSERR]  diag tag ($FFFF)
		dc.l	ColdReset           ; [VEC_ADDRERR] Kick ver,rev
		dc.l	ColdReset           ; [VEC_ILLEGAL] Exec ver,rev
		dc.l	ColdReset           ; [VEC_ZERODIV] System serial
		dcb.l	-6+1+15,ColdReset   ; [VEC_CHK..VEC_UNINT]
RomTagName:	dc.b	'latocspi',0,0      ; [VEC_RESV16..VEC_RESV23]
RomTagRes:	dc.w	$4AFC               ;   RTC_MATCHWORD   (RT_MATCHWORD)
		dc.l	RomTagRes           ;                   (RT_MATCHTAG)
		dc.l    RomTagEnd           ;                   (RT_ENDSKIP)
		dc.b    $02                 ;   RTF_SINGLETASK  (RT_FLAGS)
		dc.b    0                   ;                   (RT_VERSION)
		dc.b    0                   ;   NT_UNKNOWN      (RT_TYPE)
		dc.b    127                 ;                   (RT_PRI)
		dc.l    RomTagName          ;                   (RT_NAME)
		dc.l    RomTagId            ;                   (RT_IDSTRING)
		dc.l	ColdReset           ; [VEC_SPUR]        (RT_INIT)
		dcb.l	-25+1+51,ColdReset  ; [VEC_INT1..VEC_FPUNDER]
ColdReset:	reset                       ; [VEC_FPOE] (compat ColdStart-2)
ColdStart:	bra.b	0$                  ;            (compat = $00F800D2)
		dcb.l	-53+1+58,ColdReset  ; [VEC_FPOVER..VEC_MMUACC]
0$:		bra.w	RomStart            ; [VEC_RESV59]
		dcb.l	-60+1+63,ColdReset  ; [VEC_UNIMPEA..VEC_RESV63]
RomTagId:	   	                    ; [VEC_USER..]
		dc.b	'latocspi.rom 0.0 (27.01.2024)',13,10,0 ; 
		dc.b	'Latency Test OCS PAL interlaced',0
		dc.b	'(c) 2024 Nico Bendlin <nico@nicode.net>',0
		dc.b	'No Rights Reserved.',0
		dcb.b	*&1,0   ; align to word
		dcb.b	*&2,0   ; align to long
		dcb.l	256-((*-RomBase)/4),ColdReset
	IFNE	(ColdStart-RomBase)-$00D2
	FAIL	"Unexpected ColdStart offset, review the code."
	ENDC
	IFNE	(ColdStart-ColdReset)-2
	FAIL	"Unexpected ColdReset offset, review the code."
	ENDC

;
; ROM entry point
;
RomStart:
custom		EQUR	a6  ; $DFF000
ciaa		EQUR	a5  ; $BFE001
;cpu		    	    ; $000000 256*4 cpu vectors
bpl0		EQUR	sp  ; $000400 (640/8)*(512+64)
spr0		EQUR	a4  ; $00B800 (1+512/2+1)*4*8
;aud		    	    ; $00D840 8*2 sinus wave
;end		    	    ; $00D850 ~54K
		; disable/clear all interrupts/DMA
		move.w	#%0010011100000000,sr   ; supervisor mode, IPL 7
		lea	($DFF000),custom
		move.w	#$7FFF,d0           ; #~INTF_SETCLR / #~DMAF_SETCLR
		move.w	d0,($09A,custom)    ; (intena,)
		move.w	d0,($09C,custom)    ; (intreq,)
		move.w	d0,($096,custom)    ; (dmacon,)
		; disable the ROM overlay
		lea	($BFE001),ciaa
		move.b	#$03,($0200,ciaa)   ; #CIAF_LED|CIAF_OVERLAY,(ciaddra,)
		bclr.b	#0,(ciaa)           ; #CIAB_OVERLAY,(ciapra,)
		; init CPU vectors (and bpl0 / unused stack)
		moveq	#0,d0
		movea.l	d0,bpl0
		move.l	d0,(bpl0)+  ; LOCATION_ZERO (kick alert tag #'HELP')
		move.l	d0,(bpl0)+  ; ABSEXECBASE (abs exec.library pointer)
		move.w	#(-2+1+255)-1,d0    ; [VEC_BUSERR..]
		lea	(ColdReset,pc),a0
0$:		move.l	a0,(bpl0)+
		dbf	d0,0$

	MACRO	wait_vpos_0   ; wait for line 0 (>= 256, < 256)
.wv0a_\@:	btst.b	#$7&0,((($F-0)>>3)+$004,custom) ; #0,(vposr+1,) V8
		beq.b	.wv0a_\@
.wv0b_\@:	btst.b	#$7&0,((($F-0)>>3)+$004,custom) ; #0,(vposr+1,) V8
		bne.b	.wv0b_\@
	ENDM

ScrInit:	wait_vpos_0
		; PAL HiRes interlaced 640x512+128+44
		move.l	#$2C812CC1,($08E,custom)    ; (diwstrt/diwstop,)
		move.l	#$003C00D4,($092,custom)    ; (ddfstrt/ddfstop,)
		move.l	bpl0,($0E0,custom)          ; (0*4+bplpt,)
		move.l	#$82040000,($100,custom)    ; (bplcon0/bplcon1,)
		move.l	#$00000C00,($104,custom)    ; (bplcon2/bplcon3,)
		move.l	#$00500050,($108,custom)    ; (bpl1mod/bpl2mod,)
		move.l	#$00000888,($180,custom)    ; (0*2+color/1*2+color,)
		move.w	#$0F00,(17*2+$180,custom)   ; (17*2+color,) sprite 0/1
		move.w	#$00F0,(21*2+$180,custom)   ; (21*2+color,) sprite 2/3
		move.w	#$000F,(25*2+$180,custom)   ; (25*2+color,) sprite 4/5
		move.w	#$0FF0,(29*2+$180,custom)   ; (25*2+color,) sprite 6/7
BplInit:
		move.l	#%10011000111000011110000011111000,d2   ; lines MSB
		move.l	#%00011111100000001111111100000000,d3   ; lines LSB
		movea.l	bpl0,a0
		move.w	#(512+64)-1,d0
0$:		moveq	#(640/64)-1,d1
1$:		move.l	d2,(a0)+
		move.l	d3,(a0)+
		dbf	d1,1$
		move.l	d2,d1
		roxr.l	#1,d1
		roxr.l	#1,d3
		roxr.l	#1,d2
		dbf	d0,0$
		movea.l	a0,spr0
		move.l	#%11111111000000000000000011111111,d0
		move.l	#%00000000000000011000000000000000,d1
		suba.w	#((640/2)+16)/8,a0
		move.w	#(512+64)-1,d2
2$:		and.l	d0,(a0)
		or.l	d1,(a0)
		suba.w	#(640/8),a0
		dbf	d2,2$
SprInit:	movea.l	spr0,a0
		moveq	#8-1,d0
		move.w	#((44+0)&$FF)<<8,d2
		move.w	#(((44+(512/2))&$FF)<<8)|(((((44+(512/2))&$100)>>1)|((44+0)&$100))>>6),d3
		move.w	#128,d4
0$:		move.w	d4,d5
		lsr.w	#1,d5
		or.w	d2,d5
		swap	d5
		move.w	d4,d5
		andi.w	#1,d5
		or.w	d3,d5
		move.l	d5,(a0)+
		move.l	#%11111111111111110000000000000000,d5
		move.w	#(512/2)-1,d1
1$:		move.l	d5,(a0)+
		dbf	d1,1$
		clr.l	(a0)+
		addi.w	#((640/2)+16)/8,d4
		dbf	d0,0$
AudInit:
		lea	($0A0,custom),a1    ; (aud,)
		moveq	#4-1,d0
		move.l	#((16/2)<<16)|508,d1    ; ac_len/ac_per
		move.l	#((64/2)<<16)|$0000,d2  ; ac_vol/ac_dat
0$:		move.l	a0,(a1)+    ; (x*ac_SIZEOF+aud+ac_ptr,)
		move.l	d1,(a1)+    ; (x*ac_SIZEOF+aud+ac_len/ac_per,)
		move.l	d2,(a1)+    ; (x*ac_SIZEOF+aud+ac_vol/ac_dat,)
		addq.l	#4,a1       ; (x*ac_SIZEOF+aud+ac_pad,)
		dbf	d0,0$
		move.l	#(0<<24)|(49<16)|(90<<8)|117,(a0)+
		move.l	#(127<<24)|(117<16)|(90<<8)|49,(a0)+
		move.l	#(0<<24)|((-49&$FF)<<16)|((-90&$FF)<<8)|(-117&$FF),(a0)+
		move.l	#((-127&$FF)<<24)|((-117&$FF)<<16)|((-90&$FF)<<8)|(-49&$FF),(a0)+
DmaInit:
		; enable bitplane/sprite/DMA at long frame
		wait_vpos_0
		move.w	($006,custom),d0   ; (vhposr,)
2$:		cmp.w 	($006,custom),d0   ; (vhposr,)
		beq.b	2$  ; wait for VHPOS change before reading LOF (ICS)
		btst.b	#$7&15,((($F-15)>>3)+$004,custom)   ; #15-8,(vposr,)
		bne.b	3$
		wait_vpos_0
3$:		move.w	#$9204,($100,custom)    ; (bplcon0,)
		move.w	#$8320,($096,custom)    ; (dmacon,)
MainLoop:
		; toogle LED when left sprite border hits center line
		moveq	#0,d0
		; move bitplane one line upwards every full _frame_
0$:		movea.l	bpl0,a0
		moveq	#64-1,d1
1$:		move.l	a0,($0E0,custom)    ; (bplpt+0*4,)
		adda.w	#640/8,a0
		; move sprites 2 pixels (1 LoRes) left every _field_
		lea	($120,custom),a1    ; (sprpt,)
		movea.l	spr0,a2
		moveq	#8-1,d2
		; do not move sprites as long as LMB is down
		move.b	(ciaa),d3   ; (ciapra,)
2$:		btst.l	#6,d3       ; #CIAB_GAMEPORT0,(ciapra,)
		beq.b	4$
		bclr.b	#$7&0,((($F-0)>>3)+$02,a2)  ; #0,(sd_ctl+1,) Z=H0,H0=0
		bne.b	3$
		bset.b	#$7&0,((($F-0)>>3)+$02,a2)  ; #0,(sd_ctl+1,)
		subq.b	#1,($00+1,a2)               ; (sd_pos+1)
		cmpi.b	#(128-16)>>1,($00+1,a2)     ; (sd_pos+1)
		bcc.b	4$
		move.b	#((128+(640/2))>>1)-1,($00+1,a2)    ; (sd_pos+1)
		bra.b	4$
3$:		cmpi.b	#(128+((640/2)/2))>>1,($00+1,a2)    ; (sd_pos+1)
		bne.b	4$
		eori.b	#$02,d0     ; #CIAF_LED
		move.b	d0,(ciaa)   ; (ciapra,)
		; enable audio/DMA (DMAF_AUD1|DMAF_AUD0)
		move.w	#$8203,($096,custom)    ; (dmacon,)
4$:		move.l	a2,(a1)+
		adda.w	#(1+(512/2)+1)*4,a2
		dbf	d2,2$
		wait_vpos_0
		; disable audio/DMA (DMAF_AUDIO)
		move.w	#$000F,($096,custom)    ; (dmacon,)
		dbf	d1,1$
		bra.b	0$

RomTagEnd:

	IFEQ	ROM_SIZE-$080000
		dcb.b	$040000-(*-RomBase),ROM_FILL
KickSplit:	dc.l	ROM_ID11            ; [VEC_RESETSP]
		dc.l	ColdStart           ; [VEC_RESETPC]
		dcb.l	-2+1+51,ColdReset   ; [VEC_BUSERR..VEC_FPUNDER]
		reset                       ; [VEC_FPOE] (compat $FC00D0)
		bra.b	0$                  ;            (compat $FC00D2)
		dcb.l	-53+1+58,ColdReset  ; [VEC_FPOVER..VEC_MMUACC]
0$:		bra.w	KickSplit+2         ; [VEC_RESV59]
		dcb.l	-60+1+63,ColdReset  ; [VEC_UNIMPEA..VEC_RESV63]
		dcb.l	-64+1+255,ColdReset ; [VEC_USER..]
	ENDC

		dcb.b	ROM_SIZE-(8*2)-(2*4)-(*-RomBase),ROM_FILL
RomFooter:
		dc.l	0           ; $FFFFE8: ROM checksum (set on build)
		dc.l	ROM_SIZE    ; $FFFFEC: ROM size for software reset
		    	            ; 	lea	($01000000),a0  ; ROM end 
		    	            ; 	suba.l	(-$0014,a0),a0  ; ROM size
		    	            ; 	movea.l	($0004,a0),a0   ; ColdStart
		    	            ; 	subq.l	#2,a0           ; ColdReset
		    	            ; 	reset	                ; 1st reset
		    	            ; 	jmp	(a0)    ; always prefetched
		; CPU Autovector interrupt exception vector indices (68000)
		; NOTE: MSB is unused (but 0 to make the ROM parsers happy)
		dc.w	24      ; VEC_SPUR      ; spurious interrupt
		dc.w	25      ; VEC_INT1      ; TBE,DSKBLK,SOFTINT
		dc.w	26      ; VEC_INT2      ; PORTS
		dc.w	27      ; VEC_INT3      ; COPER,VERTB,BLIT
		dc.w	28      ; VEC_INT4      ; AUD2,AUD0,AUD3,AUD1
		dc.w	29      ; VEC_INT5      ; RBF,DSKSYNC
		dc.w	30      ; VEC_INT6      ; EXTER,INTEN
		dc.w	31      ; VEC_INT7      ; NMI
	IFNE	(*-RomBase)-ROM_SIZE
	FAIL	"Unexpected ROM size, review the code."
	ENDC

	END
