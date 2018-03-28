# webasm-solidity Overview

# Running the task

Before the task is run, its specification must be posted to blockchain. We assume that the specification is the hash of the initial state of the VM (`start_state`). The VM has two kinds of fields, merkle roots for state and registers. The state contains the following fields:
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

These are binary merkle roots for 64-bit values, calculated using keccak256. Zero is the default value, except for `calltable_types` it is `-1`. `input_name` and `input_data` are two level merkle trees. There are always 1024 files.

There are the following registers:
* `pc`: Program counter.
* `stack_ptr`: Pointer to the top of the stack. The stack includes local variables.
* `call_ptr`: Pointer to the top of the call stack. Stores the return location.
* `memsize`: Size of the memory.
These are considered as 256-bit values when calculating the hash.

In the initial state, all values except code and input roots are empty.

In the offline interpreter there are of course just arrays instead of merkle roots.

https://github.com/mrsmkl/spec/blob/master/interpreter/merkle/mrun.ml#L8

The prover will then run the task with off-line interpreter and post the hash of the end state and the number of steps
the computation took. (There will have to be a flag in the VM to tell that the execution has ended or something).
One step is performing one instruction.

## Specification of the code

There are few reasons why it is not convenient to simply use WASM binary code for the representation of the code:
1. Initialization: the code execution should start from a simple state, but WASM includes complex initialization.
2. For each jump, we need to know the next PC and the change in stack.
3. Handling more complex instructions like `br_table`.

For these reasons the code is preprocessed into another format, description here https://github.com/TrueBitFoundation/ocaml-offchain/wiki/Initializing-and-preprocessing-WebAssembly

# Challenging the output of the task

If a verifier disagrees with the output, it can post a challenge using contract https://github.com/mrsmkl/spec/blob/master/solidity/interactive2.sol

The contract has the following inputs and global variables:
* `start_state`: specification of the task.
* `end_state`: the posted result of the computation task.
* `steps`: steps taken in the computation.
* `prover`: address of the prover who claims that the end result of computing from `start_state` is `end_state`.
* `challenger`: address of the challenger that disagrees with the `end_state`
* `next`: tells whose turn it is to make the next move. Can only be `prover` or `challenger`.
* `clock` and `timeout`: if the player whose turn is next hasn't performed the step after `timeout` blocks, that player will lose.
* `idx1`: Last known state where both players agree.
* `idx2`: First known state where bot players disagree.
* `proof[i]`: Perhaps should be called states, these are the hashes of the VM after `i` steps. If there is no hash, it means that it has not been posted to the blockchain yet. `O(log steps)` hashes will be posted to blockchain.

If it is the prover's turn, it will use the `report` method to post a hash of a state between `idx1` and `idx2`. For example if binary search is used, this will be hash of state `idx1 + (idx2-idx1)/2` (check formula).

If it is the challengers turn, for example in binary search it will tell if it agrees or disagrees with the state that the prover posted previously.

Eventually if the players do not give up, they will find the first state where they disagree (it will be in `proof[idx2]`). Then `proof[idx1]` will have the last state where they agree (`idx2 == idx1+1`). Now the prover will have to show that when one instruction is ran in the state with hash `proof[idx1]` then the resulting state is `proof[idx2]`. To make the checking more easy, each step is divided into several "phases", so the prover will next post all the intermediate states between `proof[idx1]` and `proof[idx2]`.

# Checking single instruction

https://github.com/mrsmkl/spec/blob/master/solidity/instruction.sol

## Phases

When the point of disagreement is found, the prover can use the off-line interpreter to generate a proof of correctness of the transition step. The off-line interpreter will generate a proof with the following components:
* `states`: First state hash in the list is the last agreed state, last state in the list is first disagreed state. Others are state hashes for the intermediate states.
* `fetch`: proof of correctness for the phase that fetches the instruction.
* `init`: phase for initializing registers
* `reg1`, `reg2` and `reg3`: phases for reading into registers.
* `alu`: arithmetic operation, result will be in register `reg1`.
* `write1`: first write from some register to memory or stack.
* `write2`: second write from some register to memory or stack.
* `pc`: updating program counter.
* `stack_ptr`, `call_ptr`: updating pointers.
* `memsize`: updating the memory size. After this phase, we should be in the final state of the transition (the first state where the players disagree).

So that all phases won't have to be checked, the challenger select the phase where it sees the error happening. The prover can then post one of the proofs that will be checked by the on-line interpreter. (Actually the challenger could just provide a proof that some of the phases generates a different state compared to what prover claimed.)

## Example of on-line interpreter operation

For example if the disagreement is in the `fetch` phase, the prover will first use `setVM` method to send the VM state in the first agreed state (`phase[0]`). Now the challenger claims that `phase[1]` is wrong. The array `proof` is the Merkle proof that tells which opcode is in location `vm.pc`. This proof is checked in line `require(vm.code == getRoot(proof, vm.pc))`. The opcode is retrieved from the proof using `getLeaf` method. Now a new state can be generated, and we can compare if it was the same as claimed
```
    function proveFetch(bytes32[] proof) returns (bool) {
        require(init == 0 && msg.sender == prover);
        bytes32 state1 = phases[0];
        bytes32 state2 = phases[1];
        bytes32 op = getLeaf(proof, vm.pc);
        require(state1 == hashVM());
        require(state2 == sha3(state1, op));
        require(vm.code == getRoot(proof, vm.pc));
        winner = prover;
        return true;
    }
```

Perhaps the idea is easier to understand if the method is written in the following way (without checking):
```
    function performFetch(bytes32 state1, bytes32[] proof, VM vm) returns (bytes32) {
        require(state1 == hashVM(vm));
        require(vm.code == getRoot(proof, vm.pc));
        bytes32 op = getLeaf(proof, vm.pc);
        return sha3(state1, op);
    }
```

This method gets as an argument the state before fetching `state1`, the current state of the VM `vm` and the Merkle proof for the opcode. It returns the hash of the state after fetching. In this case the result state is just the previous state of the VM and the fetched opcode. What the lines do:
1. Check that the hash of the VM state is correct.
2. Check that the Merkle proof is correct i.e. it can be used to generate the Merkle root.
3. Retrieve the opcode from the proof.
4. Create the new state, it is just the previous VM state because nothing was changed, and the retrieved operation. Then return the hash of this state.

To have less phases, it would be easy to initialize the registers at the same time, the immediate value would just have to be read from the opcode.

## Merkle proofs

The phases have been designed so that in each phase there is at most one Merkle proof that is needed.
