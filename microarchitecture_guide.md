# Jellycore Microarchitecture Guide
## Introduction
Jellycore is a 32-bit core architecture implementing a part of the RV32IM specification, excluding division. It is designed to support out-of-order instruction execution with a focus on cycle-level considerations, enabling a deeper understanding of CPU core microarchitecture. To achieve this, the design emphasizes the Back End while simplifying the Front End and memory communication. Jellycore is heavily inspired by RIDECORE, and some of hardware modules are directly adapted from it. [[1]](#reference)

## Jellycore Overview
(pipeline overview figure)

Jellycore consists of the following stages: Fetch, Decode, Register Rename, Dispatch, Issue, Execute, Memory, Writeback, and Commit. The core design features are outlined below:

- A gshare branch predictor
- A merged register file
- A unified issue queue
- A read-after-issue mechanism to streamline dispatch and data movement
- Wakeup logic inspired by the MIPS R10000 and prefix-sum-based select logic for position based priority
- Selective re-execution to handle memory-order violations
- Backward-traversal recovery for branch mispredictions

Jellycore supports a 2-way superscalar pipeline for the Fetch, Decode, Rename, Dispatch, and Commit. It includes 3 issue ports that directs instructions to 2 ALU, 1 Load/Store Unit, 1 Branch Unit, 1 Multiplier. For simplicity, memory is accessed directly without a cache hierarchy.

## Fetch

## Decode

## Register Rename
Register Renaming eliminates false dependences to exploit more ILP by renaming every register tag and allocating a new physical register tag to instructions producing a register result. Jellycore uses a merged register file designs, which holds both speulative and committed values. Register Renaming in Jellycore is done in a single cycle, as 2-wide instruction renaming does not significantly increase complexity due to the simplicity of the dependence check logic and the RAT read.

Renaming performs two main functions:

- Translates architectural register tags to physical register tags using mapping information in the Register Alias Table (RAT).
- Allocates a new physical register tag to every instruction that performs a register write operation and updates the new mapping information in the RAT.

To achieve this correctly, a freelist for physical register tags, the RAT, and dependence check logic within an instruction group are required.

### Freelist
The Freelist is implemented as a bit-vector, where each bit represents the availability of a physical register tag. A Priority Decoder scans the bit-vector to find the required number (at most 2) of available tags for the current instruction group. The selected tags are then sent to the RAT to update the new mapping of architectural registers for instructions producing register results. If no free physical register is available, the renaming stage generates a stall signal.

### Register Alias Table (RAT)
The Register Alias Table is a RAM that maintains the speculative mappings from architectural registers to physical registers. At the negative edge of the renaming stage, the RAT is looked up to provide physical tags for each source operand. The original destination tags are also read to restore the RAT to its architectural state and invalidate all speculative mappings during recovery from misspeculation. The newly allocated physical tags are updated at the end of the cycle (positive edge)

### Dependence Check Logic
The Dependence Check Logic is responsible for honoring true dependences between instructions in the same group by comparing the destination tag of the first instruction and the source tags of the second instruction. It also generates a WAW_valid signal to update the RAT correctly. When two instructions in the same group write to the same architectural register, the mapping should follow the destination tag of the second instruction.

(dependence check logic figure)

## Dispatch
Dispatch allocates resources to each instruction for executing instructions out of order (Issue Queue, Load/Store Queue) and ensuring instructions are committed in order (Reorder Buffer). The type of instruction is used to determine which structures it requires and where to place it. It is also responsible for allocating a port number to the corresponding Functional Unit (FU) for each instruction and balancing the load on the FUs. If there is any structure with no available slot, the dispatch stage generates a stall signal.

(dispatch flow(wrap_around + rob index, load/store index, freelist, scoreboard) figure)

### Issue Port
Jellycore has three Issue Ports, each directing instructions to specific FUs ([Execute and Bypass](#execute-and-bypass)). After instructions are renamed, an Issue Port number is assigned to each instruction based on its type and the load on FUs. This number is allocated to the instruction's Wakeup Logic entry and is used to steer the request signal to the corresponding Select Logic associated with the assigned Issue Port.

### Scoreboard
The Scoreboard is a table that maintains the register states. Each entry in this table represents the state of a register value, including whether it is available and how many cycles it needs to become ready. The entry is composed of M-bit (match bit), R-bit (ready bit), a shift register, and delay bits. This information is copied to the issue queue entry at dispatch, enabling each instruction in the issue queue to track the readiness of its source operands. The mechanism of the Scoreboard is described in [Issue Logic](#issue-logic-wakeupselect).

### Issue Queue
The Issue Queue holds instructions waiting to be executed out of order. All renamed instructions enter the Issue Queue and wait until all of their source operands are ready and they are selected by the Select Logic. The Wakeup/Select process is described in detail in [Issue Logic](#issue-logic-wakeupselect). The available entries in the Issue Queue are also maintained by the Issue Queue Freelist.

### Load Queue and Store Queue
The Load Queue and Store Queue are FIFO queues that store Load and Store instructions, respectively. At dispatch, Loads should accompany the tail of the Store Queue to forward the value of address-matched older stores in the Store Queue, and Stores should accompany the tail of the Load Queue to detect memory-order violations by searching the Load Queue. Thus, the tail information from the Load/Store Queues is allocated to the Issue Queue.

### Reorder Buffer
The Reorder Buffer (ROB) is a FIFO queue that holds all in-flight instructions in the pipeline. The ROB ensures that instructions are committed in program order, regardless of the order in which the processor executes them. At dispatch, all instructions are dispatched to the ROB and the Issue Queue. The ROB entry number is sent to the Issue Queue to address branch misprediction using an additional sorting bit (by Buyuktosunoglu [[1]](#reference)). The sorting bit and the ROB entry number are concatenated as follows:

- Sorting Bit | ROB Entry Number

(sorting bit and wrap around process figure)

The ROB is a circular FIFO queue that wraps around when the tail reaches the lowest index (where lower indices represent younger instructions) and allocates the highest index. When this occurs, the ROB generates a wrap-around signal and it is sent to the Issue Queue to set the sorting bit of all previously dispatched instructions to 1. Newly dispatched instructions are assigned a sorting bit of 0. This mechanism ensures that younger instructions with a sorting bit of 0 but higher ROB entry numbers are recognized as younger than instructions with a sorting bit of 1 and lower ROB entry numbers.

During recovery from a branch misprediction, the ROB entry number of the branch instruction, including the sorting bit, is compared with the instructions in the Issue Queue to identify and flush those on the wrong path. The Reorder Buffer also stores mapping information, including the architectural register tag of the destination register and its original physical register tag before renaming. This information enables backward-traversal recovery, which restores the architectural state of the RAT. The detailed process is explained in [Recovery](#recovery).

### Immediate Buffer, PC Buffer, and Predicted Address Buffer
The Immediate Buffer stores immediate values for instructions that use immediate operands, such as addi, lw/sw, beq, and others. The PC Buffer stores PC values for PC-related calculations. Additionally, branch and jump instructions must retain their predicted target address to verify whether the predicted branch target matches the calculated address. To avoid re-accessing the Branch Target Buffer and to initiate recovery as quickly as possible, a small Predicted Address Buffer is implemented to store the predicted target addresses. These structures are managed with freelists, which return an index number while assigning instructions to the Issue Queue at dispatch when necessary.


## Issue
The Issue Logic is a core component that enables out-of-order execution of instructions. It consists of the Issue Queue, Wakeup Logic, and Select Logic. All renamed instructions wait in the Issue Queue. When their source operands become ready through the Wakeup Logic or the Scoreboard, they send request signals to the Select Logic, which prioritizes instructions based on the location in the Issue Window. If selected, the instruction is issued and broadcasts its destination tag to all entries in the Issue Queue ([[2]](#reference)).

(issue logic figure)

### Issue Queue
Jellycore uses a unified issue queue, which utilizes entries more flexibly compared to distributed Issue Queues and Reservation Stations. Therefore, all instructions enter the same Issue Queue regardless of their type. Jellycore also adopts read-after-issue to streamline the dispatch stage and data movement, so the Issue Queue does not hold source values.

### Wakeup Logic
Each Wakeup Logic entry consists of following fields, similar to the MIPS R10000 ([[2]](#reference), [[3]](#reference), [[4]](#reference)).

(issue queue(wakeup logic) entry figure)

The source tag fields are tied to comparators which compare the source tag with broadcasted tags and assert a signal when a match from one of them occurs to indicate the source value is about to be ready. In Jellycore, destination tags of instructions are broadcasted in the same cycle as instruction selection for execution. Since not all instructions have the same execution latency, the DELAY field holds the execution latency of the instruction producing the source operand value. The DELAY field is filled with the least significnat N-1 zeros bits for N-cycle exeution latency.

(scoreboard and wakeup logic entry mechanism figure)

When the tag in the Source Tags field matches the destination tag of a parent via one of the tag comparators (CAM Search), the MATCH bit is set, and the value in the DELAY field is copied into the SHIFT field. The SHIFT field is part of an arithmetic right shift register, with its least significant bit serving as the READY bit. The MATCH bit acts as a shift enable signal for this register. Once all READY bits are set, the instruction sends a request signal to the Select Logic. (The Scoreboard operates with essentially the same mechanism as the Wakeup Logic entry. The register value states it holds are copied into the Wakeup Logic entry at dispatch.)

These fields are used only when the register value corresponding to the source tag of an instruction serves as an operand for execution. Otherwise, the Issue Logic fills the SHIFT field with 1's (with the READY bit set to 1) and sets the MATCH bit using operand valid signals and operand select signals (e.g., uses_rs and src_sel).

As discussed above, a cache is not implemented in this design, meaning that memory operations always have a consistent execution latency. Consequently, there is no need for speculative wakeup of load consumers, and the DELAY field of the destination tag for loads always contains the correct latency.

### Select Logic

(prefix-sum Select logic figure)

Jellycore adopts the Select Logic using a prefix-sum circuit which selects one request signal to grant based on the cumulative sum of 1-bit issue requests from the Wakeup Logic. The prefix-sum circuit computes the cumulative sum of request signals starting from the first Wakeup Logic entry and grants i-th request signal if it is asserted and the (i-1)-th cumulative sum is 0. This is a simple position-based selection mechanism that prioritizes request signals from higher-positioned entries in the Issue Window. To reduce complexity, a compaction circuit for oldest-first selection is not used.

The Select Logic comsists of three prefix-sum circuits, each dedicated to a single Issue Port. Note that the request signal generated by an instruction is routed to only one specific prefix-sum circuit based on the instruction's Issue Port number.

To enable back-to-back execution of single cycle instructions, two of following are required ([[6]](#reference)).
- Wakeup and Select in a Single Cycle
- Data Forwarding

(wakeup-select process at cycle-level + example figure)

### Payload RAM
The Payload RAM stores additional information about instructions required for execution. It includes the following items:

- alp_op: Selects which operation to perform on the ALU.
- imm_ptr, pc_ptr, and pba_ptr: Index the corresponding buffer entries.
- inst_type, uses_rs, and src_sel: Indicate the type of operation and operand.
- lq_idx: Verifies the correct order of memory operations by searching the Load Queue when stores issue.
- sq_idx: Looks for an available value to forward from older and dependent stores by searching the Store Queue (and the Store Buffer) when loads issue.
- sorting_bit and rob_num: Used during recovery from branch mispredictions to compare the relative position in the ROB with the mispredicted branch instruction and to flush instructions on the wrong path.


## Execute and Bypass

## Memory Operations

a merged store queue and store buffer (from the superfluous load queue)

### Load Queue


### Store Queue and Store Buffer
(merged store queue figure)

### Recovery from Memory Order Violation

## Commit


## Recovery from Branch Misprediction
backward-traversal recovery

## Reference
1. M. Fujunami, S. Mashimo, T. V. Chu, Kenji Kise, ["RIDECORE: RIsc-v Dynamic Execution CORE"](https://github.com/ridecore/ridecore). 

2. A. Buyuktosunoglu, A. El-Moursy, D. H. Albonesi, ["An oldest-first Select logic implementation for non-compacting issue queues"](https://ieeexplore.ieee.org/abstract/document/1158026?casa_token=bk5M2nsGCiQAAAAA:X8YbCzzJhruD7Em9tDfljI5dP1r-wRLovMa2-YEhhCQ0R1SBmDvtGlZ1VBz41YOj7GW5Vl5n), in 15th Annual IEEE International ASIC/SOC Conference, 2002.

3. K. Yamaguchi, Y. Kora, H. Ando, ["Evaluation of Issue Queue Delay: Banking Tag
RAM and Identifying Correct Critical Path"](https://ieeexplore.ieee.org/abstract/document/6081417), in IEEE 29th International Conference on Computer Design, 2012.

4. Kenneth C. Yeager, [“The MIPS R10000 superscalar microprocessor”](https://ieeexplore.ieee.org/document/491460), in IEEE Micro 16.2, 1996.

5. J. Stark, M.D. Brown, Y. N. Patt, ["On Pipelining Dynamic Instruction Scheduling Logic"](https://dl.acm.org/doi/10.1145/360128.360136), in Proceedings of the 33rd annual ACM/IEEE international symposium on Microarchitecture, 2000.

6. Khubaib, M.A. Suleman, M. Hashemi, C. Wilkerson, Y. N. Patt, ["MorphCore: An Energy-Efficient Microarchitecture for High Performance ILP and High Throughput TLP"](https://dl.acm.org/doi/10.1109/MICRO.2012.36), in Proceedings of the 2012 45th Annual IEEE/ACM International Symposium on Microarchitecture, 2012.

7. I. Jeong, J. Lee, M. K. Yoon, W. W. Ro, ["Reconstructing Out-of-Order Issue Queue"](https://dl.acm.org/doi/10.1109/MICRO56248.2022.00023), in Proceedings of the 55th Annual IEEE/ACM International Symposium on Microarchitecture, 2022.

8. S. Palacharla, N. P. Jouppi, J. E. Smith, ["Complexity-effective superscalar processors"](https://dl.acm.org/doi/abs/10.1145/264107.264201), in Proceedings of the 24th annual international symposium on Computer architecture, 1997.

9. A. Ros, S. Kaxiras ["The superfluous load queue"](https://dl.acm.org/doi/10.1109/MICRO.2018.00017), in Proceedings of the 51st Annual IEEE/ACM International Symposium on Microarchitecture, 2018.