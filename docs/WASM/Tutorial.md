Sample program at http://github.com/mrsmkl/coindrop

Truebit tasks have to be written in a language that can be compiled into WebAssembly, for example C.
For input and output, the normal system calls for file system access should work. Later in the tutorial we explain how to add files, and how they can be constructed in the blockchain.

In our example, we assume that the users can enter following kind of transactions into the blockchain:
1. First field is the address of the user
2. Second field is the monetary value, ether
3. Additional data, here they are x and y coordinates.
```c
struct data {
    uint8_t *addr;
    uint8_t *value;
    uint8_t *x;
    uint8_t *y;
};
```

Reading a single 256-bit value from the file. Standard output is currently only used for debugging, they are not stored anywhere
```c
uint8_t *get_bytes32(FILE *f) {
    uint8_t *res = malloc(32);
    int ret = fread(res, 1, 32, f);
    printf("Got %i\n", ret);
    if (ret != 32) {
        printf("Error %i: %s\n", ferror(f), strerror(ferror(f)));
        free(res);
        return 0;
    }
    return res;
}
```

Read the record that represents the transaction:
```c
struct data get_data(FILE *f) {
    struct data res;
    res.addr = get_bytes32(f);
    res.value = get_bytes32(f);
    res.x = get_bytes32(f);
    res.y = get_bytes32(f);
    return res;
}
```

This is the main program, it will be called by Truebit system. First it opens the files for input and output.
```c
int main(int argc, char **argv) {
    FILE *input = fopen("input.data", "rb");

    if (!input) {
        fprintf(stderr, "Error: Cannot read input.data\n");
        return 1;
    }
    FILE *output = fopen("output.data", "wb");
    if (!output) {
        fprintf(stderr, "Error: Cannot open output.data for writing\n");
        return 1;
    }
```

Then each transaction is processed. Here we just output the address and corresponding value. This means that the ether can be paid back to the users.
```c
    
    while (1) {
        struct data record = get_data(input);
        if (record.addr == 0) break;
        
        fwrite(record.addr, 1, 32, output);
        fwrite(record.value, 1, 32, output);
        
    }
    fclose(input);
    fclose(output);
    return 0;
}
```

This file can be compiled using command
```
emcc -o simple.js simple.c
```
You need to have a version of LLVM with WebAssembly support, fastcomp is not currently supported. 
See this page for details: https://github.com/kripken/emscripten/wiki/New-WebAssembly-Backend, and https://github.com/mrsmkl/llvm6-wasm/blob/master/Dockerfile has a build script that should work (remember to update emscripten configuration).
It will generate two files, `simple.js` and `simple.wasm`. The command
```
node simple.js
```
could be used to run the program (except that it cannot access the filesystem).

The command 
```
node ~/emscripten-module-wrapper/prepare.js simple.js --file input.data --file output.data
```
will link our runtime to the WASM file.
If the files `input.data` and `output.data` do not exist, just create empty files:
```
touch input.data
touch output.data
```
It will output many things, currently we are interested in the initial code hash.
The command will also upload the WASM file to IPFS and give the IPFS hash.
Before users trust the smart contract that relies on the Truebit task, they should check that the code hash and IPFS hash are correct.

Here is the smart contract that uses Truebit tasks to implement computations:
```
contract Coindrop {

   event GotFiles(bytes32[] files);
   event Consuming(bytes32[] arr);

   uint nonce;
   TrueBit truebit;
   Filesystem filesystem;

   string code;
   bytes32 init;

   // the user input is associated with blocks
   struct Block {
      bytes32[] inputs;
      bytes32[] settled;
      bytes32 next_state;
      bytes32 input_file;
      bytes32 bundle;
      uint task;
      uint last;
   }

   mapping (uint => Block) blocks;
   mapping (uint => uint) task_to_block;
   
   uint current;
```

Initialize the contract with Truebit system addresses, and the code hash and the IPFS address for the code file. Also we have the file for the internal state that is saved between tasks, currently unused.
```
   function Coindrop(address tb, address fs, string code_address, bytes32 init_hash, bytes32 next_state) public {
      truebit = TrueBit(tb);
      filesystem = Filesystem(fs);
      code = code_address;     // address for wasm file in IPFS
      init = init_hash;        // the canonical hash
      blocks[0].next_state = next_state;
      current = block.number;
   }
```
User input transactions. They are associated with block numbers. For each Ethereum block, we can have at most one task.
```
   function addCoin(int x, int y) payable public {
      initBlock(block.number);
      Block storage b = blocks[current];
      b.inputs.push(bytes32(msg.sender));
      b.inputs.push(bytes32(x));
      b.inputs.push(bytes32(y));
      b.inputs.push(bytes32(msg.value));
   }

   function initBlock(uint num) internal {
      if (blocks[current].task == 0) return;
      Block storage b = blocks[num];
      if (b.inputs.length > 0) return;
      b.last = current;
      current = num;
   }
   
   function checkInput() public view returns (bytes32[]) {
      return blocks[current].inputs;
   }

```

This method will submit the transaction to Truebit for processing.
```
   function submitBlock() public {
      uint num = current;
      Block storage b = blocks[num];
      require(block.number > num && b.task == 0);
      Block storage last = blocks[b.last];
```
There will be three files: one for input and output, and one for internal state.
```
      b.input_file = filesystem.createFileWithContents("input.data", num, b.inputs, b.inputs.length*32);
      b.bundle = filesystem.makeBundle(num);
      filesystem.addToBundle(b.bundle, b.input_file);
      filesystem.addToBundle(b.bundle, last.next_state);
      bytes32[] memory empty = new bytes32[](0);
      filesystem.addToBundle(b.bundle, filesystem.createFileWithContents("output.data", num+1000000000, empty, 0));
```
The files are bundled together with the initial code, and then the initial state can be calculated.
```
      filesystem.finalizeBundleIPFS(b.bundle, code, init);
```

Now the taskk can be submitted to Truebit. We also specify which files the solver has to upload. If the second parameter is 0, it means that it should be uploaded to blockchain, and if it is 1, it means that it should be uploaded to IPFS.
``` 
      b.task = truebit.addWithParameters(filesystem.getInitHash(b.bundle), 1, 1, idToString(b.bundle), 20, 25, 8, 20, 10);
      truebit.requireFile(b.task, hashName("output.data"), 0);
      truebit.requireFile(b.task, hashName("state.data"), 1);
      task_to_block[b.task] = num;
   }
```

Callback that is called by the Truebit system. It reads the settled transactions, and remembers the state file (currently empty)
```
   uint remember_task;

   // this is the callback name
   function solved(uint id, bytes32[] files) public {
      remember_task = task_to_block[id];
      filesystem.forwardData(files[0], this);
      Block storage b = blocks[remember_task];
      b.next_state = files[1];
      GotFiles(files);
   }
   function consume(bytes32, bytes32[] arr) public {
      Consuming(arr);
      require(Filesystem(msg.sender) == filesystem);
      Block storage b = blocks[remember_task];
      b.settled = arr;
   }
```

From settled transactions, we can withdraw funds.
```
   function pull(uint num, uint idx) public {
      Block storage b = blocks[num];
      require(b.settled[idx*2] == bytes32(msg.sender));
      uint v = uint(b.settled[idx*2+1]);
      b.settled[idx*2+1] = bytes32(0);
      msg.sender.transfer(v);
   }
}
```

Now we just have to deploy the contract with correct initial code hash and IPFS address. See `deploy.js` for details.

