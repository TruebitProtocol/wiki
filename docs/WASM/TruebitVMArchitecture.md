# TruebitVM Architecture

## Features

 * Parallel computation
 * Floating point support
 * IPFS support

 An experimental JIT is also in progress

Perhaps we should follow WASM structure more carefully:
 * Split code segment into functions
 * Split stack into frames

Implementation options
 * Could be implemented in Rust, based on parity-wasm
 * Another idea that I want to test is translating the WASM file so that it will have explicit stack, perhaps JIT compilation will make this faster than interpreter.

 # Requirements

 ## General performance

There are two modes for the interpreter:
1. Generate outputs from inputs
2. Generate intermediate states or Merkle roots

For the first case, it should be straightforward to use JIT. But if the performance difference between JIT and interpreter is too high, the feasibility of the system becomes endangered. For example JIT might perform a task in a minute, but the interpreter might take an hour. Idea: perhaps the system could pay to the task giver if there is a delay?

## Gas metering

Metering by instruction makes JIT much slower. This can be optimized though, the current approach at https://github.com/ewasm/wasm-metering seems to be OK.

## Easy merkleization

There are three concerns here:
1. It must be easy enough to convert the state into a merkle tree (note that the tree cannot have arbitrary depth)
2. Generating proofs for atomic transitions
3. Handling initialization of the code (jump tables, memory, etc.)

The best solution would be to have all this implemented using instrumentation, see https://github.com/TrueBitFoundation/webasm-solidity/wiki/Merkleization-with-JIT ... not sure yet if this is possible.

# Memory Abstraction

The basic difference between off-chain and on-chain interpreters is that off-chain interpreter has easy access to the machine state, and the on-chain interpreter will only have access to the parts of the memory that was sent to blockchain. We say that the interpreter is stuck if there is not enough data to run it forward.

Here is a simplified memory model for off-chain interpreter:
```
contract Onchain {
  uint pc;
  uint reg1;
  uint opcode;
  uint[] code;
  uint[] memory;
  function getPc() returns (uint) {
     return pc;
  }
  function setPc(uint newval) {
     pc = newval;
  }
  function getMemory(uint pos) returns (uint) {
     return memory[pos];
  }
  function setMemory(uint pos, uint newval) {
     memory[pos] = newval;
  }
}
```

The memory model for on-chain interpreter is as follows:
```
contract Onchain {
  bytes32 state; // Initially only the state is known
  uint pc; // Solver can post these other variables to make the interpreter be able to run forward
  uint reg1;
  uint opcode;
  bytes32 code_root;
  bytes32 memory_root;
  bytes32[] merkle_proof;
  function getPc() returns (uint) {
     // If the hash is not correct, we do not yet know what the pc is in the state
     require(sha3(pc, reg1, opcode, code_root, memory_root) == state);
     return pc;
  }
  function setPc(uint newval) {
     require(sha3(pc, reg1, opcode, code_root, memory_root) == state);
     pc = newval;
     // State has changed, generate new hash
     state = sha3(pc, reg1, opcode, code_root, memory_root);
  }
  // getRoot, getLeaf and setLeaf are defined in instruction.sol
  function getMemory(uint pos) returns (uint) {
     require(sha3(pc, reg1, opcode, code_root, memory_root) == state);
     // If the merkle proof is not correct, we do not know what is the memory value in position pos
     require(getRoot(merkle_proof, pos) == memory_root);
     return uint(getLeaf(merkle_proof, pos));
  }
  function setMemory(uint pos, uint newval) {
     require(sha3(pc, reg1, opcode, code_root, memory_root) == state);
     require(getRoot(merkle_proof, pos) == memory_root);
     setLeaf(merkle_proof, pos, bytes32(newval));
     // First generate new memory root, then new state
     memory_root = getLeaf(merkle_proof, pos);
     state = sha3(pc, reg1, opcode, code_root, memory_root);
  }
}
```

The rest of the interpreter is the same for on-chain and off-chain interpreters. We just have to make sure that each step or phase is small enough so that it won't be stuck. Another possibility would be to extend the on-chain memory model so that more data can be posted.

Reference: https://github.com/chriseth/scrypt-interactive/

# Parallel Computation

To be able to run larger computations, we will have to have some way to handle parallelism.
Here is one way to implement parallel computations.

First, add an instruction that runs several tasks in parallel. There has to be a block of memory that will be modified by this instruction. For each parallel task, this memory block includes a task specification, that is, task code and input files. The intended semantics of the instruction is just to (synchronously) run the tasks and collect their output
into this special block.
This instruction is similar to WebAssembly module calling other modules in JavaScript.

Verifying this instruction would have two phases:
1. Find the parallel task where the error has happened. The prover and challenger start from the root hash of the special
block, and if they disagree, the prover will post the hashes of the subtrees. The challenger will then pick one of these,
and so on, until a task where there is a disagreement is found.
2. For the task that solver and verifier disagree on, we can now run another normal verification game.
There has to be some restriction on the level of recursion for these parallel instructions.

There is one possible advantage for implementing this even without using parallelism: If the off-chain interpreter
is too slow for running a task, the task can be split into a several pieces, each of them ran with JIT, and only one of
the pieces would have to be handled with the off-chain interpreter.

# JIT

## Simple benchmark

This is just calculating factorial of 12345678.

Results
* Reference interpreter: 25 s
* ocaml-offchain: 5.3 s
* wasmi: 4.8 s
* binaryen: 3.3 s
* wabt: 2.2 s
* native C: 0.03 s factorial 1234567890 2.6 s
* node.js JIT: 0.09 s factorial 1234567890 2.6 s

It seems that at least for some kind of computation, JIT will have a much better efficiency. The most general way to implement merkleization is by using instrumentation, but we need access to data such as contents of stack, which is not accessible easily. For this reason we would have to instrument the code so that it builds an explicit stack in parallel to the internal stack. But doing this in a naive way might erase the performance gains.

## Critical path

Let's have a coarse measure of number of steps: Each function call is a step, and each loop iteration is a step.
Perhaps also exiting from a function could be this kind of step.
Prover and verifier have to find the first step for which they disagree.
The _critical path_ for a step in execution include the function calls in the stack needed for the step, and for each loop that is in the stack, the loop iteration.

For example:
```
function asd() {
   return 123;
}
function bsd() {
   return 123+asd();
}
function main() {
   for (int i = 0; i < 10; i++) bsd();
}
```

We have steps
1. main
2. main, for.0
3. main, for.0, bsd
4. main, for.0, bsd, asd
5. main, for.0, bsd
6. main, for.0
7. main, for.1
8. main, for.1, bsd
9. main, for.1, bsd, asd
10. main, for.1, bsd
11. main, for.1
12. ...

The critical path for step 9 is
 * function call `main` at step 1
 * for loop 2nd iteration at step 7
 * function call `bsd` at step 8
 * function call `asd` at step 9. We call this last part of the critical path the _critical block_.

The idea is that to construct the stack, we only need to handle the critical path, and the critical path should be a small part of the execution (at least in normal programs). 

## Constructing the stack

For each function or loop body in the critical path, we have two versions: one is normal, and other is for the critical path, and this one will construct the stack needed for merkleization. There are probably some ways to optimize this if needed, because it is possible to determine which statements can generate an element on stack.

Memory and globals should not be problems for generation.

## Instructions, subinstructions and phases

The critical block will have for each instruction a possibility to generate the intermediate state.
Some of the instructions are more complex and need to have several subinstructions, like
* Function call (local initialization)
* br_table
* Check dynamic call

Finally the instructions can be divided into phases, these are designed so that each phase will only need one merkle proof.

Notes:
* Easy to have a pointer to original WASM instruction

## Initial state

Following data has to be calculated
* Initial memory
* Jump tables, including function addresses
* Initial globals
* Call tables

Global variables are mostly used for interacting with JS, so they can be changed to memory accesses or inlined.
Instead of special memory initialization, there could be code to initialize it, then we can start from empty memory.
Calculating jump tables and the call table will need separate programs to calculate them.

## Initial performance analysis

Box2D benchmark
* Plain WASM: 5.5s
* Constructing critical path: 16s
* Building stack: 28s

I think 10x slowdown would be acceptable, but in these results, there is much room for optimization.

# Floating Point

Here are some ways to handle floating point.

## Define deterministic floating point handling with judges

This means that the floating point ops are implemented in the same way as other operations. Nondeterminism in the standard 
is resolved by selecting one legal value for `NaN`.

Pros:
* All WASM files will work without modifications.

Cons:
* Need to implement floating point operations on-chain.
* Might be unsafe to use JIT.

## Correct all NaNs to a single value

This means that the WASM file will first be converted to another WASM file, where after each operation that might return
NaN, we check the result and if it is NaN, we change it to a standard value. Perhaps it is more efficiently to canonize 
NaN values when a floating point value is stored or reinterpreted as integer. (There is also a copysign operation).

Pros:
* Can run with JIT.

Cons:
* Need to implement floating point operations on-chain.
* Might be harder to check if posted WASM files are valid.

Perhaps this can be combined with the first solution so that before solvers run the code with a JIT, they convert the
WASM file to remove nondeterminism.

## Replace floating point operations with integer implementations

In the WASM file, each floating point operation is replaced with a call to software implementation of that operation.
Link to a software implementation of floating point operations: https://github.com/tianocore/edk2/tree/master/StdLib/LibC/Softfloat


Pros:
* Can run with JIT.
* No floating point needed on-chain.

Cons:
* Integer operations are slower than hardware implementation.
* Have to check that posted WASM files do not use floating point.
