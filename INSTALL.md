# install toolchain

go to https://projectf.io/posts/building-ice40-fpga-toolchain/ and follow the steps to install the FPGA toolchain

# build and write bitstream for FPGA module in slot 3:
1. run `make`
2. copy bitstream: `scp dcmctrl.bin pi@[IP]:~`
3. write bitstream: `ssh pi@[IP] 'cp ~/dcmctrl.bin /proc/pilot/module3/bitstream'`

# write bitstream
1. copy bitstream to 

# pilot plugin installation

1. copy plugin folder to pilot firmware project
2. add the plugin to the .pilotfwconfig.json in the appropriate FPGA module section:

## Example for FPGA module in slot 3:   
```json
        {
            "slot": 3,
            "fid": "fpga",
            "fid_nicename": "FPGA",
            "plugin": "dcmctrl"
        },
```