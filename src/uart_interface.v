`timescale 1ns / 10ps

module uart_interface #(
    // Module parameters for clock rate and baud rate
    parameter integer CLOCK_RATE = 200_000_000,  // System clock frequency in Hz
    parameter integer BAUD_RATE = 9600         // Desired baud rate in bps
)(
    input  wire       clk,                // System clock
    input  wire       rst_n,              // Active-low asynchronous reset
    input  wire       tx_start,           // Trigger to start data transmission
    input  wire [7:0] tx_data_in,         // Data to be transmitted
    input  wire       rx_serial_in,       // Serial data input for reception
    output wire       tx_serial_out,      // Serial data output for transmission
    output wire [7:0] rx_data_out,        // Received data
    output wire       rx_ready,           // Indicates received data is ready
    output wire       parity_error,       // Parity Error
    output wire       tx_busy             // Indicates transmission is in progress
);


    wire baud_clk;          // Wire to connect the baud clock to Tx and Rx modules
    wire tx_start_sync;     // This will be the synchronized tx_start signal in the baud clock domain
    wire rx_serial_in_sync; // This will be the synchronized rx_serial_in signal in the baud clock domain
    
    // Instantiate the XPM CDC macro for the tx_start signal
    xpm_cdc_single #(
        .DEST_SYNC_FF(2), // Number of flip-flops in the destination domain, usually 2 or more for reliability
        .INIT_SYNC_FF   (0),
        .SIM_ASSERT_CHK (0),
        .SRC_INPUT_REG(0) // 0 if the source signal is already registered; otherwise 1
    ) xpm_cdc_tx_start (
        .src_clk(clk),           // Source clock
        .dest_clk(clk),          // Destination clock
        .src_in(tx_start),       // Input signal in the source clock domain
        .dest_out(tx_start_sync) // Output signal synchronized to the destination clock domain
    );
    
    // Instantiate the XPM CDC macro for the tx_start signal
    xpm_cdc_single #(
        .DEST_SYNC_FF(2), // Number of flip-flops in the destination domain, usually 2 or more for reliability
        .INIT_SYNC_FF   (0),
        .SIM_ASSERT_CHK (0),
        .SRC_INPUT_REG(0) // 0 if the source signal is already registered; otherwise 1
    ) xpm_cdc_rx_serial_in (
        .src_clk(clk),               // Source clock
        .dest_clk(baud_clk),         // Destination clock
        .src_in(rx_serial_in),       // Input signal in the source clock domain
        .dest_out(rx_serial_in_sync) // Output signal synchronized to the destination clock domain
    );
    
    // Instantiate the Baud Rate Generator
    baud_rate_generator#(
       .CLOCK_RATE(CLOCK_RATE),  // System clock frequency in Hz
       .BAUD_RATE(BAUD_RATE)     // Desired baud rate in bps
    ) baud_gen (
        .clk(clk),
        .rst_n(rst_n),
        .baud_clk(baud_clk)
    );
    
    // Instantiate the Tx Module
    uart_tx tx_module (
        .clk(clk),
        .baud_clk(baud_clk),
        .rst_n(rst_n),
        .data_in(tx_data_in),
        .tx_start(tx_start_sync),
        .txd(tx_serial_out),
        .tx_busy(tx_busy)
    );
    
    // Instantiate the Rx Module
    uart_rx #(
        .CLOCK_RATE(CLOCK_RATE),
        .BAUD_RATE(BAUD_RATE)
    ) rx_module (
        .clk(clk),
        .rst_n(rst_n),
        .baud_clk(baud_clk),
        .rxd(rx_serial_in_sync),
        .data_out(rx_data_out),
        .rx_ready(rx_ready),
        .parity_error(parity_error)
    );
    
endmodule
