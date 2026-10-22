import argparse
import numpy as np
import serial
import time
import sys

def load_labels(filename):
    """Loads a text file with one integer label per line."""
    print(f"Loading labels from {filename}...")
    labels = []
    with open(filename, 'r') as f:
        for line in f:
            line = line.strip()
            if line:
                try:
                    labels.append(int(line))
                except ValueError:
                    print(f"Error parsing label: {line}")
                    sys.exit(1)
    print(f"Loaded {len(labels)} labels.")
    return labels

def load_input_vectors(filename):
    """
    Loads input vectors from a C-style array text file.
    Expected format per line: { 0.0f, 1.0f, ... };
    """
    print(f"Loading input vectors from {filename}...")
    vectors = []
    with open(filename, 'r') as f:
        for i, line in enumerate(f):
            line = line.strip()
            if not line:
                continue
            
            line_clean = line.strip('{').strip('};')
            parts = line_clean.split(',')
            
            try:
                floats = [float(p.strip().rstrip('f')) for p in parts if p.strip()]
                vectors.append(floats)
            except ValueError as e:
                print(f"Error parsing floats on line {i+1}: {e}")
                print(f"Line content: {line}")
                sys.exit(1)
                
    print(f"Loaded {len(vectors)} input vectors.")
    return vectors

def convert_to_bytes(float_vector):
    """Converts a list of floats to a little-endian byte string."""
    arr = np.array(float_vector, dtype='<f4')
    return arr.tobytes()

def send_one_sample(ser: serial.Serial, payload_bytes: bytes, write_chunk=None, inter_chunk_delay=0.0):
    if write_chunk is None:
        ser.write(payload_bytes)
    else:
        for i in range(0, len(payload_bytes), write_chunk):
            ser.write(payload_bytes[i:i+write_chunk])
            if inter_chunk_delay > 0:
                time.sleep(inter_chunk_delay)
    ser.flush()

def read_one_prediction(ser: serial.Serial, timeout_s=3.0):
    old_timeout = ser.timeout
    ser.timeout = timeout_s
    try:
        data = ser.read(1) # Read exactly 1 byte
        if len(data) == 1:
            return int.from_bytes(data, 'little')
        return None # Timeout
    finally:
        ser.timeout = old_timeout

def main():
    # These arguments allow user to specify serial port, baudrate, input files, etc.
    ap = argparse.ArgumentParser(
        description="Send feature vectors from a text file over UART and check predictions."
    )
    # --- Serial Port Args ---
    ap.add_argument("--port", required=True, help="Serial port (e.g., COM5)")
    ap.add_argument("--baud", type=int, default=115200, help="Baudrate (default: 115200)")
    
    # --- File Input Args ---
    ap.add_argument("--inputs", required=True, help="Path to inputs.txt file")
    ap.add_argument("--labels", required=True, help="Path to labels.txt file (ground truth)")
    
    ap.add_argument("--output", help="Optional: File to save the FPGA's predictions to (e.g., label_results.txt)")
    
    # --- Model & Send Args ---
    ap.add_argument("--bytes", type=int, required=True, help="Expected bytes per sample (e.g., 488 for 122 floats)")
    ap.add_argument("--chunk", type=int, default=64, help="Write in chunks of N bytes (default: 64)")
    ap.add_argument("--delay", type=float, default=0.001, help="Delay between chunks (default: 0.001s)")
    ap.add_argument("--pred-timeout", type=float, default=3.0, help="Seconds to wait for prediction (default: 3.0)")

    args = ap.parse_args()

    # Load test data from files
    input_vectors = load_input_vectors(args.inputs)
    true_labels = load_labels(args.labels)
    
    n = len(input_vectors)
    if n == 0:
        print("No inputs found.")
        return
    if n != len(true_labels):
        print(f"Error: Mismatch in file lengths! Inputs: {n}, Labels: {len(true_labels)}")
        return

    # --- Open output file if specified ---
    output_file_handle = None
    if args.output:
        try:
            output_file_handle = open(args.output, 'w')
            print(f"Saving prediction results to: {args.output}")
        except IOError as e:
            print(f"Error: Could not open output file {args.output} for writing: {e}")
            return

    # Open serial port
    with serial.Serial(
        port=args.port,
        baudrate=args.baud,
        bytesize=serial.EIGHTBITS,
        parity=serial.PARITY_NONE,
        stopbits=serial.STOPBITS_ONE,
        timeout=1,
        write_timeout=2,
    ) as ser:
        ser.reset_input_buffer()
        ser.reset_output_buffer()

        correct = 0
        wrong = 0
        
        print(f"\nStarting test: sending {n} samples to {args.port} at {args.baud} baud...")
        
        # --- *** START TIMER *** ---
        start_time = time.time()
        
        for idx in range(n):
            input_floats = input_vectors[idx]
            true_label = true_labels[idx]
            raw_bytes = convert_to_bytes(input_floats)
            
            if len(raw_bytes) != args.bytes:
                print(f"Error at index {idx}: Vector has {len(raw_bytes)} bytes, but expected {args.bytes}")
                continue

            send_one_sample(
                ser,
                raw_bytes,
                write_chunk=args.chunk,
                inter_chunk_delay=args.delay,
            )

            pred = read_one_prediction(ser, timeout_s=args.pred_timeout)
            
            # --- *** WRITE TO FILE *** ---
            if output_file_handle:
                if pred is None:
                    output_file_handle.write("-1\n") # Write -1 for timeout
                else:
                    output_file_handle.write(f"{pred}\n")
            

            if pred is None:
                wrong += 1
                print(f"[{idx:05d}] true={true_label} \tpred=∅ (TIMEOUT) \t-> ❌")
            else:
                is_ok = (pred == true_label)
                if is_ok:
                    correct += 1
                    # --- *** MODIFIED THIS LINE *** ---
                    print(f"[{idx:05d}] true={true_label} \tpred={pred} \t-> ✅")
                else:
                    wrong += 1
                    print(f"[{idx:05d}] true={true_label} \tpred={pred} \t-> ❌")

        # --- *** END TIMER AND CALCULATE DURATION *** ---
        end_time = time.time()
        total_duration = end_time - start_time
        
        print("\n=== Summary ===")
        print(f"Total tested: {n}")
        print(f"Correct: {correct}")
        print(f"Wrong:   {wrong}")
        accuracy = (correct / n) * 100
        print(f"Accuracy: {accuracy:.2f}%")
        # --- *** PRINT TOTAL TIME *** ---
        print(f"Total time: {total_duration:.2f} seconds")
        
    # --- Close the output file ---
    if output_file_handle:
        output_file_handle.close()
        print(f"Results saved to {args.output}")

if __name__ == "__main__":
    main()