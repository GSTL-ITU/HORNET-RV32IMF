import argparse
import sys
from sklearn import metrics

def load_labels(filename):
    """Loads a text file with one integer label per line."""
    labels = []
    with open(filename, 'r') as f:
        for i, line in enumerate(f):
            line = line.strip()
            if line:
                try:
                    # Handle potential "-1" for timeouts
                    labels.append(int(line))
                except ValueError:
                    print(f"Error: Non-integer found in {filename} on line {i+1}: '{line}'")
                    sys.exit(1)
    return labels

def print_comparison_report(y_true, y_pred, title):
    """
    Calculates and prints a detailed comparison report.
    """
    # Get all unique labels from both lists
    labels = sorted(list(set(y_true) | set(y_pred)))
    
    # Calculate main metrics
    accuracy = metrics.accuracy_score(y_true, y_pred)
    
    # Get the detailed classification report as a string
    # This includes precision, recall, and F1-score for each class
    report = metrics.classification_report(
        y_true, 
        y_pred, 
        labels=labels, 
        zero_division=0
    )
    
    # --- Print the full report ---
    print(title)
    print("=" * len(title))
    print(f"Overall Accuracy: {accuracy * 100:.4f}%\n")
    
    print("Detailed Metrics (Precision, Recall, F1-Score):")
    print(report)
    
    # Also show a confusion matrix
    print("Confusion Matrix:")
    print(metrics.confusion_matrix(y_true, y_pred, labels=labels))
    print("\n" + "-"*80 + "\n")


def main():
    ap = argparse.ArgumentParser(
        description="Compares Ground Truth vs. C-Local vs. FPGA-UART predictions."
    )
    ap.add_argument("--truth", required=True, 
                    help="Path to ground-truth file (labels.txt)")
    ap.add_argument("--c-local", required=True, 
                    help="Path to C-local predictions (label_results.txt)")
    ap.add_argument("--fpga-uart", required=True, 
                    help="Path to FPGA-UART predictions (FPGA_results.txt)")
    
    args = ap.parse_args()

    # Load all three files
    print("Loading data...")
    y_true = load_labels(args.truth)
    y_c_local = load_labels(args.c_local)
    y_fpga_uart = load_labels(args.fpga_uart)

    # --- Verify lengths ---
    len_true = len(y_true)
    len_c = len(y_c_local)
    len_fpga = len(y_fpga_uart)

    if not (len_true == len_c == len_fpga):
        print("\n!!! WARNING: File lengths do not match! !!!")
        print(f"  {args.truth}: {len_true} lines")
        print(f"  {args.c_local}: {len_c} lines")
        print(f"  {args.fpga_uart}: {len_fpga} lines")
        
        n_total = min(len_true, len_c, len_fpga)
        print(f"Comparing up to the shortest file limit: {n_total} samples\n")
        
        # Truncate all lists to the shortest length
        y_true = y_true[:n_total]
        y_c_local = y_c_local[:n_total]
        y_fpga_uart = y_fpga_uart[:n_total]
    else:
        print(f"Successfully loaded and verified {len_true} samples from all 3 files.\n")

    # --- Run the 3 comparisons ---

    # 1. Ground Truth vs. C-Local
    print_comparison_report(
        y_true, 
        y_c_local, 
        "Report 1: Ground Truth (labels.txt) vs. C-Local (label_results.txt)"
    )

    # 2. Ground Truth vs. FPGA-UART
    print_comparison_report(
        y_true, 
        y_fpga_uart, 
        "Report 2: Ground Truth (labels.txt) vs. FPGA-UART (FPGA_results.txt)"
    )

    # 3. C-Local vs. FPGA-UART
    # This is the most important for you. 
    # A 100% accuracy here means your hardware perfectly matches your C-code simulation.
    print_comparison_report(
        y_c_local, 
        y_fpga_uart, 
        "Report 3: C-Local (label_results.txt) vs. FPGA-UART (FPGA_results.txt)"
    )

if __name__ == "__main__":
    main()

# Run this script from the terminal:
# python compare_all.py --truth labels.txt --c-local label_results.txt --fpga-uart FPGA_results.txt    