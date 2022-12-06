all: ControlCpu.gen/saros/bl1/mifs.tag ControlCpu.gen/saros/bl1/bl1.coe

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

ControlCpu.gen/saros/bl1/mifs.tag: ControlCpu.gen/saros/bl1/bl1.mif
	for dir in \
		ControlCpu.gen/sources_1/ip/blk_mem \
		ControlCpu.sim/sim_1/behav/xsim \
		ControlCpu.ip_user_files/sim_scripts/blk_mem/vcs \
		ControlCpu.ip_user_files/sim_scripts/blk_mem/xsim \
		ControlCpu.ip_user_files/sim_scripts/blk_mem/riviera \
		ControlCpu.ip_user_files/sim_scripts/blk_mem/modelsim \
		ControlCpu.ip_user_files/sim_scripts/blk_mem/activehdl \
		ControlCpu.ip_user_files/sim_scripts/blk_mem/questa \
		ControlCpu.ip_user_files/sim_scripts/blk_mem/xcelium \
		ControlCpu.ip_user_files/mem_init_files ; \
	    do if [ -f $$dir/blk_mem.mif ] ; then cp "$<" "$$dir/blk_mem.mif" ; fi ; done
	touch "$@"

ControlCpu.gen/saros/bl1/bl1.mif: ControlCpu.gen/saros/config.log
	$(MAKE) -C "$(@D)" "$(@F)"

.PHONY: ControlCpu.gen/saros/bl1/bl1.mif

clean:
	$(RM) -r ControlCpu.gen/saros

.PHONY: clean
