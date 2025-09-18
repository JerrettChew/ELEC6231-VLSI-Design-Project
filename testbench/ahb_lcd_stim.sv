module ahb_lcd_stim();

timeunit 1ns;
timeprecision 100ps;

  // input of module
  logic HRESETn, HCLK;
  logic [31:0] HADDR, HWDATA;
  logic [2:0] HSIZE;
  logic [1:0] HTRANS;
  logic HWRITE, HREADY, HSEL;
  
  // output of module to AHB
  wire [31:0] HRDATA;
  wire HREADYOUT;
  
  // output of module to peripherals
  wire RS, RnW, E;
  wire [7:0] DB;

  ahb_lcd dut(.HCLK, .HRESETn, 
              .HADDR, .HWDATA, .HSIZE, .HTRANS, .HWRITE, .HREADY, .HSEL,
	      .HRDATA, .HREADYOUT,
	      .RS, .RnW, .E, .DB);

  always  /* simulating 32.768 kHz, ~30us */
    begin
           HCLK = 0;
      #7.5us HCLK = 1;
      #15us HCLK = 0;
      #7.5us HCLK = 0;
    end
    
  initial
    begin
            HRESETn = 0;
	    HADDR = 0;
	    HWDATA = 0;
	    HSIZE = 0;
	    HTRANS = 0;
	    HSEL = 0;
	    HREADY = 0;
	    HWRITE = 0;
      #30us HRESETn = 1;
      
      HREADY = 1;
      HADDR = 32'h0000_0004;
      HSEL = 1;
      HWRITE = 1;
      HWDATA = 0;
      HTRANS = 2;
      #30us
      
      HREADY = 1;
      HADDR = 32'h0000_0000;
      HSEL = 1;
      HWRITE = 1;
      HWDATA = 32'h022C_33AA;
      HTRANS = 2;
      #30us
      
      HREADY = 1;
      HADDR = 32'h0000_0004;
      HSEL = 1;
      HWRITE = 0;
      HWDATA = 32'h011F_2C35;
      HTRANS = 2;
      #30us
      
      HREADY = 1;
      HADDR = 32'h0000_0008;
      HSEL = 1;
      HWRITE = 1;
      HWDATA = 32'h0000_0000;
      HTRANS = 0;
      #30us

      HREADY = 1;
      HADDR = 32'h0000_0008;
      HSEL = 1;
      HWRITE = 1;
      HWDATA = 32'hFFFF_FFFF; //RS, RW, DB[7:0]
      HTRANS = 1;
      #30us
      
      HREADY = 1;
      HADDR = 32'h0000_0000C;
      HSEL = 1;
      HWRITE = 1;
      HWDATA = 32'h0000_0230; //RS, RW, DB[7:0]
      HTRANS = 1;
      #30us
      
      HREADY = 1;
      HADDR = 32'h0000_00000;
      HSEL = 1;
      HWRITE = 1;
      HWDATA = 32'h0000_0002; //Enable, DI
      HTRANS = 0;
      #30us
      
      // Do nothing
      HREADY = 1;
      HADDR = 32'h0000_00000;
      HSEL = 1;
      HWRITE = 1;
      HWDATA = 32'h0000_0000;
      HTRANS = 0;
      #90us
      
      HREADY = 1;
      HADDR = 32'h0000_0000C;
      HSEL = 1;
      HWRITE = 1;
      HWDATA = 32'h0000_0000;
      HTRANS = 1;
      #30us
      
      HREADY = 1;
      HADDR = 32'h0000_00000;
      HSEL = 1;
      HWRITE = 1;
      HWDATA = 32'h0000_0003; //Enable, DI
      HTRANS = 0;
      #30us
      
      #1000us $stop;
            $finish;
    end

endmodule
