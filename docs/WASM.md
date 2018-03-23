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