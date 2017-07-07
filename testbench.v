module testbench;
	reg clk = 1;
	always #5 clk = ~clk;

	reg reset;

	integer cycle;
	always @(posedge clk) cycle <= reset ? 0 : cycle + 1;

	reg spi_ss;
	reg spi_clk;
	reg spi_mosi;
	wire spi_miso;

	wire [7:0] motor_left;
	wire [7:0] motor_right;
	wire [7:0] motor_reset;

	reg  [7:0] motor_pulse;
	reg  [7:0] motor_fault;
	reg  [7:0] motor_otw;

	wire motor_left_0 = motor_left[0];
	wire motor_right_0 = motor_right[0];
	wire motor_pulse_0 = motor_pulse[0];

	dcmctrl uut (
		.clk(clk),
		.reset(reset),
		.spi_ss(spi_ss),
		.spi_clk(spi_clk),
		.spi_mosi(spi_mosi),
		.spi_miso(spi_miso),
		.motor_left(motor_left),
		.motor_right(motor_right),
		.motor_reset(motor_reset),
		.motor_pulse(motor_pulse),
		.motor_fault(motor_fault),
		.motor_otw(motor_otw)
	);

	reg [7:0] spidata;

	task spi_xfer_begin;
		begin
			spi_ss <= 0;
			#50;
		end
	endtask

	task spi_xfer_byte(input [7:0] d);
		integer i;
		begin
			spidata <= d;
			#50;
			for (i = 0; i < 8; i = i+1) begin
				spi_mosi <= spidata[7];
				spi_clk <= 0;
				#50;
				spi_clk <= 1;
				spidata <= {spidata, spi_miso};
				#50;
			end
		end
	endtask

	task spi_xfer_end;
		begin
			spi_ss <= 1;
			#100;
		end
	endtask

	integer i;

	initial begin
		$dumpfile("testbench.vcd");
		$dumpvars(0, testbench);

		spi_ss <= 1;
		spi_clk <= 1;
		spi_mosi <= 0;
		reset <= 1;

		motor_pulse <= 0;
		motor_fault <= 0;
		motor_otw <= 0;

		repeat (100) @(posedge clk);
		reset <= 0;

		// Zero initialize register file and reset

		spi_xfer_begin;
		spi_xfer_byte(128);
		for (i = 0; i < 128; i = i+1)
			spi_xfer_byte(0);
		spi_xfer_end;

		repeat (10) @(posedge clk);
		reset <= 1;

		repeat (10) @(posedge clk);
		reset <= 0;

		// Set target speed and position for channel 0

		spi_xfer_begin;
		spi_xfer_byte(128 | 64);
		spi_xfer_byte(100); // target speed
		spi_xfer_byte(0); // target position [23:16]
		spi_xfer_byte(0); // target position [15:8]
		spi_xfer_byte(20); // target position [7:0]
		spi_xfer_end;

		#500000;
		$finish;
	end

	initial begin
		motor_pulse <= 0;
		#500;

		forever begin
			motor_pulse <= motor_left | motor_right;
			#123;
			motor_pulse <= 0;
			#3777;
		end
	end
endmodule
