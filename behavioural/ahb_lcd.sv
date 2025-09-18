// AHB-Lite custom interface for LCD display (ahb_lcd.sv)
// This module interfaces with the lcd_1x8_display module
//
// Number of addressable locations : 5
// Size of each addressable location : 32 bits
// Supported transfer sizes : Word
// Alignment of base address : Word aligned
//
// Address map :
//   Base addess + 0, + 4 : 
//     Read LCD_CHAR for 8 characters register
//     Write LCD_CHAR for 8 characters register
//   Base addess + 8 : 
//     Read Instruction register
//     Write Instruction register
//	       10 bits for LCD module instruction code
//		   RS R/W DB7 DB6 DB5 DB4 DB3 DB2 DB1 DB0
//   Base addess + 12 : 
//     Write only
//     Write LCD Control register
//	       Bit 0: Display/Instruction, set 1 to display LCD characters, set 0 to send instruction codes 
//	       Bit 1: Enable bit, flagged by master to start a data transfer 
//   Base addess + 16 : 
//     Read only
//     Read Status register
//	       Bit 0: Busy flag bit, flagged when interface is busy 

module ahb_lcd(

  // AHB Global Signals
  input HCLK,
  input HRESETn,

  // AHB Signals from Master to Slave
  input [31:0] HADDR,    // Only HADDR[4:2] is used (other bits are ignored)
  input [31:0] HWDATA,
  input [2:0] HSIZE,
  input [1:0] HTRANS,
  input HWRITE,
  input HREADY,
  input HSEL,

  // AHB Signals from Slave to Master
  output logic [31:0] HRDATA,
  output HREADYOUT,

  // Non-AHB Signals to LCD
  output logic RS, // Register Select
  output logic RnW, // Read/Write
  output logic E, // Operation Enable
  inout [7:0] DB // 8-bit Data Bus

);

timeunit 1ns;
timeprecision 100ps;

// AHB transfer codes needed in this module
localparam No_Transfer = 2'b00;

// Registers for LCD Control and Data
logic write_enable, read_enable;
logic [2:0] word_address;  // Determine which register to access
logic [7:0] LCD_CHAR [7:0];  // Character codes for LCD (8 characters)
logic [9:0] LCD_INST;  // Instruction register (10 bits)
logic [1:0] LCD_CTRL;  // Control bits (Display/Instruction and Enable)
logic LCD_STATUS;  // Busy flag bit

logic [7:0] DB_internal;  // Generated DB from lcd
logic DB_write;           // Flag to enable DB tristate

// Generate the control signals in the address phase
always_ff @(posedge HCLK, negedge HRESETn)
  if ( !HRESETn ) 
	begin
      write_enable <= '0;
      read_enable <= '0;
      word_address <= '0;
    end 
  else if (HREADY && HSEL && (HTRANS != No_Transfer)) 
	begin
      write_enable <= HWRITE;
      read_enable <= !HWRITE;
      word_address <= HADDR[4:2];  // Use bits [4:2] of HADDR to select the register
    end 
  else 
    begin
      write_enable <= '0;
      read_enable <= '0;
      word_address <= '0;
    end

// Act on control signals in the data phase

// Write Operation to the LCD Interface Registers
always_ff @(posedge HCLK, negedge HRESETn)
  if ( !HRESETn ) 
    begin
      LCD_CHAR[0] <= '0;
      LCD_CHAR[1] <= '0;
      LCD_CHAR[2] <= '0;
      LCD_CHAR[3] <= '0;
      LCD_CHAR[4] <= '0;
      LCD_CHAR[5] <= '0;
      LCD_CHAR[6] <= '0;
      LCD_CHAR[7] <= '0;
      LCD_INST <= '0;
      LCD_CTRL <= 2'b00;
    end 
  else if (write_enable) 
    begin
      case (word_address)
        3'b000: // Address + 0 (Store lower 4 characters)
          begin
            LCD_CHAR[0] <= HWDATA[7:0];   // Character 0
            LCD_CHAR[1] <= HWDATA[15:8];  // Character 1
            LCD_CHAR[2] <= HWDATA[23:16]; // Character 2
            LCD_CHAR[3] <= HWDATA[31:24]; // Character 3
          end

        3'b001: // Address + 4 (Store higher 4 characters)
          begin
            LCD_CHAR[4] <= HWDATA[7:0];   // Character 4
            LCD_CHAR[5] <= HWDATA[15:8];  // Character 5
            LCD_CHAR[6] <= HWDATA[23:16]; // Character 6
            LCD_CHAR[7] <= HWDATA[31:24]; // Character 7
          end

        3'b010: LCD_INST <= HWDATA[9:0];  // Address + 8 (Instruction Code)
        3'b011: LCD_CTRL <= HWDATA[1:0];  // Address + 12 (Control Bits)
        default: ;
      endcase
    end
  else if (LCD_CTRL[1])
    LCD_CTRL[1] <= 0;  // Reset Enable flag after 1 cycle (if set by master)

// Read Operation from the LCD Interface Registers
always_comb
  if (!read_enable)
    HRDATA = '0;  // If not enabled for read, output zero
  else 
    begin
      case (word_address)
        3'b000: HRDATA = {LCD_CHAR[3], LCD_CHAR[2], LCD_CHAR[1], LCD_CHAR[0]};  // Address + 0 (Lower 4 characters)
        3'b001: HRDATA = {LCD_CHAR[7], LCD_CHAR[6], LCD_CHAR[5], LCD_CHAR[4]};  // Address + 4 (Higher 4 characters)
        3'b010: HRDATA = {22'b0, LCD_INST};  // Address + 8 (Instruction Register, 10-bit value)
        3'b011: HRDATA = 32'b0;              // Address + 12 (Control Register, Write-only, return 0)
        3'b100: HRDATA = {31'b0, LCD_STATUS}; // Address + 16 (Status Register: Busy flag)
        default: HRDATA = '0;                // Default case: return 0
      endcase
    end

// Transfer Response - Single Cycle Operation (No Wait States)
assign HREADYOUT = '1;

// LCD Control Logic
// This part of the code contains the state machine of the control module
enum logic [3:0] { IDLE, INSTRUCTION, DISPLAY, CHAR0, CHAR1, CHAR2, CHAR3, CHAR4, CHAR5, CHAR6, CHAR7 } LCD_STATE;
enum logic [1:0] {SETUP, ENABLE, HOLD} DATA_STATE;

always_ff @(posedge HCLK, negedge HRESETn) 
begin
  if (!HRESETn) 
    begin
      // Reset all outputs and state variables
      LCD_STATE <= IDLE;
      DATA_STATE <= SETUP;
    end 
  else
    begin
      case(LCD_STATE)
        IDLE:        if(LCD_CTRL[1])  // Check enable bit
	               if(LCD_CTRL[0])  // **Display mode: Send 8 characters**
	                 begin
	                   LCD_STATE <= DISPLAY;
		         end
	               else             // **Instruction mode: Send 10-bit instruction**
	                 begin
	                   LCD_STATE <= INSTRUCTION;
		         end
	INSTRUCTION: if(DATA_STATE == SETUP)
	               DATA_STATE <= ENABLE;
		     else if(DATA_STATE == ENABLE)
	               DATA_STATE <= HOLD;
		     else 
		       begin
		         DATA_STATE <= SETUP;
		         LCD_STATE <= IDLE;
		       end
	DISPLAY:     if(DATA_STATE == SETUP)
	               DATA_STATE <= ENABLE;
		     else if(DATA_STATE == ENABLE)
	               DATA_STATE <= HOLD;
		     else 
		       begin
		         DATA_STATE <= SETUP;
		         LCD_STATE <= CHAR0;
		       end
	CHAR0:       if(DATA_STATE == SETUP)
	               DATA_STATE <= ENABLE;
		     else if(DATA_STATE == ENABLE)
	               DATA_STATE <= HOLD;
		     else 
		       begin
		         DATA_STATE <= SETUP;
		         LCD_STATE <= CHAR1;
		       end
	CHAR1:       if(DATA_STATE == SETUP)
	               DATA_STATE <= ENABLE;
		     else if(DATA_STATE == ENABLE)
	               DATA_STATE <= HOLD;
		     else 
		       begin
		         DATA_STATE <= SETUP;
		         LCD_STATE <= CHAR2;
		       end
	CHAR2:       if(DATA_STATE == SETUP)
	               DATA_STATE <= ENABLE;
		     else if(DATA_STATE == ENABLE)
	               DATA_STATE <= HOLD;
		     else 
		       begin
		         DATA_STATE <= SETUP;
		         LCD_STATE <= CHAR3;
		       end
	CHAR3:       if(DATA_STATE == SETUP)
	               DATA_STATE <= ENABLE;
		     else if(DATA_STATE == ENABLE)
	               DATA_STATE <= HOLD;
		     else 
		       begin
		         DATA_STATE <= SETUP;
		         LCD_STATE <= CHAR4;
		       end
	CHAR4:       if(DATA_STATE == SETUP)
	               DATA_STATE <= ENABLE;
		     else if(DATA_STATE == ENABLE)
	               DATA_STATE <= HOLD;
		     else 
		       begin
		         DATA_STATE <= SETUP;
		         LCD_STATE <= CHAR5;
		       end
	CHAR5:       if(DATA_STATE == SETUP)
	               DATA_STATE <= ENABLE;
		     else if(DATA_STATE == ENABLE)
	               DATA_STATE <= HOLD;
		     else 
		       begin
		         DATA_STATE <= SETUP;
		         LCD_STATE <= CHAR6;
		       end
	CHAR6:       if(DATA_STATE == SETUP)
	               DATA_STATE <= ENABLE;
		     else if(DATA_STATE == ENABLE)
	               DATA_STATE <= HOLD;
		     else 
		       begin
		         DATA_STATE <= SETUP;
		         LCD_STATE <= CHAR7;
		       end
	CHAR7:       if(DATA_STATE == SETUP)
	               DATA_STATE <= ENABLE;
		     else if(DATA_STATE == ENABLE)
	               DATA_STATE <= HOLD;
		     else 
		       begin
		         DATA_STATE <= SETUP;
		         LCD_STATE <= IDLE;
		       end
	default: LCD_STATE <= IDLE;
      endcase
    end
end

always_comb
begin
  /* Default values */
  LCD_STATUS = 0;
  DB_internal = 0;
  DB_write = 1;
  RS = 0;
  RnW = 0;
  E = 0;

  case(LCD_STATE)
    IDLE:        ;
    INSTRUCTION: begin
                   DB_write = 1;
                   DB_internal = LCD_INST[7:0];   // Send lower 8 bits
                   {RS, RnW} = LCD_INST[9:8];  // Send control bits
                 end
    DISPLAY:     begin
                   DB_write = 1;
                   DB_internal = 8'h80;		// set address to 0
		   RS = 0;
		   RnW = 0;
                 end
    CHAR0:       begin
                   DB_write = 1;
                   DB_internal = LCD_CHAR[0];
		   RS = 1;
		   RnW = 0;
                 end
    CHAR1:       begin
                   DB_write = 1;
                   DB_internal = LCD_CHAR[1];
		   RS = 1;
		   RnW = 0;
                 end
    CHAR2:       begin
                   DB_write = 1;
                   DB_internal = LCD_CHAR[2];
		   RS = 1;
		   RnW = 0;
                 end
    CHAR3:       begin
                   DB_write = 1;
                   DB_internal = LCD_CHAR[3];
		   RS = 1;
		   RnW = 0;
                 end
    CHAR4:       begin
                   DB_write = 1;
                   DB_internal = LCD_CHAR[4];
		   RS = 1;
		   RnW = 0;
                 end
    CHAR5:       begin
                   DB_write = 1;
                   DB_internal = LCD_CHAR[5];
		   RS = 1;
		   RnW = 0;
                 end
    CHAR6:       begin
                   DB_write = 1;
                   DB_internal = LCD_CHAR[6];
		   RS = 1;
		   RnW = 0;
                 end
    CHAR7:       begin
                   DB_write = 1;
                   DB_internal = LCD_CHAR[7];
		   RS = 1;
		   RnW = 0;
                 end
    default: ;
  endcase
  
  
  if(DATA_STATE == ENABLE)
    E = 1;        // set enable bit
    
  if(LCD_STATE != IDLE)
    LCD_STATUS = 1;  // set busy bit when LCD is non-idle
end

assign DB = (DB_write) ? DB_internal : 8'bz;

endmodule
