# Verification and Validation

## Overview

The `VRM21-Discrete-Wavelet-Transform` project has been evaluated through both RTL simulation and hardware-level validation.

The verification flow is divided into two primary stages:

1. RTL simulation using dedicated Verilog testbenches.
2. FPGA validation using a PYNQ-based software environment.

The simulation environment focuses on functional behavior and AXI interface operation, while the FPGA validation confirms that the implementation operates correctly in an actual hardware data path.

---

## RTL Simulation

The repository provides separate testbenches for the forward Discrete Wavelet Transform (DWT) and Inverse Discrete Wavelet Transform (IDWT) implementations.

### DWT Verification

The DWT testbench performs the following operations:

1. Initializes the DUT and AXI interfaces.
2. Applies a reset sequence.
3. Loads Symlet 4 (`sym4`) low-pass filter coefficients.
4. Converts the coefficients into Q15 fixed-point representation.
5. Writes the coefficients into the hardware coefficient registers through AXI4-Lite transactions.
6. Injects a stereo impulse signal through the AXI4-Stream interface.
7. Captures the low-pass and high-pass output streams.
8. Records the resulting data in CSV format.

The DWT output data is organized as:

```text
{High_R, High_L, Low_R, Low_L}
```

The generated CSV file contains the following columns:

```text
Time(ns),Low_L,Low_R,High_L,High_R
```

This allows the impulse response and filter-bank decomposition behavior to be inspected independently for both stereo channels.

---

### IDWT Verification

The IDWT testbench performs the reverse processing flow.

The verification sequence includes:

1. DUT initialization and reset.
2. Loading the `sym4` low-pass filter coefficients.
3. AXI4-Lite coefficient register configuration.
4. Injection of a decimated impulse signal.
5. Interpolation of the input data stream.
6. QMF synthesis filtering.
7. Capture of the reconstructed stereo output.
8. Export of the output samples to CSV format.

The IDWT input format is:

```text
{High_R, High_L, Low_R, Low_L}
```

The reconstructed output format is:

```text
{Out_R, Out_L}
```

The generated CSV file contains:

```text
Time(ns),Out_L,Out_R
```

---

## Coefficient Generation

Wavelet coefficients used by the RTL simulation are generated using the Python package `PyWavelets`.

The provided coefficient generation script creates Q15 fixed-point memory initialization files for the Symlet 4 wavelet.

The generated files are:

```text
sym4_lpf.mem
sym4_hpf.mem
```

The coefficients are converted from floating-point values into signed 16-bit Q15 fixed-point representation.

The conversion process can be summarized as:

```text
Q15 = round(coefficient × 32768)
```

The resulting values are clamped to the signed 16-bit range before being stored as hexadecimal two's-complement values.

The current RTL implementation uses the low-pass coefficient set as the configurable coefficient source. The associated QMF cores derive the corresponding complementary filter behavior internally.

---

## FPGA Hardware Validation

In addition to RTL simulation, the DWT implementation has been tested on an FPGA using a PYNQ-based software environment.

The hardware validation environment used:

* A PYNQ-compatible FPGA platform.
* An FPGA bitstream containing the DWT accelerator.
* AXI DMA for high-throughput sample transfer.
* AXI4-Lite for runtime coefficient configuration.
* Python with NumPy, Pandas, Matplotlib, and PyWavelets.

The FPGA validation software automatically identifies the DWT AXI-Lite IP from the loaded hardware overlay and dynamically configures the wavelet coefficients before processing the input signal.

The coefficient configuration flow uses the following process:

1. A wavelet is selected in software.
2. The corresponding decomposition low-pass coefficients are obtained through PyWavelets.
3. The floating-point coefficients are converted to signed Q15 values.
4. The coefficients are written to the DWT accelerator through AXI4-Lite registers.

This allows the same hardware implementation to operate with multiple supported wavelet coefficient sets without requiring FPGA bitstream regeneration.

---

## Multi-Wavelet Hardware Evaluation

The FPGA implementation was evaluated using multiple wavelet configurations with filter lengths compatible with the current eight-tap hardware configuration.

The tested wavelets included:

* Haar
* Daubechies 2 (`db2`)
* Daubechies 4 (`db4`)
* Coiflet 1 (`coif1`)
* Symlet 4 (`sym4`)

Wavelets with fewer than eight coefficients are zero-padded during AXI-Lite configuration.

The validation process dynamically updates the coefficient registers before processing each dataset.

---

## Multi-Level DWT Processing

The FPGA validation environment was also used to perform a five-level DWT decomposition.

For each decomposition level:

1. The current approximation signal is transferred to the FPGA.
2. The DWT accelerator generates approximation and detail components.
3. The detail component is stored as the output for the current decomposition level.
4. The approximation component becomes the input for the next level.

The resulting decomposition consists of:

```text
A5
D5
D4
D3
D2
D1
```

where:

* `A5` is the fifth-level approximation component.
* `D1` through `D5` are the corresponding detail components.

The hardware validation software also supports batch processing of multiple input datasets and generates plots for the resulting decomposition bands.

---

## AXI DMA Data Packing

The FPGA validation environment uses packed stereo samples for DMA transfers.

The DWT input format is:

```text
Bits [15:0]  : Left channel
Bits [31:16] : Right channel
```

The DWT output format is:

```text
Bits [15:0]  : Low-pass left channel
Bits [31:16] : Low-pass right channel
Bits [47:32] : High-pass left channel
Bits [63:48] : High-pass right channel
```

This format matches the RTL interface definitions and allows all four wavelet subband values to be transferred through a single 64-bit AXI4-Stream transaction.

---

## Streaming Phase Handling

Hardware validation also included chunked DMA transfers for longer input signals.

Because the DWT decimator operates on alternating sample positions, the software validation environment maintains a phase-tracking mechanism between DMA chunks.

This prevents the decimation phase from becoming misaligned when the input signal is divided into multiple transfers.

The phase state is updated when a chunk contains an odd number of input samples.

This behavior is particularly important when processing large datasets because independent DMA chunks cannot always be treated as completely independent decimation sequences.

---

## Multi-Level Decomposition Capability

The RTL implementation provides a single-stage DWT processing architecture.

Each hardware transaction performs one level of wavelet decomposition, producing:

* A low-frequency approximation component.
* A high-frequency detail component.

For stereo data, the approximation and detail components are generated independently for the left and right channels.

Although the hardware architecture contains only a single DWT stage, multiple decomposition levels can be constructed through iterative processing controlled by the Processing System (PS).

The basic decomposition flow is:

```text
Input Signal
     |
     v
+------------+
| DWT Level 1|
+------------+
     |
     +--------------------> Detail Component D1
     |
     v
Approximation Component A1
     |
     v
+------------+
| DWT Level 2|
+------------+
     |
     +--------------------> Detail Component D2
     |
     v
Approximation Component A2
     |
    ...
```

The approximation output from one processing iteration can be transferred back to the Processing System and used as the input for the next DWT iteration.

For example, a five-level decomposition can be performed as:

```text
Input
  |
  v
DWT Hardware
  |
  +--> D1
  |
  v
 A1
  |
  v
DWT Hardware
  |
  +--> D2
  |
  v
 A2
  |
  v
DWT Hardware
  |
  +--> D3
  |
  v
 A3
  |
  v
DWT Hardware
  |
  +--> D4
  |
  v
 A4
  |
  v
DWT Hardware
  |
  +--> D5
  |
  v
 A5
```

This approach allows a single reusable hardware accelerator to perform deeper multi-level wavelet decomposition without requiring multiple DWT stages to be instantiated simultaneously in the FPGA fabric.

The number of decomposition levels is therefore primarily controlled by the software execution flow and the available Processing System memory and data-transfer resources.

### Processing System Iteration

In a PYNQ-based system, the iterative decomposition process can be implemented by:

1. Sending the current input signal to the DWT accelerator through AXI DMA.
2. Receiving the approximation and detail outputs.
3. Storing the detail component for the current decomposition level.
4. Using the approximation component as the input signal for the next iteration.
5. Repeating the process until the required decomposition level is reached.

Conceptually:

```text
Current Input
      |
      v
+-------------------+
| FPGA DWT Stage    |
+-------------------+
      |
      +--> Detail Output --> Store Dn
      |
      v
Approximation Output
      |
      v
Reuse as Next Input
```

This architecture provides a resource-efficient approach to multi-level DWT processing because the same FPGA hardware is reused for every decomposition level.

The RTL itself remains a single-stage implementation, while the Processing System is responsible for controlling the recursive decomposition flow.

### Architectural Considerations

This iterative architecture introduces a trade-off between FPGA resource utilization and processing throughput.

Using a single reusable DWT hardware stage:

* Reduces FPGA resource requirements.
* Avoids replicating the complete filter-bank architecture for every decomposition level.
* Allows the decomposition depth to be controlled in software.
* Supports flexible runtime processing flows.

However, each additional decomposition level requires another Processing System and FPGA data-transfer iteration.

Therefore, this architecture prioritizes hardware resource efficiency and configurability rather than fully parallel multi-stage processing.

---

## Verification Scope

The current verification and validation process covers:

* AXI4-Lite coefficient register access.
* Runtime coefficient configuration.
* AXI4-Stream handshake behavior.
* Stereo input and output data packing.
* DWT analysis filtering.
* IDWT interpolation behavior.
* QMF-based synthesis filtering.
* Decimation behavior.
* Multi-level DWT processing.
* Fixed-point Q15 coefficient representation.
* RTL simulation with CSV output logging.
* FPGA-based functional validation.
* AXI DMA data transfers.
* Dynamic wavelet coefficient reconfiguration.

The FPGA validation described in this document confirms that the DWT hardware architecture has been exercised in an operational FPGA environment. The PYNQ validation application itself is not included in this repository because the repository is focused on the reusable RTL implementation, simulation environment, and supporting documentation.

---

## Simulation Results

Simulation output files are stored under the repository's `results/` directory.

These CSV files are generated directly by the corresponding Verilog testbenches and can be used for numerical inspection or external plotting.

The available result files are intended to document the behavior of the RTL implementation under the provided verification scenarios.

Additional result files may be added as further wavelet configurations and verification cases are evaluated.
