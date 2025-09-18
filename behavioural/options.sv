///////////////////////////////////////////////////////////////////////
//
// options.sv - 2024/2025
//
//    This options file sets a number of compile time options
//    which are necessary for successful simulation
//
///////////////////////////////////////////////////////////////////////

// The following line specifies the clock period
//
`define clock_period 30517.6ns
//
// The default frequency of 32.768kHz is based on a freely available clock chip
// If you choose to vary this frequency you should base your new frequency
//  on another freely available clock chip and you should give details in your
//  design documentation (technical note)

// The following line indicates that a file "monitor.sv" exists and contains
// custom monitoring information
//
//`define special_monitor

// The following line indicates that the model does not support scan path
//  signals
//   (Test, SDI, SDO)
//
`define no_scan_signals

// The following line indicates that the model supports separate scan control
//  signals
//   (Test, ScanEnable)
//
//`define scan_enable

// The following line indicates that the model does not properly simulate
//  the pullup behaviour of the pads and an external pullup should be
//  simulated.
//  (this overcomes a problem with the simulation of the ICUP pad cell) 
//
//`define external_pullup

// The following line indicates that synchronisation of inputs is a function
//  of the wrapper file: "altimeter.sv". This is a good place to do the
//  synchronisation if you wish to control the choice of gates used in the
//  synchroniser. 
//
//`define synchronise_inputs_within_wrapper

// The following line indicates that synchronisation of reset is a function
//  of the wrapper file: "altimeter.sv". This is a good place to do the
//  synchronisation if you wish to control the choice of gates used in the
//  synchroniser. 
//
//`define synchronise_reset_within_wrapper

// The following line indicates that the stimulus should ensure that the
//  hall effect inputs and button signals are well behaved to avoid setup
//  and hold violations during simulation.
//
//`define sanitise_input

// The following line specifies a start-up time for the sports altimeter
// After reset, the testbench should wait for this time before expecting
// the device to work
//
`define start_up_time 50ms

// Uncomment the following line to indicate that your sports altimeter
//  supports an OLED display
//
//`define include_oled

// Uncomment the following line to indicate that your sports altimeter
//  supports an Alarm buzzer
//
//`define include_alarm

// Uncomment the following line to indicate that the altimeter sensor
//  is a simple one which returns the pressure in Pascals
//
//`define use_simple_sensor

// Uncomment ONE of the following lines to indicate that the alitimeter
//  is designed for a specific purpose
//  (the default is for a multi-purpose altimeter)
//
`define mountain_sports
//`define aerial_sports

// The following line specifies the number of operating modes
//
`define num_modes 4

// The following lines specify the sequence of operating modes after reset
//
`define Mode0 Pressure
`define Mode1 Altitude
`define Mode2 TripTime
`define Mode3 VerticalSpeed
