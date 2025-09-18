module ahb_simple_i2c_stim();

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
  logic nMode, nTrip;

  ahb_buttons dut(.HCLK, .HRESETn, 
              .HADDR, .HWDATA, .HSIZE, .HTRANS, .HWRITE, .HREADY, .HSEL,
	      .HRDATA, .HREADYOUT,
	      .nMode, .nTrip);

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
      
      nMode = 1;
      nTrip = 1;
      
      #30us 
      
      HRESETn = 1;
      
      #25ms
      nMode = 0;
      #30ms
      nMode = 1;
      #30ms
      
      // testing to see if data will be replaced (data should not change while data_valid)
      nMode = 0;
      #500us
      nMode = 1;
      #500us
      nTrip = 0;
      #500us
      nTrip = 1;
      
      //read datavalid
      #30us
      HADDR = 4;
      HREADY = 1;
      HWDATA = 0;
      HSIZE = 0;
      HSEL = 1;
      HWRITE = 0;
      HTRANS = 2;
      
      #30us
      HADDR = 0;
      HREADY = 1;
      HWDATA = 0;
      HSIZE = 0;
      HSEL = 1;
      HWRITE = 0;
      HTRANS = 2;
      
      #30us
      HADDR = 0;
      HREADY = 1;
      HWDATA = 0;
      HSIZE = 0;
      HSEL = 1;
      HWRITE = 0;
      HTRANS = 0;
      
      // both reg
      #500us
      nMode = 0;
      #300us
      nTrip = 0;
      #30ms 
      nMode = 1;
      nTrip = 1;
      #30ms
      
      //read datavalid
      #30us
      HADDR = 4;
      HREADY = 1;
      HWDATA = 0;
      HSIZE = 0;
      HSEL = 1;
      HWRITE = 0;
      HTRANS = 2;
      
      #30us
      HADDR = 0;
      HREADY = 1;
      HWDATA = 0;
      HSIZE = 0;
      HSEL = 1;
      HWRITE = 0;
      HTRANS = 2;
      
      #30us
      HADDR = 0;
      HREADY = 1;
      HWDATA = 0;
      HSIZE = 0;
      HSEL = 1;
      HWRITE = 0;
      HTRANS = 0;
      
      // both reg, same timing
      #500us
      nMode = 0;
      nTrip = 0;
      #30ms 
      nMode = 1;
      nTrip = 1;
      
      #500us
      $stop;
      $finish;
    end

endmodule
