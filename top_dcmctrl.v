module top_dcmctrl  (
	output LED1_1,
	output LED1_2,
	input  clk,
	output INT,
	input SPI_CS,
	input SPI_CLK,
	input SPI_MOSI,
	output SPI_MISO,

	output SLOT1_IO0, //PWM_A    (1)
	output SLOT1_IO1, //PWM_B    (1)
	output SLOT1_IO2, //PWM_C    (1)
	output SLOT1_IO3, //PWM_D    (1)
	output SLOT1_IO4, //RESET_AB (1)
	output SLOT1_IO5, //RESET_CD (1)
	input  SLOT1_IO6, //FAULT    (1)
	input  SLOT1_IO7, //OTW      (1)
	output SLOT1_IO8, //MODE     (1)
	output SLOT1_IO9, //TODO: TEMP FOR TESTING

	output SLOT2_IO0, //PWM_A    (2)
	output SLOT2_IO1, //PWM_B    (2)
	output SLOT2_IO2, //PWM_C    (2)
	output SLOT2_IO3, //PWM_D    (2)
	output SLOT2_IO4, //RESET_AB (2)
	output SLOT2_IO5, //RESET_CD (2)
	input  SLOT2_IO6, //FAULT    (2)
	input  SLOT2_IO7, //OTW      (2)
	output SLOT2_IO8, //MODE     (2)
	output SLOT2_IO9,

	output SLOT4_IO0, //PWM_A    (3)
	output SLOT4_IO1, //PWM_B    (3)
	output SLOT4_IO2, //PWM_C    (3)
	output SLOT4_IO3, //PWM_D    (3)
	output SLOT4_IO4, //RESET_AB (3)
	output SLOT4_IO5, //RESET_CD (3)
	input  SLOT4_IO6, //FAULT    (3)
	input  SLOT4_IO7, //OTW      (3)
	output SLOT4_IO8, //MODE     (3)
	output SLOT4_IO9,

	input  SLOT3_IO0, //HALL 1
	input  SLOT3_IO1, //HALL 2
	input  SLOT3_IO2, //HALL 3
	input  SLOT3_IO3, //HALL 4
	input  SLOT3_IO4, //HALL 5
	input  SLOT3_IO5,  //HALL 6
	//input  SLOT3_IO6  //RESET
	//output SLOT3_IO7,
	//output SLOT3_IO8,
	//output SLOT3_IO9
);

	localparam MODE = 0;

	wire [7:0] motor_left;
	wire [7:0] motor_right;
	wire [7:0] motor_reset;

	wire  [7:0] motor_pulse;
	wire  [7:0] motor_fault = 0;
	wire  [7:0] motor_otw = 0;

	localparam RESET = 1;
	assign SLOT1_IO4 = RESET;
	assign SLOT1_IO5 = RESET;

	assign SLOT2_IO4 = RESET;
	assign SLOT2_IO5 = RESET;

	assign SLOT4_IO4 = RESET;
	assign SLOT4_IO5 = RESET;

	//SLOT 1
	assign motor_left[1]  = SLOT1_IO0;
	assign motor_right[1] = SLOT1_IO1;
	assign motor_left[0]  = SLOT1_IO2;
	assign motor_right[0] = SLOT1_IO3;
	//assign motor_reset[1] = !SLOT1_IO4;
	//assign motor_reset[0] = !SLOT1_IO5;
	assign motor_fault[1] = !SLOT1_IO6;
	assign motor_fault[0] = !SLOT1_IO6;
	assign motor_otw[1]   = !SLOT1_IO7;
	assign motor_otw[0]   = !SLOT1_IO7;
	assign SLOT1_IO8      = MODE;

	//SLOT 2
	assign motor_left[3]  =  SLOT2_IO0;
	assign motor_right[3] =  SLOT2_IO1;
	assign motor_left[2]  =  SLOT2_IO2;
	assign motor_right[2] =  SLOT2_IO3;
	//assign motor_reset[3] = !SLOT2_IO4;
	//assign motor_reset[2] = !SLOT2_IO5;
	assign motor_fault[3] = !SLOT2_IO6;
	assign motor_fault[2] = !SLOT2_IO6;
	assign motor_otw[3]   = !SLOT2_IO7;
	assign motor_otw[2]   = !SLOT2_IO7;
	assign SLOT2_IO8      = MODE;

	//SLOT 4
	assign motor_left[5]  =  SLOT4_IO0;
	assign motor_right[5] =  SLOT4_IO1;
	assign motor_left[4]  =  SLOT4_IO2;
	assign motor_right[4] =  SLOT4_IO3;
	//assign motor_reset[5] = !SLOT4_IO4;
	//assign motor_reset[4] = !SLOT4_IO5;
	assign motor_fault[5] = !SLOT4_IO6;
	assign motor_fault[4] = !SLOT4_IO6;
	assign motor_otw[5]   = !SLOT4_IO7;
	assign motor_otw[4]   = !SLOT4_IO7;
	assign SLOT3_IO8      = MODE;

	//SLOT 3
	assign motor_pulse[0] = SLOT3_IO0;
	assign motor_pulse[1] = SLOT3_IO1;
	assign motor_pulse[2] = SLOT3_IO2;
	assign motor_pulse[3] = SLOT3_IO3;
	assign motor_pulse[4] = SLOT3_IO4;
	assign motor_pulse[5] = SLOT3_IO5;

    //LED
	localparam LED_STATUS = 1;
	wire LED = LED1_1;
	assign LED = LED1_2;
	assign LED = !LED_STATUS;


// Powerup Reset Logic
// generate a reset pulse on initial powerup
reg [16:0]  pup_count = 0;
reg         pup_reset = 1;

always @(posedge clk)
   begin
    pup_count <= pup_count + 1;
    if (pup_count == 24000) pup_reset <= 0;
   end

wire reset = pup_reset;

dcmctrl uut (
	.clk(clk),
	//.reset(reset),
	.reset(reset),
	.irq(INT),

	.spi_ss(SPI_CS),
	.spi_clk(SPI_CLK),
	.spi_mosi(SPI_MOSI),
	.spi_miso(SPI_MISO),

	.motor_left(motor_left),
	.motor_right(motor_right),
	.motor_reset(motor_reset),
	.motor_pulse(motor_pulse),
	.motor_fault(motor_fault),
	.motor_otw(motor_otw)
);

endmodule