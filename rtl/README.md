# RTL Directory

This directory contains the RTL implementation of the VRM21 Discrete Wavelet Transform (DWT) and Inverse Discrete Wavelet Transform (IDWT) processing modules.

The implementation is intended for fixed-point stereo audio and streaming data processing using AXI4-Lite for configuration and AXI4-Stream for sample transfer.

## RTL Modules

| Module                     | Description                                                                                                     |
| -------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `vrm_dwt_axi.v`            | Top-level Level-1 DWT module with AXI4-Lite coefficient configuration and AXI4-Stream input/output interfaces.  |
| `dwt_decimator_axis.v`     | AXI4-Stream decimation stage used by the DWT processing path.                                                   |
| `vrm_idwt_axi.v`           | Top-level Level-1 IDWT module with AXI4-Lite coefficient configuration and AXI4-Stream input/output interfaces. |
| `idwt_interpolator_axis.v` | AXI4-Stream interpolation stage used by the IDWT processing path.                                               |

## Processing Architecture

The Level-1 DWT processing path can be summarized as:

```text
Stereo AXI4-Stream Input
          │
          ▼
    QMF Analysis Cores
      ┌───────────┐
      │ Left      │
      │ Right     │
      └───────────┘
          │
          ▼
Low/High Subband Packing
          │
          ▼
AXI4-Stream Decimator
          │
          ▼
64-Bit DWT Output
```

The output data is packed using the following format:

```text
{High_R, High_L, Low_R, Low_L}
```

Each component occupies 16 bits.

The Level-1 IDWT processing path performs the reverse operation:

```text
64-Bit DWT Input
          │
          ▼
AXI4-Stream Interpolator
          │
          ▼
Subband Extraction
          │
          ▼
    QMF Synthesis Cores
      ┌───────────┐
      │ Left      │
      │ Right     │
      └───────────┘
          │
          ▼
32-Bit Stereo AXI4-Stream Output
```

The reconstructed stereo output is packed as:

```text
{Right_Channel, Left_Channel}
```

## External RTL Dependencies

This directory depends on the QMF analysis and synthesis implementations provided by the **VRM21 Quadrature Mirror Filter Module FPGA** repository.

[VRM21-Studios/Quadrature-Mirror-Filter-Module-FPGA](https://github.com/VRM21-Studios/Quadrature-Mirror-Filter-Module-FPGA?utm_source=chatgpt.com)

The following modules are required by the DWT and IDWT top-level implementations:

```text
qmf_analysis_core
qmf_synthesis_core
```

These modules are intentionally not duplicated in this repository. They should be obtained from the QMF repository and included in the FPGA project together with the modules contained in this directory.

This dependency structure allows the QMF implementation to remain independently maintained and reused by other DSP architectures within the VRM21-Studios ecosystem.

## FIR Dependency

The QMF implementation is based on FIR filtering principles and may itself depend on RTL components from the **VRM21 FIR Module FPGA** repository.

[VRM21-Studios/FIR-Module-FPGA](https://github.com/VRM21-Studios/FIR-Module-FPGA?utm_source=chatgpt.com)

Therefore, depending on the specific QMF implementation revision being used, an FPGA project may require RTL sources from the following repositories:

```text
VRM21-Discrete-Wavelet-Transform
        │
        ├── Quadrature-Mirror-Filter-Module-FPGA
        │
        └── FIR-Module-FPGA
```

The exact dependency hierarchy should be verified against the version of the QMF implementation included in the target FPGA project.

## Integration

A typical RTL integration flow is:

1. Add the RTL files from this directory to the FPGA project.
2. Add the required QMF RTL modules from the Quadrature Mirror Filter repository.
3. Add any additional FIR dependencies required by the selected QMF implementation.
4. Ensure that all RTL files use compatible parameter values.
5. Configure the DWT or IDWT coefficients through the AXI4-Lite interface before streaming data.
6. Connect the AXI4-Stream interfaces to the appropriate upstream and downstream processing blocks or DMA engines.

## AXI4-Lite Coefficient Configuration

Both `vrm_dwt_axi.v` and `vrm_idwt_axi.v` provide an AXI4-Lite interface for runtime coefficient configuration.

The coefficient registers are stored internally and flattened before being supplied to the corresponding QMF processing cores.

The basic register organization is:

| Word Address   | Function                                           |
| -------------- | -------------------------------------------------- |
| `0`            | General-purpose identification or control register |
| `1` to `NTAPS` | QMF coefficient registers                          |

The number of coefficient registers is determined by the `NTAPS` parameter.

## Important Notes

* The RTL in this directory implements Level-1 DWT and IDWT processing paths.
* The current architecture processes stereo audio using independent left and right QMF cores.
* The DWT output is decimated by a factor of two.
* The IDWT processing path restores the sample rate through zero-insertion interpolation.
* AXI4-Stream backpressure is handled through the `TVALID` and `TREADY` handshake mechanism.
* `TLAST` propagation is preserved across the decimation and interpolation stages.
* Filter behavior, frequency response, reconstruction accuracy, and fixed-point numerical characteristics depend on the configured QMF coefficients.
* External QMF and FIR RTL dependencies should use compatible revisions and parameter configurations.

## Related Repositories

* [Quadrature-Mirror-Filter-Module-FPGA](https://github.com/VRM21-Studios/Quadrature-Mirror-Filter-Module-FPGA?utm_source=chatgpt.com) — QMF analysis and synthesis filter bank implementation used by the DWT and IDWT cores.

* [FIR-Module-FPGA](https://github.com/VRM21-Studios/FIR-Module-FPGA?utm_source=chatgpt.com) — FIR filtering implementation that provides relevant underlying DSP infrastructure for the broader VRM21 filtering ecosystem.
