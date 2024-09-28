`timescale 1ns / 10ps

module uart_tx  #(
    // Module parameters for clock rate and baud rate
    parameter integer CLOCK_RATE = 200_000_000,  // System clock frequency in Hz
    parameter integer BAUD_RATE = 9600           // Desired baud rate in bps
)(
    input  wire       clk,         // System Clock input
    input  wire       baud_clk,
    input  wire       rst_n,       // Active-low asynchronous reset
    input  wire [7:0] data_in,     // 8-bit data input
    input  wire       tx_start,    // Signal to start transmission
    output reg        txd,         // Transmitted serial data
    output reg        tx_busy      // Transmitter is busy
);      

    // State encoding using localparam
    localparam IDLE       = 0;
    localparam START_BIT  = 1;
    localparam DATA_BITS  = 2;
    localparam STOP_BIT   = 3;
    
    // Current and next state
    reg [1:0] fsm_state;
    
    // Internal signals
    reg [3:0] bit_index   = 0;  // Index for data bits
    reg [7:0] data_buffer = 0;  // Buffer to hold data being transmitted
    reg       parity_bit  = 0;  // Calculated parity bit
    reg       tx_start_r;
    // Flags for baud clock events
    reg baud_clk_edge;             // Detect baud clock rising edge
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_clk_edge <= 0;
        end else begin
            baud_clk_edge <= baud_clk;  // Save the previous baud clock state for edge detection
        end
    end
    
    wire baud_clk_rising = (baud_clk && !baud_clk_edge);  // Detect baud clock rising edge
    
    // State machine for transmitting data
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_buffer <= 0;
            bit_index   <= 0;
            fsm_state   <= IDLE;
            txd         <= 1'b1; // Idle state of the line is high
            tx_busy     <= 1'b0;
            parity_bit  <= 0;
            tx_start_r  <= 0;
        end else begin
            case (fsm_state)
                IDLE: begin
                    bit_index <= 0;
                    tx_busy   <= 1'b0;
                    tx_start_r <= tx_start;
                    if (!tx_start_r & tx_start) begin
                        data_buffer <= data_in;   // Load data to transmit
                        parity_bit  <= ^data_in;  // Recalculate even parity when loading new data
                        tx_busy     <= 1'b1;
                        fsm_state   <= START_BIT;
                    end
                end
    
                START_BIT: begin
                    if (baud_clk_rising) begin
                        txd <= 0; // Start bit
                        if (bit_index == 0) begin
                            fsm_state <= DATA_BITS;
                        end
                    end
                end
                
                DATA_BITS: begin
                    if (baud_clk_rising) begin
                        if (bit_index < 8) begin
                            txd       <= data_buffer[bit_index];
                            bit_index <= bit_index + 1;
                        end else begin
                            txd       <= parity_bit; // Send the parity bit now not to waste one baud clock
                            fsm_state <= STOP_BIT;
                        end 
                    end
                end
                
                STOP_BIT: begin
                    if (baud_clk_rising) begin
                        txd       <= 1;    // Stop bit
                        tx_busy   <= 1'b0; // Mark transmission as complete, ready for next
                        bit_index <= 0;
                        fsm_state <= IDLE;
                    end
                end
                
                default: begin 
                    fsm_state <= IDLE;
                    txd       <= 1'b1;
                end
            endcase
        end
    end

endmodule
