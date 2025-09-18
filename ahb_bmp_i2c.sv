// AHB-Lite custom interface for I2C interface (ahb_i2c.sv)
// This module interfaces with the simple i2c sensor module
//
// Number of addressable locations : 5
// Size of each addressable location : 32 bits
// Supported transfer sizes : Word
// Alignment of base address : Word aligned
//
// Address map :
//   Base address + 0 :
//     Read/Write
//     Contain device address
//   Base address + 4 : 
//     Read/Write
//     Contains target register addresses (up to 4 addresses)
//   Base address + 8, +12 : 
//     Read only
//     Contains read data read from the sensor (up to 6 bytes)
//   Base addess + 16 : 
//     Read/Write
//     Contains write data to be written to sensor (up to 4 bytes of data)
//   Base addess + 20 : 
//     Write only
//     Control register
//       Bit 0: R/W bit, set high to perform read transfer, low for write transfer
//       Bit 1: Start bit, flagged by master to perform a transfer, reset after one cycle
//       Bit 2~4: nbytes, controls number of read/write operations to be performed
//   Base addess + 24 : 
//     Read only
//     Status register
//       Bit 0: DataValid bit, flagged after a read operation is completed and while data is valid, reset when new I2C transfer is started
//       Bit 1: Busy bit, flagged while the interface is not idle

module ahb_bmp_i2c(
  // AHB Global Signals
  input HCLK,
  input HRESETn,

  // AHB Signals from Master to Slave
  input [31:0] HADDR,
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
  output logic SCL,
  output logic SDA_out,
  input SDA_in
);

timeunit 1ns;
timeprecision 100ps;
  
  // AHB transfer codes needed in this module
  localparam No_Transfer = 2'b0;

  // Register addresses
  localparam DEVICE_ADDR_REG = 3'b000;
  localparam REG_ADDR_REG = 3'b001;
  localparam READ_DATA_LOW_REG = 3'b010;
  localparam READ_DATA_HIGH_REG = 3'b011;
  localparam WRITE_DATA_REG = 3'b100;
  localparam CONTROL_REG = 3'b101;
  localparam STATUS_REG = 3'b110;

  logic write_enable, read_enable;
  logic [2:0] word_address;
  
  // programmer's model registers
  logic [6:0] device_addr;
  logic [7:0] reg_addr [0:3];
  logic [7:0] read_data [0:5];
  logic [7:0] write_data [0:3];
  logic [4:0] control_reg;
  logic [1:0] status_reg;
  
  // I2C frame logic variables
  enum logic [2:0] {WRITE_DEVICE_ADDR, WRITE_REG_ADDR, WRITE_DATA, READ_REG_ADDR, READ_DEVICE_ADDR, READ_DATA} control_state;
  logic [2:0] byte_counter;
  logic [7:0] I2C_tx_data;
  logic SDA_continue;
  logic SDA_restart;
  logic I2C_write_flag;
  
  // controller variables mapped from register file
  logic I2C_read_op;
  logic SDA_start;
  logic [2:0] nbytes;
    
  assign I2C_read_op = control_reg[0];
  assign SDA_start = control_reg[1];
  assign nbytes = {control_reg[4], control_reg[3], control_reg[2]} - 1;
  
  // SDA, SCL generation variables
  enum logic[4:0] {SETUP, IDLE, START1, START2, DATA1, CLOCK1, DATA2, CLOCK2, END1, END2, RESTART1, RESTART2} gen_state;
  logic[4:0] SDA_out_counter;
  logic SDA_out_internal;
  logic I2C_read_enable;
  
  // synchronise SDA, SCL to clock (remove static hazards)
  logic SDA_out_next;
  logic SCL_next;
  
  // read handler variables
  logic read_ack;
  
  // AHB address decoding and control
  always_ff @(posedge HCLK, negedge HRESETn)
  if(!HRESETn) 
    begin
      write_enable <= '0;
      read_enable <= '0;
      word_address <= '0;
    end
  else 
    if (HREADY && HSEL && (HTRANS != No_Transfer)) 
      begin
        write_enable <= HWRITE;
        read_enable <= !HWRITE;
        word_address <= HADDR[4:2];
      end
    else 
      begin
        write_enable <= '0;
        read_enable <= '0;
        word_address <= '0;
      end

  //AHB write operation
  always_ff @(posedge HCLK, negedge HRESETn)
  if(!HRESETn) 
    begin
      device_addr <= '0;
      {reg_addr[3], reg_addr[2], reg_addr[1], reg_addr[0]} <= '0;
      {write_data[3], write_data[2], write_data[1], write_data[0]} <= '0;
      control_reg <= '0;
    end
  else if (write_enable) 
    begin
      case (word_address)
        DEVICE_ADDR_REG:  device_addr <= HWDATA[6:0];
        REG_ADDR_REG:     {reg_addr[3], reg_addr[2], reg_addr[1], reg_addr[0]} <= HWDATA;
        WRITE_DATA_REG:   {write_data[3], write_data[2], write_data[1], write_data[0]} <= HWDATA;
        CONTROL_REG:      control_reg <= HWDATA[4:0];
        default: ;
      endcase
    end
  else if (control_reg[1])
    control_reg[1] <= 0;  // Reset start bit after 1 cycle (if set by master)

  //AHB read operation
  always_comb
  if(!read_enable)
    HRDATA = '0;
  else 
    begin
      case (word_address)
        DEVICE_ADDR_REG:     HRDATA = {25'b0, device_addr};
        REG_ADDR_REG:        HRDATA = {reg_addr[3], reg_addr[2], reg_addr[1], reg_addr[0]};
        READ_DATA_LOW_REG:   HRDATA = {read_data[3], read_data[2], read_data[1], read_data[0]};
        READ_DATA_HIGH_REG:  HRDATA = {16'b0, read_data[5], read_data[4]};
        STATUS_REG:          HRDATA = {30'b0, status_reg};
        default:             HRDATA = 32'b0;
      endcase
    end
  
  
  // Transfer Response - Single Cycle Operation (No Wait States)
  assign HREADYOUT = '1;
  
  // I2C frame logic controller
  always_ff @(posedge HCLK, negedge HRESETn)
  if(!HRESETn)
    begin
      control_state <= WRITE_DEVICE_ADDR;
      byte_counter <= '0;
    end
  else if(SDA_out_counter == 8 && gen_state == CLOCK2)
    begin
      case(control_state)
        WRITE_DEVICE_ADDR:if(read_ack)
                            if(I2C_read_op)
	                      control_state <= READ_REG_ADDR;
	                    else
	                      control_state <= WRITE_REG_ADDR;
	WRITE_REG_ADDR:   control_state <= WRITE_DATA; 
	WRITE_DATA:       if(byte_counter == nbytes)
                            begin
	                      control_state <= WRITE_DEVICE_ADDR;
			      byte_counter <= 0;
                            end
			  else
			    begin
	                      control_state <= WRITE_REG_ADDR;
			      byte_counter <= byte_counter + 1;
			    end
        READ_REG_ADDR:    control_state <= READ_DEVICE_ADDR; 
        READ_DEVICE_ADDR: control_state <= READ_DATA; 
        READ_DATA:        if(byte_counter == nbytes)
	                    begin
	                      control_state <= WRITE_DEVICE_ADDR;
			      byte_counter <= 0;
			    end
			  else
			    byte_counter <= byte_counter + 1;
      endcase
    end
    
  always_comb
  begin
    I2C_tx_data = 8'b1111_1111;
    I2C_write_flag = 1;
    SDA_continue = 0;
    SDA_restart = 0;
    
    // SDA should continue if byte_counter is not equal to nbytes
    if(byte_counter != nbytes) 
      SDA_continue = 1;
    
    case(control_state)
      WRITE_DEVICE_ADDR:  begin
                            if(!read_ack)
			      SDA_continue = 0;
                            I2C_tx_data = {device_addr, 1'b0};
                          end
      WRITE_REG_ADDR:     begin
                            I2C_tx_data = reg_addr[byte_counter];
			    SDA_continue = 1;
                          end
      WRITE_DATA:         I2C_tx_data = write_data[byte_counter];
      READ_REG_ADDR:      begin
                            I2C_tx_data = reg_addr[0];
			    SDA_restart = 1;
			  end
      READ_DEVICE_ADDR:   I2C_tx_data = {device_addr, 1'b1};
      READ_DATA:          I2C_write_flag = 0;
      default: ;
    endcase
  end
  
  // SDA, SCL generation
  always_ff @(posedge HCLK, negedge HRESETn)
  if(!HRESETn)
    begin
      gen_state <= SETUP;
      SDA_out_counter <= '0;
    end
  else
    begin
      case(gen_state)
        SETUP:   gen_state <= IDLE;
        IDLE:    if(SDA_start || control_state == READ_DEVICE_ADDR)
	           gen_state <= START1;
        START1:  gen_state <= START2;
	START2:  gen_state <= DATA1;
	DATA1:   gen_state <= CLOCK1;
	CLOCK1:  gen_state <= DATA2;
	DATA2:   gen_state <= CLOCK2;
	CLOCK2:  if((SDA_out_counter == 8) && (! SDA_continue))
		   gen_state <= END1;
		 else if((SDA_out_counter == 8) && (SDA_restart))
		   gen_state <= RESTART1;
		 else
		   begin
		     if(SDA_out_counter == 8)
		       SDA_out_counter <= 0;
	             gen_state <= DATA1;
		   end
	END1:     begin
	            gen_state <= END2;
		    SDA_out_counter <= 0;
		  end
	END2:     gen_state <= IDLE;
	RESTART1: begin
	            gen_state <= RESTART2;
		    SDA_out_counter <= 0;
		  end
	RESTART2: gen_state <= IDLE;
        default: gen_state <= IDLE;
      endcase
      
      // Increment counter after every data sent
      // Counter value from 0 to 7 represent data bytes
      // Counter value == 8 means acknowledgement bit (either master or slave)      
      if(gen_state == CLOCK2 && SDA_out_counter < 8)
        SDA_out_counter <= SDA_out_counter + 1;
    end

  always_comb
  begin
    SCL_next = 1;
    SDA_out_next = 1;
    SDA_out_internal = 1;
    I2C_read_enable = 0;
    
    // determine what to transmit on SDA_out
    if(SDA_out_counter < 8)      // 8 bits data transfer (either read or write)
      if(I2C_write_flag)         // master write to SDA
        SDA_out_internal = I2C_tx_data[7 - SDA_out_counter];
      else                       // master hold SDA_out high to read input from SDA_in
        begin
          SDA_out_internal = 1;
	  I2C_read_enable = 1;
	end
    else                         // Acknowledgement (either read or write)
      if(I2C_write_flag)
        begin
          SDA_out_internal = 1;  // Hold high to read slave acknowledgement
	  I2C_read_enable = 1;
        end
      else
        SDA_out_internal = ~SDA_continue;    // Hold high to end read transfer, hold low to continue read transfer
    
    case(gen_state)
      SETUP:  SCL_next = 0;
      IDLE:   ;
      START1: SDA_out_next = 0;
      START2: begin
                SDA_out_next = 0;
                SCL_next = 0;
	      end
      DATA1:  begin
                SDA_out_next = SDA_out_internal;
		SCL_next = 0;
              end
      CLOCK1: begin
                SDA_out_next = SDA_out_internal;
              end
      DATA2:  begin
                SDA_out_next = SDA_out_internal;
              end
      CLOCK2: begin
                SDA_out_next = SDA_out_internal;
		SCL_next = 0;
              end
      END1:   begin
		SCL_next = 0;
                SDA_out_next = 0;
              end
      END2:   begin
                SDA_out_next = 0;
              end
      RESTART1:begin
                 SCL_next = 0;
               end
      RESTART2:begin
                 SCL_next = 0;
               end
      default: ;
    endcase
  end
  
  // synchronise SDA_out, SCL to clock
  always_ff @(posedge HCLK, negedge HRESETn)
  if(! HRESETn)
    begin
      SCL <= '0;
      SDA_out <= '0;
    end
  else
    begin
      SCL <= SCL_next;
      SDA_out <= SDA_out_next;
    end
  
  
  assign status_reg[1] = (gen_state != IDLE);
  
  // read handler
  always_ff @(posedge HCLK, negedge HRESETn)
  if(! HRESETn)
    begin
      read_data[0] <= '0;
      read_data[1] <= '0;
      read_data[2] <= '0;
      read_data[3] <= '0;
      read_data[4] <= '0;
      read_data[5] <= '0;
      read_ack <= 0;
    end
  else if(I2C_read_enable && gen_state == CLOCK1)
    begin
      case(SDA_out_counter)
      0: read_data[byte_counter][7] <= SDA_in;
      1: read_data[byte_counter][6] <= SDA_in;
      2: read_data[byte_counter][5] <= SDA_in;
      3: read_data[byte_counter][4] <= SDA_in;
      4: read_data[byte_counter][3] <= SDA_in;
      5: read_data[byte_counter][2] <= SDA_in;
      6: read_data[byte_counter][1] <= SDA_in;
      7: read_data[byte_counter][0] <= SDA_in;
      8: read_ack <= ~SDA_in;	// acknowledgement is 0 in I2C protocol
      default: ;
      endcase
    end 
  
  // DataValid status logic
  logic DataValid;
  always_ff @(negedge HCLK, negedge HRESETn)
  if(! HRESETn)
    DataValid <= 0;
  else
    if ( byte_counter == nbytes && control_state == READ_DATA  && SDA_out_counter == 8 && gen_state == CLOCK2 )
      DataValid <= 1;
    else if ( SDA_start )
      DataValid <= 0;
  assign status_reg[0] = DataValid;

endmodule
