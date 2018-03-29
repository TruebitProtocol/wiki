# JIT

Thoughts and initial research on using a JIT.

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
