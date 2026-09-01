# Limitations

## Current Verification Status

The current implementation is undergoing RTL simulation and verification.

The provided DWT and IDWT testbenches generate CSV output files for subsequent analysis.

Hardware validation results, including FPGA implementation results, are not implied by the current RTL source alone.

The final verification documentation should distinguish between:

* RTL simulation results.
* Numerical comparison against a software reference.
* FPGA synthesis results.
* Hardware execution results.

## Level-1 Transform

The current top-level implementation provides a single decomposition or reconstruction level.

Recursive multilevel DWT processing is not implemented internally.

A multilevel architecture must be constructed externally by connecting the low-frequency approximation output of one level to the input of another level.

## External RTL Dependencies

The DWT and IDWT top-level modules depend on external QMF processing cores.

The required modules are not duplicated inside this repository.

Simulation and synthesis therefore require the relevant RTL sources from the QMF dependency to be included in the project.

The QMF implementation may itself depend on FIR processing components.

Refer to `rtl/README.md` for the required dependency structure.

## Coefficient Reconfiguration During Streaming

The coefficient register bank can be accessed through AXI4-Lite while the streaming interface is active.

The current implementation does not provide a dedicated atomic coefficient-bank update mechanism.

Updating individual coefficients during an active frame may therefore cause different samples within a processing sequence to use different filter configurations.

Software should configure the complete coefficient set before beginning a streaming transaction whenever a consistent filter configuration is required.

## Fixed-Point Accuracy

The implementation uses finite-width fixed-point arithmetic.

Wavelet coefficients are converted from floating-point values into Q15 representation.

As a result, the RTL output can differ from an ideal floating-point DWT or IDWT reference.

The magnitude of these differences depends on:

* Wavelet coefficient quantization.
* Input amplitude.
* Filter length.
* Accumulator precision.
* Output scaling.
* Rounding behavior.
* Saturation behavior.

## AXI4-Lite Implementation Scope

The AXI4-Lite interface is implemented as a lightweight coefficient configuration interface.

The current design should not be interpreted as a complete generic-purpose AXI4-Lite peripheral implementation with additional features such as:

* Multiple independent configuration banks.
* Atomic bank switching.
* Interrupt generation.
* Hardware-managed configuration status.
* Advanced error reporting.

The interface is primarily intended to support coefficient injection and basic register access.

## Wavelet Configuration

The provided Python utility currently generates coefficients for the Symlet 4 (`sym4`) wavelet.

The default RTL configuration assumes:

```text
NTAPS = 8
```

Changing the wavelet may require corresponding changes to the RTL and verification environment.

A wavelet with a different filter length cannot automatically be substituted without checking the coefficient register bank size and associated RTL parameters.

## CSV-Based Simulation Results

The provided testbenches record output samples in CSV format.

CSV generation demonstrates that simulation output has been captured, but the files alone do not establish complete functional equivalence with a mathematical reference model.

Additional analysis is required to evaluate:

* Reconstruction accuracy.
* Sample alignment.
* Expected filter latency.
* Frequency response.
* Perfect reconstruction behavior.
* Quantization error.

These analyses can be added after the simulation result files are available.

## FPGA Validation

The current repository documentation should not claim FPGA validation unless the complete design has been synthesized, implemented, deployed, and tested on actual FPGA hardware.

RTL simulation success and successful synthesis are separate validation stages from physical hardware execution.
