# Coefficient Configuration

## Overview

The DWT and IDWT top-level modules use runtime-configurable filter coefficients.

The coefficient values are stored in an internal register bank and configured through the AXI4-Lite interface.

This approach allows the filter configuration to be changed without modifying or rebuilding the top-level RTL source.

## Default Configuration

The default DSP parameters are:

```text
DATAW     = 16
COEFW     = 16
NTAPS     = 8
OUT_SHIFT = 15
ACCW      = 64
ROUND     = 1
SATURATE  = 1
```

The default configuration is designed around eight-tap wavelet filters.

The provided Python coefficient generator currently uses the Symlet 4 (`sym4`) wavelet.

## Coefficient Format

The generated coefficients use signed 16-bit Q15 fixed-point representation.

The conversion from a floating-point coefficient is:

```text
Q15 = round(coefficient × 32768)
```

The result is limited to the signed 16-bit range:

```text
-32768 ≤ Q15 ≤ 32767
```

Negative values are represented internally using two's complement notation.

## AXI4-Lite Register Access

Coefficient register `n` is accessed at:

```text
Address = 0x04 + (n × 4)
```

For an eight-tap configuration:

| Coefficient   | Address |
| ------------- | ------- |
| `coef_reg[0]` | `0x04`  |
| `coef_reg[1]` | `0x08`  |
| `coef_reg[2]` | `0x0C`  |
| `coef_reg[3]` | `0x10`  |
| `coef_reg[4]` | `0x14`  |
| `coef_reg[5]` | `0x18`  |
| `coef_reg[6]` | `0x1C`  |
| `coef_reg[7]` | `0x20`  |

Only the lower `COEFW` bits of each AXI4-Lite write transaction are stored in the coefficient register bank.

## Coefficient Injection Workflow

The simulation workflow uses the following sequence:

```text
PyWavelets
    │
    ▼
Floating-Point Wavelet Coefficients
    │
    ▼
Q15 Conversion
    │
    ▼
Verilog Memory File
    │
    ▼
$readmemh
    │
    ▼
Testbench Coefficient Array
    │
    ▼
AXI4-Lite Write Transactions
    │
    ▼
RTL Coefficient Register Bank
    │
    ▼
QMF Processing Core
```

This workflow allows the same generated coefficient data to be used for simulation without hard-coding wavelet coefficients into the top-level RTL.

## Coefficient Flattening

The coefficient register bank is implemented as an unpacked Verilog array:

```verilog
reg signed [COEFW-1:0] coef_reg [0:NTAPS-1];
```

The external QMF processing cores expect a packed coefficient vector.

The top-level modules therefore flatten the register bank into:

```text
h0_flat[NTAPS × COEFW - 1:0]
```

The coefficient mapping is:

```text
h0_flat[k × COEFW +: COEFW] = coef_reg[k]
```

This preserves the coefficient ordering defined by the register bank.

## DWT and IDWT Coefficient Use

Both `vrm_dwt_axi.v` and `vrm_idwt_axi.v` expose an equivalent coefficient configuration mechanism.

The forward DWT passes the configured coefficient vector to the QMF analysis cores.

The inverse DWT passes the configured coefficient vector to the QMF synthesis cores.

The detailed construction of complementary filter paths is handled by the external QMF implementation.

## Reconfiguration Considerations

The current implementation allows coefficients to be modified through AXI4-Lite while the hardware is active.

However, software should avoid changing filter coefficients during an active data frame unless the resulting transient behavior is explicitly acceptable for the application.

A recommended configuration sequence is:

1. Reset or idle the streaming data path.
2. Write all filter coefficients through AXI4-Lite.
3. Confirm completion of all AXI write transactions.
4. Begin or resume AXI4-Stream processing.

This avoids unintentionally processing a single frame with multiple coefficient configurations.

## Changing the Wavelet

A different wavelet can be used by modifying the Python coefficient generation script.

The selected wavelet must be checked against the RTL configuration before use.

In particular:

```text
Number of generated coefficients = NTAPS
```

If a wavelet produces a different number of coefficients, the following components may require modification:

* `NTAPS` parameter in the RTL.
* AXI4-Lite address range.
* Testbench coefficient array size.
* Generated memory file contents.
* Verification scripts and expected output analysis.

The fixed-point precision and scaling characteristics of the selected wavelet should also be evaluated before deployment to hardware.
