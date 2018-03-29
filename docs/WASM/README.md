# WASM
This page is meant to be a portal to all things WASM related to Truebit

## General WASM Information

Here is a list of resources to start learning WASM:

[WASM Reference Manual](https://github.com/sunfishcode/wasm-reference-manual)

[UCB CS294-113: Virtual Machines and Managed Runtimes](http://www.wolczko.com/CS294/)

[WebAssembly Training Courses](https://www.nobleprog.com/webassembly-training)

## EWASM

[EWASM Spec](https://github.com/ewasm/design)

## Truebit WASM

The WASM Computation layer that is meant to be used for Generalized Verification Games involves multiple repositories to be put together:

[WASM Solidity Interpreter](https://github.com/TrueBitFoundation/webasm-solidity)

[Offchain WASM Interpreter in OCaml](https://github.com/TrueBitFoundation/ocaml-offchain)

[Emscripten Module Wrapper](https://github.com/TrueBitFoundation/emscripten-module-wrapper)

## Emscripten Installation Instructions

Run these commands to get a proper version of emscripten running

```
git clone https://github.com/juj/emsdk.git

cd emsdk

LLVM_CMAKE_ARGS="-DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD=WebAssembly" ./emsdk install sdk-tag-1.37.28-64bit

./emsdk activate sdk-tag-1.37.28-64bit

source ./emsdk_env.sh
```

# Usage

# Running C Programs

It is now possible to use emscripten to produce `.wasm` files that can be ran with our interpreter.

First you have to install emscripten. Using emscripten SDK didn't work for me, so I built from sources:
http://kripken.github.io/emscripten-site/docs/building_from_source/index.html

Basically you have to build `fastcomp` (http://kripken.github.io/emscripten-site/docs/building_from_source/building_fastcomp_manually_from_source.html), and then modify the configuration file `.emscripten`. Also install binaryen (https://github.com/WebAssembly/binaryen) and get the main emscripten repo (https://github.com/kripken/emscripten/) and put it in your PATH.

Configuration file `.emscripten` should look something like this:
```
EMSCRIPTEN_ROOT = os.path.expanduser(os.getenv('EMSCRIPTEN') or '/home/sami/emscripten') # directory
LLVM_ROOT = os.path.expanduser(os.getenv('LLVM') or '/home/sami/emscripten-fastcomp/build/bin') # directory
BINARYEN_ROOT = os.path.expanduser(os.getenv('BINARYEN') or '/home/sami/binaryen') # directory
```

Assume that `emcc` is in your `PATH` and your C program is at `main.c`. Then you can type
```
emcc -s -s WASM=1 main.c
```

If it complains about not finding `wasm.js-pre.js`, create it using
```
cp ~/src/js/binaryen.js-pre.js ~/binaryen/src/js/wasm.js-pre.js
cp ~/src/js/binaryen.js-post.js ~/binaryen/src/js/wasm.js-post.js
```
(These seem to be wrong, but they are only needed for running it in the browser)

Compiling the C file with emscripten will create two files, `a.out.wast` and `a.out.wasm`. `a.out.wast` won't work because binaryen and reference interpreter disagree about WAST syntax. See also https://github.com/kripken/emscripten/wiki/WebAssembly

The WASM file can be ran with our interpreter by using:
```
wasm -m -wasm a.out.wasm
```
It should run the main function from the C file. Use trace option `-t` to see what happened.
```
wasm -t -m -wasm a.out.wasm
```

# Initializing and Preprocessing WebAssembly

## Initialization

WebAssembly has the following steps before starting the execution of program:
* Initialize memory
* Initialize global variables
* Initialize call tables: an index can be used to call any function from the call table.
Instead of function types we have a function type hash. This way we can be sure that indirect calls can be checked easily.

It is useful to start from empty memory etc, and have initialization code instead, so the code would include almost all of the information needed for running a task. Only other information that is needed is the input from the file system. Then, the task specification is just (the hash of) the code and the input. An empty VM state can be easily constructed from this data (using hashes of empty stack etc.).

## Pre-processing

There are two reasons why the WebAssembly code is pre-processed before it is interpreted:
* Calculating jumps: for example if we have an `if` operation in the bytecode, to execute it efficiently, we need a way to jump to the else branch and the end of `if`-statement.
* Stack adjustment: We only have one stack for evaluation, it also includes local variables. For example if a function returns, it will need to pop the local variables and function parameters from the stack, and move the returned values to replace them. Perhaps stack could be implemented as a linked list, but then there might be problems with allocation and merkle proofs.
* There is another stack for calling functions. Returning from a function is a special operation.

## Decoding

Another step that is not implemented in the on-chain interpreter is decoding instructions. This means that each action of each phase in the execution of an instruction is given separately. This step could be implemented in the on-chain interpreter to save storage space. One complication would be that instructions would have different sizes because some need immediate values.

## Verified generation of the initial state

Currently the specification of the task is the hash of the initial state. Because of this, when a task is posted as wasm file, it has to be associated with an initial state hash. Then the solvers and verifiers can check if the wasm file and the initial state match.

There is a problem if the wasm file and the initial state do not match. The whole initial state could be posted instead, but it might be several times larger than the wasm file (if decoding the instructions is not implemented in solidity).

Solution alternatives:
* Implement preprocessing in solidity
* Implement preprocessor as wasm module

The second alternative is easier, for example the ocaml runtime can be compiled into wasm: https://github.com/sebmarkbage/ocamlrun-wasm

## Description of special instructions

There are following special instructions:
* `EXIT`: Normal exit.
* `JUMP`: Static jump to a position in code.
* `JUMPI`: Conditional jump to a position in code. Jumps if the top element in stack is not `0`.
* `JUMPFORWARD n`: Use a jump table with size `n`.
* `LABEL`: Used to resolve the jumps.
* `RETURN`: Returns from function, this means that it takes a value from the call stack and jumps to that location.
* `DROP`: Can drop many values from stack.
* `DUP n`: Duplicates the `n`th element from stack to the top. Used for getting local variables.
* `SWAP n`: Replaces the `n`th element in the stack with the top element. Used for setting local variables.
* `CHECKCALLI`: Check that the type of the function that will be called indirectly is correct.
* `INPUTSIZE n`: Get the size of `n`th file.
* `INPUTNAME n i`: Get the `i`th byte of the name of the `n`th file.
* `INPUTDATA n i`: Get the `i`th byte of the `n`th file.
* `OUTPUTSIZE n sz`: Set the size of `n`th file. Also sets the bytes all to zero.
* `OUTPUTNAME n i v`: Set the `i`th byte of the name of the `n`th file.
* `OUTPUTDATA n i v`: Set the `i`th byte of the `n`th file.