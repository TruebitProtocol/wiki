
# Truebit VM Spec

Truebit is an interactive cryptoeconomic protocol for verifiable computation.

It is explained in detail in the [whitepaper](http://people.cs.uchicago.edu/~teutsch/papers/truebit.pdf), this [post](https://medium.com/truebit/truebit-the-marketplace-for-verifiable-computation-f51d1726798f), and this [presentation](https://youtu.be/S7DVQb0NmBA?t=3m36s).

In this spec, we will confine ourselves to the design of the Truebit Virtual Machine.

Recall that the Task Giver creates a Task by providing a program (a WebAssembly module), a set of inputs, and a reward. The Solver supplies the solution, having run it offchain. Verifiers can submit challenges. In case of no challenge, the Task Giver receives their solution via a callback. In the case of a challenge, the Solver and Challenger engage in a verification game (effectively a binary search through the program instructions, resolving in O(log(n)) time, with n being the number of instructions) with the first disputed step run on chain, using the base blockchain as a supreme court.

As such, the Truebit virtual machine has two implementations:
* The Offchain VM: executes tasks offchain and creates state snapshots.
* The Onchain VM: is initialized by state snapshots and proofs, and executes a single step onchain.

The Truebit Virtual Machine is a modified version of WebAssembly.

In this spec, we will explore the various components of the design.

# Why WebAssembly?

WebAssembly is an ISA (instruction set architecture) developed by the four major browser vendors: Google, Apple, Mozilla, and Microsoft.

Truebit builds off of the WebAssembly VM, instead of the EVM (Ethereum Virtual Machine) or another VM. The following considerations played into this design decision:

* WASM is portable; due to its original home in the browser, it runs on most hardware architectures and operating systems.

* WASM is size- and load-time-efficient; this minimizes the amount of data and state needed within the Truebit system.

* WASM is designed to be sandboxed and secure; the VM can only interact with the host environment through imports and exports.

* WASM is a compilation target for existing high-level programming languages (C, C++, Rust, etc); these programs have large library ecosystems which can be run on Truebit.

* WASM has the continued resources of large tech companies behind it (Google, Apple, Mozilla, Microsoft); as such, it will continue to improve and has a growing ecosystem of tooling.

* WASM is becoming the virtual machine of choice for blockchains going forward; existing projects include Ethereum (eWASM), Polkadot, Dfinity, and EOS. Using WASM allows Truebit to directly integrate with these chains going forward.

* EVM words are 256 bits, rendering state snapshots and proofs more demanding.

* EVM words are 256 bits, and do not map efficiently to 32/64 bit architectures.

* EVM has special-meaning opcodes which do not correspond to VM operations, and need to be removed in Truebit (e.g. CALL, SSTORE, SLOAD, etc.)

# Non-determinism

Blockchain consensus requires determinism. Nodes running the same computation should arrive at the same solution under all circumstances; otherwise, there will be a disagreement.

As such, the Truebit Virtual Machine defines a deterministic subset of WebAssembly.

The particular features pertain to:

## Resource Limits

Nodes have different amounts of memory and native call stack limits (depending on their operating system). Left unchecked, they would run into their respective limits and fail at different times. This breaks consensus.

To prevent this, the Truebit virtual machine fixes these values for all nodes.

### The Call Stack

In Truebit, the max call stack depth is set as a parameter. 

This is helpful, moreover, as knowing the stack depth allows us to easily Merkleize the state and read proofs. 

This is implemented via metering; each call increments a counter, which at some points hits max limit.

An alternate implementation could allow the call stack to grow, while making it expensive to do so. This system could increase cost quadratically with depth of stack elements (as the EVM does with memory allocation currently). The costs could, moreover, relate to how large the call frame is (pushing a call frame with more locals should cost more). This design might be unnecessary for Truebit, however, as all code is provided by the Task Giver; execution does not take place in an adversarial environment where one contract can call into another.

### The Memory

The Truebit VM requires that memory is fully allocated upfront. This allows the state Merkle tree to be defined ahead of time.

## Floating Point

In the IEEE 754 standard for floating point, the sign bit of NaNs is unspecified, and thus largely architecture-dependent. WebAssembly does not specify this behaviour either.

This means we have to force native code compiled from WebAssembly to behave in the same way as the canonical Truebit VM interpreter.

This can be done in one of three ways:

1- Make the NaN bits deterministic: 

This involves canonicalizing the bit pattern of NaNs in the Truebit VM. We instrument the interpreter or JIT such that after each floating point operation that “could” result in a NaN, it canonicalises the definition. To keep things efficient, this only needs to be done after observing the non-deterministic bit and seeing a NaN.

Refer to this issue from Cretonne, Mozilla’s WASM JIT, for more info: https://github.com/cretonne/cretonne/issues/311

We would, moreover, implement a floating point library in Solidity for use by the onchain interpreter.

2- Emulate floating point as integers:

Since the onchain interpreter is not able to represent floating point values (it is implemented on Ethereum), we emulate all floating point as integers. 

This approach used in the Truebit proof of concept implementation. We use this [tool](http://www.jhauser.us/arithmetic/SoftFloat.html) to do so.

3- Disallow floating points:

In the “validation” phase of executing the WASM module, can add an extra rule which disallows floating point values and operations. This prevents modules with floating point from running in the system. It is the approach used by eWASM and parity-wasm.

## External Calls

External calls are a source of non-deterministic execution (think of a random generator function). It could be argued that non-determinism introduced by some calls can be “local” and not affect the final state. This will be explored through formal verification methods in the future. For the time being, however, Truebit disallows external calls by the VM.

## Instantiating the VM

The instantiation of the WASM VM is non-deterministic and left up to the JIT (i.e. in how the memory, globals, and call tables are loaded). Truebit’s approach to making this deterministic is described in section “Instantiating the VM”.

# Determining the Task Reward

Task Givers need to remunerate Solvers, in accordance to the amount of work they perform.

Moreover, Truebit is a computation marketplace. Task Givers can pay more or less, making an attractive offer for Solvers. Solvers, on the other hand, take on tasks which are profitable given their own cost structures and margins. We allow market forces and competition to drive efficiency.

To implement this system, Truebit employs a similar model to Ethereum. A Task Giver supplies a “gas price” and “gas limit” when they submit the task. The two values being:

* Gas price: amount they will pay per gas (denominated in the payment currency – e.g. ETH).
* Gas limit: the max amount of gas they will pay for within this computation.

Truebit has a gas schedule – mapping WASM opcodes to gas – which is used to dynamically keep track of gas consumed by a Task.

# Metering

Inspired by the eWASM and parity-wasm designs ([link](https://github.com/ewasm/wasm-metering)), Truebit implements gas metering as follows:

The metering job begins by reading through the WASM bytecode. It identifies branching instructions (e.g. an “if” opcode). These instructions straddle blocks of code which will be executed as atomic units (e.g. either, all instructions within an if block are executed, or none are). For each block, then, the metering process tallies up gas costs used by all instructions and chunks of allocated memory; it then inserts a single metering instruction at the top of the block, effectively adding the value to an ongoing gas counter, which is modeled by a global variable.

Thus, the WASM module now has metering instructions injected in. When time comes for execution, each block of code increases the gas used counter. The process terminates if this value goes above the gas limit set by the Task Giver.

A question remains: _who_ injects the metering instructions into the WASM module?

We cannot require the Task Giver to provide a metered WASM module, since they could lie (and  their incentives in fact have them lowering their costs).

How we do this is presented in the section “Execution of a Task”.

# Dealing with State

Truebit verification games narrow down disputed computation to a single step, which is then run on the blockchain.

By the end of a game, the Solver has committed to their state before the disputed instruction (dubbed the preState), and their state after the disputed instruction (dubbed the postState) by means of a Merkle root hash. At this point, the onchain VM is initialized to the preState, the disputed instruction is run, and the resulting state is compared to the Solver’s postState. If the two values are different, the Solver lied and their deposit is slashed.

Knowing this process, we notice the following points:

1. state snapshots: the offchain VM should be able to create Merkle trees of state; the onchain VM should be able to read Merkleize state and initialize.

2. execution of the disputed step should always fit in the blockchain gas limit.

3. initialization of the VM state should be deterministic.

We will discuss these in turn.

## State Snapshots

This is a Merkle tree created from the VM state.

The VM state (i.e. the leafs of the tree) include the following (details [here](https://github.com/TrueBitFoundation/wiki/blob/master/docs/WASM/WASMSolidityOverview.md)):

* `code`: Merkle root of the op code array.
* `stack`: Merkle root of the stack.
* `memory`: Merkle root of memory.
* `globals`: WebAssembly global variables.
* `calltable`: Table of function pointers.
* `calltable_types`: Types of function pointers.
* `call_stack`: Merkle root of the function call stack.
* `input_size`: Merkle root for the sizes of input files.
* `input_name`: Merkle root for the names of input files.
* `input_data`: Merkle root for the contents of input files.
* `pc`: Program counter.
* `stack_ptr`: Pointer to the top of the stack. 
* `call_ptr`: Pointer to the top of the call stack.
* `memsize`: Size of the memory.

Note that in the initial state, all values except code and inputs roots are empty.

To make merkleization simpler, the Truebit VM fixes the size of memory and stack depth. This makes the leafs addressable.

Each leaf of the tree is 64 bits. Memory has the most bits – e.g. 30 bits can represent ~ 4 GB.

### The Stack

To create the state tree, Truebit needs to Merkleize the WASM stack (the value stack, the control-flow stack, the call stack). This is one area where Truebit diverges from other implementations; the WASM spec does not specify the stack implementation. 

To simplify merkleization, the Truebit proof of concept uses a single stack (implemented on the heap). This adds some other complications, however, such as the code needing to keep track of jumps, as there is no separate control-flow stack. A future scope of work is to perhaps follow the WASM spec more closely here.

It’s helpful to note that the Truebit VM is not the only usecase needing stack inspection. GC (garbage collection) requires this. It could also be helpful for crash reporting, and other debugging tools.

### Memory Abstraction

The core difference between the off-chain and on-chain VMs is that off-chain VM has full access to the machine state, and the on-chain VM only has access to the parts of the memory that were sent to blockchain with Merkle proofs. 

We say that the onchain interpreter is stuck if there is not enough data to run it forward. This only happens if the Solver neglects to provide data, which results in them being slashed.

# Phases: Execution of the Disputed Step

To say that a disputed WASM instruction is run on-chain is actually a simplification.

To assure that the disputed step fits in the Ethereum gas limit, and to reduce the number of required merkle proofs, we break each WASM opcode into multiple phases.

To visualize this in a simple way, think of the i32.add opcode. Under the hood, this involves the following phases amongst others:

* Pop the first stack element into a register.
* Pop the second stack element into a register.
* Add the two numbers.
* Push the result onto the stack.

Once the verification game is narrowed down a single instruction, the Solver uses the offchain interpreter to commit to a state root after each phase in that instruction. The challenger, then, picks a single phase for challenge. The Solver provides the required proof for that phase. Finally, the disputed phase is run onchain.

The off-chain interpreter can generate [proofs](https://github.com/TrueBitFoundation/wiki/blob/master/docs/WASM/WASMSolidityOverview.md) with the following components:

1. `states`: First state hash in the list is the last agreed state, last state in the list is first disagreed state. Others are state hashes for the intermediate states.
2. `fetch`: proof of correctness for the phase that fetches the instruction.
3. `init`: phase for initializing registers
4. `reg1`, `reg2` and `reg3`: phases for reading into registers.
5. `alu`: arithmetic operation, result will be in register reg1.
6. `write1`: first write from some register to memory or stack.
7. `write2`: second write from some register to memory or stack.
8. `pc`: updating program counter.
9. `stack_ptr`, `call_ptr`: updating pointers.
10. `memsize`: updating the memory size. After this phase, we should be in the final state of the transition (the first state where the players disagree).

WASM opcodes rely on the same underlying phases (reading from the stack, writing to the stack, etc). 

The onchain VM needs to 1) implement each of these phases, and 2) have a mapping of opcode to phases. Thus, depending on the instruction pointed to by the pc, and the phase index challenged by the Challenger, it has all information needed to execute on chain.

# Initialization of VM State

To create a task, a Task Giver provides the Truebit contract with code (a WASM module) and inputs.

The provided WASM module is simply a binary file. Using the module as a blueprint, the offchain VM needs to first be instantiated, before execution can happen.

This involves:

* Initializing memory, based on the “segments” section.
* Initializing global variables.
* Initializing call tables, based on the “elements” section.

This process is non-deterministic (for instance, functions can be referenced at different indexes in the call table). This has no outwardly-visible effect on the execution of the WASM module. In Truebit, however, we require consensus on intermediate states.

Let’s think through the binary search used during the verification game. Consider the case when during consecutive queries, the Challenger realizes that they disagree with the Solver’s state at the ½ mark, then the ¼ mark, then the ⅛ mark, and onwards; the dispute is narrowed down until the very first step. The Challenger agrees with the Solver on task inputs (which is always the case), but they disagree on the transition to the next state; they disagree with how the VM was instantiated.

There are two ways to solve this problem:

1- Require the Task Giver provides a Merkle Root for the instantiated VM alongside the program and inputs. This effectively fixes the instantiated VM as a known initial state, solving the problem above.

By asking the Task Giver to provide the instantiated VM root, we are requiring them to install the Truebit client, instantiate the VM (differently for each input), and provide these values. This is a terrible user experience, effectively precluding this option. Truebit should be simple to use; a Task Giver should simply provide a program and inputs, and at some time later, receive their results. 

2- Define a deterministic pre-processing step for going from the program and inputs to an instantiated VM. Both Solver and Verifier need to follow this exact process; in case of disagreement, the onchain VM adjudicates. This is explored more deeply in the section on pre-processing within “Execution of a Truebit Task”.

# The Filesystem

Simple Truebit tasks have the program and inputs passed in directly. For instance, [scrypt-interactive](http://github.com/truebitfoundation/scrypt-interactive) (Truebit’s implementation for Scrypt as used for the Doge-Ethereum bridge) receives plaintext fields as an input and returns their Scrypt hash.

More complex tasks can read data from a decentralized filesystem. For instance, [Livepeer](https://github.com/livepeer/verification-truebit) ffprobe tasks reference video segments stored on IPFS. This is explored further below.

## Data Availability

Data availability is an open problem.

Note that a Task Giver can create a task without actually making the program and inputs publicly available, and waste Solver resources looking for the non-existent data. 

More problematically, imagine that the Task Giver and Solver are colluding: the Solver submits a solution, and when Verifiers go to check, they do not find the program or inputs available on the filesystem, and therefore cannot challenge.

We are looking to multiple avenues as a solution here:

* Storing data on the blockchain: this is the simplest, yet most expensive, avenue. It involves storing data inside of a Truebit “filesystem” contract’s storage, inside of Ethereum logs (8 gas per byte), or as a new contract’s code. We foresee this being utilized for storage in the immediate future.

* Jason Teutsch [“On decentralized oracles for data availability”](http://people.cs.uchicago.edu/~teutsch/papers/decentralized_oracles.pdf) –  exploring the use of Nakamoto consensus.

* Ethereum [sharding](https://github.com/ethereum/wiki/wiki/Sharding-FAQ) research: achieving consensus on blobs of data (uninterpreted transactions), by building a protocol involving randomly assigned validators performing proposal, attestation, notarization, and meta-notarization.

* [Filecoin](https://filecoin.io/filecoin.pdf): the incentive layer layered ontop of IPFS assures public availability of data using cryptographic proofs and cryptoeconomic incentives.

* [Swarm](http://swarm-guide.readthedocs.io/en/latest/introduction.html): Swarm is a distributed storage platform and content distribution service.

* For specific Truebit tasks, the ecosystem around the task could assure availability. For instance, in the case of Livepeer, video segments are to be made available by the transcoder independently of Truebit verification.

## Accessing the Filesystem

The WASM VM is embedded in a host environment.

In the case of Truebit, this host environment provides syscalls which can read data stored in content-addressed filesystems. The address hash cryptographically commits to the data chunks, which is usually stored in a binary Merkle tree. Since the Truebit Task specifies the hash of the program and inputs, the Truebit VM can safely read data from the filesystem by validating merkle proofs.

The syscalls can be made accessible to the WASM VM in the following manner:.

* Syscalls can be provided to the module as imports. These imported functions are, then, replaced by special instructions during the Truebit pre-processing step.

* There could be a Truebit “Filesystem” WASM module, usable by tasks. This would be the only authority able to interact with the host system. The filesystem module could, for example, access data from IPFS.

These functions are verified on-chain in a special way: Whenever a function is called to read from a file, its output has to be checked against a Merkle proof provided by the solver.

It is also possible to allow write-access to files in this virtual filesystem. This causes the root hash to update in the same way as the root hash of, for instance, memory updates.

# The Truebit Task Lifecycle

This section explores the lifecycle of a Truebit task from creation, to execution and verification.

## Creation of a Truebit Task

The Task Giver calls into the Truebit contract providing the following pieces of information:

* The program (WASM module) – this can be passed in directly, or as an address hash on a  content-addressed filesystem (a merkle root committing to the data).
* The inputs – passed in a similar fashion to the above.
* Gas price.
* Gas limit.

Recall that that “gas price” and “gas limit” determine how much the Task Giver is paying for compute resources. This relies on gas metering, which relies on metering instructions injected into the bytecode. Since we cannot trust the Task Giver to correctly inject these instructions, we require them to submit the WASM module without metering. The rest is handled during task execution.

## Execution of a Truebit Task

The Solver or Verifier uses the following procedure to execute a Truebit task:

**Step 1) Download the program and inputs, from the decentralized filesystem.**

**Step 2) Inject metering instructions.**

As described in the section on “metering”, this involves processing the bytecode, and injecting metering instructions for every block of code.

**Step 3) Perform pre-processing & instantiate the VM.**

As described in the section on “Initialization of VM State”, the module (which is simply a binary file) is used as a blueprint to instantiate the VM. Specifically, the linear memory, the global variables, and the call tables are initialized.

Since the Truebit proof of concept implementation has a single stack for evaluation, this step needs to also perform the following:

**Calculate jumps**: jumps need to be calculated to enable control-flow operations. This involves reading through the WASM module, and whenever there is a branching point, inlining which instruction it should jump to.

**Stack adjustment**: since the Truebit VM has only one stack, it also includes local variables. All functions share the same stack, so call frames need to be managed in this step. When a function returns, local variables and function parameters should be popped off and return values should replace them. 

A direction of future work is to perhaps follow the WASM spec more closely here; splitting code segments into functions, and the stack into frames. This will, however, complicate the creation of state snapshots and merkle proofs.

**Step 4) Execute instructions**

Execute the instructions beginning to end.

**Step 5) Submit the solution or challenge to the Truebit contract.**

### Dispute Resolution

If the Solver and Challenger disagree on how instructions were executed (i.e. step 4), a standard Truebit verification game takes place to resolve the dispute.

The question now is: what if the Solver and Challenger disagree on how the task was metered, pre-processed, or the VM instantiated (i.e. in steps 2 and 3)?

We can think of each step as a separate program with inputs and outputs:

* Step 2, metering, is a program which receives WASM bytecode, and returns the WASM bytecode with metering instructions injected in.
* Step 3, pre-processing and VM instantiation, is a program which receives the WASM module and inputs, and returns the initialized VM state root.

Both programs are fully deterministic, so the system should be able to resolve disputes.

The breakthrough insight, then, is to implement both these steps as WebAssembly modules (could write them in Rust, and compile to WASM). If the Solver and Challenger disagree, a separate verification game is played for the specific step.

### Speed of Execution

The process of taking state snapshots is slow and resource-intensive – it involves placing the entire VM state in a Merkle tree and taking the root.

But note that state snapshots are only needed in case of dispute.

As such, Truebit supplies two modes of execution:

**1) Execution with JIT, without state snapshots**:

Solvers and Verifiers run the task in this manner on their first run. At this point, only the final solution matters, and state snapshots are not needed. So the program is run beginning to end. JIT (just-in-time compilation) optimizations speed up execution.

[Cretonne](https://cretonne.readthedocs.io/en/latest/), the Mozilla WASM JIT, is a promising resource to investigate here.

**2) Execution with interpreter, with state snapshots**:

Solvers and Challengers run the task in this manner during verification games. The interpreter executes instructions one at a time, and has the ability to create state snapshots. This process is much slower than running with JIT.

Note that given Truebit’s incentives, rational Solvers are expected to always provide correct solutions. Therefore, all code will be executed with JIT (the first mode of execution above), which is fast.

# Truebit Toolchain & Code

Truebit codebases involving the virtual machine are:

#### [github.com/truebitfoundation/ocaml-offchain](https://github.com/truebitfoundation/ocaml-offchain):

A fork of the reference WASM interpreter, written in OCaml, that is currently used as the Truebit  offchain interpreter. It implements state snapshots.

#### [github.com/truebitfoundation/webasm-solidity](https://github.com/truebitfoundation/webasm-solidity):

The onchain interpreter, written in Solidity. It has the ability to initialize state based on merkle proofs and run phases of computation.

It currently also includes code for the dispute-resolution layer (the challenge/response protocol and binary search), however, this will soon be pulled out into a separate repo.

#### [github.com/mrsmkl/verification-truebit](https://github.com/mrsmkl/verification-truebit):
Proof of Concept implementation for running a Livepeer task on Truebit (our first WASM integration), using the above ocaml-offchain and webasm-solidity repos under the hood.

#### [github.com/truebitfoundation/emscripten-module-wrapper](https://github.com/truebitfoundation/emscripten-module-wrapper):
Use Emscripten to compile C or C++ into a WASM module. Then, take the generated Javascript host environment integration (Emscripten’s default), and pack them into the module so it’s a self-sufficient unit.

# Misc

This section includes miscellaneous items related to the VM.

## New WebAssembly Features to Watch Out For

WASM is an evolving spec. 

The Truebit team recently presented at the latest Community Group meeting (notes [here](https://github.com/WebAssembly/meetings/blob/master/2018/CG-04.md) under “WebAssembly in Blockchains”) where new proposals and updates to the spec are debated.

We should keep an eye on the following features as they could impact us:

Potentially helpful features: Reference Types, Annotations.

Potentially harmful features (since they cause nondeterminism): Threads (with shared memory); GC; SIMD.

## Blockchain API for WASM

The Javascript API defines a standard interface by which the WASM VM integrates with browsers.

WASM is now finding a home in multiple blockchain projects: Truebit, Ethereum, Dfinity, Polkadot, EOS, …

These projects implement similar APIs around how the VM accesses blockchain state: account stores, account codes, block hash, block number, block header fields, …

Coordinating around a standardized Blockchain API achieving these goals would be beneficial for interoperability and tooling across the space.

