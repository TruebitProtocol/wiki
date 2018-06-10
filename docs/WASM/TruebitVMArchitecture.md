# TruebitVM Architecture

Overview of the Truebit Web Assembly Virtual Machine Architecture

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
contract Offchain {
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

## Imposed Limitations
* External Calls: external calls are a source of non-deterministic execution. Truebit needs the task to be deterministic so that the solver and verifier can both run the exact same internal states for the same task. For an example of how external calls yield different internal states, think of the pid of the child process returned by the `fork` system call or a random generator function. It could be argued that the non-determinism introduced by the external calls can be "local" and does not affect the final state(or the part of it that counts). The rise of formal specification  might have something to say about this issue but for the proof of concept implementation of Truebit, will not try to tackle this issue.<br/>
* Floating-Point: WASM's specification allows some nondeterminism for floating-point arithmetic. The solver originally runs the task using any WASM build toolchain. Needless to say we cannot gurantee the toolchains used will behave the same when it comes to the non-determinism in floating-point arithmetic.<br/>
