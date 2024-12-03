# Fetch

# Decode

# Register Renaming
Register Renaming eliminates false dependences to exploit more ILP by renaming architectural register tags to physical register tags for every instruction.

Renaming performs two main functions.
(1) translate architectural register tags to physical register tags using mapping information in Register Alias Table(RAT)
(2) allocate a new physical register tag to every instruction which performs a register write operation and write the new mapping information to RAT.

To correctly achieve these, it requires freelist, Front-end RAT, and dependence check logic in an instruction group. Freelist stores bit-vector which indicates each physical register tag is free to use. If there is no free physcial register to assign, Renaming stalls.

An original destination tag should be sent to release itself in commit stage which is no longer represent architectural register tag. 

In this core, Front-end RAT contains speculative mapping information(non-committed) which can be replaced when branch mispredictions occur. On the other hand, Retirement RAT holds committed architectrual state. In every commit stage, destination

# Dispatch

# Issue (Wakeup/Select)

# Execute

# Writeback

# Commit