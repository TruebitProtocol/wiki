# Dispute Resolution Overview

The point of the Dispute Resolution Layer is to provide general purpose tools around building verification games. Verification games are at the very heart of the Truebit protocol. Anytime there is a dispute there between the parties involved in the Truebit system, a verification game is be played to determine fraud. These games can be verifying different things like WASM programs, Scrypt hashes, Merkle Proofs, etc. Howeverm, in most cases the behavior is very similar across different types of games. There are really three main pieces:

1. Initializing a new game

A verification game is created and the data is stored in a Game struct. The input data includes the solver, verifier, the merkle root of the program instructions, the hash of the output, the number of steps, the response time, and the computation layer interface.

2. Query/Response session

Verifier queries steps of the computation from the Solver. The choice of the steps is most optimally done as a binary search. Query/Response continues until it has been narrowed down to two consecutive states. 

3. Perform Final Verification

The Solver agrees on the lower step, and has already committed to what the output of the next step is supposed to look like. At this point a Solver can submit the state for the lower and higher steps, as well as a merkle proof that the instruction for the state transition is a valid instruction in the original program. If everything checks out the Solver wins and the Verify loses. 

If a Solver is backed into a corner, where they've been narrowed down to two states and they know they will lose it is expected that the Solver will not trigger `callJudge` and the Verifier will wait till they can call `timeout` thus prosecuting the Solver.

## Implementation

If you want to see our dipsute resolution contract, go [here](https://github.com/TrueBitFoundation/truebit-os/blob/master/contracts/dispute/Interactive.sol)

Users and developers will never to need to worry about the details about this contract because the truebit-os client abstracts these details away.