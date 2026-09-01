`timescale 1ns / 1ps

// =============================================================================
// MODULE: vrm_dwt_axi
// DESCRIPTION:
//   AXI4-Lite and AXI4-Stream wrapper for a Level-1 stereo Discrete Wavelet
//   Transform (DWT) analysis stage.
//
//   The module accepts stereo audio samples through an AXI4-Stream interface,
//   processes the left and right channels using QMF analysis cores, and performs
//   decimation before transmitting the resulting low-pass and high-pass
//   subbands through the AXI4-Stream master interface.
//
//   The QMF filter coefficients are programmable through the AXI4-Lite
//   interface.
//
// DEPENDENCY:
//   qmf_analysis_core
//   Available from the VRM21 Quadrature Mirror Filter repository.
//
// DATA FORMAT:
//   Input:
//     s_axis_tdata[15:0]  : Left-channel sample
//     s_axis_tdata[31:16] : Right-channel sample
//
//   Output:
//     m_axis_tdata = {high_R, high_L, low_R, low_L}
//
// MEMORY MAP:
//   Word Address 0        : Identification / user register
//   Word Address 1..NTAPS : QMF analysis filter coefficients
// =============================================================================

module vrm_dwt_axi #(

    // -------------------------------------------------------------------------
    // AXI4-Lite Interface Parameters
    // -------------------------------------------------------------------------
    parameter integer C_S_AXI_ADDR_WIDTH = 6,
    parameter integer C_S_AXI_DATA_WIDTH = 32,

    // -------------------------------------------------------------------------
    // AXI4-Stream Interface Parameters
    // -------------------------------------------------------------------------
    parameter integer S_AXIS_DATA_WIDTH = 32,
    parameter integer M_AXIS_DATA_WIDTH = 64,

    // -------------------------------------------------------------------------
    // DSP Core Parameters
    // -------------------------------------------------------------------------
    parameter integer DATAW     = 16,
    parameter integer COEFW     = 16,
    parameter integer NTAPS     = 8,
    parameter integer OUT_SHIFT = 15,
    parameter integer ACCW      = 64,
    parameter integer ROUND     = 1,
    parameter integer SATURATE  = 1

)(
    input  wire                              clk,
    input  wire                              rstn,

    // =========================================================================
    // AXI4-LITE SLAVE INTERFACE
    // Control and coefficient configuration interface.
    // =========================================================================

    // Write Address Channel
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     s_axi_awaddr,
    input  wire                              s_axi_awvalid,
    output reg                               s_axi_awready,

    // Write Data Channel
    input  wire [C_S_AXI_DATA_WIDTH-1:0]     s_axi_wdata,
    input  wire                              s_axi_wvalid,
    output reg                               s_axi_wready,

    // Write Response Channel
    output reg  [1:0]                        s_axi_bresp,
    output reg                               s_axi_bvalid,
    input  wire                              s_axi_bready,

    // Read Address Channel
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     s_axi_araddr,
    input  wire                              s_axi_arvalid,
    output reg                               s_axi_arready,

    // Read Data Channel
    output reg  [C_S_AXI_DATA_WIDTH-1:0]     s_axi_rdata,
    output reg  [1:0]                        s_axi_rresp,
    output reg                               s_axi_rvalid,
    input  wire                              s_axi_rready,

    // =========================================================================
    // AXI4-STREAM SLAVE INTERFACE
    // Stereo input sample stream.
    // =========================================================================

    input  wire [S_AXIS_DATA_WIDTH-1:0]      s_axis_tdata,
    input  wire                              s_axis_tvalid,
    output wire                              s_axis_tready,
    input  wire                              s_axis_tlast,

    // =========================================================================
    // AXI4-STREAM MASTER INTERFACE
    // Decimated Level-1 DWT subband output stream.
    // =========================================================================

    output wire [M_AXIS_DATA_WIDTH-1:0]      m_axis_tdata,
    output wire                              m_axis_tvalid,
    input  wire                              m_axis_tready,
    output wire                              m_axis_tlast
);

    // =========================================================================
    // A. AXI4-LITE REGISTER INTERFACE
    // =========================================================================

    // General-purpose identification register.
    reg [31:0] dummy_reg;

    // Programmable QMF analysis filter coefficient bank.
    reg signed [COEFW-1:0] coef_reg [0:NTAPS-1];

    integer i;

    // Convert byte addresses into 32-bit word addresses.
    wire [C_S_AXI_ADDR_WIDTH-3:0] awaddr_word =
        s_axi_awaddr[C_S_AXI_ADDR_WIDTH-1:2];

    wire [C_S_AXI_ADDR_WIDTH-3:0] araddr_word =
        s_axi_araddr[C_S_AXI_ADDR_WIDTH-1:2];

    always @(posedge clk) begin
        if (!rstn) begin

            // Reset AXI4-Lite interface signals.
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
            s_axi_bvalid  <= 1'b0;

            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;

            s_axi_bresp   <= 2'b00;
            s_axi_rresp   <= 2'b00;
            s_axi_rdata   <= {C_S_AXI_DATA_WIDTH{1'b0}};

            // Default identification value for the reconfigurable DWT core.
            dummy_reg <= 32'hD871_A001;

            // Clear all programmable filter coefficients.
            for (i = 0; i < NTAPS; i = i + 1) begin
                coef_reg[i] <= {COEFW{1'b0}};
            end

        end else begin

            // -----------------------------------------------------------------
            // AXI4-Lite Write Transaction
            // -----------------------------------------------------------------
            if (!s_axi_awready && s_axi_awvalid && s_axi_wvalid) begin

                s_axi_awready <= 1'b1;
                s_axi_wready  <= 1'b1;

                // Address 0: General-purpose register.
                if (awaddr_word == 0) begin

                    dummy_reg <= s_axi_wdata;

                // Addresses 1 through NTAPS: Filter coefficient registers.
                end else if ((awaddr_word > 0) &&
                             (awaddr_word <= NTAPS)) begin

                    coef_reg[awaddr_word - 1] <=
                        s_axi_wdata[COEFW-1:0];
                end

            end else begin

                s_axi_awready <= 1'b0;
                s_axi_wready  <= 1'b0;

            end

            // Generate the AXI4-Lite write response.
            if (s_axi_awready && !s_axi_bvalid) begin

                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00;

            end else if (s_axi_bready) begin

                s_axi_bvalid <= 1'b0;

            end

            // -----------------------------------------------------------------
            // AXI4-Lite Read Transaction
            // -----------------------------------------------------------------
            if (!s_axi_arready && s_axi_arvalid) begin

                s_axi_arready <= 1'b1;
                s_axi_rvalid  <= 1'b1;
                s_axi_rresp   <= 2'b00;

                // Address 0: General-purpose register.
                if (araddr_word == 0) begin

                    s_axi_rdata <= dummy_reg;

                // Addresses 1 through NTAPS: Filter coefficient registers.
                end else if ((araddr_word > 0) &&
                             (araddr_word <= NTAPS)) begin

                    // Zero-extend the coefficient to the AXI data width.
                    s_axi_rdata <=
                        {{(32-COEFW){1'b0}},
                         coef_reg[araddr_word - 1]};

                // Undefined addresses return zero.
                end else begin

                    s_axi_rdata <= 32'h0000_0000;

                end

            end else begin

                s_axi_arready <= 1'b0;

                // Complete the read transaction after the master accepts data.
                if (s_axi_rvalid && s_axi_rready) begin
                    s_axi_rvalid <= 1'b0;
                end

            end
        end
    end

    // =========================================================================
    // B. QMF COEFFICIENT BUS GENERATION
    // =========================================================================
    // Flatten the coefficient register bank into the packed bus format required
    // by qmf_analysis_core.
    // =========================================================================

    wire [NTAPS*COEFW-1:0] h0_flat;

    genvar k;

    generate
        for (k = 0; k < NTAPS; k = k + 1) begin : flatten_coeffs

            assign h0_flat[k*COEFW +: COEFW] = coef_reg[k];

        end
    endgenerate

    // =========================================================================
    // C. INPUT FLOW CONTROL AND PIPELINE ALIGNMENT
    // =========================================================================

    // The decimator controls upstream flow through AXI4-Stream backpressure.
    wire decimator_ready;

    assign s_axis_tready = decimator_ready;

    // A sample is accepted by both QMF analysis cores only when the input
    // transaction completes successfully.
    wire core_en = s_axis_tvalid && decimator_ready;

    // One-cycle pipeline alignment for AXI4-Stream control signals.
    reg valid_delayed;
    reg last_delayed;

    always @(posedge clk) begin
        if (!rstn) begin

            valid_delayed <= 1'b0;
            last_delayed  <= 1'b0;

        end else if (decimator_ready) begin

            valid_delayed <= s_axis_tvalid;
            last_delayed  <= s_axis_tlast;

        end
    end

    // =========================================================================
    // D. STEREO QMF ANALYSIS CORES
    // =========================================================================

    wire [15:0] low_L;
    wire [15:0] high_L;

    wire [15:0] low_R;
    wire [15:0] high_R;

    // -------------------------------------------------------------------------
    // Left-Channel QMF Analysis
    // -------------------------------------------------------------------------
    qmf_analysis_core #(
        .DATAW(DATAW),
        .COEFW(COEFW),
        .NTAPS(NTAPS),
        .ACCW(ACCW),
        .OUT_SHIFT(OUT_SHIFT),
        .ROUND(ROUND),
        .SATURATE(SATURATE)
    ) analysis_L (

        .clk(clk),
        .rstn(rstn),
        .en(core_en),

        .din(s_axis_tdata[15:0]),
        .h0_coef_flat(h0_flat),

        .dout_low(low_L),
        .dout_high(high_L)

    );

    // -------------------------------------------------------------------------
    // Right-Channel QMF Analysis
    // -------------------------------------------------------------------------
    qmf_analysis_core #(
        .DATAW(DATAW),
        .COEFW(COEFW),
        .NTAPS(NTAPS),
        .ACCW(ACCW),
        .OUT_SHIFT(OUT_SHIFT),
        .ROUND(ROUND),
        .SATURATE(SATURATE)
    ) analysis_R (

        .clk(clk),
        .rstn(rstn),
        .en(core_en),

        .din(s_axis_tdata[31:16]),
        .h0_coef_flat(h0_flat),

        .dout_low(low_R),
        .dout_high(high_R)

    );

    // Pack the four Level-1 DWT subband outputs into a single AXI4-Stream word.
    //
    // Bit allocation:
    //   [63:48] : Right-channel high-pass subband
    //   [47:32] : Left-channel high-pass subband
    //   [31:16] : Right-channel low-pass subband
    //   [15:0]  : Left-channel low-pass subband
    //
    wire [M_AXIS_DATA_WIDTH-1:0] core_merged_tdata =
        {high_R, high_L, low_R, low_L};

    // =========================================================================
    // E. LEVEL-1 DWT DECIMATION STAGE
    // =========================================================================
    // A single wide decimator is used to preserve synchronization between all
    // stereo low-pass and high-pass subband components, including TLAST.
    // =========================================================================

    dwt_decimator_axis #(
        .DATA_WIDTH(M_AXIS_DATA_WIDTH)
    ) decimator_merged (

        .clk(clk),
        .rstn(rstn),

        .s_axis_tdata(core_merged_tdata),
        .s_axis_tvalid(valid_delayed),
        .s_axis_tready(decimator_ready),
        .s_axis_tlast(last_delayed),

        .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast)

    );

endmodule
