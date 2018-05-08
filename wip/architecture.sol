
pragma solidity ^0.4.18;

contract ComputationLayer {
  // implements the following:
  // 1) wasm interpreter: virtual memory, alu, ...
  // 2) filesystem: storing data in EVM storage.
  // 3) merkle tree processing: creating state roots & reading proofs.

  // called by DisputeResolutionLayer, returns state hash after running instruction.
  function performStep() public; // returns state hash. 
}

contract DisputeResolutionLayer {
  // implements the following:
  // 1) verification game: query and response.
  // 2) slashing conditions: comparison of resulting state to the one provided by the Solver.

  // called by IncentiveLayer
  function startGame(bytes32 taskID, address solver, address challenger);

  // called by client (challenger):
  function query(bytes32 gameId, uint stepNumber);

  // called by client (solver):
  function respond(bytes32 gameId, uint stepNumber, bytes32 hash);
  
  // called by client (anyone):
  function timeout(bytes32 gameId) public;

  // called by a client,
  // calls ComputationLayer:performStep and decides whether resulting state is equal to highStepState,
  // then calls IncetiveLayer:gameDecided with the resulting boolean.
  function performStepVerification(bytes32 gameId, bytes32[3] lowStepState, bytes32[3] highStepState, bytes proof) public;
}

contract IncentiveLayer {
  // implements the following:
  // 1) selection of solver.
  // 2) incentivization of verifiers: forced errors & jackpot.
  // 3) selection and ordering of challengers.
  // 4) rewards: being handed to solver.
  // 5) kicking off verification games, into the dispute-resolution layer.

  // called by client (anyone):
  function makeDeposit() public payable;
  function withdrawDeposit() public;

  // called by client (task giver)
  function createTask(uint minDeposit, bytes32 taskData, uint numBlocks) public payable;
  
  // called by client (anyone, to become solver):
  function registerForTask();

  // called by client (anyone):
  function selectRandomizedSolver(bytes32 taskID);

  // called by client (solver):
  function submitSolution(bytes32 taskID)

  // called by client (verifier):
  function commitChallenge(bytes32 taskID)
  
  // called by client (anyone):
  // can also be called by gameDecided()
  // calls DisputeResolutionLayer:createGame()
  function startNextGame(bytes32 taskID);

  // called by DisputeResolution:performStepVerification
  function gameDecided(bytes32 taskID, address winner, address loser);

  // called by client (anyone):
  // checks timeout, rewards solver.
  function taskDecided(bytes32 taskID)

  // caller tbd
  // called as a result of solver revealing there was a forced error.
  // pays out jackpot to all challengers, according to exponential dropoff.
  function taskWasForcedError(bytes32 taskID)
}
