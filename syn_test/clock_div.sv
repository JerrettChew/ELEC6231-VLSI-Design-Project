module clock_divider (
    input clk_in,       // 50 MHz clock input
    input rst_n,        // Active low reset
    input enable,       // enable switch
    output logic clk_out       // 32.768 kHz clock output
);

    // The division factor (rounded to the nearest integer)
    //localparam DIV_FACTOR = 1524;
    localparam DIV_FACTOR = 762;

    // Counter to divide the input clock
    reg [31:0] counter; // A 32-bit counter should be sufficient for this range

    // Always block triggered by the input clock
    always @(posedge clk_in or negedge rst_n) begin
        if (~rst_n) begin
            // Reset the counter and output clock
            counter <= 32'd0;
            clk_out <= 1'b0;
        end else begin
            if (counter == (DIV_FACTOR - 1)) 
	      begin
                // Toggle the output clock
                clk_out <= ~clk_out;
                // Reset the counter
                counter <= 32'd0;
              end 
	    else if ( enable  == 0 )
	      begin
                // Increment the counter
                counter <= counter + 1;
              end
        end
    end

endmodule
