`timescale 1ns/1ps

module tb_uart_loopback;

    // Parameters
    localparam CLOCK_RATE = 200_000_000;  // 200 MHz system clock
    localparam BAUD_RATE = 115200;        // 115200 baud rate
    localparam CLK_PERIOD = 5;            // Clock period for 200 MHz = 5 ns
    localparam MESSAGE_LEN = 13;          // Length of the message "Hello, World!"

    // Testbench signals
    reg clk;
    reg rst_n;
    reg tx_start;
    reg [7:0] tx_data_in;
    wire tx_serial_out;
    wire [7:0] rx_data_out;
    wire rx_ready;
    wire parity_error;
    wire tx_busy;

    reg rx_serial_in;

    // Register to hold the message "Hello, World!"
    reg [8*MESSAGE_LEN-1:0] message;  // Packed register to hold the message

    integer i, j;

    // UART Interface Instance
    uart_interface #(
        .CLOCK_RATE(CLOCK_RATE),
        .BAUD_RATE(BAUD_RATE)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .tx_start(tx_start),
        .tx_data_in(tx_data_in),
        .rx_serial_in(rx_serial_in),
        .tx_serial_out(tx_serial_out),
        .rx_data_out(rx_data_out),
        .rx_ready(rx_ready),
        .parity_error(parity_error),
        .tx_busy(tx_busy)
    );
    
    // Clock generation
    always begin
        #CLK_PERIOD clk = ~clk;
    end
    
    // Task to send a character over UART with proper tx_start pulsing and checks
    task uart_send_byte (input [7:0] byte);
        begin
            // Wait until the transmitter is not busy
            wait (!tx_busy);
    
            // Load the data to transmit first
            tx_data_in = byte;
    
            // Pulse tx_start high and wait for at least one clock cycle
            tx_start = 1'b1;
            # (10 * CLK_PERIOD);  // Small delay to hold tx_start high
            tx_start = 1'b0;
        end
    endtask

    
    // Transmission process: Sends each character in the message
    initial begin
        // Initialize transmission-related signals
        tx_start = 0;
        tx_data_in = 8'b0;  

        // Initialize the message: "Hello, World!"
        message = "Hello, World!";
        
        // Wait until reset is deasserted
        wait(rst_n == 1'b1);

        // Send each character in the message
        for (i = 0; i < MESSAGE_LEN; i = i + 1) begin
            uart_send_byte(message[8*(MESSAGE_LEN-1-i) +: 8]);  // Extract each 8-bit character
        end
    end

    // Reception process: Waits for rx_ready and displays received data
    initial begin
        // Initialize signals
        clk = 0;
        rst_n = 0;
        rx_serial_in = 1'b1; // Idle state for RX line
        
        // Apply reset
        #100;
        rst_n = 1;
        
        // Loop to receive each character
        for (j = 0; j < MESSAGE_LEN; j = j + 1) begin
            wait (rx_ready == 1'b1);
            $display("Received data[%0d]: %c", j, rx_data_out);
        end
        
        // Finish simulation after all characters are received
        #1000; // Additional delay to ensure all transmissions are complete
        $finish;
    end
    
    // Loopback: Connect TX to RX
    always @(posedge clk) begin
        rx_serial_in <= tx_serial_out;
    end

endmodule
