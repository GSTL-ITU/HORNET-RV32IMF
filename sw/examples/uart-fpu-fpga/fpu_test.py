import serial
import struct
import math
import argparse
import time

def main():
    ap = argparse.ArgumentParser(description="Test RISC-V Hardware FPU via UART")
    ap.add_argument("--port", required=True, help="Serial port (e.g., /dev/ttyUSB0 or COM3)")
    ap.add_argument("--baud", type=int, default=115200, help="Baudrate")
    args = ap.parse_args()

    # Define test vectors: (A, B, C)
    # We will test: A+B, A-B, A*C, A/C, sqrt(A)
    # C must not be 0. A must be >= 0 for sqrt.
    test_cases = [
        (15.5, 4.25, 2.0),      # Standard fractions
        (144.0, 50.0, 12.0),    # Clean integers represented as floats
        (0.854, -0.122, 1.5),   # Negatives and small decimals
        (9999.9, 1111.1, 3.33), # Larger numbers
        (0.0, 0.0, 1.0)         # Zero test
    ]

    with serial.Serial(args.port, args.baud, timeout=2) as ser:
        ser.reset_input_buffer()
        print(f"Connected to FPGA on {args.port} at {args.baud} baud.\n")

        for idx, (a, b, c) in enumerate(test_cases):
            print(f"--- Test Case {idx+1} ---")
            print(f"Sending:  A = {a}, B = {b}, C = {c}")

            # Pack 3 floats (little-endian) -> 12 bytes
            payload = struct.pack('<3f', a, b, c)
            ser.write(payload)
            ser.flush()

            # Wait for 5 floats to come back -> 20 bytes
            resp = ser.read(20)
            
            if len(resp) < 20:
                print(f"❌ Error: Expected 20 bytes, got {len(resp)} (Timeout!)\n")
                continue

            # Unpack 5 floats
            fadd, fsub, fmul, fdiv, fsqrt = struct.unpack('<5f', resp)
            
            # Compute expected answers in Python
            exp_add = a + b
            exp_sub = a - b
            exp_mul = a * c
            exp_div = a / c
            exp_sqrt = math.sqrt(a)

            # Verification (Using math.isclose to handle tiny IEEE-754 precision differences)
            tol = 1e-5
            results = [
                ("A + B", fadd, exp_add),
                ("A - B", fsub, exp_sub),
                ("A * C", fmul, exp_mul),
                ("A / C", fdiv, exp_div),
                ("sqrt(A)", fsqrt, exp_sqrt),
            ]

            all_pass = True
            for name, fpga_val, py_val in results:
                passed = math.isclose(fpga_val, py_val, rel_tol=tol, abs_tol=tol)
                status = "✅" if passed else "❌"
                print(f"{status} {name:7}: FPGA = {fpga_val:<12.5f} | Expected = {py_val:<12.5f}")
                if not passed:
                    all_pass = False

            if all_pass:
                print("Result: ALL PASS\n")
            else:
                print("Result: FAILED\n")

            time.sleep(0.1) # Brief pause before next burst

if __name__ == "__main__":
    main()