// Example code for an M0 AHBLite System-on-Chip
//  Iain McNally
//  ECS, University of Soutampton
//
//
// This version supports 4 AHBLite slaves:
//
//  ahb_rom           ROM
//  ahb_ram           RAM
//  ahb_switches      A handshaking interface to support input from switches and buttons
//  ahb_out           An output interface supporting simultaneous update of data and valid signals
//

module soc(

  input HCLK, HRESETn,
  
  // Button signals
  input nMode,
  input nTrip,
  
  // LCD signals
  output RS, // Register Select
  output RnW, // Read/Write
  output E, // Operation Enable
  inout [7:0] DB, // 8-bit Data Bus
  
  // I2C signals
  output SCL,
  output SDA_out,
  input SDA_in

);
 
timeunit 1ns;
timeprecision 100ps;

  // Global & Master AHB Signals
  wire [31:0] HADDR, HWDATA, HRDATA;
  wire [1:0] HTRANS;
  wire [2:0] HSIZE, HBURST;
  wire [3:0] HPROT;
  wire HWRITE, HMASTLOCK, HRESP, HREADY;

  // Per-Slave AHB Signals
  wire HSEL_ROM, HSEL_RAM, HSEL_BUTTON, HSEL_LCD, HSEL_I2C;
  wire [31:0] HRDATA_ROM, HRDATA_RAM, HRDATA_BUTTON, HRDATA_LCD, HRDATA_I2C;
  wire HREADYOUT_ROM, HREADYOUT_RAM, HREADYOUT_BUTTON, HREADYOUT_LCD, HREADYOUT_I2C;

  // Non-AHB M0 Signals
  wire TXEV, RXEV, SLEEPING, SYSRESETREQ, NMI;
  wire [15:0] IRQ;
  wire LOCKUP;
  
  // Set this to zero because simple slaves do not generate errors
  assign HRESP = '0;

  // Set all interrupt and event inputs to zero (unused in this design) 
  assign NMI = '0;
  assign IRQ = {16'b0000_0000_0000_0000};
  assign RXEV = '0;

  // Coretex M0 DesignStart is AHB Master
  CORTEXM0DS m0_1 (

    // AHB Signals
    .HCLK, .HRESETn,
    .HADDR, .HBURST, .HMASTLOCK, .HPROT, .HSIZE, .HTRANS, .HWDATA, .HWRITE,
    .HRDATA, .HREADY, .HRESP,                                   

    // Non-AHB Signals
    .NMI, .IRQ, .TXEV, .RXEV, .LOCKUP, .SYSRESETREQ, .SLEEPING

  );


  // AHB interconnect including address decoder, register and multiplexer
  ahb_interconnect interconnect_1 (

    .HCLK, .HRESETn, .HADDR, .HRDATA, .HREADY,

    .HSEL_SIGNALS({HSEL_I2C,HSEL_LCD,HSEL_BUTTON,HSEL_RAM,HSEL_ROM}),
    .HRDATA_SIGNALS({HRDATA_I2C,HRDATA_LCD,HRDATA_BUTTON,HRDATA_RAM,HRDATA_ROM}),
    .HREADYOUT_SIGNALS({HREADYOUT_I2C,HREADYOUT_LCD,HREADYOUT_BUTTON,HREADYOUT_RAM,HREADYOUT_ROM})

  );


  // AHBLite Slaves
        
  ahb_rom rom_1 (

    .HCLK, .HRESETn, .HADDR, .HWDATA, .HSIZE, .HTRANS, .HWRITE, .HREADY,
    .HSEL(HSEL_ROM),
    .HRDATA(HRDATA_ROM), .HREADYOUT(HREADYOUT_ROM)

  );

  ahb_ram ram_1 (

    .HCLK, .HRESETn, .HADDR, .HWDATA, .HSIZE, .HTRANS, .HWRITE, .HREADY,
    .HSEL(HSEL_RAM),
    .HRDATA(HRDATA_RAM), .HREADYOUT(HREADYOUT_RAM)

  );
  
  ahb_buttons buttons_1 (

    .HCLK, .HRESETn, .HADDR, .HWDATA, .HSIZE, .HTRANS, .HWRITE, .HREADY,
    .HSEL(HSEL_BUTTON),
    .HRDATA(HRDATA_BUTTON), .HREADYOUT(HREADYOUT_BUTTON),

    .nMode(nMode), .nTrip(nTrip)
  
  );

  ahb_lcd lcd_1 (

    .HCLK, .HRESETn, .HADDR, .HWDATA, .HSIZE, .HTRANS, .HWRITE, .HREADY,
    .HSEL(HSEL_LCD),
    .HRDATA(HRDATA_LCD), .HREADYOUT(HREADYOUT_LCD),

    .RS(RS), .RnW(RnW), .E(E), .DB(DB)

  );
  
  ahb_bmp_i2c sensor_1 (

    .HCLK, .HRESETn, .HADDR, .HWDATA, .HSIZE, .HTRANS, .HWRITE, .HREADY,
    .HSEL(HSEL_I2C),
    .HRDATA(HRDATA_I2C), .HREADYOUT(HREADYOUT_I2C),

    .SDA_in(SDA_in), .SDA_out(SDA_out), .SCL(SCL)

  );

endmodule
