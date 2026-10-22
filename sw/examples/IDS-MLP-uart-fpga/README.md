> 🔗 **Original Source:** The Neural Network models, datasets, and architecture concepts in this directory are adapted from the overarching Edge AI ecosystem developed in the [HORNET-RV32IMF-For-AI-Applications](https://github.com/GSTL-ITU/HORNET-RV32IMF-For-AI-Applications) repository.

# 🧠 HORNET-RV32IMF: Edge Intelligence & MLP Inference Test

This directory hosts a comprehensive, hardware-in-the-loop (HIL) system integration test. It deploys a Multi-Layer Perceptron (MLP) Neural Network, specifically trained on the NSL-KDD dataset for Intrusion Detection (IDS), directly onto the **HORNET-RV32IMF** processor. 



## 🎯 Test Objectives

This test acts as a massive stress-test for the entire SoC architecture, validating:
* **Deep Memory Access:** Fetching large arrays of static network weights (`MLP_weights_folded.h`).
* **Intensive Arithmetic:** Continuous, heavy utilization of the FPU and ALU for dot-products and ReLU activations.
* **Interrupt-Driven UART:** Handling large payload buffers (hundreds of bytes per inference) asynchronously via Fast Interrupts while the core calculates.

## 📂 Directory Structure

Unlike simple unit tests, this directory contains a complete embedded AI pipeline.

| File / Directory | Description |
| :--- | :--- |
| **`inference_light_noBatch_FPGA.c`** | **The Firmware:** The main C application. It initializes the UART and IRQ, computes the Dense layer dot-products, applies ReLU activations, and transmits the predicted classification back to the host. |
| **`MLP_weights_folded.h`** | **The Model:** A C-header containing the pre-trained weights and biases. This is a "lightweight/folded" model where Batch Normalization math has been pre-computed and folded into the dense layers to save CPU cycles. |
| **`Makefile` & `linksc.ld`** | **The Build System:** Scripts to compile the firmware and generate the `memory_init.mem` file for Vivado. |
| **`test/`** | **Hardware-in-the-Loop Suite:** Contains Python scripts (`compare_all.py`), input test vectors (`inputs.txt`), expected ground-truth labels, and pre-compiled `.bit` streams for quick deployment. |

---

## 🚀 Quick Start Guide

**1. Build the Firmware**
Compile the C application and generate the `memory_init.mem` payload.
```bash
make clean
make build
```
**2. Synthesize & Flash the FPGA**
Use the generated `.mem` file in your Vivado project to initialize the block RAM and program the board. *(Alternatively, you can skip synthesis and flash one of the pre-compiled bitstreams located in `test/bit_streams/` if your hardware matches).*

**3. Run the Hardware-in-the-Loop Test**
Navigate to the `test/` subdirectory to stream the NSL-KDD feature vectors from your PC to the running FPGA. The Python script will compare the FPGA's hardware predictions against the expected labels.

```bash
cd test
python3 compare_all.py --port /dev/ttyUSB1 --baud 115200 --inputs inputs.txt --labels labels.txt --bytes 488
```
*(Please refer to `test/README.md` for more granular details on the Python verification scripts and terminal outputs).*

---

## 👤 Author / Credentials

* **Yusuf Tekin:** tekiny20@itu.edu.tr