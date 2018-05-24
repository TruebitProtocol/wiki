# What modifications would we need to have to use WASMI interpreter from Parity

## Data structures

First we need to be able to take state snapshots.
The structure of data in the interpreter is roughly the following:
 * Code: split into functions (with signatures?)
 * There are also labels associated with instructions, these are the calculated destinations for jumps
 * Memory: will probably be 64 bit values, just linear memory
 * Globals: probably best to remove, not really needed
 * Call table
 * Function calls have stacks

The code is divided into function bodies. This already will detach us from WASM bytecode format, so there will have to be some kind of preprocessing step.

Structure of the stack:
 * Call frames include single value stack and control stack for blocks
 * Call frames also have the PC

Each function context has its own block stack (control stack) and PC.
If types are needed for initial values, also need a preprocessing step for them.

Control stack frames are complex: it has three labels, for start, end and branch position. Then there is also a frame type and block return value type.
Perhaps some of these are only used for validation. Similarly, perhaps in the value stack, the types are unnecessary at runtime.

Memory and stack handling are abstracted, so it is possible to use this to generate the proofs quite easily.

## Initialization

One problem is that instantiating the module has several steps, like setting of different tables and memory data segments. In the preprocessing stage we can convert most of these to
normal operations.

Globals: convert them to linear memory access.

When allocating a module, WASMI initializes signatures, this will have to be done using a special function instead.
Probably need to have different kind of signature for more efficient runtime checking.

Initializing call tables.

Exports and imports: hopefully can be ignored / made builtin

Locals: there has to be some kind of upper limit, all are initialized to 0.
Floating point values are not needed so everything should be binary zero.
But the types of the local variables would still have to be implemented.

Initializing function body labels:
* The FuncBody labels are calculated in the validation step.
* Each code position is associated with label ⇒ need to have a preprocessing step for this.

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
These can be ignored when converting to merkle trees.

Copy memory method: hopefully not used in op codes.

Probably have to forbid WASM grow, convert them to nops.


