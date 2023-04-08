all: ControlCpu.srcs/saros/boot_loader_state.mem

ControlCpu.runs/ControlCpu.mcs:

ControlCpu.gen/saros/%: ControlCpu.gen/saros/config.log
	$(MAKE) -C "$(@D)" "$(@F)"
.PHONY: ControlCpu.gen/saros/%

ControlCpu.gen/saros/bl1/bl1.coe: ControlCpu.gen/saros/config.log
	$(MAKE) -C "$(@D)" "$(@F)"

.PHONY: ControlCpu.gen/saros/bl1/bl1.coe

ControlCpu.gen/saros/bl1/bl1.mem: ControlCpu.gen/saros/config.log
	$(MAKE) -C "$(@D)" "$(@F)"

.PHONY: ControlCpu.gen/saros/bl1/bl1.mem

ControlCpu.gen/saros/config.log: ControlCpu.srcs/saros/configure
	$(RM) -r $(@D)
	mkdir -p $(@D)
	cd $(@D) && ../../ControlCpu.srcs/saros/configure --host=riscv32-unknown-elf

ControlCpu.srcs/saros/configure:
	cd $(@D) && autoreconf -i

%/dir.tag:
	mkdir -p "$(@D)"
	@touch "$@"

ControlCpu.gen/saros/bl1/mif.tag: ControlCpu.gen/saros/bl1/bl1.mif
	find -name blk_mem.mif -print0 | xargs -0 --no-run-if-empty -n1 cp -a $<
	touch $@

ControlCpu.gen/saros/bl1/bl1.mif: ControlCpu.gen/saros/config.log
	$(MAKE) -C "$(@D)" "$(@F)"
.PHONY: ControlCpu.gen/saros/bl1/bl1.mif

ControlCpu.srcs/saros/boot_loader.mem: ControlCpu.gen/saros/bl1/bl1.mem
	cp "$<" "$@"

ControlCpu.srcs/saros/boot_loader_state.mem: ControlCpu.srcs/saros/boot_loader.mem
	scripts/gen_cache_metadata.py `cat $< | wc -l` 13 0 2048 > $@.tmp
	mv $@.tmp $@

clean:
	$(RM) -r ControlCpu.gen/saros

.PHONY: clean
