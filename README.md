# JELLYCORE
JELLYCORE is a RISC-V 2-wide Superscalar Out-of-Order Core supporting RV32IM instruction set. Written in Verilog HDL, it is being developed by Gyeongjae Lee and Hoje Lee at Yonsei University. JELLYCORE's microarchitecture is based on structures described in research papers and "Processor Microarchitecture: An Implementation Perspective". For detailed information about microarchitectue, please refer to [microarchiteure_guide.md](https://github.com/GyeongjaeLee/Jellycore/blob/main/.microarchitecture_guide.md).

Although still under development, JELLYCORE aimsto be synthesizable and testable on FPGAs. 

Some hardware modules in JELLYCORE and simulation method are adapted from [RIDECORE](https://github.com/ridecore/ridecore). 

# How to start (Linux)
This guide is based on the RIDECORE simulation process.

### Install Toolchains

* riscv-tools : riscv-tools include a C/C++ cross compiler for RISC-V and an ISA simulator. Install them with:
    ```
    sudo apt update
    sudo apt install gcc-riscv64-unknown-elf
    ```
* Icarus Verilog (iverilog) : Icarus Verilog is an open-source verilog simulator. Install it with:

    ```
    sudo apt install iverilog
    ```

* memgen : memgen generates binary code for JELLYCORE from ELF files. The source code for memgen is located in toolchain/memgen-v0.9. Compile it using:
    ```
    cd toolchain/memgen-v0.9
    make
    ```

### Compile Applications and Simulate JELLYCORE

Some sample applications are in src/test/jellycore/app. Compile this source code with "make", then you can generate binary code (init.bin) from the C code and the assembly startup code. By copying this binary code to src/test/jellycore/bin through "make copy", you can run it in verilog simulation.

To simulate JELLYCORE, you have to generate an executable file (a.out) through "make last" in src/test/jellycore/sim. The Makefile compiles testbench_last.v and all the source codes. tesbench_last.v loads a sample binary code in src/test/jelloycore/bin and runs it on the implemented core. By running the executable file (a.out), the results of the application will be printed based on the data in the data memory at the end of simulation. 
