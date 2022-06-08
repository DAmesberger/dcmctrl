# configuration
SHELL = /bin/sh
FPGA_PKG = cb132
FPGA_TYPE = hx1k
PCF = pilotfpga.pcf

# included modules
ADD_SRC = dcmctrl.v

top_dcmctrl: top_dcmctrl.rpt top_dcmctrl.bin

%.json: %.v $(ADD_SRC)
	yosys -ql $(basename $@)-yosys.log -p \
	    'synth_ice40 -top $(basename $@) -json $@' $< $(ADD_SRC)

%.asc: %.json
	nextpnr-ice40 --${FPGA_TYPE} --package ${FPGA_PKG} --json $< --pcf ${PCF} --asc $@

%.rpt: %.asc
	icetime -d ${FPGA_TYPE} -mtr $@ $<

%.bin: %.asc
	icepack $< $(subst top_,,$@)

all: top_dcmctrl

clean:
	rm -f top*.json top*.asc top*.rpt *.bin top*yosys.log

.PHONY: all clean