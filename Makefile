all: ControlCpu.gen/saros/bl1/bl1.coe

ControlCpu.runs/ControlCpu.mcs:

ControlCpu.gen/saros/%: ControlCpu.gen/saros/config.log
	$(MAKE) -C "$(@D)" "$(@F)"
.PHONY: ControlCpu.gen/saros/%

ControlCpu.gen/saros/config.log: ControlCpu.srcs/saros/configure
	$(RM) -r $(@D)
	mkdir -p $(@D)
	cd $(@D) && ../../ControlCpu.srcs/saros/configure --host=riscv64-linux-gnu

ControlCpu.srcs/saros/configure:
	cd $(@D) && autoreconf -i

%/dir.tag:
	mkdir -p "$(@D)"
	@touch "$@"

clean:
	$(RM) -r ControlCpu.gen/saros

.PHONY: clean
