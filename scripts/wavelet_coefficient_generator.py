import pywt


def generate_mem_files():
    """
    Generate Q15 fixed-point coefficient memory files for the Symlet 4 wavelet.

    Two Verilog-compatible memory files are generated:
        - sym4_lpf.mem: Low-pass decomposition filter coefficients.
        - sym4_hpf.mem: High-pass decomposition filter coefficients.
    """

    # Symlet 4 uses an eight-tap filter configuration.
    wavelet = pywt.Wavelet("sym4")

    def to_q15_hex(value):
        """
        Convert a floating-point coefficient to a signed Q15 hexadecimal value.

        The resulting value is stored as a 16-bit two's complement
        hexadecimal number suitable for use with Verilog $readmemh.
        """

        # Convert the floating-point coefficient to Q15 format.
        q_value = int(round(value * 32768.0))

        # Clamp the result to the signed 16-bit range.
        if q_value > 32767:
            q_value = 32767
        if q_value < -32768:
            q_value = -32768

        # Convert the signed integer to a 16-bit two's complement value.
        return format(q_value & 0xFFFF, "04X")

    # Generate decomposition low-pass and high-pass coefficients.
    low_pass_hex = [to_q15_hex(coefficient) for coefficient in wavelet.dec_lo]
    high_pass_hex = [to_q15_hex(coefficient) for coefficient in wavelet.dec_hi]

    # Write the low-pass coefficients in a Verilog-compatible memory format.
    with open("sym4_lpf.mem", "w", encoding="ascii") as file:
        file.write("\n".join(low_pass_hex) + "\n")

    # Write the high-pass coefficients in a Verilog-compatible memory format.
    with open("sym4_hpf.mem", "w", encoding="ascii") as file:
        file.write("\n".join(high_pass_hex) + "\n")

    print("[SUCCESS] Wavelet coefficient memory files generated successfully.")
    print("[OUTPUT] sym4_lpf.mem")
    print("[OUTPUT] sym4_hpf.mem")


if __name__ == "__main__":
    generate_mem_files()
