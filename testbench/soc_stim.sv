module soc_stim();
     
timeunit 1ns;
timeprecision 100ps;

  logic HRESETn, HCLK;
  
  wire RS, RnW, E;
  wire [7:0] DB;
  
  wire SCL, SDA_out;
  logic SDA_in;
  
  wire LOCKUP;

  soc dut(.HCLK, .HRESETn, 
          .RS, .RnW, .E, .DB, 
          .SCL, .SDA_out, .SDA_in,
	   .LOCKUP);

  always
    begin
                HCLK = 0;
      #7.629us  HCLK = 1;
      #15.528us HCLK = 0;
      #7.629us  HCLK = 0;
    end
    

  initial
    begin
            SDA_in = 0;
            HRESETn = 0;
      #10ns HRESETn = 1;
   	
      #5s $stop;
          $finish;
    end
       
endmodule
