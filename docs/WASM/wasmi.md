# What modifications would we need to have to use WASMI interpreter from Parity

## Data structures

Structure:
 * Code: functions (with signatures?)
 * Memory: will probably be 64 bit values, just linear memory
 * Globals: probably best to remove
 * Call table
 * Function calls have stacks

The code is divided into function bodies. This already will detach us from WASM bytecode format.
The FuncBody labels are calculated in the validation step.
Each code position is associated with label ⇒ perhaps need to have a preprocessing step for this.

Structure of the stack:
 * Call frames include value stack and control stack
 * So there is on stack per function
 * Call frames also have the PC

Each function context has its own block stack and PC.
If types are needed for initial values, also need a preprocessing step for them.

Control stack frames are complex.
Stack frames: perhaps the types are unnecessary at runtime.
Labels have to be looked up here.

Memory and stack handling are abstracted, so it is possible to use this to generate the proofs quite easily.

## Initialization

Alloc module:  initializes signatures, this will have to be done using a special function.

Initializing call tables.

Exports and imports: hopefully can be ignored / made builtin

Probably need to have different kind of signature for more efficient runtime checking.

Locals: there has to be some kind of upper limit, all are initialized to 0.
Floating point values are not needed so everything should be binary zero.

Initializing func body labels.

## Instructions

When calling a function, the arguments are copied into another stack. This will require several steps.
 * Perhaps copying can be avoided, just access these variables from previous stack.

Branching: many frames can be discarded, perhaps these would have to be separate instructions.
 * Seems like they do nothing much, so can probably just be implemented by updating the stack pointer

br_table: large instruction.
 * Perhaps there could be initialized a special table for handling these.

## Things to keep in mind

There is some redundant data that wasmi keeps track of:
* reference counters
* weak pointers
* pointers back to stack

These can be ignored when converting to merkle trees. But we need to check out how they are used in the interpreter steps.

Copy memory: hopefully not used in op codes.

Probably have to forbid WASM grow, convert them to nops.


