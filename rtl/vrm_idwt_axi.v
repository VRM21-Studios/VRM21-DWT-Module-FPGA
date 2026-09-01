`timescale 1ns / 1ps

// =============================================================================
// MODULE: vrm_idwt_axi
// DESCRIPTION:
//   AXI4-Lite and AXI4-Stream wrapper for a Level-1 stereo Inverse Discrete
//   Wavelet Transform (IDWT) synthesis stage.
//
//   The module accepts decimated stereo wavelet subbands through an AXI4-Stream
//   interface. The input data is interpolated by a factor of two and processed
//   by independent QMF synthesis cores for the left and right audio channels.
//
//   The QMF synthesis filter coefficients are programmable through the AXI4-Lite
//   interface.
//
// DEPENDENCY:
//   qmf_synthesis_core
//   Available from the VRM21 Quadrature Mirror Filter repository.
//
// INPUT DATA FORMAT:
//   s_axis_tdata[63:48] : Right-channel high-pass subband
//   s_axis_tdata[47:32] : Left-channel high-pass subband
//   s_axis_tdata[31:16] : Right-channel low-pass subband
//   s_axis_tdata[15:0]  : Left-channel low-pass subband
//
// OUTPUT DATA FORMAT:
//   m_axis_tdata[31:16] : Reconstructed right-channel sample
//   m_axis_tdata[15:0]  : Reconstructed left-channel sample
//
// MEMORY MAP:
//   Word Address 0        : Identification / user register
//   Word Address 1..NTAPS : QMF synthesis filter coefficients
// =============================================================================

module vrm_idwt_axi #(

    // -------------------------------------------------------------------------
    // AXI4-Lite Interface Parameters
    // -------------------------------------------------------------------------
    parameter integer C_S_AXI_ADDR_WIDTH = 6,
    parameter integer C_S_AXI_DATA_WIDTH = 32,

    // -------------------------------------------------------------------------
    // AXI4-Stream Interface Parameters
    // -------------------------------------------------------------------------
    parameter integer S_AXIS_DATA_WIDTH = 64,
    parameter integer M_AXIS_DATA_WIDTH = 32,

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
    input  wire                                  clk,
    input  wire                                  rstn,

    // =========================================================================
    // AXI4-LITE SLAVE INTERFACE
    // Control and coefficient configuration interface.
    // =========================================================================

    // Write Address Channel
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]         s_axi_awaddr,
    input  wire                                  s_axi_awvalid,
    output reg                                   s_axi_awready,

    // Write Data Channel
    input  wire [C_S_AXI_DATA_WIDTH-1:0]         s_axi_wdata,
    input  wire                                  s_axi_wvalid,
    output reg                                   s_axi_wready,

    // Write Response Channel
    output reg  [1:0]                            s_axi_bresp,
    output reg                                   s_axi_bvalid,
    input  wire                                  s_axi_bready,

    // Read Address Channel
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]         s_axi_araddr,
    input  wire                                  s_axi_arvalid,
    output reg                                   s_axi_arready,

    // Read Data Channel
    output reg  [C_S_AXI_DATA_WIDTH-1:0]         s_axi_rdata,
    output reg  [1:0]                            s_axi_rresp,
    output reg                                   s_axi_rvalid,
    input  wire                                  s_axi_rready,

    // =========================================================================
    // AXI4-STREAM SLAVE INTERFACE
    // Decimated Level-1 DWT subband input stream.
    // =========================================================================

    input  wire [S_AXIS_DATA_WIDTH-1:0]          s_axis_tdata,
    input  wire                                  s_axis_tvalid,
    output wire                                  s_axis_tready,
    input  wire                                  s_axis_tlast,

    // =========================================================================
    // AXI4-STREAM MASTER INTERFACE
    // Reconstructed stereo output stream.
    // =========================================================================

    output wire [M_AXIS_DATA_WIDTH-1:0]          m_axis_tdata,
    output wire                                  m_axis_tvalid,
    input  wire                                  m_axis_tready,
    output wire                                  m_axis_tlast
);

    // =========================================================================
    // A. AXI4-LITE REGISTER INTERFACE
    // =========================================================================

    // General-purpose identification register.
    reg [31:0] dummy_reg;

    // Programmable QMF synthesis filter coefficient bank.
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

            // Default identification value for the reconfigurable IDWT core.
            dummy_reg <= 32'hD871_B002;

            // Clear all programmable synthesis coefficients.
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
    // Flatten the coefficient register bank into the packed format required by
    // qmf_synthesis_core.
    // =========================================================================

    wire [NTAPS*COEFW-1:0] h0_flat;

    genvar k;

    generate
        for (k = 0; k < NTAPS; k = k + 1) begin : flatten_coeffs

            assign h0_flat[k*COEFW +: COEFW] = coef_reg[k];

        end
    endgenerate

    // =========================================================================
    // C. INTERPOLATION STAGE
    // =========================================================================
    // The interpolator increases the subband sample rate by a factor of two
    // before the data is processed by the QMF synthesis filter bank.
    // =========================================================================

    wire [S_AXIS_DATA_WIDTH-1:0] interp_tdata;
    wire                         interp_tvalid;
    wire                         interp_tlast;
    wire                         interp_tready;

    // The interpolation stage advances when the downstream reconstruction
    // output interface is ready to accept the corresponding sample.
    assign interp_tready = m_axis_tready;

    idwt_interpolator_axis #(
        .DATA_WIDTH(S_AXIS_DATA_WIDTH)
    ) interpolator_inst (

        .clk(clk),
        .rstn(rstn),

        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),

        .m_axis_tdata(interp_tdata),
        .m_axis_tvalid(interp_tvalid),
        .m_axis_tready(interp_tready),
        .m_axis_tlast(interp_tlast)

    );

    // =========================================================================
    // D. QMF SYNTHESIS FILTER BANK
    // =========================================================================

    // Extract the four 16-bit DWT subband components.
    //
    // Input format:
    //   {high_R, high_L, low_R, low_L}
    //
    wire [15:0] interp_low_L  = interp_tdata[15:0];
    wire [15:0] interp_low_R  = interp_tdata[31:16];
    wire [15:0] interp_high_L = interp_tdata[47:32];
    wire [15:0] interp_high_R = interp_tdata[63:48];

    // Enable both synthesis cores only when valid interpolated data is
    // available and the output interface can accept the resulting sample.
    wire core_en =
        interp_tvalid && m_axis_tready;

    // The synthesis core introduces a one-clock processing latency. Delay the
    // corresponding AXI4-Stream control signals to maintain data alignment.
    reg valid_delayed;
    reg last_delayed;

    always @(posedge clk) begin
        if (!rstn) begin

            valid_delayed <= 1'b0;
            last_delayed  <= 1'b0;

        end else if (m_axis_tready) begin

            valid_delayed <= interp_tvalid;
            last_delayed  <= interp_tlast;

        end
    end

    // -------------------------------------------------------------------------
    // Left-Channel QMF Synthesis
    // -------------------------------------------------------------------------
    wire [15:0] out_L;

    qmf_synthesis_core #(
        .DATAW(DATAW),
        .COEFW(COEFW),
        .NTAPS(NTAPS),
        .ACCW(ACCW),
        .OUT_SHIFT(OUT_SHIFT),
        .ROUND(ROUND),
        .SATURATE(SATURATE)
    ) synthesis_L (

        .clk(clk),
        .rstn(rstn),
        .en(core_en),

        .din_low(interp_low_L),
        .din_high(interp_high_L),
        .h0_coef_flat(h0_flat),

        .dout_merged(out_L)

    );

    // -------------------------------------------------------------------------
    // Right-Channel QMF Synthesis
    // -------------------------------------------------------------------------
    wire [15:0] out_R;

    qmf_synthesis_core #(
        .DATAW(DATAW),
        .COEFW(COEFW),
        .NTAPS(NTAPS),
        .ACCW(ACCW),
        .OUT_SHIFT(OUT_SHIFT),
        .ROUND(ROUND),
        .SATURATE(SATURATE)
    ) synthesis_R (

        .clk(clk),
        .rstn(rstn),
        .en(core_en),

        .din_low(interp_low_R),
        .din_high(interp_high_R),
        .h0_coef_flat(h0_flat),

        .dout_merged(out_R)

    );

    // =========================================================================
    // E. AXI4-STREAM OUTPUT ROUTING
    // =========================================================================
    //
    // Output format:
    //   m_axis_tdata[31:16] : Reconstructed right-channel sample
    //   m_axis_tdata[15:0]  : Reconstructed left-channel sample
    // =========================================================================

    assign m_axis_tdata  = {out_R, out_L};
    assign m_axis_tvalid = valid_delayed;
    assign m_axis_tlast  = last_delayed;

endmodule
