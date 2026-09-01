# Scripts

This directory contains Python utilities used to support the simulation and verification workflow of the VRM21 Discrete Wavelet Transform implementation.

## Wavelet Coefficient Generator

The coefficient generation script creates Verilog-compatible memory files containing fixed-point wavelet filter coefficients.

The current implementation uses the **Symlet 4 (`sym4`)** wavelet provided by the PyWavelets library. The selected wavelet provides eight coefficients for each decomposition filter, matching the default `NTAPS = 8` configuration used by the RTL implementation.

The script generates the following files:

* `sym4_lpf.mem` — Low-pass decomposition filter coefficients.
* `sym4_hpf.mem` — High-pass decomposition filter coefficients.

These files contain one 16-bit hexadecimal coefficient per line and are intended to be loaded into Verilog simulation environments using the `$readmemh` system task.

## Fixed-Point Representation

PyWavelets provides wavelet coefficients in floating-point format. Before being written to the memory files, each coefficient is converted to signed 16-bit Q15 fixed-point representation.

The conversion is defined as:

```text
Q15 = round(coefficient × 32768)
```

The resulting value is limited to the signed 16-bit range:

```text
-32768 to 32767
```

Negative values are then represented using 16-bit two's complement notation.

For example, the generated hexadecimal values can be loaded directly into a Verilog declaration such as:

```verilog
reg signed [15:0] h0_mem [0:7];

initial begin
    $readmemh("sym4_lpf.mem", h0_mem);
end
```

## Requirements

The scripts in this directory are intended to run with:

* Python 3.11.9
* PyWavelets

The current coefficient generation script has been written for and is compatible with Python 3.11.9.

Install the required Python dependency with:

```bash
pip install PyWavelets
```

Alternatively, if a `requirements.txt` file is provided in the repository root, install the dependencies with:

```bash
pip install -r requirements.txt
```

## Usage

Run the coefficient generator from the directory containing the script:

```bash
python generate_wavelet_coefficients.py
```

The command generates the following output files:

```text
sym4_lpf.mem
sym4_hpf.mem
```

The script reports the generated files after successful completion.

## Generated Coefficient Files

### `sym4_lpf.mem`

Contains the low-pass decomposition coefficients of the Symlet 4 wavelet.

This file is currently used by the RTL testbenches to configure the coefficient registers of the DWT and IDWT filter banks through their AXI4-Lite interfaces.

### `sym4_hpf.mem`

Contains the high-pass decomposition coefficients of the Symlet 4 wavelet.

The current QMF-based RTL architecture derives the complementary high-pass filtering behavior internally. Therefore, this file is generated as a reference coefficient set and for potential use in independent verification, analysis, or future RTL configurations.

## Relationship to the RTL Implementation

The generated coefficients are intended primarily for the simulation workflow.

A typical verification flow is:

```text
PyWavelets
    │
    ▼
Wavelet Coefficient Generator
    │
    ├── sym4_lpf.mem
    │
    └── sym4_hpf.mem
             │
             ▼
      Verilog Testbench
             │
             ▼
     AXI4-Lite Configuration
             │
             ▼
       DWT / IDWT RTL
```

The testbenches currently load `sym4_lpf.mem` using `$readmemh` and subsequently write the coefficients into the RTL coefficient register bank through the AXI4-Lite interface.

This approach allows the filter coefficients to be configured without modifying the RTL source code.

## Notes

* The generated `.mem` files use uppercase hexadecimal notation.
* Each line contains one 16-bit coefficient.
* The files are compatible with the Verilog `$readmemh` system task.
* The default `sym4` configuration produces eight coefficients per filter.
* The default RTL parameter `NTAPS = 8` is intended to match this coefficient count.
* Changing the selected wavelet may require corresponding changes to the RTL `NTAPS` parameter and verification environment.

## Dependency Summary

| Component             | Requirement                    |
| --------------------- | ------------------------------ |
| Python                | 3.11.9                         |
| Wavelet Library       | PyWavelets                     |
| Generated Format      | 16-bit Q15 fixed-point         |
| Memory File Format    | Verilog-compatible hexadecimal |
| Default Wavelet       | Symlet 4 (`sym4`)              |
| Default Filter Length | 8 taps                         |
