module uart_rx (
    input  wire       clk,           // System clock input (200 MHz)
    input  wire       baud_clk,      // Baud clock (from baud rate generator)
    input  wire       rst_n,         // Active-low asynchronous reset
    input  wire       rxd,           // Received serial data
    output reg [7:0]  data_out,      // 8-bit data output
    output reg        rx_ready,      // Data byte received and ready
    output reg        parity_error   // Parity error flag
);

    // State encoding
    localparam IDLE         = 0;
    localparam START_BIT    = 1;
    localparam DATA_BITS    = 2;
    localparam STOP_BIT     = 3;
    localparam CHECK_PARITY = 4;
    localparam STORE_BYTE   = 5;

    // Current and next state
    reg [2:0] fsm_state;

    // Internal signals
    reg [3:0] bit_index = 0;       // Index for data bits
    reg [7:0] shift_register = 0;  // Shift register for incoming data
    reg calculated_parity = 0;     // Calculated parity for comparison
    reg received_parity_bit = 0;

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

    // State machine for receiving data
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fsm_state           <= IDLE;
            data_out            <= 0;
            bit_index           <= 0;
            rx_ready            <= 0;
            parity_error        <= 0;
            calculated_parity   <= 0;
            received_parity_bit <= 0;
            shift_register      <= 0;
        end else begin
            case (fsm_state)
                IDLE: begin
                    rx_ready   <= 0;
                    bit_index  <= 0;
                    if (baud_clk_rising && !rxd) begin  // Start bit detected on baud clock
                        calculated_parity <= 0; // Reset parity calculation
                        parity_error      <= 0;
                        shift_register    <= 0;
                        fsm_state         <= DATA_BITS; // Start receiving data bits
                    end 
                end

                DATA_BITS: begin
                    if (baud_clk_rising) begin
                        if (bit_index < 8) begin 
                            shift_register[bit_index] <= rxd;
                            calculated_parity         <= calculated_parity ^ rxd; // Update parity calculation
                            bit_index                 <= bit_index + 1;
                        end else begin
                            received_parity_bit <= rxd;      // Capture the parity bit when bit_index == 8
                            fsm_state           <= STOP_BIT; // Move to stop bit reception
                        end
                    end
                end

                STOP_BIT: begin
                    if (baud_clk_rising) begin
                        if (rxd) begin  // Stop bit verified
                            fsm_state <= CHECK_PARITY;
                        end else begin
                            fsm_state <= IDLE;  // Error: Invalid stop bit
                        end
                    end
                end

                CHECK_PARITY: begin
                    if ((calculated_parity ^ received_parity_bit) == 0) begin
                        fsm_state <= STORE_BYTE;
                    end else begin
                        parity_error <= 1;
                        fsm_state    <= IDLE; // Parity error, discard byte
                    end
                end

                STORE_BYTE: begin
                    data_out  <= shift_register;
                    rx_ready  <= 1;
                    fsm_state <= IDLE;
                end

                default: fsm_state <= IDLE;
            endcase
        end
    end
endmodule