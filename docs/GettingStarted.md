# Getting Started

Truebit has been and always will be an open source project. We welcome collaboration and want to build a strong community with developers all around the world! If you want to get involved, but don't know how, you've come to the right place!

This page is meant for user's getting started with the codebase. If you want a high level overview of the protocol go [here](https://github.com/TrueBitFoundation/wiki/blob/master/docs/Overview.md)

# Using the Code

Truebit is still in early stages of development and does not have a working product yet. If you are interested in running Truebit and playing some verification games, we do have some working prototypes.

You can mess with our Scrypt Verifier system we built for the Doge-Ethereum bridge.
* [scrypt-interactive](https://github.com/TrueBitFoundation/scrypt-interactive)

Or you can use our prototype WASM Interpreter by following this [tutorial](https://github.com/TrueBitFoundation/wiki/blob/master/docs/WASM/Tutorial.md)

# Working on the Code

The best place to get started is by looking at the list of issues on our repos. If there isn't an issue, is it really a problem? If you don't see an issue, but think there should be one, go ahead and make it! One of our team members will take a look at it promptly.

If there is an issue that peaks your interest feel to make a PR! If there is an issue that you don't believe is explained well, then say so! We will read your comments and do our best to update the issue description accordingly. Some of our issues are related to more research related questions and might have a group of people already working on them. Hopefully, there is already a place where those people can communicate. Otherwise, we here at Truebit will do our best to organize an action group to get things moving forward.

Truebit is broken down into 3 modular pieces: Incentive Layer, Dispute Resolution Layer, and Computation Layer.

Each of these pieces falls somewhere along the onchain-offchain spectrum.

## Onchain

This is where the incentive layer lives. As it is purely implemented with smart contracts. The incentive layer is meant to use smart contracts to incentivize verifier's to check solutions in a trustless manner.

Relevant Resources:
[incentive-layer](https://github.com/TrueBitFoundation/incentive-layer)

## Onchain/Offchain

The dispute resolution layer lives somewhere between onchain and offchain. The verification game involves a query/response session where each steps are being run offchain to generate hashes of the queried computation steps. However, the final query step is executed onchain to validate the claims of the solver.

Relevant Resources:
* [dispute-resolution-layer](https://github.com/TrueBitFoundation/dispute-resolution-layer)
* [webasm-solidity](https://github.com/TrueBitFoundation/webasm-solidity)

## Offchain

The computation layer lives offchain. It is typically implemented as a module that can be plugged into the dispute resolution layer. The main goal of Truebit is to create a plugin for general types of computation. This is why we are working on a deterministic WASM interpreter. Which will enable users to write smart contract-like code in languages such as C++ and Rust. We also have simpler offchain plugins that we refer to as Truebit Lite. As opposed to implementing a complete Turing Machine like the WASM interpreter, a Truebit Lite system implements one function.

WASM Interpreter Relevant Resources:
* [ocaml-offchain](https://github.com/TrueBitFoundation/ocaml-offchain)
* [emscripten-module-wrapper](https://github.com/TrueBitFoundation/emscripten-module-wrapper)

Truebit Lite:
* [scrypt-interactive](https://github.com/TrueBitFoundation/scrypt-interactive)
* [simple adder vm](https://github.com/TrueBitFoundation/dispute-resolution-layer/blob/master/contracts/test/SimpleAdderVM.sol)

# I Just Do Protocol, Bro

Not all parts of the Truebit protocol are set in stone. If you have an idea on how to possibly improve the protocol, or believe you have found an attack then we want to know! The best way to get started is to check any of the relevant repositories and see if an issue has been made. If there isn't an issue that you think is relevant, then make one! That way you can get a persisting conversation going with the rest of Truebit community! 

Here are some links for relevant resources related to working on the protocol:

* [Truebit Whitepaper](https://people.cs.uchicago.edu/~teutsch/papers/truebit.pdf)
* [Token Mechanics Ideas](https://medium.com/truebit/a-token-based-roadmap-to-trustless-computation-2264e80e82bd)
* [Truebit Technical Summary](https://medium.com/truebit/truebit-the-marketplace-for-verifiable-computation-f51d1726798f)