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
  wire SCL, SDA_out;
  logic SDA_in;

  ahb_simple_i2c dut(.HCLK, .HRESETn, 
              .HADDR, .HWDATA, .HSIZE, .HTRANS, .HWRITE, .HREADY, .HSEL,
	      .HRDATA, .HREADYOUT,
	      .SCL, .SDA_out, .SDA_in);

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
      SDA_in = 0;
      
      #30us 
      
      HRESETn = 1;
      
      // Write 0b0001000 to device address
      HREADY = 1;
      HADDR = 32'h0000_0000;
      HSEL = 1;
      HWRITE = 1;
      HWDATA = 0;
      HTRANS = 2;
      
      #30us
      
      // Enable, nbytes = 3
      HREADY = 1;
      HADDR = 32'h0000_0014;
      HSEL = 1;
      HWRITE = 1;
      HWDATA = 32'h0000_0008;
      HTRANS = 2;
      
      #30us
      
      HREADY = 1;
      HADDR = 32'h0000_0000;
      HSEL = 1;
      HWRITE = 1;
      HWDATA = 32'h0000_000F;
      HTRANS = 0;
      #30us
      
      #1200us 
      
      // SDA_in input pattern
      SDA_in = 1;
      #120us
      SDA_in = 0;
      #120us
      SDA_in = 1;
      #500us
      SDA_in = 0;
      #505us
      SDA_in = 1;
      #175us
      SDA_in = 0;
      #220us
      SDA_in = 1;
      #100us
      SDA_in = 0;
      
      #3000us 
      
      // Read from readData 
      HREADY = 1;
      HADDR = 32'h0000_0008;
      HSEL = 1;
      HWRITE = 0;
      HWDATA = 0;
      HTRANS = 2;
      
      #30us
      
      HREADY = 1;
      HADDR = 32'h0000_0000;
      HSEL = 1;
      HWRITE = 0;
      HWDATA = 0;
      HTRANS = 0;
      
      #100us
      
      // perform another read (just to check datavalid)
      // Enable, nbytes = 3
      HREADY = 1;
      HADDR = 32'h0000_0014;
      HSEL = 1;
      HWRITE = 1;
      HWDATA = 32'h0000_0008;
      HTRANS = 2;
      
      #30us
      
      HREADY = 1;
      HADDR = 32'h0000_0000;
      HSEL = 1;
      HWRITE = 1;
      HWDATA = 32'h0000_000F;
      HTRANS = 0;
      #30us
      
      #3000us 
      $stop;
      $finish;
    end
  
  /*
  initial
    begin
        HRESETn = 0;
        SDA_in = 0;
        SDA_start = 0;
	I2C_write_op = 0;
	nbytes = 0;
	device_addr = 7'b1110111;
	reg_addr = 8'b10010110;
	write_data = 8'b01010101;
	
      #30us 

        // perform a read operation
        HRESETn = 1;
        SDA_start = 1;
	I2C_write_op = 0;
	nbytes = 2;
	device_addr = 7'b1110111;
	reg_addr = 8'b10010110;
	
      #1200us 
      
        SDA_start = 0;
      
      #5000us $stop;
              $finish;
    end*/

endmodule
