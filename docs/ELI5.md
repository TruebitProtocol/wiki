## Explain Like I'm 5

For a great technical summary of the protocol go [here](https://medium.com/truebit/truebit-the-marketplace-for-verifiable-computation-f51d1726798f)

The short version is Truebit is an incentivized scalability solution for distributed trustless networks. The protocol is enforced by playing an interactive "game". We are currently implementing Truebit to be used by the Ethereum blockchain, in order for Ethereum users to be able to overcome the gas limit while still being secure.

## Roles
* Taskgiver: is the user posting a task that needs to be solved by a Solver. <br/>
* Solver: is the user chosen to solve the task for a reward.<br/>
* Verifier(s): are the users that check the solution to the task that is posted by the Solver.<br/>
* Challenger(s): are the Verifiers that disagree with the solution posted by the Solver. <br/>

## Task Life Cycle

1. Task Create - New task is created on the Truebit Incentive Layer smart contract by a Task Giver.
2. Solver Selected - A Solver is selected to solve the task
3. Solution Submitted - The selected solver submits a solution to the task
4. Solution Challenged - There is a period of time where verifier's are welcome to challenge the solution
5. Verification Game - If there is a challenge, then a verification game is played to determine if the solution is correct or not.
6. Task Finalized - If there was no challenge, or all of the verification games have been resolved, then the task is finalized.

If you want a more in depth look at the life cycle of a task take a look at the [incentive layer](https://github.com/TrueBitFoundation/Developer-Resources/blob/master/docs/IncentiveLayer.md). For now we will give a summary of the different states of the task. 

## Verification Game Life Cycle

1. Game Created - If a task's solution is challenged then a verification game is created on the Truebit dispute resolution layer smart contract.
2. Query/Response - The Verifier queries the solver for different steps (uses binary search scheme to choose which steps). The Solver responds to these steps with hashes of the internal VM state.
3. Step Verification - Once the binary search narrows down the computation to two steps it then runs the state transition on chain. If the result of that computation is what the Solver originally stated, then the Solver will win. Otherwise, the Verifier wins.

If you want a more in depth analysis of the Verification Game go to the [dispute resolution layer](https://github.com/TrueBitFoundation/Developer-Resources/blob/master/docs/DisputeResolutionLayer.md)
