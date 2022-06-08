//`define DCMCTRL_DUMMY
module dcmctrl #(
	parameter integer N_CHANNELS = 6,
	parameter integer TIMEOUT_EXP2 = 25, //around 1.4 sec timeout @24MHz, Formula=(2^TIMEOUT_EXP2)/24000000
	parameter integer RESET_EXP = 18 //around 10ms
) (
	input clk,
	input reset,
	input enable,
	output irq,

	input spi_ss,
	input spi_clk,
	input spi_mosi,
	output reg spi_miso,

	output reg [N_CHANNELS-1:0] motor_left,
	output reg [N_CHANNELS-1:0] motor_right,
	output reg [N_CHANNELS-1:0] motor_reset,
	input [N_CHANNELS-1:0] motor_pulse,
	input [N_CHANNELS-1:0] motor_fault,
	input [N_CHANNELS-1:0] motor_otw
);
	// ---- SPI Interface ----

	reg [7:0] spi_shiftreg;
	reg [2:0] spi_bitcnt;
	reg spi_first_byte;

	reg last_spi_clk;

	reg spi_write;
	reg spi_xstrobe;

	reg spi_rstrobe;
	reg spi_wstrobe;
	reg [6:0] spi_raddr;
	reg [6:0] spi_waddr;
	reg [7:0] spi_rdata;
	reg [7:0] spi_wdata;

	reg spi_ss_q;
	reg spi_clk_q;
	reg spi_mosi_q;

	always @(posedge clk) begin
		spi_ss_q <= spi_ss;
		spi_clk_q <= spi_clk;
		spi_mosi_q <= spi_mosi;
	end
	always @(posedge clk) begin
		spi_rstrobe <= 0;
		spi_wstrobe <= spi_rstrobe && spi_write && !spi_first_byte;
		spi_xstrobe <= spi_rstrobe;
		spi_wdata = spi_shiftreg;
		last_spi_clk <= spi_clk_q;

		if (reset || spi_ss_q) begin
			/* reset everything */
			spi_first_byte <= 0;
			spi_write <= 0;
			spi_miso <= 0;

			/* new transaction */
			spi_shiftreg <= 0;
			spi_bitcnt <= 0;
			spi_first_byte <= 1;
		end else
		if (!last_spi_clk && spi_clk_q) begin
			/* next bit in */
			spi_shiftreg <= {spi_shiftreg, spi_mosi_q};
			spi_bitcnt <= spi_bitcnt + 1;
			if (spi_bitcnt == 7) begin
				if (spi_first_byte)
					{spi_write, spi_raddr} <= {spi_shiftreg, spi_mosi_q};
				else
					spi_raddr <= spi_raddr + 1;
				spi_waddr <= spi_raddr;
				spi_rstrobe <= 1;
			end
		end else
		if (last_spi_clk && !spi_clk_q) begin
			/* next bit out */
			spi_miso <= spi_shiftreg[7];
		end else
		if (spi_xstrobe) begin
			spi_shiftreg <= spi_rdata;
			spi_first_byte <= 0;
		end
	end

	// ---- Register File ----

	reg [7:0] registers [0:128];

	(* keep *) reg reg_wstrobe;
	(* keep *) reg reg_rstrobe;
	(* keep *) reg [6:0] reg_addr;
	(* keep *) reg [7:0] reg_wdata;

	wire reg_flowctrl = spi_wstrobe || spi_rstrobe;
	reg reg_flowctrl_q;

	(* keep *) wire [7:0] reg_rdata = reg_flowctrl_q ? reg_rdata_q : spi_rdata;
	(* keep *) reg  [7:0] reg_rdata_q;

	always @(posedge clk) begin
		if (spi_wstrobe || reg_wstrobe) begin
			registers[spi_wstrobe ? spi_waddr : reg_addr] <= spi_wstrobe ? spi_wdata : reg_wdata;
		end

		spi_rdata <= registers[spi_rstrobe ? spi_raddr : reg_addr];

		reg_flowctrl_q <= reg_flowctrl;
		reg_rdata_q <= reg_rdata;
	end

`ifdef DCMCTRL_DUMMY
	// with this define set the core is a simple SPI memory and
	// the motor ctrl outputs are constant low (for testing)
	always @(posedge clk) begin
		reg_wstrobe <= 0;
		reg_rstrobe <= 0;
		reg_addr <= 0;
		reg_rdata <= 0;
		reg_wdata <= 0;
		motor_left <= 0;
		motor_right <= 0;
		motor_reset <= 0;
	end
`else
	// ---- Motor Controller ----

	(* keep *) reg [9:0] mc_state;
	(* keep *) reg [3:0] mc_channel;

	(* keep *) reg [23:0] mc_current_position;
	(* keep *) reg [23:0] mc_target_position;
	(* keep *) reg [7:0] mc_flags [0:N_CHANNELS-1];

	(* keep *) reg [7:0] mc_chan_speed [0:N_CHANNELS-1];
	(* keep *) reg [N_CHANNELS-1:0] mc_chan_turn_left;
	(* keep *) reg [N_CHANNELS-1:0] mc_chan_turn_right;

	(* keep *) reg [N_CHANNELS-1:0] mc_chan_pulse;
	(* keep *) reg [N_CHANNELS-1:0] mc_chan_last_pulse;

	(* keep *) reg mc_write_flags;
	(* keep *) reg mc_write_position;

	(* keep *) reg [N_CHANNELS-1:0] mc_chan_live;
	(* keep *) reg [TIMEOUT_EXP2-1:0] mc_timeout;
	//(* keep *) reg [RESET_EXP-1:0] reset_timeout;

	// "move left" := mc_position_delta < 0
	// "move right" := mc_position_delta > 0
	wire [23:0] mc_position_delta = mc_target_position - mc_current_position;

	wire mc_timeout_check = &mc_timeout[TIMEOUT_EXP2-1 -: 3];
	//wire reset_timeout_check = &reset_timeout[RESET_EXP-1 -: 3];

	always @(posedge clk) begin
		mc_chan_pulse <= mc_chan_pulse | (motor_pulse & ~mc_chan_last_pulse);
		mc_chan_last_pulse <= motor_pulse;

		mc_timeout <= mc_chan_speed[0] == 0 ? mc_timeout : (mc_timeout + 1);
		mc_chan_live <= mc_timeout ? (mc_chan_live | mc_chan_pulse) : 0;

		if (reset) begin
			mc_state <= 0;
			mc_channel <= 0;
			mc_chan_pulse <= 0;
			reg_wstrobe <= 0;
			reg_rstrobe <= 0;
			mc_chan_live <= 0;
			mc_timeout <= 0;
			motor_reset <= 1;
		end else
		if (!reg_flowctrl) begin
			reg_wstrobe <= 0;
			reg_rstrobe <= 0;

			case (mc_state)
				// --- Read state from register file ---
				0: begin
					mc_write_flags <= 0;
					mc_write_position <= 0;
					reg_addr <= mc_channel * 4;
					reg_rstrobe <= 1;
					mc_state <= 1;
				end
				1: begin
					reg_addr <= reg_addr + 1;
					reg_rstrobe <= 1;
					mc_state <= 2;
				end
				2: begin
					if (mc_flags[mc_channel] != 0 && reg_rdata == 0) begin
						mc_chan_live[mc_channel] <= 0;
						mc_timeout <= 0;
						motor_reset[mc_channel] <= 0; //TODO - pulse
					end
					mc_flags[mc_channel] <= reg_rdata;
					reg_addr <= reg_addr + 1;
					reg_rstrobe <= 1;
					mc_state <= 3;
				end
				3: begin
					mc_current_position[23:16] <= reg_rdata;
					reg_addr <= reg_addr + 1;
					reg_rstrobe <= 1;
					mc_state <= 4;
				end
				4: begin
					mc_current_position[15:8] <= reg_rdata;
					reg_addr <= reg_addr + 61;
					reg_rstrobe <= 1;
					mc_state <= 5;
				end
				5: begin
					mc_current_position[7:0] <= reg_rdata;
					reg_addr <= reg_addr + 1;
					reg_rstrobe <= 1;
					mc_state <= 6;
				end
				6: begin
					//`ifndef SYNTHESIS
					// if (mc_channel == 0)
					//	$display("curr pos = %d", mc_current_position);
					//`endif
					mc_chan_speed[mc_channel] <= reg_rdata;
					reg_addr <= reg_addr + 1;
					reg_rstrobe <= 1;
					mc_state <= 7;
				end
				7: begin
					mc_target_position[23:16] <= reg_rdata;
					reg_addr <= reg_addr + 1;
					reg_rstrobe <= 1;
					mc_state <= 8;
				end
				8: begin
					mc_target_position[15:8] <= reg_rdata;
					mc_state <= 9;
				end
				9: begin
					mc_target_position[7:0] <= reg_rdata;
					mc_state <= 100;
				end

				// --- Update state ---
				100: begin
					if (mc_position_delta == 0) begin
						mc_chan_live[mc_channel] <= 1;
					end
					mc_chan_turn_left[mc_channel] <= !mc_flags[mc_channel] && mc_position_delta[23];
					mc_chan_turn_right[mc_channel] <= !mc_flags[mc_channel] && !mc_position_delta[23] && mc_position_delta[22:0];
					mc_state <= 101;
				end
				101: begin
					motor_reset[mc_channel] <= 0;
					if (mc_timeout_check && !mc_chan_live[mc_channel] && !mc_flags[mc_channel][2:0]) begin
						mc_flags[mc_channel][2] <= 1;
						mc_write_flags <= 1;
						mc_timeout <= 0;
					end
					if (motor_fault[mc_channel] && !mc_flags[mc_channel][1]) begin
						motor_reset[mc_channel] <= 1;
						mc_flags[mc_channel][1] <= 1;
						mc_write_flags <= 1;
					end
					//Don't stop motor, the OTW does mean that the temperature is critical, but
					//if the temp exceeds a limit, a FAULT will be raised
					//if (motor_otw[mc_channel] && !mc_flags[mc_channel][0]) begin
					//	motor_reset[mc_channel] <= 1;
					//	mc_flags[mc_channel][0] <= 1;
					//	mc_write_flags <= 1;
					//end
					mc_state <= 1000;
				end

				// --- Write state back to register file ---
				1000: begin
					mc_channel <= mc_channel == N_CHANNELS-1 ? 0 : mc_channel+1;
					mc_chan_last_pulse[mc_channel] <= motor_pulse[mc_channel];

					if (mc_chan_pulse[mc_channel]) begin
						if (mc_chan_turn_left[mc_channel])
							mc_current_position <= mc_current_position - 1;
						if (mc_chan_turn_right[mc_channel])
							mc_current_position <= mc_current_position + 1;
						mc_chan_pulse[mc_channel] <= 0;
						mc_write_position <= 1;
					end

					reg_addr <= mc_channel * 4;
					reg_wstrobe <= mc_write_flags;
					reg_wdata <= mc_flags[mc_channel];
					mc_state <= 1001;
				end
				1001: begin
					reg_addr <= reg_addr + 1;
					reg_wstrobe <= mc_write_position;
					reg_wdata <= mc_current_position[23:16];
					mc_state <= 1002;
				end
				1002: begin
					reg_addr <= reg_addr + 1;
					reg_wstrobe <= mc_write_position;
					reg_wdata <= mc_current_position[15:8];
					mc_state <= 1003;
				end
				1003: begin
					reg_addr <= reg_addr + 1;
					reg_wstrobe <= mc_write_position;
					reg_wdata <= mc_current_position[7:0];
					mc_state <= 0;
				end
			endcase
		end
	end

	// ---- PWM Controller ----

	(* keep *) reg [7:0] pwm_stage1_count;
	(* keep *) reg [3:0] pwm_stage1_channel;

	(* keep *) reg [7:0] pwm_stage2_count;
	(* keep *) reg [3:0] pwm_stage2_channel;
	(* keep *) reg [7:0] pwm_stage2_speed;

	(* keep *) reg [0:N_CHANNELS-1] motor_left_prev ;
	(* keep *) reg [0:N_CHANNELS-1] motor_right_prev ;

	always @(posedge clk) begin
		if (reset) begin
			pwm_stage1_count <= 0;
			pwm_stage1_channel <= 0;
			pwm_left_prev <= 0;
			pwm_right_prev <= 0;
		end else begin
			pwm_stage1_count <= pwm_stage1_count + 1;
			if (pwm_stage1_channel == N_CHANNELS-1) begin
				pwm_stage1_channel <= 0;
			end else begin
				pwm_stage1_channel <= pwm_stage1_channel + 1;
			end

			pwm_stage2_count <= pwm_stage1_count;
			pwm_stage2_channel <= pwm_stage1_channel;
			pwm_stage2_speed <= mc_chan_speed[pwm_stage1_channel];

			motor_left[pwm_stage2_channel] <= mc_chan_turn_left[pwm_stage2_channel] && (pwm_stage2_count < pwm_stage2_speed);
			motor_right[pwm_stage2_channel] <= mc_chan_turn_right[pwm_stage2_channel] && (pwm_stage2_count < pwm_stage2_speed);

	     	if (mc_chan_turn_left[pwm_stage2_channel] && motor_left[pwm_stage2_channel] && !motor_left_prev[pwm_stage2_channel]) begin
	     		motor_right[pwm_stage2_channel] <= 1;
	     	end

	     	if (mc_chan_turn_right[pwm_stage2_channel] && motor_right[pwm_stage2_channel] && !motor_right_prev[pwm_stage2_channel]) begin
	     		motor_left[pwm_stage2_channel] <= 1;
	     	end

	     	motor_left_prev[pwm_stage2_channel] <= motor_left[pwm_stage2_channel];
	     	motor_right_prev[pwm_stage2_channel] <= motor_right[pwm_stage2_channel];
		end
	end
`endif
endmodule
