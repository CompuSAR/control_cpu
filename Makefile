ControlCpu.runs/ControlCpu.mcs:

ControlCpu.gen/saros/bl1/bl1.bin: ControlCpu.gen/saros/bl1/dir.tag
	$(MAKE) -C "$(@D)" -f "$(shell pwd)/ControlCpu.srcs/saros/bl1/Makefile" "$(@F)" VPATH="$(shell pwd)/ControlCpu.srcs/saros/bl1"

%/dir.tag:
	mkdir -p "$(@D)"
	@touch "$@"

clean:
	$(RM) -r ControlCpu.gen/saros

.PHONY: clean
