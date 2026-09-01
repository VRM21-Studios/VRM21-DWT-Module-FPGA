# Interfaces

## Overview

The DWT and IDWT modules use two standard interface types:

* AXI4-Lite for control and coefficient configuration.
* AXI4-Stream for sample transport.

The implementation uses a single clock and active-low synchronous interface reset signal:

```text
clk
rstn
```

## AXI4-Lite Interface

AXI4-Lite is used to configure and inspect the internal coefficient register bank.

The default interface configuration is:

```text
C_S_AXI_ADDR_WIDTH = 6
C_S_AXI_DATA_WIDTH = 32
```

A six-bit byte address provides sufficient address space for the control register and the default eight coefficient registers.

### Write Interface

The write interface uses the following signals:

```text
s_axi_awaddr
s_axi_awvalid
s_axi_awready

s_axi_wdata
s_axi_wvalid
s_axi_wready

s_axi_bresp
s_axi_bvalid
s_axi_bready
```

The current implementation accepts the write address and write data when both valid signals are asserted and the corresponding ready signals are generated.

A successful write returns an AXI response value of:

```text
2'b00
```

### Read Interface

The read interface uses:

```text
s_axi_araddr
s_axi_arvalid
s_axi_arready

s_axi_rdata
s_axi_rresp
s_axi_rvalid
s_axi_rready
```

A successful read returns:

```text
s_axi_rresp = 2'b00
```

## Register Map

The coefficient register map is based on 32-bit word addresses.

| Byte Address | Register                | Description                                    |
| ------------ | ----------------------- | ---------------------------------------------- |
| `0x00`       | Control / ID Register   | Readable and writable general-purpose register |
| `0x04`       | Coefficient 0           | Q15 filter coefficient                         |
| `0x08`       | Coefficient 1           | Q15 filter coefficient                         |
| `0x0C`       | Coefficient 2           | Q15 filter coefficient                         |
| `...`        | ...                     | Additional coefficients                        |
| `4 × NTAPS`  | Coefficient `NTAPS - 1` | Final filter coefficient                       |

For the default `NTAPS = 8` configuration, the coefficient registers occupy addresses from `0x04` through `0x20`.

The coefficient values are stored using the lower `COEFW` bits of the AXI write data.

## DWT AXI4-Stream Input

The forward DWT module accepts a 32-bit stereo stream.

```text
s_axis_tdata[15:0]   = Left channel
s_axis_tdata[31:16]  = Right channel
```

The associated AXI4-Stream signals are:

```text
s_axis_tdata
s_axis_tvalid
s_axis_tready
s_axis_tlast
```

A sample transfer occurs when:

```text
s_axis_tvalid && s_axis_tready
```

The `TLAST` signal identifies the final sample of an input frame.

## DWT AXI4-Stream Output

The forward DWT produces a 64-bit packed subband stream:

```text
m_axis_tdata[15:0]   = Low_L
m_axis_tdata[31:16]  = Low_R
m_axis_tdata[47:32]  = High_L
m_axis_tdata[63:48]  = High_R
```

Equivalent packed representation:

```text
{High_R, High_L, Low_R, Low_L}
```

The output interface uses:

```text
m_axis_tdata
m_axis_tvalid
m_axis_tready
m_axis_tlast
```

The output is transferred when:

```text
m_axis_tvalid && m_axis_tready
```

## IDWT AXI4-Stream Input

The inverse DWT receives the same packed 64-bit subband format:

```text
s_axis_tdata[15:0]   = Low_L
s_axis_tdata[31:16]  = Low_R
s_axis_tdata[47:32]  = High_L
s_axis_tdata[63:48]  = High_R
```

Equivalent packed representation:

```text
{High_R, High_L, Low_R, Low_L}
```

The input interface follows the standard AXI4-Stream handshake:

```text
s_axis_tvalid && s_axis_tready
```

## IDWT AXI4-Stream Output

The IDWT reconstruction output is a 32-bit stereo sample:

```text
m_axis_tdata[15:0]   = Reconstructed Left
m_axis_tdata[31:16]  = Reconstructed Right
```

Equivalent packed representation:

```text
{Right, Left}
```

The output transfer occurs when:

```text
m_axis_tvalid && m_axis_tready
```

## Backpressure

Both processing paths support downstream backpressure through the AXI4-Stream `TREADY` signal.

The internal decimator and interpolator propagate flow-control information to prevent uncontrolled data loss when the downstream interface is temporarily unable to accept data.

The effective throughput and latency depend on:

* Downstream `TREADY` behavior.
* Filter core pipeline latency.
* Decimation or interpolation state.
* AXI4-Stream frame boundaries.
