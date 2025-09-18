#define __MAIN_C__

#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <math.h>
#include <fptc.h>
#include <ARMCM0.h>
#include <core_cm0.h>

// Define the raw base address values for the i/o devices

#define AHB_BUTTON_BASE                         0x40000000
#define AHB_LCD_BASE                            0x50000000
#define AHB_I2C_BASE                            0x60000000

// Define pointers with correct type for access to 32-bit i/o devices
//
// The locations in the devices can then be accessed as:
//   Button Interface
//    BUTTON_REGS[0]: bit 0 -> mode, bit 1 -> trip, bit 2 -> both
//    BUTTON_REGS[1]: bit 0 -> datavalid
//   I2C
//    I2C_REGS[0]: bits 7~0 -> device address
//    I2C_REGS[1]: 4 sets of byte register addresses
//    I2C_REGS[2]: lower 4 bytes from data read
//    I2C_REGS[3]: upper 2 bytes from data read
//    I2C_REGS[4]: 4 write bytes
//    I2C_REGS[5]: bit 0 -> r/w, bit 1 -> start, bit 2~4 -> n bytes
//    I2C_REGS[6]: bit 0 -> datavalid, bit 1 -> busy flag
//   LCD
//    LCD_REGS[0]: contains characters to be written to DDRAM[3~0]
//    LCD_REGS[1]: contains characters to be written to DDRAM[7~4]
//    LCD_REGS[2]: 10 bits instruction code
//    LCD_REGS[3]: bit 0 -> D/I, bit 1 -> enable
//    LCD_REGS[4]: bit 0 -> busy flag
//
volatile uint32_t* BUTTON_REGS = (volatile uint32_t*) AHB_BUTTON_BASE;
volatile uint32_t* LCD_REGS = (volatile uint32_t*) AHB_LCD_BASE;
volatile uint32_t* I2C_REGS = (volatile uint32_t*) AHB_I2C_BASE;

//////////////////////////////////////////////////////////////////
// Global variables
//////////////////////////////////////////////////////////////////

typedef struct {

  uint16_t t1;
  uint16_t t2;
  int8_t   t3;
  int16_t  p1;
  int16_t  p2;
  int8_t   p3;
  int8_t   p4;
  uint16_t p5;
  uint16_t p6;
  int8_t   p7;
  int8_t   p8;
  int16_t  p9;
  int8_t   p10;
  int8_t   p11;
  int64_t  t_lin;

} BMP390_calib_data;

BMP390_calib_data calib_data_global;

#define VSI_QUEUE_SIZE 8

//////////////////////////////////////////////////////////////////
// Functions to access button interface
//////////////////////////////////////////////////////////////////

bool buttons_valid(void){

  return BUTTON_REGS[1];

}

uint32_t buttons_read(void){

  return BUTTON_REGS[0];

}

void button_wait_for_any_data(void) {

  // this is a 'busy wait'

  //  ( it should only be used if there is nothing
  //   else for the embedded system to do )

  while ( BUTTON_REGS[1] == 0 );
  
  return;

}

//////////////////////////////////////////////////////////////////
// Functions to access I2C interface
//////////////////////////////////////////////////////////////////

bool i2c_valid(void){

  return (I2C_REGS[6] & 0x00000001);	// bit 0 valid

}

bool i2c_busy(void){

  return (I2C_REGS[6] & 0x00000002);	// bit 1 busy

}

void i2c_set_device_address(uint32_t address){

  I2C_REGS[0] = address;

}

uint32_t i2c_get_device_address(void){

  return I2C_REGS[0];

}

void i2c_set_register_address(uint8_t addr3, uint8_t addr2, uint8_t addr1, uint8_t addr0){

  /* shift register addresses to match programmer model */
  uint32_t addresses = 0;
  addresses = ((uint32_t)addr3 << 24) + ((uint32_t)addr2 << 16) + ((uint32_t)addr1 << 8) + (uint32_t)addr0;
  
  I2C_REGS[1] = addresses;

}

uint32_t i2c_get_register_address(void){
  
  return I2C_REGS[1];

}

uint32_t i2c_get_lower_read_data(void){

  return I2C_REGS[2];

}

uint32_t i2c_get_higher_read_data(void){

  return I2C_REGS[3];

}

uint32_t i2c_get_write_data(void){

  return I2C_REGS[4];

}

void i2c_set_write_data(uint8_t data3, uint8_t data2, uint8_t data1, uint8_t data0){

  /* shift write data to match programmer model */
  uint32_t data = 0;
  data = ((uint32_t)data3 << 24) + ((uint32_t)data2 << 16) + ((uint32_t)data1 << 8) + (uint32_t)data0;

  I2C_REGS[4] = data;

}

void i2c_enable (uint32_t r_w, uint32_t nbytes){
  
  uint32_t control = 0;
  
  control = r_w;			// r/w bit [0]
  control = control + (1 << 1);		// start bit [1]
  control = control + (nbytes << 2);	// nbytes [4:2]
  
  I2C_REGS[5] = control;

}

//////////////////////////////////////////////////////////////////
// Functions to access LCD interface
//////////////////////////////////////////////////////////////////

void lcd_set_lower_characters(uint32_t value) {

 LCD_REGS[0] = value;

}

void lcd_set_higher_characters(uint32_t value) {

 LCD_REGS[1] = value;

}

uint32_t lcd_get_lower_characters(void) {

 return LCD_REGS[0];

}

uint32_t lcd_get_higher_characters(void) {

 return LCD_REGS[1];

}

void lcd_set_instruction(bool rs, bool r_w, uint8_t data) {

  uint32_t instruction_code = (rs << 9) + (r_w << 8) + data;
  
  LCD_REGS[2] = instruction_code;

}

uint32_t lcd_get_instruction(void) {

  return LCD_REGS[2];

}

void lcd_enable (bool d_i){
  
  uint32_t control = 0;
  
  control = d_i;			// display/instruction bit [0] (1 for display, 0 for instruction)
  control = control + (1 << 1);		// enable bit [1]
  
  LCD_REGS[3] = control;

}


bool lcd_busy(void){

  return LCD_REGS[4];	// bit 0 busy

}

//////////////////////////////////////////////////////////////////
// Delay function
//////////////////////////////////////////////////////////////////

volatile uint32_t sys_tick_counter = 0;

void SysTick_Handler(void) {
    sys_tick_counter++;  // Increment every 1s
}

// SysTick Initialization
void SysTick_Init(uint32_t ticks) {
    SysTick->LOAD = ticks - 1;
    SysTick->VAL = 0;
    SysTick->CTRL = SysTick_CTRL_CLKSOURCE_Msk | SysTick_CTRL_TICKINT_Msk | SysTick_CTRL_ENABLE_Msk;
}

time_t time(time_t *t) {
    time_t current_time = sys_tick_counter;
    if (t) {
        *t = current_time;
    }
    return current_time;
}

/*
void delay_ms(uint32_t ms) {
    uint32_t start = sys_tick_counter;
    uint32_t target_ticks = (ms * 1000) / 2136; // convert 2.168ms to 1000ms
    
    while ((sys_tick_counter - start) < target_ticks);
}
*/

void delay_ms(uint32_t ms){
  uint32_t start = SysTick->VAL;
  uint32_t ticks = (ms * 32768 / 1000) ; // number of ticks to equal 1 millisecond on 32.768kHz clock
  
  // start - SysTick->VAL is the amount of ticks that has elapsed
  // added modulo SysTick->LOAD logic to deal with potential edge cases where SysTick->VAL underflows (resetted after hitting 0)
  // adding SysTick->LOAD ensure the value never goes negative since working with unsigned integers
  while ((SysTick->LOAD + start - SysTick->VAL) % SysTick->LOAD < ticks) ;
} 

//////////////////////////////////////////////////////////////////
// LCD Functions
//////////////////////////////////////////////////////////////////

// Busy wait, can be improved
void lcd_wait_not_busy(void) {
  while(lcd_busy()) ;
  return;
}

void lcd_send_command(bool rs, bool r_w, uint8_t i) {
  lcd_wait_not_busy();

  lcd_set_instruction(rs, r_w, i);
  lcd_enable(0);
}

void lcd_refresh_display(void) {
  lcd_wait_not_busy();
  
  lcd_enable(1);
}

void lcd_init(void) {
  // This part of the code is translated from LCD datasheet
  delay_ms(50);                    //Wait >40 msec after power is applied
  lcd_set_instruction(0, 0, 0x30); //command 0x30 = Wake up
  lcd_enable(0);
  delay_ms(5);                    //must wait 5ms, busy flag not available
  lcd_set_instruction(0, 0, 0x30); //command 0x30 = Wake up #2
  lcd_enable(0);
  delay_ms(1);                     //must wait 160us, busy flag not available
  lcd_set_instruction(0, 0, 0x30); //command 0x30 = Wake up #3
  lcd_enable(0);
  delay_ms(1);                     //must wait 160us, busy flag not available

  lcd_send_command(0, 0, 0x38); //Function set: 8-bit/2-line
  lcd_send_command(0, 0, 0x08); //Display OFF
  lcd_send_command(0, 0, 0x01); //Clear display
  lcd_send_command(0, 0, 0x06); //Entry mode set: set DDRAM address to increment after each write, no display shift
  lcd_send_command(0, 0, 0x0c); //Display ON; Cursor OFF
}

uint8_t lcd_digit_to_uint8 (uint32_t digit){
  uint8_t retval;

  switch (digit){
    case 0:  retval = 0x30;
             break;
    case 1:  retval = 0x31;
             break;
    case 2:  retval = 0x32;
             break;
    case 3:  retval = 0x33;
             break;
    case 4:  retval = 0x34;
             break;
    case 5:  retval = 0x35;
             break;
    case 6:  retval = 0x36;
             break;
    case 7:  retval = 0x37;
             break;
    case 8:  retval = 0x38;
             break;
    case 9:  retval = 0x39;
             break;
    case 10:  retval = 0x41;
             break;
    case 11:  retval = 0x42;
             break;
    case 12:  retval = 0x43;
             break;
    case 13:  retval = 0x44;
             break;
    case 14:  retval = 0x45;
             break;
    case 15:  retval = 0x46;
             break;
    default: retval = 0x20;
             break;
  }
  
  return retval;
}

void lcd_set_pressure_display (uint32_t pressure){
  uint8_t lcd_char[8];
  
  // get digits of pressure
  uint32_t hundred_thousands, ten_thousands, thousands, hundreds;
  hundred_thousands = (pressure % 1000000) / 100000;
  ten_thousands = (pressure % 100000) / 10000;
  thousands = (pressure % 10000) / 1000;
  hundreds = (pressure % 1000) / 100;
  
  // remove preceding zeroes where applicable
  if(hundred_thousands == 0) {
    hundred_thousands = 16; // remove first digit display instead of displaying 0
                            // setting the number to not 0~9 make LCD display blank
    if(ten_thousands == 0){		    
      ten_thousands = 16;
      
      if(thousands == 0){
        thousands = 16;
	
	// there is no need to check for hundreds = 0 case, just display 0 millibars instead of blank
      }
    }
  }
  
  // set display: [ ][1][0][1][3][ ][m][b]
  // address 0 corresponds to leftmost character on LCD display, 7 corresponds to rightmost character
  lcd_char[0] = 0x20;
  lcd_char[1] = lcd_digit_to_uint8(hundred_thousands); 
  lcd_char[2] = lcd_digit_to_uint8(ten_thousands);
  lcd_char[3] = lcd_digit_to_uint8(thousands); 
  lcd_char[4] = lcd_digit_to_uint8(hundreds);
  lcd_char[5] = 0x20; 
  lcd_char[6] = 0x6D;
  lcd_char[7] = 0x62; 
  
  uint32_t higher_char, lower_char;
  higher_char = (lcd_char[7] << 24) + (lcd_char[6] << 16) + (lcd_char[5] << 8) + lcd_char[4];
  lower_char = (lcd_char[3] << 24) + (lcd_char[2] << 16) + (lcd_char[1] << 8) + lcd_char[0];
  
  lcd_set_higher_characters(higher_char);
  lcd_set_lower_characters(lower_char);
}

void lcd_set_altitude_display (uint32_t altitude){
  uint8_t lcd_char[8];
  
  // get digits of altitude
  uint32_t thousands, hundreds, tens, ones;
  thousands = (altitude % 10000) / 1000;
  hundreds = (altitude % 1000) / 100;
  tens = (altitude % 100) / 10;
  ones = altitude % 10;
  
  // remove preceding zeroes where applicable
  if(thousands == 0) {
    thousands = 16; // remove first digit display instead of displaying 0
                            // setting the number to not 0~9 make LCD display blank
    if(hundreds == 0){		    
      hundreds = 16;
      
      if(tens == 0){
        tens = 16;
	
	// there is no need to check for ones = 0 case, just display 0 meters
      }
    }
  }
  
  // set display: [ ][9][9][9][9][ ][m][ ]
  // address 0 corresponds to leftmost character on LCD display, 7 corresponds to rightmost character
  lcd_char[0] = 0x20;
  lcd_char[1] = lcd_digit_to_uint8(thousands); 
  lcd_char[2] = lcd_digit_to_uint8(hundreds);
  lcd_char[3] = lcd_digit_to_uint8(tens); 
  lcd_char[4] = lcd_digit_to_uint8(ones);
  lcd_char[5] = 0x20; 
  lcd_char[6] = 0x6D;
  lcd_char[7] = 0x20; 
  
  uint32_t higher_char, lower_char;
  higher_char = (lcd_char[7] << 24) + (lcd_char[6] << 16) + (lcd_char[5] << 8) + lcd_char[4];
  lower_char = (lcd_char[3] << 24) + (lcd_char[2] << 16) + (lcd_char[1] << 8) + lcd_char[0];
  
  lcd_set_higher_characters(higher_char);
  lcd_set_lower_characters(lower_char);
}

void lcd_set_timer_display(time_t seconds) {
  uint8_t lcd_char[8];
    
  // Calculate hours, minutes and seconds
  uint32_t hours = seconds / 3600;
  uint32_t minutes = (seconds % 3600) / 60;
  uint32_t sec = seconds % 60;

  // Handle hours, minutes and seconds as digits
  //uint32_t hour_tens = hours / 10;
  uint32_t hour_ones = hours % 10;
    
  uint32_t minute_tens = minutes / 10;
  uint32_t minute_ones = minutes % 10;
    
  uint32_t second_tens = sec / 10;
  uint32_t second_ones = sec % 10;
    
  // Set display:
  // LCD format: [ ][H][:][M][M][:][S][S]
  // address 0 corresponds to leftmost character on LCD display, 7 corresponds to rightmost character
  lcd_char[0] = 0x20;  // Maximum range up to 9 hours
  //lcd_char[0] = lcd_digit_to_uint8(hour_tens);  // Tens place of hours, uncomment to set
  lcd_char[1] = lcd_digit_to_uint8(hour_ones);  // Ones place of hours
  lcd_char[2] = 0x3A;  // Colon (':')
  lcd_char[3] = lcd_digit_to_uint8(minute_tens);  // Tens place of minutes
  lcd_char[4] = lcd_digit_to_uint8(minute_ones);  // Ones place of minutes
  lcd_char[5] = 0x3A;  // Colon (':')
  lcd_char[6] = lcd_digit_to_uint8(second_tens);  // Tens place of seconds
  lcd_char[7] = lcd_digit_to_uint8(second_ones);  // Ones place of seconds
    
  // Set the higher and lower 32-bit LCD registers
  uint32_t higher_char = (lcd_char[7] << 24) + (lcd_char[6] << 16) + (lcd_char[5] << 8) + lcd_char[4];
  uint32_t lower_char = (lcd_char[3] << 24) + (lcd_char[2] << 16) + (lcd_char[1] << 8) + lcd_char[0];
    
  // Display the characters on the LCD
  lcd_set_higher_characters(higher_char);
  lcd_set_lower_characters(lower_char);
}

void lcd_set_vsi_display (fpt velocity_in){
  uint8_t lcd_char[8];
  
  // get digits of velocity (multiply before right shifting back to decimal to set tenths to ones place etc)
  bool negative_sign = velocity_in & 0x80000000;//msb
  
  fpt velocity = velocity_in;
  
  if(negative_sign)
    velocity = -1 * velocity;
    
  uint32_t ones, tenths, hundredths;
  ones = (velocity >> 14) % 10;
  tenths = ((velocity * 10) >> 14) % 10;
  hundredths = ((velocity * 100) >> 14) % 10;
  
  // set display: [+-][9][.][9][9][m][/][s]
  // address 0 corresponds to leftmost character on LCD display, 7 corresponds to rightmost character
  if(negative_sign)
    lcd_char[0] = 0x2D;
  else
    lcd_char[0] = 0x20;
  lcd_char[1] = lcd_digit_to_uint8(ones); 
  lcd_char[2] = 0x2E;
  lcd_char[3] = lcd_digit_to_uint8(tenths); 
  lcd_char[4] = lcd_digit_to_uint8(hundredths);
  lcd_char[5] = 0x6D; 
  lcd_char[6] = 0x2F;
  lcd_char[7] = 0x73; 
  
  uint32_t higher_char, lower_char;
  higher_char = (lcd_char[7] << 24) + (lcd_char[6] << 16) + (lcd_char[5] << 8) + lcd_char[4];
  lower_char = (lcd_char[3] << 24) + (lcd_char[2] << 16) + (lcd_char[1] << 8) + lcd_char[0];
  
  lcd_set_higher_characters(higher_char);
  lcd_set_lower_characters(lower_char);
}

void lcd_set_pressure_init_display (uint8_t *buffer){
  uint8_t lcd_char[8];
  
  // set display: [1][0][1][3][2][5][P][a]
  // address 0 corresponds to leftmost character on LCD display, 7 corresponds to rightmost character
  lcd_char[0] = lcd_digit_to_uint8(buffer[5]); 
  lcd_char[1] = lcd_digit_to_uint8(buffer[4]); 
  lcd_char[2] = lcd_digit_to_uint8(buffer[3]); 
  lcd_char[3] = lcd_digit_to_uint8(buffer[2]); 
  lcd_char[4] = lcd_digit_to_uint8(buffer[1]); 
  lcd_char[5] = lcd_digit_to_uint8(buffer[0]); 
  lcd_char[6] = 0x50;
  lcd_char[7] = 0x61; 
  
  uint32_t higher_char, lower_char;
  higher_char = (lcd_char[7] << 24) + (lcd_char[6] << 16) + (lcd_char[5] << 8) + lcd_char[4];
  lower_char = (lcd_char[3] << 24) + (lcd_char[2] << 16) + (lcd_char[1] << 8) + lcd_char[0];
  
  lcd_set_higher_characters(higher_char);
  lcd_set_lower_characters(lower_char);
}

void lcd_set_altitude_init_display (uint8_t *buffer){
  uint8_t lcd_char[8];
  
  // set display: [ ][9][9][9][9][ ][m][ ]
  // address 0 corresponds to leftmost character on LCD display, 7 corresponds to rightmost character
  lcd_char[0] = 0x20; 
  lcd_char[1] = lcd_digit_to_uint8(buffer[3]); 
  lcd_char[2] = lcd_digit_to_uint8(buffer[2]); 
  lcd_char[3] = lcd_digit_to_uint8(buffer[1]); 
  lcd_char[4] = lcd_digit_to_uint8(buffer[0]); 
  lcd_char[5] = 0x20; 
  lcd_char[6] = 0x6D;
  lcd_char[7] = 0x20; 
  
  uint32_t higher_char, lower_char;
  higher_char = (lcd_char[7] << 24) + (lcd_char[6] << 16) + (lcd_char[5] << 8) + lcd_char[4];
  lower_char = (lcd_char[3] << 24) + (lcd_char[2] << 16) + (lcd_char[1] << 8) + lcd_char[0];
  
  lcd_set_higher_characters(higher_char);
  lcd_set_lower_characters(lower_char);
}

//////////////////////////////////////////////////////////////////
// BMP Functions
//////////////////////////////////////////////////////////////////

void BMP390_init(void){

  // set target address and enable read
  // pwr_ctrl register 0x1b set to normal mode, enable 0x33;
  // osr 0x1c set to osr_t 000, osr_p 010;
  // odr 0x1d set to odr 010, 50 hz;
  // odr 0x1f set to odr 010, coef 3;
  i2c_set_register_address(0, 0x1D, 0x1C, 0x1B);
  i2c_set_write_data(0, 0x02, 0x02, 0x33);
  
  i2c_enable(0, 3);

  while(i2c_busy());
}

void BMP390_read_data(uint8_t address, uint8_t* data, uint8_t nbytes){

  uint32_t i;
  uint32_t lower_bytes, higher_bytes;
  
  // set target address and enable read
  i2c_set_register_address(0, 0, 0, address);
  
  // wait for not busy to enable read
  while(i2c_busy());
  i2c_enable(1, nbytes);
  
  // wait until data is valid
  while(!i2c_valid());
  
  // read from target registers
  // only consider lower bytes
  if( nbytes < 4 ){
    lower_bytes = i2c_get_lower_read_data();
    uint32_t mask = 0x000000FF;
    
    for(i = 0; i < nbytes; i++){
      data[i] = (uint8_t) ((lower_bytes & (mask << (8 * i))) >> (8 * i));
    }
  }
  else{
    lower_bytes = i2c_get_lower_read_data();
    higher_bytes = i2c_get_higher_read_data();
    uint32_t mask = 0x000000FF;
    
    for(i = 0; i < nbytes; i++){
      if(i < 4)
        data[i] = (uint8_t) ((lower_bytes & (mask << (8 * i))) >> (8 * i));
      else
        data[i] = (uint8_t) ((higher_bytes & (mask << (8 * (i - 4)))) >> (8 * (i - 4)));
    }
  }  

}

void BMP390_get_calib_coeff(BMP390_calib_data* calib_data){

  uint8_t buffer[6];

  // get T1, T2, T3 coefficients
  BMP390_read_data(0x31, buffer, 5);
  calib_data->t1 = (uint16_t) ( ((uint16_t)(buffer[1]) << 8) | buffer[0] );
  calib_data->t2 = (uint16_t) ( ((uint16_t)(buffer[3]) << 8) | buffer[2] );
  calib_data->t3 = (int8_t)   ( buffer[4] );
  
  // get P1, P2, P3, P4 coefficients
  BMP390_read_data(0x36, buffer, 6);
  calib_data->p1 = (int16_t) ( ((uint16_t)(buffer[1]) << 8) | buffer[0] );
  calib_data->p2 = (int16_t) ( ((uint16_t)(buffer[3]) << 8) | buffer[2] );
  calib_data->p3 = (int8_t)  ( buffer[4] );
  calib_data->p4 = (int8_t)  ( buffer[5] );
  
  // get P5, P6, P7, P8 coefficients
  BMP390_read_data(0x3C, buffer, 6);
  calib_data->p5 = (uint16_t) ( ((uint16_t)(buffer[1]) << 8) | buffer[0] );
  calib_data->p6 = (uint16_t) ( ((uint16_t)(buffer[3]) << 8) | buffer[2] );
  calib_data->p7 = (int8_t)   ( buffer[4] );
  calib_data->p8 = (int8_t)   ( buffer[5] );

  // get P9, P10, P11 coefficients
  BMP390_read_data(0x42, buffer, 4);
  calib_data->p9 =  (int16_t) ( ((uint16_t)(buffer[1]) << 8) | buffer[0] );
  calib_data->p10 = (int8_t)  ( buffer[2] );
  calib_data->p11 = (int8_t)  ( buffer[3] );
  
}

int64_t BMP390_compensate_temperature(uint32_t uncomp_temp, BMP390_calib_data* calib_data){

  /* translated from bmp390 library by Shifeng Li */
  /* https://github.com/libdriver/bmp390/blob/main/src/driver_bmp390.c */

  uint64_t partial_data1;
  uint64_t partial_data2;
  uint64_t partial_data3;
  int64_t partial_data4;
  int64_t partial_data5;
  int64_t partial_data6;
  int64_t comp_temp;
  
  /* calculate compensate temperature */
  partial_data1 = (uint64_t)(uncomp_temp - ((uint64_t)(calib_data->t1) << 8));
  partial_data2 = (uint64_t)(calib_data->t2 * partial_data1);                           // need to divide by 2^30
  partial_data3 = (uint64_t)(partial_data1 * partial_data1);
  partial_data4 = (int64_t)(((int64_t)partial_data3) * ((int64_t)calib_data->t3));      // need to divide by 2^48
  partial_data5 = ((int64_t)(((int64_t)partial_data2) << 18) + (int64_t)partial_data4); // need to divide by 2^48
  partial_data6 = (int64_t)(((int64_t)partial_data5) >> 32);                            // need to divide by 2^16
  
  calib_data->t_lin = partial_data6;
  
  //comp_temp = (int64_t)((partial_data6 * 25)  >> 14);     // multiply by 100
  comp_temp = (int64_t)(partial_data6  >> 16);
  
  return comp_temp;
  
}

int64_t BMP390_compensate_pressure(uint32_t uncomp_press, BMP390_calib_data* calib_data){

  /* translated from bmp390 library by Shifeng Li */
  /* https://github.com/libdriver/bmp390/blob/main/src/driver_bmp390.c */

  int64_t partial_data1;
  int64_t partial_data2;
  int64_t partial_data3;
  int64_t partial_data4;
  int64_t partial_data5;
  int64_t partial_data6;
  int64_t offset;
  int64_t sensitivity;
  uint64_t comp_press;
  
  /* calculate compensate pressure */
  partial_data1 = calib_data->t_lin * calib_data->t_lin;            // divide by 2^32
  partial_data2 = partial_data1 >> 6;                               // divide by 2^26
  partial_data3 = (partial_data2 * calib_data->t_lin) >> 8;         // divide by 2^34
  partial_data4 = (calib_data->p8 * partial_data3) >> 5;            // divide by 2^44
  partial_data5 = (calib_data->p7 * partial_data1) << 4;            // divide by 2^44
  partial_data6 = (calib_data->p6 * calib_data->t_lin) << 22;       // divide by 2^44
  offset = (int64_t)((int64_t)(calib_data->p5) << 47) + partial_data4 + partial_data5 + partial_data6; // divide by 2^44
  
  partial_data2 = (((int64_t)calib_data->p4) * partial_data3) >> 5;                          // divide by 2^66
  partial_data4 = (calib_data->p3 * partial_data1) << 2;                                     // divide by 2^66
  partial_data5 = ((int64_t)(calib_data->p2) - 16384) * ((int64_t)calib_data->t_lin) << 21;  // divide by 2^66
  sensitivity = (((int64_t)(calib_data->p1) - 16384) << 46) + partial_data2 + partial_data4 + partial_data5; // divide by 2^66
  
  partial_data1 = (sensitivity >> 24) * uncomp_press;                             // divide by 2^42
  partial_data2 = (int64_t)(calib_data->p10) * (int64_t)(calib_data->t_lin);      // divide by 2^64
  partial_data3 = partial_data2 + ((int64_t)(calib_data->p9) << 16);              // divide by 2^64
  partial_data4 = (partial_data3 * uncomp_press) >> 13;                           // divide by 2^51
  partial_data5 = ((partial_data4 / 10) * uncomp_press) >> 9;                            // divide by 10 then multiply by 10 to avoid overflow
  partial_data5 = (partial_data5 * 10);                                            // divide by 2^42   
  partial_data6 = (int64_t)((uint64_t)uncomp_press * (uint64_t)uncomp_press);
  partial_data2 = ((int64_t)(calib_data->p11) * (int64_t)(partial_data6)) >> 16;  // divide by 2^49
  partial_data3 = (partial_data2 * uncomp_press) >> 7;                            // divide by 2^42
  partial_data4 = (offset >> 2) + partial_data1 + partial_data5 + partial_data3;  // divide by 2^42
  
  //comp_press = (((uint64_t)partial_data4 * 25) >> 40);     // multiply by 100
  comp_press = ((uint64_t)partial_data4 >> 42);     // multiply by 100
  
  return comp_press;
  
}

//////////////////////////////////////////////////////////////////
// Algorithms, altitude and velocity calculation
//////////////////////////////////////////////////////////////////

uint32_t altitude_lut [20][2] = {
  {3742, 10876}, // p/p0 = 0.2273
  {4026, 10377}, // p/p0 = 0.2457
  {4353,  9869}, // p/p0 = 0.2657
  {4705,  9356}, // p/p0 = 0.2872
  {5087,  8833}, // p/p0 = 0.3105
  {5500,  8303}, // p/p0 = 0.3357
  {5946,  7766}, // p/p0 = 0.3629
  {6427,  7221}, // p/p0 = 0.3923
  {6948,  6667}, // p/p0 = 0.4241
  {7512,  6105}, // p/p0 = 0.4585
  {8122,  5534}, // p/p0 = 0.4957
  {8780,  4955}, // p/p0 = 0.5359
  {9493,  4367}, // p/p0 = 0.5794
  {10263, 3770}, // p/p0 = 0.6264
  {11094, 3166}, // p/p0 = 0.6771
  {11995, 2550}, // p/p0 = 0.7321
  {12966, 1927}, // p/p0 = 0.7914
  {14018, 1294}, // p/p0 = 0.8556
  {15155,  652}, // p/p0 = 0.9250
  {16384,    0}  // p/p0 = 1.0000
};

uint32_t calculate_altitude(uint32_t p, uint32_t p0){

  // height = h0 + Tb/0.0065 [(p/p0)^0.19 - 1]
  // g = 9.81
  // M = 0.02896968 molar mass of dry air
  // R = 8.31432 universal gas constant
  // p0 = pressure at h0 (101325 by default)
  // h0 = sea level (0 by default), probably set to constant 0, reducing one operation
  
  uint32_t altitude_estimate;
  
  /* (p/p0) value in lut is left shifted by 14 to store ints instead of floats */
  int pres_fraction = (p << 14) / p0;
 
  /* deal with edge cases first (the values outside of lut are capped to maximum and minimum values */
  if (pres_fraction < altitude_lut[0][0])
    altitude_estimate = altitude_lut[0][1];
  else if (pres_fraction >= altitude_lut[19][0])
    altitude_estimate = altitude_lut[19][1];
  else
    for(int i=0; i<19; i++){
      if(pres_fraction >= altitude_lut[i][0] && pres_fraction < altitude_lut[i+1][0]){
        int p1 = altitude_lut[i][0];
        int p2 = altitude_lut[i+1][0];
        int h1 = altitude_lut[i][1]; 
        int h2 = altitude_lut[i+1][1];
        altitude_estimate = h1 + (pres_fraction-p1)*(h2-h1)/(p2-p1);
                
        break;
      }
    }
    
  return altitude_estimate;
}

fpt previous_altitude = i2fpt(0);
uint32_t previous_time = 1234567;
fpt current_vsi = i2fpt(0);
fpt instant_vsi = i2fpt(0);


fpt kalman_state = i2fpt(0);      // Estimated vertical speed
fpt kalman_p = i2fpt(1);          // Estimation error covariance
fpt kalman_q = fl2fpt(0.001);     // Process noise covariance
fpt kalman_r = fl2fpt(0.1);       // Measurement noise covariance
fpt kalman_k = i2fpt(0);          // Kalman gain

fpt iir_state = i2fpt(0);          
fpt alpha = fl2fpt(0.15);


typedef struct {
    fpt values[VSI_QUEUE_SIZE];
    uint8_t head;
    uint8_t count;
} vsi_fifo_t;

vsi_fifo_t vsi_fifo = {0};

void vsi_fifo_push(fpt value) {
    vsi_fifo.values[vsi_fifo.head] = value;
    
    // Move head to next position (circular buffer)
    vsi_fifo.head = (vsi_fifo.head + 1) % VSI_QUEUE_SIZE;
    
    // Increment count if not full yet
    if (vsi_fifo.count < VSI_QUEUE_SIZE) {
        vsi_fifo.count++;
    }
}

fpt vsi_fifo_average(void) {
    if (vsi_fifo.count == 0) {
        return i2fpt(0);
    }
    
    fpt sum = i2fpt(0);
    for (uint8_t i = 0; i < vsi_fifo.count; i++) {
        sum = fpt_add(sum, vsi_fifo.values[i]);
    }

    return fpt_div(sum, i2fpt(vsi_fifo.count));
}

fpt calculate_vertical_speed(fpt current_altitude) 
{
    uint32_t current_time = time(NULL);

    fpt time_diff = i2fpt(0);
    if (previous_time != 1234567) {
        time_diff = fpt_sub(i2fpt(current_time), i2fpt(previous_time));

        if (time_diff > fl2fpt(1.0)) {
            fpt altitude_diff = fpt_sub(current_altitude, previous_altitude);

            instant_vsi = fpt_div(altitude_diff, time_diff);

            vsi_fifo_push(instant_vsi);

            current_vsi = vsi_fifo_average();

            previous_altitude = current_altitude;
            previous_time = current_time;
        }
    } else {
        previous_altitude = current_altitude;
        previous_time = current_time;
    }

    return current_vsi;
}


//////////////////////////////////////////////////////////////////
// Pressure and Altitude initialisation
//////////////////////////////////////////////////////////////////

uint32_t init_update_digit(uint32_t Value) {
  // Avoid exceeding 10, return to 0 after exceeding 10
  if(Value + 1 == 10) 
    return 0;
    
  return (Value + 1);
}

uint32_t pressure_initialisation(void){
  uint8_t digits[6] = {0,0,0,0,0,0};
  uint8_t current_digit = 5;
  uint32_t p0;
  
  uint32_t buttons_pressed;
  bool nmode_pressed, ntrip_pressed;
  
  while(current_digit >= 0){
    lcd_set_pressure_init_display(digits);
    
    /* update display */
    while(lcd_busy()) ;
    lcd_refresh_display();
  
    while(! buttons_valid()); // wait until button pressed
  
    if(buttons_valid()){
      buttons_pressed = buttons_read();
      nmode_pressed = buttons_pressed & 0x01;
      ntrip_pressed = buttons_pressed & 0x02;
    }
    
    // move to next digit, end initialization if already at digit 0
    if(nmode_pressed){
      if(current_digit == 0) 
        break;
      else
        current_digit = current_digit - 1;	   
    }
    // update digit to be displayed
    else if(ntrip_pressed){
      digits[current_digit] = init_update_digit(digits[current_digit]);
    }
  }
  
  p0 = (digits[5] * 100000) + (digits[4] * 10000) + (digits[3] * 1000) + (digits[2] * 100) + (digits[1] * 10) + digits[0];
  
  if(p0 == 0) p0 = 101325; // reset value to standard sea level pressure to prevent division by 0 errors (pressure 0 is out of range anyways)
   
  return p0;
}

uint32_t altitude_initialisation(void){
  uint8_t digits[4] = {0,0,0,0};
  uint8_t current_digit = 3;
  uint32_t p0;
  
  uint32_t buttons_pressed;
  bool nmode_pressed, ntrip_pressed;
  
  while(current_digit >= 0){
    lcd_set_altitude_init_display(digits);
    
    /* update display */
    while(lcd_busy()) ;
    lcd_refresh_display();
  
    while(! buttons_valid()); // wait until button pressed
  
    if(buttons_valid()){
      buttons_pressed = buttons_read();
      nmode_pressed = buttons_pressed & 0x01;
      ntrip_pressed = buttons_pressed & 0x02;
    }
    
    // move to next digit, end initialization if already at digit 0
    if(nmode_pressed){
      //Update the corresponding digits values based on the current Sea_Level_Pressure_Set_States.
      if(current_digit == 0) 
        break;
      else
        current_digit = current_digit - 1;	   
    }
    // update digit to be displayed
    else if(ntrip_pressed){
      digits[current_digit] = init_update_digit(digits[current_digit]);
    }
  }
  
  p0 = (digits[3] * 1000) + (digits[2] * 100) + (digits[1] * 10) + digits[0];
   
  return p0;
}

//////////////////////////////////////////////////////////////////
// Main Function
//////////////////////////////////////////////////////////////////

int main(void) {
  
  /* 32.768kHz -> 32768 ticks for 1s
     sys_tick_counter global variable or time(NULL) returns time since program starts in seconds
  */
  SysTick_Init(32768);  
  
  uint8_t read_buffer[6] = {0, 0, 0, 0, 0, 0};
  
  lcd_init();
  
  /* initialize bmp sensor */
  i2c_set_device_address(0x77);                // Device address = 0b1110111 for bmp390 pressure sensor
  BMP390_init();
  BMP390_get_calib_coeff(&calib_data_global);
  
  /* variables for event loop */
  uint32_t buttons_pressed;
  bool nmode_pressed, ntrip_pressed, both_pressed;
  uint32_t display_mode = 0;  // current mode, 0 pressure, 1 altitude, 2 trip timer, 3 VSI, 4 initialisation
  uint32_t p0 = 101325;
  uint32_t altitude = 0;
  fpt velocity = 0;
  uint32_t uncomp_pres, uncomp_temp;
  int64_t pressure_Pa;
  int64_t temperature_C;

  // repeat forever (embedded programs generally do not terminate)
  while(1){
    /* read pressure (lower 3 bytes) + temperature (higher 3 bytes), and compensate readings */
    BMP390_read_data(0x04, read_buffer, 6);
    uncomp_pres = ((uint32_t) (read_buffer[2]) << 16) + ((uint32_t) (read_buffer[1]) << 8) + (uint32_t) (read_buffer[0]);
    uncomp_temp = ((uint32_t) (read_buffer[5]) << 16) + ((uint32_t) (read_buffer[4]) << 8) + (uint32_t) (read_buffer[3]);
    
    temperature_C = BMP390_compensate_temperature(uncomp_temp, &calib_data_global); // temperature is unused
    pressure_Pa = BMP390_compensate_pressure(uncomp_pres, &calib_data_global);
    //pressure_Pa = uncomp_temp;
    
    /* altitude and velocity calculation algorithms */
    altitude = calculate_altitude(pressure_Pa, p0);
    velocity = calculate_vertical_speed(i2fpt(altitude));
    
    /* cap values before display */
    if(altitude > 9999) altitude = 9999;
    if(altitude < 0) altitude = 0;
  
    /* check for button being pressed */
    nmode_pressed = 0;
    ntrip_pressed = 0;
    both_pressed = 0;
    if(buttons_valid()){
      buttons_pressed = buttons_read();
      nmode_pressed = buttons_pressed & 0x01;
      ntrip_pressed = buttons_pressed & 0x02;
      both_pressed = buttons_pressed & 0x04;
    }
    
    /* handle button presses */
    if(nmode_pressed){   // change lcd display mode (does not set to initialisation)
      switch(display_mode){
        case 0: display_mode = 1; // pressure -> altitude
	        break;
	case 1: display_mode = 2; // altitude -> trip timer
	        break;
	case 2: display_mode = 3; // trip timer -> vsi
	        break;
	case 3: display_mode = 0; // vsi -> pressure
	        break;
        default: display_mode = 0;
	        break;
      }
    }
    
    if(ntrip_pressed){   // reset trip timer to 0 (just reset sys_tick_timer)
      sys_tick_counter = 0;
    }
    
    if(both_pressed){   
      if(display_mode == 0){
        p0 = pressure_initialisation();
      }
      if(display_mode == 1){
        uint32_t altitude_init = altitude_initialisation();
        int pres_fraction_estimate;
	
	// inverse of altitude algorithm
        if (altitude_init >= altitude_lut[0][1])
          pres_fraction_estimate = altitude_lut[0][0];
        else if (altitude_init < altitude_lut[19][1])
          pres_fraction_estimate = altitude_lut[19][0];
        else
          for(int i=0; i<19; i++){
            if(altitude_init < altitude_lut[i][1] && altitude_init >= altitude_lut[i+1][1]){
              int p1 = altitude_lut[i][0];
              int p2 = altitude_lut[i+1][0];
              int h1 = altitude_lut[i][1]; 
              int h2 = altitude_lut[i+1][1];
              pres_fraction_estimate = p1 + ((int)altitude_init-h1)*(p2-p1)/(h2-h1);
                
              break;
            }
          }
	  
	p0 = (pressure_Pa << 14) / pres_fraction_estimate;
      }
    }
    
    /* set lcd values */
    switch(display_mode){
      case 0: lcd_set_pressure_display(pressure_Pa);
              break;
      case 1: lcd_set_altitude_display(altitude);
              break;
      case 2: lcd_set_timer_display(time(NULL));
              break;
      case 3: lcd_set_vsi_display(velocity);
              break;
    }
    
    /* update display */
    while(lcd_busy()) ;
    lcd_refresh_display();
  }
}

