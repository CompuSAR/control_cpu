all: ControlCpu.gen/sources_1/ip/blk_mem/blk_mem.mif ControlCpu.srcs/saros/bl1/bl1.coe

ControlCpu.runs/ControlCpu.mcs:

ControlCpu.gen/saros/%: ControlCpu.gen/saros/config.log
	$(MAKE) -C "$(@D)" "$(@F)"
.PHONY: ControlCpu.gen/saros/%

ControlCpu.gen/saros/bl1/bl1.coe: ControlCpu.gen/saros/config.log
	$(MAKE) -C "$(@D)" "$(@F)"

.PHONY: ControlCpu.gen/saros/bl1/bl1.coe

ControlCpu.gen/saros/config.log: ControlCpu.srcs/saros/configure
	$(RM) -r $(@D)
	mkdir -p $(@D)
	cd $(@D) && ../../ControlCpu.srcs/saros/configure --host=riscv64-linux-gnu

ControlCpu.srcs/saros/configure:
	cd $(@D) && autoreconf -i

%/dir.tag:
	mkdir -p "$(@D)"
	@touch "$@"

ControlCpu.gen/sources_1/ip/blk_mem/blk_mem.mif: ControlCpu.gen/saros/bl1/bl1.mif
	find -name blk_mem.mif -print0 | xargs -0 rm
	cp "$<" "$@"

ControlCpu.gen/saros/bl1/bl1.mif: ControlCpu.gen/saros/config.log
	$(MAKE) -C "$(@D)" "$(@F)"
.PHONY: ControlCpu.gen/saros/bl1/bl1.mif

ControlCpu.srcs/saros/bl1/bl1.coe: ControlCpu.gen/saros/bl1/bl1.coe
	cp "$<" "$@"

clean:
	$(RM) -r ControlCpu.gen/saros

.PHONY: clean
