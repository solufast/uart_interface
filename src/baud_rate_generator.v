`timescale 1ns / 10ps

module baud_rate_generator#(
    // Module parameters for clock frequency and baud rate
    parameter integer CLOCK_RATE = 200_000_000,  // System clock frequency in Hz
    parameter integer BAUD_RATE = 9600          // Desired baud rate in bps
)
(
    input wire clk,         // System clock input
    input wire rst_n,       // Active-low asynchronous reset
    output reg baud_clk     // Baud rate clock output
);

    // Calculate the number of system clock cycles for a quarter of the baud period
    localparam integer BAUD_PERIOD_COUNTER = CLOCK_RATE / (4 * BAUD_RATE);

    // Counter to track the number of clock cycles
    reg [31:0] counter = 0;

    // Baud rate clock generation logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset condition
            counter <= 0;
            baud_clk <= 0;
        end else begin
            if (counter >= BAUD_PERIOD_COUNTER - 1) begin
                // Reset counter and toggle baud clock
                counter <= 0;
                baud_clk <= ~baud_clk;
            end else begin
                // Increment counter
                counter <= counter + 1;
            end
        end
    end
endmodule
