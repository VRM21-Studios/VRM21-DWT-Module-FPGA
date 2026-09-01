`timescale 1ns / 1ps

// =============================================================================
// MODULE: idwt_interpolator_axis
// DESCRIPTION:
//   AXI4-Stream interpolation-by-two stage for inverse discrete wavelet
//   transform processing.
//
//   Each accepted input sample produces two output samples:
//
//     1. The original input sample.
//     2. A zero-valued sample.
//
//   The resulting sequence implements zero-stuffing interpolation and doubles
//   the effective sample rate before QMF synthesis filtering.
//
//   For an input sequence:
//
//       X0, X1, X2, X3, ...
//
//   The output sequence becomes:
//
//       X0, 0, X1, 0, X2, 0, X3, 0, ...
//
//   TLAST is asserted on the zero-valued interpolation sample associated with
//   the final input sample. This preserves the correct output packet length.
// =============================================================================

module idwt_interpolator_axis #(

    // Input data width. The default format contains four 16-bit DWT subbands.
    parameter integer DATA_WIDTH = 64

)(
    input  wire                  clk,
    input  wire                  rstn,

    // =========================================================================
    // AXI4-STREAM SLAVE INTERFACE
    // Input stream from DMA or a preceding IDWT stage.
    // =========================================================================

    input  wire [DATA_WIDTH-1:0] s_axis_tdata,
    input  wire                  s_axis_tvalid,
    output wire                  s_axis_tready,
    input  wire                  s_axis_tlast,

    // =========================================================================
    // AXI4-STREAM MASTER INTERFACE
    // Interpolated stream for the QMF synthesis filter bank.
    // =========================================================================

    output wire [DATA_WIDTH-1:0] m_axis_tdata,
    output wire                  m_axis_tvalid,
    input  wire                  m_axis_tready,
    output wire                  m_axis_tlast
);

    // =========================================================================
    // INTERPOLATION STATE AND BUFFER
    // =========================================================================
    //
    // State 0:
    //   Transmit the buffered original input sample.
    //
    // State 1:
    //   Transmit a zero-valued interpolation sample.
    // =========================================================================

    reg                  state;
    reg [DATA_WIDTH-1:0] buf_data;
    reg                  buf_tlast;
    reg                  buf_valid;

    // =========================================================================
    // AXI4-STREAM OUTPUT CONTROL
    // =========================================================================

    // Output data is valid whenever an input sample is stored internally.
    assign m_axis_tvalid =
        buf_valid;

    // Transmit the original sample first, followed by a zero-valued sample.
    assign m_axis_tdata =
        (state == 1'b0) ? buf_data : {DATA_WIDTH{1'b0}};

    // The output packet terminates after the interpolation sample associated
    // with the final input sample.
    assign m_axis_tlast =
        (state == 1'b1) ? buf_tlast : 1'b0;

    // =========================================================================
    // AXI4-STREAM INPUT FLOW CONTROL
    // =========================================================================
    //
    // The input interface is ready when:
    //
    //   1. No sample is currently buffered.
    //
    //   2. The interpolator is transmitting the zero-valued sample and the
    //      downstream interface accepts it during the current transaction.
    //
    // This permits continuous input throughput between interpolation pairs.
    // =========================================================================

    assign s_axis_tready =
        (!buf_valid) || (state == 1'b1 && m_axis_tready);

    // AXI4-Stream handshake completion indicators.
    wire in_fire =
        s_axis_tvalid && s_axis_tready;

    wire out_fire =
        m_axis_tvalid && m_axis_tready;

    // =========================================================================
    // INTERPOLATION STATE MACHINE
    // =========================================================================

    always @(posedge clk) begin
        if (!rstn) begin

            state     <= 1'b0;
            buf_valid <= 1'b0;
            buf_data  <= {DATA_WIDTH{1'b0}};
            buf_tlast <= 1'b0;

        end else begin

            case (state)

                // -------------------------------------------------------------
                // STATE 0: TRANSMIT ORIGINAL SAMPLE
                // -------------------------------------------------------------
                1'b0: begin

                    // Capture a new input sample when the buffer is empty.
                    if (in_fire && !buf_valid) begin

                        buf_valid <= 1'b1;
                        buf_data  <= s_axis_tdata;
                        buf_tlast <= s_axis_tlast;

                    // After the original sample is accepted downstream,
                    // transmit the corresponding zero-valued sample.
                    end else if (out_fire) begin

                        state <= 1'b1;

                    end
                end

                // -------------------------------------------------------------
                // STATE 1: TRANSMIT ZERO-VALUED INTERPOLATION SAMPLE
                // -------------------------------------------------------------
                1'b1: begin

                    if (out_fire) begin

                        // Return to the original-sample transmission state.
                        state <= 1'b0;

                        // Accept a new input sample immediately when available,
                        // allowing continuous processing between sample pairs.
                        if (s_axis_tvalid) begin

                            buf_valid <= 1'b1;
                            buf_data  <= s_axis_tdata;
                            buf_tlast <= s_axis_tlast;

                        end else begin

                            buf_valid <= 1'b0;

                        end
                    end
                end

            endcase
        end
    end

endmodule
