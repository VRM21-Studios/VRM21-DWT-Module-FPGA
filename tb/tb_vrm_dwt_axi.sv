`timescale 1ns / 1ps

// =============================================================================
// TESTBENCH: tb_vrm_dwt_axi
// =============================================================================
// Verifies the Level-1 Discrete Wavelet Transform processing path, including
// AXI4-Lite coefficient configuration and AXI4-Stream data processing.
//
// Test sequence:
//   1. Apply system reset.
//   2. Load wavelet coefficients from a memory file.
//   3. Configure the coefficient registers through AXI4-Lite.
//   4. Apply a stereo impulse to the AXI4-Stream input.
//   5. Record the low-pass and high-pass subband outputs to a CSV file.
// =============================================================================

module tb_vrm_dwt_axi;

// =========================================================================
// 1. SYSTEM CLOCK AND RESET
// =========================================================================
reg clk;
reg rstn;

// 100 MHz system clock with a 10 ns period.
always #5 clk = ~clk;

// =========================================================================
// 2. AXI4-LITE INTERFACE SIGNALS
// =========================================================================

// Write Address Channel
reg  [5:0]  s_axi_awaddr = 0;
reg         s_axi_awvalid = 0;
wire        s_axi_awready;

// Write Data Channel
reg  [31:0] s_axi_wdata = 0;
reg         s_axi_wvalid = 0;
wire        s_axi_wready;

// Write Response Channel
wire [1:0]  s_axi_bresp;
wire        s_axi_bvalid;
reg         s_axi_bready = 0;

// Read Address Channel
reg  [5:0]  s_axi_araddr = 0;
reg         s_axi_arvalid = 0;
wire        s_axi_arready;

// Read Data Channel
wire [31:0] s_axi_rdata;
wire [1:0]  s_axi_rresp;
wire        s_axi_rvalid;
reg         s_axi_rready = 0;

// =========================================================================
// 3. AXI4-STREAM INTERFACES
// =========================================================================

// Input: 32-bit stereo audio stream.
reg  [31:0] s_axis_tdata;
reg         s_axis_tvalid;
reg         s_axis_tlast;
wire        s_axis_tready;

// Output: 64-bit packed wavelet subbands.
wire [63:0] m_axis_tdata;
wire        m_axis_tvalid;
wire        m_axis_tlast;
reg         m_axis_tready;

// =========================================================================
// 4. DEVICE UNDER TEST
// =========================================================================
vrm_dwt_axi #(
    .C_S_AXI_ADDR_WIDTH(6),
    .S_AXIS_DATA_WIDTH(32),
    .M_AXIS_DATA_WIDTH(64),
    .NTAPS(8)
) DUT (
    .clk(clk),
    .rstn(rstn),

    .s_axi_awaddr(s_axi_awaddr),
    .s_axi_awvalid(s_axi_awvalid),
    .s_axi_awready(s_axi_awready),

    .s_axi_wdata(s_axi_wdata),
    .s_axi_wvalid(s_axi_wvalid),
    .s_axi_wready(s_axi_wready),

    .s_axi_bresp(s_axi_bresp),
    .s_axi_bvalid(s_axi_bvalid),
    .s_axi_bready(s_axi_bready),

    .s_axi_araddr(s_axi_araddr),
    .s_axi_arvalid(s_axi_arvalid),
    .s_axi_arready(s_axi_arready),

    .s_axi_rdata(s_axi_rdata),
    .s_axi_rresp(s_axi_rresp),
    .s_axi_rvalid(s_axi_rvalid),
    .s_axi_rready(s_axi_rready),

    .s_axis_tdata(s_axis_tdata),
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tready(s_axis_tready),
    .s_axis_tlast(s_axis_tlast),

    .m_axis_tdata(m_axis_tdata),
    .m_axis_tvalid(m_axis_tvalid),
    .m_axis_tready(m_axis_tready),
    .m_axis_tlast(m_axis_tlast)
);

// =========================================================================
// AXI4-LITE WRITE TASK
// =========================================================================
// Performs a complete AXI4-Lite write transaction.
//
// The address and data channels are presented simultaneously and remain
// valid until both channels have been accepted by the DUT. The task then
// waits for the write response.
// =========================================================================
task axi_write(
    input [5:0]  addr,
    input [31:0] data
);
    begin
        @(posedge clk);

        s_axi_awaddr  = addr;
        s_axi_awvalid = 1'b1;

        s_axi_wdata   = data;
        s_axi_wvalid  = 1'b1;

        s_axi_bready  = 1'b1;

        // Wait until the DUT accepts both address and write data.
        while (!(s_axi_awready && s_axi_wready))
            @(posedge clk);

        // Deassert the valid signals after the write request is accepted.
        s_axi_awvalid = 1'b0;
        s_axi_wvalid  = 1'b0;

        // Wait for the AXI4-Lite write response.
        while (!s_axi_bvalid)
            @(posedge clk);

        s_axi_bready = 1'b0;
    end
endtask

// =========================================================================
// 5. TEST SEQUENCE AND CSV LOGGER
// =========================================================================
integer f_out;
integer i;

// Wavelet low-pass filter coefficient storage.
reg signed [15:0] h0_mem [0:7];

initial begin

    // ---------------------------------------------------------------------
    // INITIAL SIGNAL VALUES
    // ---------------------------------------------------------------------
    clk = 0;
    rstn = 0;
    i = 0;

    s_axis_tdata  = 0;
    s_axis_tvalid = 0;
    s_axis_tlast  = 0;

    // Keep the output interface ready throughout this test.
    m_axis_tready = 1'b1;

    // ---------------------------------------------------------------------
    // LOAD WAVELET COEFFICIENTS
    // ---------------------------------------------------------------------
    $readmemh("sym4_lpf.mem", h0_mem);

    // ---------------------------------------------------------------------
    // CREATE CSV OUTPUT FILE
    // ---------------------------------------------------------------------
    f_out = $fopen("dwt_output.csv", "w");
    $fdisplay(f_out, "Time(ns),Low_L,Low_R,High_L,High_R");

    // ---------------------------------------------------------------------
    // RESET SEQUENCE
    // ---------------------------------------------------------------------
    $display("=========================================================");
    $display(" VRM21 LEVEL-1 DWT AXI VERIFICATION");
    $display("=========================================================");

    $display("[SYSTEM] Applying reset...");

    #100;
    rstn = 1'b1;

    #50;

    $display("[SYSTEM] Reset released.");

    // ---------------------------------------------------------------------
    // CONFIGURE WAVELET COEFFICIENTS THROUGH AXI4-LITE
    // ---------------------------------------------------------------------
    $display("---------------------------------------------------------");
    $display("[AXI-LITE] Configuring wavelet filter coefficients...");

    for (i = 0; i < 8; i = i + 1) begin
        axi_write(
            6'h04 + (i * 4),
            {{16{h0_mem[i][15]}}, h0_mem[i]}
        );

        $display(
            "           Register 0x%02X <= 0x%04h",
            6'h04 + (i * 4),
            h0_mem[i]
        );
    end

    $display("[AXI-LITE] Coefficient configuration completed.");
    $display("---------------------------------------------------------");

    #50;

    // ---------------------------------------------------------------------
    // APPLY AXI4-STREAM IMPULSE INPUT
    // ---------------------------------------------------------------------
    $display("[AXI-STREAM] Starting stereo impulse test...");

    @(posedge clk);

    // Sample 0: Zero-valued stereo sample.
    s_axis_tvalid <= 1'b1;
    s_axis_tdata  <= {16'd0, 16'd0};

    @(posedge clk);
    while (!s_axis_tready)
        @(posedge clk);

    // Sample 1: Full-scale stereo impulse.
    // This stimulus is used to observe the low-pass and high-pass
    // wavelet filter responses.
    s_axis_tdata <= {16'h7FFF, 16'h7FFF};

    @(posedge clk);
    while (!s_axis_tready)
        @(posedge clk);

    // Remaining samples: Zero-valued samples to capture the filter
    // response following the impulse.
    for (i = 0; i < 30; i = i + 1) begin

        s_axis_tdata <= {16'd0, 16'd0};

        // Mark the final input sample.
        if (i == 29)
            s_axis_tlast <= 1'b1;

        @(posedge clk);

        while (!s_axis_tready)
            @(posedge clk);
    end

    // End the AXI4-Stream transaction.
    s_axis_tvalid <= 1'b0;
    s_axis_tlast  <= 1'b0;

    $display("[AXI-STREAM] Input sequence completed.");

    // ---------------------------------------------------------------------
    // WAIT FOR THE PROCESSING PIPELINE TO DRAIN
    // ---------------------------------------------------------------------
    #500;

    $display("---------------------------------------------------------");
    $display("[RESULT] Simulation completed successfully.");
    $display("[RESULT] Output data written to: dwt_output.csv");
    $display("=========================================================");

    $fclose(f_out);
    $finish;
end

// =========================================================================
// CSV OUTPUT LOGGER
// =========================================================================
// Record every successful AXI4-Stream output transaction.
//
// Output packing format:
//   {High_R, High_L, Low_R, Low_L}
// =========================================================================
always @(posedge clk) begin
    if (m_axis_tvalid && m_axis_tready) begin
        $fdisplay(
            f_out,
            "%0t,%d,%d,%d,%d",
            $time,
            $signed(m_axis_tdata[15:0]),    // Low_L
            $signed(m_axis_tdata[31:16]),   // Low_R
            $signed(m_axis_tdata[47:32]),   // High_L
            $signed(m_axis_tdata[63:48])    // High_R
        );
    end
end

endmodule
