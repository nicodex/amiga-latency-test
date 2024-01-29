; SPDX-FileCopyrightText: 2024 Nico Bendlin <nico@nicode.net>
; SPDX-License-Identifier: CC0-1.0
;
;	Pack 256K ROM as Kickstart disk for Amiga 1000 bootstrap
;
;	> vasmm68k_mot -Fbin -o latocspi-a1k.adf latocspi-a1k.asm
;
	IDNT	latocspi-a1k.adf

Sector0:
		dc.b	'KICK'
		dcb.b	512-4,0

RomImage:
	INCBIN	latocspi-a1k.rom

DiskSpare:
		dcb.b	80*2*11*512-(*-Sector0),0

	END
