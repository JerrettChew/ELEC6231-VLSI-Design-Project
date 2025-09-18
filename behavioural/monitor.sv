// This special monitor file monitors signals in the system.sv module

initial
   $timeformat(0,2, " s", 10 );

always #1s
   $display("%t",$time );

always @(SENSOR.pressure_Pa)
   $display("       Pressure %0d Pa", SENSOR.pressure_Pa );

initial
   $monitor("           Mode %0d", mode_index );

