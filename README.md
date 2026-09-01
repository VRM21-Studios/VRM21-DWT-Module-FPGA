# VRM21 Discrete Wavelet Transform Module FPGA

An FPGA-oriented RTL implementation of a configurable Discrete Wavelet Transform (DWT) and Inverse Discrete Wavelet Transform (IDWT) processing architecture.

The project provides reusable single-stage hardware accelerators based on a Quadrature Mirror Filter (QMF) analysis and synthesis filter bank. The implementation uses AXI4-Stream interfaces for sample transfers and AXI4-Lite registers for runtime wavelet coefficient configuration.

Although the RTL architecture implements a single transform stage, deeper multi-level wavelet decomposition can be constructed by repeatedly processing the low-frequency approximation output through the same hardware accelerator under software control.

## Features

* Single-stage DWT analysis accelerator.
* Single-stage IDWT synthesis accelerator.
* Stereo fixed-point signal processing.
* AXI4-Stream data interfaces.
* AXI4-Lite runtime coefficient configuration.
* Configurable Q15 wavelet coefficients.
* 16-bit input and output sample representation.
* 64-bit packed DWT subband output.
* Hardware decimation for DWT processing.
* Hardware interpolation for IDWT processing.
* Reusable QMF analysis and synthesis filter-bank architecture.
* Software-controlled iterative multi-level decomposition.
* RTL simulation with CSV result generation.
* FPGA functional validation using a PYNQ-based environment.

## Architecture Overview

The repository contains two primary hardware accelerators:

```text
vrm_dwt_axi
vrm_idwt_axi
```

### DWT Processing

The DWT accelerator receives 32-bit stereo samples through AXI4-Stream.

```text
32-bit Stereo Input
        |
        v
+-------------------+
| QMF Analysis Bank |
+-------------------+
        |
        v
+-------------------+
| 2:1 Decimation    |
+-------------------+
        |
        v
64-bit Wavelet Output
```

Each 32-bit input transaction contains two signed 16-bit samples:

```text
{Right, Left}
```

The DWT output contains four 16-bit subband values:

```text
{High_R, High_L, Low_R, Low_L}
```

The low-frequency components represent the approximation signal, while the high-frequency components represent the detail signal.

### IDWT Processing

The IDWT accelerator performs the inverse processing flow.

```text
64-bit Wavelet Input
        |
        v
+-------------------+
| 2:1 Interpolation |
+-------------------+
        |
        v
+-------------------+
| QMF Synthesis Bank|
+-------------------+
        |
        v
32-bit Stereo Output
```

The input format is:

```text
{High_R, High_L, Low_R, Low_L}
```

The reconstructed stereo output is:

```text
{Out_R, Out_L}
```

## Multi-Level Wavelet Decomposition

The RTL implementation contains a single DWT processing stage. However, this does not restrict the overall system to a single decomposition level.

Multi-level decomposition can be performed by software running on the Processing System (PS).

After each DWT operation:

1. The detail output is retained as the result for the current level.
2. The low-frequency approximation output is extracted.
3. The approximation output is transferred back to memory.
4. The approximation output becomes the input for the next DWT operation.

Conceptually:

```text
Input
  |
  v
DWT Hardware
  |
  +------------------> D1
  |
  v
 A1
  |
  v
DWT Hardware
  |
  +------------------> D2
  |
  v
 A2
  |
  v
DWT Hardware
  |
  +------------------> D3
  |
  ...
```

This approach allows the same hardware accelerator to be reused for deeper wavelet decomposition without instantiating multiple DWT stages in the FPGA fabric.

The decomposition depth is therefore controlled primarily by the software processing flow and available system resources.

## Runtime Wavelet Configuration

Wavelet coefficients are stored in hardware registers and configured through AXI4-Lite.

This allows supported wavelet filters to be changed without modifying the RTL or regenerating the FPGA bitstream.

The current implementation is configured around an eight-tap hardware coefficient register bank.

The repository includes a Python utility for generating fixed-point coefficient files from PyWavelets-compatible wavelets.

The hardware validation environment has been used with several wavelet configurations, including:

* Haar
* Daubechies 2 (`db2`)
* Daubechies 4 (`db4`)
* Coiflet 1 (`coif1`)
* Symlet 4 (`sym4`)

Wavelets with fewer than eight coefficients can be zero-padded during configuration.

See:

* [`docs/coefficient_configuration.md`](docs/coefficient_configuration.md)
* [`scripts/README.md`](scripts/README.md)

for additional information.

## Fixed-Point Representation

The DSP datapath uses fixed-point arithmetic.

The standard configuration uses:

* Input data width: 16 bits
* Coefficient width: 16 bits
* Coefficient format: Q15
* Default accumulator width: 64 bits

Wavelet coefficients generated from floating-point reference values are converted according to:

```text
Q15 = round(coefficient × 32768)
```

The resulting values are stored as signed 16-bit two's-complement values.

Further details are available in:

[`docs/fixed_point_format.md`](docs/fixed_point_format.md)

## RTL Dependencies

This repository builds on reusable filter-bank components provided by other VRM21-Studios repositories.

### Quadrature Mirror Filter Module

The DWT and IDWT accelerators depend on the QMF analysis and synthesis cores provided by:

[VRM21-Studios/Quadrature-Mirror-Filter-Module-FPGA](https://github.com/VRM21-Studios/Quadrature-Mirror-Filter-Module-FPGA?utm_source=chatgpt.com)

The QMF repository provides the underlying:

* Analysis filter-bank architecture.
* Synthesis filter-bank architecture.
* Low-pass and complementary high-pass filter processing.
* Fixed-point DSP infrastructure used by the transform modules.

The required QMF RTL modules are not duplicated in this repository.

Refer to [`rtl/README.md`](rtl/README.md) for integration details.

### FIR Module

The QMF processing architecture also relies on FIR filtering infrastructure associated with:

[VRM21-Studios/FIR-Module-FPGA](https://github.com/VRM21-Studios/FIR-Module-FPGA?utm_source=chatgpt.com)

This repository focuses on the wavelet-transform control, data formatting, decimation, interpolation, and AXI integration layers rather than duplicating the underlying FIR implementation.

## Repository Structure

```text
VRM21-Discrete-Wavelet-Transform/
│
├── docs/
│   ├── architecture.md
│   ├── coefficient_configuration.md
│   ├── fixed_point_format.md
│   ├── interfaces.md
│   ├── limitations.md
│   └── verification.md
│
├── results/
│   ├── dwtl1_output.csv
│   ├── dwtl1_output_TD.png
│   ├── dwtl1_output_FD.png
│   ├── idwt_output.csv
│   ├── idwt_output_TD.png
│   └── idwt_output_FD.png
│
├── rtl/
│   ├── README.md
│   ├── vrm_dwt_axi.v
│   ├── vrm_idwt_axi.v
│   ├── dwt_decimator_axis.v
│   └── idwt_interpolator_axis.v
│
├── scripts/
│   ├── README.md
│   └── wavelet_coefficient_generator.py
│
├── tb/
│   ├── tb_vrm_dwt_axi.sv
│   └── tb_vrm_idwt_axi.sv
│
├── requirement.txt
├── LICENSE
└── README.md
```

## Main RTL Modules

### `vrm_dwt_axi.v`

The top-level DWT accelerator.

Responsibilities include:

* AXI4-Lite coefficient configuration.
* Stereo input handling.
* QMF analysis filter-bank integration.
* Low-pass and high-pass subband generation.
* Stream decimation.
* 64-bit output packing.

### `vrm_idwt_axi.v`

The top-level IDWT accelerator.

Responsibilities include:

* AXI4-Lite coefficient configuration.
* 64-bit wavelet subband input handling.
* Stream interpolation.
* QMF synthesis filter-bank integration.
* Stereo signal reconstruction.

### `dwt_decimator_axis.v`

An AXI4-Stream-compatible decimator used by the DWT processing path.

The module reduces the output sample rate by retaining the required sample phase while preserving AXI streaming behavior and frame termination information.

### `idwt_interpolator_axis.v`

An AXI4-Stream-compatible interpolator used by the IDWT processing path.

The module performs two-times interpolation by inserting zero-valued samples between valid input samples.

## Simulation

The repository provides dedicated SystemVerilog testbenches for both transform directions.

```text
tb/tb_vrm_dwt_axi.sv
tb/tb_vrm_idwt_axi.sv
```

The simulation flow performs:

* Hardware reset.
* AXI4-Lite coefficient injection.
* AXI4-Stream stimulus generation.
* Impulse-response testing.
* Output capture.
* CSV result generation.

The generated simulation results are stored under:

```text
results/
```

The repository also includes time-domain and frequency-domain visualizations derived from the generated simulation results.

## Python Environment

The coefficient-generation utilities were developed using:

```text
Python 3.11.9
```

The Python dependencies are listed in:

```text
requirement.txt
```

The primary Python dependency used for wavelet coefficient generation is:

```text
PyWavelets
```

Install the required Python packages using:

```bash
pip install -r requirement.txt
```

For the tested development environment, Python 3.11.9 is the reference version.

## FPGA Validation

The DWT architecture has also been functionally tested on FPGA using a PYNQ-based environment.

The hardware validation flow included:

* FPGA overlay loading.
* Automatic DWT IP detection.
* AXI4-Lite wavelet coefficient configuration.
* AXI DMA input and output transfers.
* Dynamic wavelet reconfiguration.
* Chunked signal processing.
* Multi-level DWT decomposition through iterative hardware reuse.

The validation environment demonstrated that a single DWT hardware stage can be reused by software to construct deeper decomposition levels.

The PYNQ validation application is not included in this repository because the primary scope of this project is the reusable RTL implementation, simulation environment, and associated documentation.

See [`docs/verification.md`](docs/verification.md) for the complete verification scope.

## Documentation

Detailed documentation is available in the [`docs/`](docs/) directory.

| Document                                                            | Description                               |
| ------------------------------------------------------------------- | ----------------------------------------- |
| [`architecture.md`](docs/architecture.md)                           | Overall DWT and IDWT architecture         |
| [`coefficient_configuration.md`](docs/coefficient_configuration.md) | Runtime wavelet coefficient configuration |
| [`fixed_point_format.md`](docs/fixed_point_format.md)               | Fixed-point representation and arithmetic |
| [`interfaces.md`](docs/interfaces.md)                               | AXI4-Lite and AXI4-Stream interfaces      |
| [`limitations.md`](docs/limitations.md)                             | Current architectural limitations         |
| [`verification.md`](docs/verification.md)                           | RTL simulation and FPGA validation        |

## Current Scope

The current implementation focuses on a configurable single-stage DWT and IDWT hardware architecture.

The design is intended as a reusable FPGA processing component rather than a complete standalone multi-level wavelet-processing system.

Multi-level decomposition is achieved through repeated accelerator invocation under software control.

The hardware coefficient register architecture currently targets wavelets compatible with the available coefficient storage configuration.

See [`docs/limitations.md`](docs/limitations.md) for additional implementation constraints.

## License

This project is distributed under the terms of the repository's included license.

## Related Projects

* [Quadrature-Mirror-Filter-Module-FPGA](https://github.com/VRM21-Studios/Quadrature-Mirror-Filter-Module-FPGA?utm_source=chatgpt.com)
* [FIR-Module-FPGA](https://github.com/VRM21-Studios/FIR-Module-FPGA?utm_source=chatgpt.com)

---

**VRM21-Discrete-Wavelet-Transform** is part of the broader collection of reusable FPGA-oriented DSP and hardware IP developed by VRM21-Studios.
