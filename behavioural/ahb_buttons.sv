// Example code for an AHBLite System-on-Chip
//  Iain McNally
//  ECS, University of Soutampton
//
// This module is an AHB-Lite Slave containing three read-only locations
//
// Number of addressable locations : 3
// Size of each addressable location : 32 bits
// Supported transfer sizes : Word
// Alignment of base address : 16 bytes (4 words)
//
// Address map :
//   Base addess + 0 : 
//     Bit 0: Mode button is pressed 
//     Bit 1: Trip button is pressed
//     Bit 2: Both buttons (Mode and Trip) are pressed at the same time
//   Base addess + 4 : 
//     Bit 0: DataValid, this status bit is cleared when Buttons register is read by master 

// For simplicity, this interface supports only 32-bit transfers.
// The most significant 16 bits of the value read will always be 0
// since there are only 16 switches.


module ahb_buttons(

  // AHB Global Signals
  input HCLK,
  input HRESETn,

  // AHB Signals from Master to Slave
  input [31:0] HADDR, // With this interface only HADDR[3:2] is used (other bits are ignored)
  input [31:0] HWDATA,
  input [2:0] HSIZE,
  input [1:0] HTRANS,
  input HWRITE,
  input HREADY,
  input HSEL,

  // AHB Signals from Slave to Master
  output logic [31:0] HRDATA,
  output HREADYOUT,

  //Non-AHB Signals
  input  nMode,
  input  nTrip

);

timeunit 1ns;
timeprecision 100ps;

  // AHB transfer codes needed in this module
  localparam No_Transfer = 2'b0;

  // Storage for status bits 
  logic       DataValid;

  //control signals are stored in registers
  logic read_enable;
  logic [1:0] word_address;
 
  logic [31:0] Status;

  logic nMode_sync[0:1];
  logic nTrip_sync[0:1];  

  logic nMode_sync_dly;
  logic nTrip_sync_dly;
  logic nMode_sync_negedge;
  logic nTrip_sync_negedge;
  
  // debouncing
  enum logic [1:0] {IDLE, TRIG, WAIT, END} nMode_counter_state, nTrip_counter_state;
  logic [9:0] nMode_counter, nTrip_counter;
  logic nModeTrig;
  logic nModeRelease;
  logic nTripTrig;
  logic nTripRelease;
  
  // trigger and valid transfer logic
  logic nMode_trig;
  logic nMode_nValid;
  logic nTrip_trig;
  logic nTrip_nValid;
  
  logic read_DataValid;
  logic Both_reg;
  logic nTrip_reg;  
  logic nMode_reg;
  
  // cross clock domain sync
  always_ff @(posedge HCLK, negedge HRESETn)
    if ( ! HRESETn )
      begin
        nMode_sync[0] <= 1'b0;
        nMode_sync[1] <= 1'b0;
        nTrip_sync[0] <= 1'b0;
        nTrip_sync[1] <= 1'b0;
      end
    else
      begin
        nMode_sync[0] <= nMode;
        nMode_sync[1] <= nMode_sync[0];
        nTrip_sync[0] <= nTrip;
        nTrip_sync[1] <= nTrip_sync[0];	  
      end

  // edge detection logic
  always_ff @(posedge HCLK, negedge HRESETn)
    if ( ! HRESETn )
      begin
        nMode_sync_dly <= 1'b0;
        nTrip_sync_dly <= 1'b0;
      end
    else
      begin
        nMode_sync_dly <= nMode_sync[1];
        nTrip_sync_dly <= nTrip_sync[1];  
      end
  assign nMode_sync_negedge = nMode_sync_dly & ~nMode_sync[1]; 
  assign nTrip_sync_negedge = nTrip_sync_dly & ~nTrip_sync[1];
  assign nMode_sync_posedge = ~nMode_sync_dly & nMode_sync[1]; 
  assign nTrip_sync_posedge = ~nTrip_sync_dly & nTrip_sync[1];
  
  // debouncing circuit for nMode
  always_ff @(posedge HCLK, negedge HRESETn)
    if( ! HRESETn )
      begin
        nMode_counter_state <= IDLE;
	nMode_counter <= '0;
      end
    else
      begin
        case(nMode_counter_state)
	IDLE:  if((nMode_sync_negedge || nMode_sync_posedge) && ~DataValid)
		 nMode_counter_state <= WAIT;
        WAIT:  if(nMode_counter < 820)
		 nMode_counter <= nMode_counter + 1;
	       else
	         begin
		   nMode_counter <= '0;
		   nMode_counter_state <= END;
		 end
	END:   nMode_counter_state <= IDLE;
	default: nMode_counter_state <= IDLE;
	endcase
      end
  
  always_comb
    begin
      nModeTrig = 0;
      nModeRelease = 0;
      
      case(nMode_counter_state)
      IDLE: if(nMode_sync_negedge && ~DataValid) nModeTrig = 1;
            else if(nMode_sync_posedge && ~DataValid) nModeRelease = 1;
      WAIT: ;
      END:  if(nMode_trig && nMode_sync_dly) nModeRelease = 1;
      default: ;
      endcase
    end
    
  // debouncing circuit for nTrip
  always_ff @(posedge HCLK, negedge HRESETn)
    if( ! HRESETn )
      begin
        nTrip_counter_state <= IDLE;
	nTrip_counter <= '0;
      end
    else
      begin
        case(nTrip_counter_state)
	IDLE:  if((nTrip_sync_negedge || nTrip_sync_posedge) && ~DataValid)
		 nTrip_counter_state <= WAIT;
        WAIT:  if(nTrip_counter < 820)
		 nTrip_counter <= nTrip_counter + 1;
	       else
	         begin
		   nTrip_counter <= '0;
		   nTrip_counter_state <= END;
		 end
	END:   nTrip_counter_state <= IDLE;
	default: nTrip_counter_state <= IDLE;
	endcase
      end
  
  always_comb
    begin
      nTripTrig = 0;
      nTripRelease = 0;
      
      case(nTrip_counter_state)
      IDLE: if(nTrip_sync_negedge && ~DataValid) nTripTrig = 1;
            else if(nTrip_sync_posedge && ~DataValid) nTripRelease = 1;
      WAIT: ;
      END:  if(nTrip_trig && nTrip_sync_dly) nTripRelease = 1;
      default: ;
      endcase
    end
  
  // update register values 
  always_ff @(posedge HCLK, negedge HRESETn)
    if( ! HRESETn )
      begin
        nMode_trig <= '0;
	nTrip_trig <= '0;
	nMode_nValid <= 0;
	nTrip_nValid <= 0;
      end
    else
      begin
	if(read_DataValid)  // set back to valid after data valid is read out
	  begin
	    nMode_nValid <= 0;
	    nTrip_nValid <= 0;
	  end
	else if(DataValid) // reset when datavalid
	  begin
	    nMode_trig <= 0;
	    nTrip_trig <= 0;
	    nMode_nValid <= 1;
	    nTrip_nValid <= 1;
	  end
	  
	// these will not trigger unless data is already invalid
        if(nModeTrig)
	  begin
	    nMode_nValid <= 1;
	    nMode_trig <= 1;
	  end
	if(nModeRelease) nMode_nValid <= 0;
	
	if(nTripTrig)
	  begin
	    nTrip_nValid <= 1;
	    nTrip_trig <= 1;
	  end 
	if(nTripRelease) nTrip_nValid <= 0;
      end
  
  //Update the button values only when the appropriate button is pressed
  always_ff @(posedge HCLK, negedge HRESETn)
    if ( ! HRESETn )
    begin
        nMode_reg <= 1'b0;
    end
    else if (read_DataValid) begin
        nMode_reg <= 1'b0;		
	end
    else if (nMode_trig & ~nTrip_trig & ~nMode_nValid & ~nTrip_nValid & ~DataValid) begin
        nMode_reg <= 1'b1;		
	end
	
  always_ff @(posedge HCLK, negedge HRESETn)
    if ( ! HRESETn )
    begin
        nTrip_reg <= 1'b0;
    end
    else if (read_DataValid) begin
        nTrip_reg <= 1'b0;		
	end
    else if (~nMode_trig & nTrip_trig & ~nMode_nValid & ~nTrip_nValid & ~DataValid) begin
        nTrip_reg <= 1'b1;		
	end

  always_ff @(posedge HCLK, negedge HRESETn)
    if ( ! HRESETn )
    begin
        Both_reg <= 1'b0;
    end
    else if (read_DataValid) begin
        Both_reg <= 1'b0;		
	end
    else if (nMode_trig & nTrip_trig & ~nMode_nValid & ~nTrip_nValid & ~DataValid) begin
        Both_reg <= 1'b1;		
	end

  // update datavalid register
  always_ff @(posedge HCLK, negedge HRESETn)
    if ( ! HRESETn )
    begin
        DataValid <= 1'b0;
    end
    else if (read_DataValid) begin
        DataValid <= 1'b0;		
	end
    else if (nMode_reg | nTrip_reg | Both_reg) begin
        DataValid <= 1'b1;		
	end

  assign read_DataValid = read_enable && (word_address == 0);

  //Generate the control signals in the address phase
  always_ff @(posedge HCLK, negedge HRESETn)
    if ( ! HRESETn )
      begin
        read_enable <= '0;
        word_address <= '0;
      end
    else if ( HREADY && HSEL && (HTRANS != No_Transfer) )
      begin
        read_enable <= ! HWRITE;
        word_address <= HADDR[3:2];
      end
    else
      begin
        read_enable <= '0;
        word_address <= '0;
      end

  //Act on control signals in the data phase

  // define the bits in the status register
  assign Status = { 29'd0, Both_reg,nTrip_reg,nMode_reg};

  // read
  always_comb
    if ( ! read_enable )
      // (output of zero when not enabled for read is not necessary
      //  but may help with debugging)
      HRDATA = '0;
    else
      case (word_address)
        0 : HRDATA = Status;
        1 : HRDATA = {31'd0,DataValid};
        // unused address - returns zero
        default : HRDATA = '0;
      endcase

  //Transfer Response
  assign HREADYOUT = '1; //Single cycle Write & Read. Zero Wait state operations



endmodule

