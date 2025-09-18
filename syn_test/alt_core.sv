///////////////////////////////////////////////////////////////////////
//
// alt_core module
//
//    this is the behavioural model of the sports altimeter without pads
//
///////////////////////////////////////////////////////////////////////

`include "options.sv"

module alt_core(

  output RS,
  output RnW,
  output E,

  input [7:0] DB_In,
  output [7:0] DB_Out,
  output logic DB_nEnable,

  input nMode, nTrip,

  output SCL,
  input SDA_In,
  output SDA_Out,

  input Clock, nReset,
  
  input enable
  

  );

timeunit 1ns;
timeprecision 100ps;

  wire Clock_int;
  
  clock_divider clock_divider1(.clk_in(Clock), .rst_n(nReset), .enable(enable), .clk_out(Clock_int));

  soc soc1(.HCLK(Clock_int), .HRESETn(nReset),
           .nMode(nMode), .nTrip(nTrip),
           .RS(RS), .RnW(RnW), .E(E), .DB(DB_Out),
	   .SCL(SCL), .SDA_out(SDA_Out), .SDA_in(SDA_In));

assign DB_nEnable = '0;

endmodule
