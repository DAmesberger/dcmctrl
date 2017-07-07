
A simple DC motor controller FPGA core
--------------------------------------

The controller has a simple SPI interface. Input data is latched on the rising
edge of serial clock and output data is made available on the falling clock edge
the clock idle state is low.

I.e. it is compatible with SPI mode "CPOL=0, CPHA=0".

The protocol is simple: The first byte of a transaction is a 7 bit register
start address + MSB set for writes, followed by write data on MOSI and read
data on MISO. The MISO signal always contains the (old) register data, even
during a write. The first MISO byte is always zero.

Register File
-------------

Important Note: the flags and current_position registers must be written
using a write-readback-loop to make sure that concurrent writes by the
controller do not conflict with writes via SPI.


	Address | Register
	--------+------------------------------
	 0x00   | channel 0 flags
	 0x01   | channel 0 current_position[23:16]
	 0x02   | channel 0 current_position[15:8]
	 0x03   | channel 0 current_position[7:0]
	--------+----------------------------------
	 0x04   | channel 1 flags
	 0x05   | channel 1 current_position[23:16]
	 0x06   | channel 1 current_position[15:8]
	 0x07   | channel 1 current_position[7:0]
	--------+----------------------------------
	 ...    | ....
	--------+----------------------------------
	 0x3c   | channel 15 flags
	 0x3d   | channel 15 current_position[23:16]
	 0x3e   | channel 15 current_position[15:8]
	 0x3f   | channel 15 current_position[7:0]
	--------+----------------------------------
	 0x40   | channel 0 pwm duty cycle
	 0x41   | channel 0 target_position[23:16]
	 0x42   | channel 0 target_position[15:8]
	 0x43   | channel 0 target_position[7:0]
	--------+----------------------------------
	 0x44   | channel 1 pwm duty cycle
	 0x45   | channel 1 target_position[23:16]
	 0x46   | channel 1 target_position[15:8]
	 0x47   | channel 1 target_position[7:0]
	--------+----------------------------------
	 ...    | ....
	--------+----------------------------------
	 0x7c   | channel 1 pwm duty cycle
	 0x7d   | channel 1 target_position[23:16]
	 0x7e   | channel 1 target_position[15:8]
	 0x7f   | channel 1 target_position[7:0]
	--------+----------------------------------

The flags register bits:

	Bit 0 ...... Got OTW condition
	Bit 1 ...... Got FAULT condition
	Bit 2 ...... Got timeout
	Bit 3 ...... Reserved
	Bit 4 ...... Reserved
	Bit 5 ...... Reserved
	Bit 6 ...... Reserved
	Bit 7 ...... Reserved

The PWM signal is automatically turned off when the flags
register for a channel has a nonzero value. The motor controller
is automatically reset in response to an OTW or FAULT condition.
