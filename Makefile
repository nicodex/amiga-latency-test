# GNU Make: <https://www.gnu.org/software/make/>
# vasm    : <http://www.compilers.de/vasm.html>
# romtool : <https://pypi.org/project/amitools/>
# FS-UAE  : <https://fs-uae.net/>

ROMNAME = latocspi

AMIGA_TOOLCHAIN ?= /opt/amiga
VASM ?= $(AMIGA_TOOLCHAIN)/bin/vasmm68k_mot
VASM_OPTS ?= -quiet -wfail -x
ROMTOOL ?= /usr/bin/env romtool
FSUAE ?= /usr/bin/env fs-uae

all: $(ROMNAME).rom $(ROMNAME)-a1k.adf

.PHONY: all clean check-rom check-a1k check test-rom test-a1k

$(ROMNAME).rom : $(ROMNAME)-rom.asm
	$(VASM) -Fbin $(VASM_OPTS) -o $@ $< && \
	$(ROMTOOL) copy --fix-checksum $@ $@

$(ROMNAME)-a1k.rom : $(ROMNAME)-rom.asm
	$(VASM) -Fbin $(VASM_OPTS) -DROM_256K -o $@ $< && \
	$(ROMTOOL) copy --fix-checksum $@ $@

$(ROMNAME)-a1k.adf : $(ROMNAME)-a1k.asm $(ROMNAME)-a1k.rom
	$(VASM) -Fbin $(VASM_OPTS) -DROM_256K -o $@ $<

clean:
	rm -f $(ROMNAME).rom
	rm -f $(ROMNAME)-a1k.rom
	rm -f $(ROMNAME)-a1k.adf

check-rom: $(ROMNAME).rom
	$(ROMTOOL) info $< && \
	$(ROMTOOL) scan $<

check-a1k: $(ROMNAME)-a1k.rom
	$(ROMTOOL) info $< && \
	$(ROMTOOL) scan $<

check: check-rom check-a1k

test-rom: $(ROMNAME)-rom.fs-uae $(ROMNAME).rom
	$(ROMTOOL) info $(ROMNAME).rom
	$(FSUAE) $<

test-a1k: $(ROMNAME)-a1k.fs-uae $(ROMNAME)-a1k.adf
	$(ROMTOOL) info $(ROMNAME)-a1k.rom
	$(FSUAE) $<

