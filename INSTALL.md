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