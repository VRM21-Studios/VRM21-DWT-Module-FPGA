`timescale 1ns / 1ps

// =============================================================================
// MODULE: dwt_decimator_axis
// DESCRIPTION:
//   AXI4-Stream decimation-by-two stage for DWT processing.
//
//   The module accepts consecutive input samples and retains every first
//   sample while discarding every second sample. The implementation uses a
//   single-stage buffer to preserve AXI4-Stream flow control and packet
//   boundaries.
//
//   TLAST is propagated when either:
//     1. The buffered sample carries TLAST, or
//     2. The discarded paired sample carries TLAST.
//
//   This behavior allows a stream with an odd number of samples to terminate
//   correctly after decimation.
// =============================================================================

module dwt_decimator_axis #(
    parameter integer DATA_WIDTH = 32
)(
    input  wire                   clk,
    input  wire                   rstn,

    // =========================================================================
    // AXI4-STREAM SLAVE INTERFACE
    // Input data stream from the preceding DWT analysis stage.
    // =========================================================================

    input  wire [DATA_WIDTH-1:0]  s_axis_tdata,
    input  wire                   s_axis_tvalid,
    output wire                   s_axis_tready,
    input  wire                   s_axis_tlast,

    // =========================================================================
    // AXI4-STREAM MASTER INTERFACE
    // Decimated output stream for DMA or a subsequent DWT level.
    // =========================================================================

    output wire [DATA_WIDTH-1:0]  m_axis_tdata,
    output wire                   m_axis_tvalid,
    input  wire                   m_axis_tready,
    output wire                   m_axis_tlast
);

    // =========================================================================
    // SINGLE-STAGE SAMPLE BUFFER
    // =========================================================================
    // The buffer retains the first sample of each input sample pair.
    // The following sample is consumed to complete the decimation-by-two
    // operation.
    // =========================================================================

    reg [DATA_WIDTH-1:0] buf_data;
    reg                  buf_tlast;
    reg                  buf_valid;

    // =========================================================================
    // AXI4-STREAM OUTPUT CONTROL
    // =========================================================================
    //
    // The buffered sample can be transmitted when:
    //
    //   1. A subsequent input sample is available, completing the sample pair.
    //
    //   2. The buffered sample carries TLAST and therefore represents the end
    //      of an odd-length input stream.
    // =========================================================================

    assign m_axis_tvalid =
        buf_valid && (s_axis_tvalid || buf_tlast);

    assign m_axis_tdata =
        buf_data;

    // Propagate the packet boundary from either sample in the decimation pair.
    assign m_axis_tlast =
        buf_tlast || (s_axis_tvalid && s_axis_tlast);

    // =========================================================================
    // AXI4-STREAM INPUT FLOW CONTROL
    // =========================================================================
    //
    // The input interface is ready when:
    //
    //   1. The internal buffer is empty.
    //
    //   2. The current buffered sample can be transferred to the downstream
    //      interface during the current transaction.
    //
    // A buffered TLAST sample does not require a second sample to complete
    // the decimation pair.
    // =========================================================================

    assign s_axis_tready =
        (!buf_valid) || (m_axis_tready && !buf_tlast);

    // AXI4-Stream handshake completion indicators.
    wire in_fire  = s_axis_tvalid && s_axis_tready;
    wire out_fire = m_axis_tvalid && m_axis_tready;

    // =========================================================================
    // BUFFER STATE UPDATE
    // =========================================================================

    always @(posedge clk) begin
        if (!rstn) begin

            buf_valid <= 1'b0;
            buf_data  <= {DATA_WIDTH{1'b0}};
            buf_tlast <= 1'b0;

        end else begin

            // -----------------------------------------------------------------
            // Buffer Empty
            // -----------------------------------------------------------------
            // Capture the first sample of a new decimation pair.
            if (!buf_valid) begin

                if (in_fire) begin

                    buf_data  <= s_axis_tdata;
                    buf_tlast <= s_axis_tlast;
                    buf_valid <= 1'b1;

                end

            // -----------------------------------------------------------------
            // Buffer Occupied
            // -----------------------------------------------------------------
            // Once the buffered sample is transferred, the corresponding
            // second sample has been consumed or the packet has terminated.
            else begin

                if (out_fire) begin
                    buf_valid <= 1'b0;
                end

            end
        end
    end

endmodule
