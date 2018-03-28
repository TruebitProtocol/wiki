# Data Availability

## Uploading data to blockchain

Using storage: 20000/32 = 625 gas per byte

Benchmarks for uploading data to blockchain as contract code:
 * 1Kb: 328340 gas -> 320 gas per byte
 * 2Kb: 602970 gas -> 294 gas per byte
 * 4Kb: 1152242 gas -> 281 gas per byte
 * 10Kb: 2800154 gas -> 273 gas per byte
 * 20Kb: 5546994 gas -> 270 gas per byte

Of this, the transaction overhead is about 70 gas per byte.

Updating data: 5000/32 = 156 gas per byte. So for volatile data, using storage is cheaper.

Zipping the wasm files could save over 50% in storage space.

## Problems

The first problem is that task giver posts a task hash, but doesn't give the data to the solver. It is hard to determine which one is wrong.

The task giver can keep giving the task, and withhold the data until he himself is assigned to become the solver. Then he can post a wrong answer, and the verifiers cannot challenge.

If the task giver controls access to the data needed for solving the task, he can perhaps find out the identities of the verifiers and bribe them.

Who will pay for the distribution of the data?

## Storj, Filecoin, other similar services

Can these help with data availability, or can the task giver still control the availability?

Filecoin should be able to guarantee availability, perhaps the TrueBit contract can query Filecoin and then find out if the data is publicly available. The solver and verifiers might have to pay the retrievers for downloading the data. The data size should be taken into account when calculating the cost of the task. Still have to be analyzed whether the task giver can control or bribe all the replicas.

If we decide that Filecoin model is good, but it takes long until Filecoin is implemented, a part of the model could be implemented in our nodes.

Swarm incentive model: http://swarm-gateways.net/bzz:/theswarm.eth/ethersphere/orange-papers/1/sw%5E3.pdf

These systems seem to be more interested in ensuring the availability for the publisher of the data.

## Erasure coding

https://github.com/ethereum/research/wiki/A-note-on-data-availability-and-erasure-coding

I don't know if this can be used directly inside TrueBit, but if it is implemented in a blockchain, data storage there should be cheaper.

## Some ideas

The peers could vote whether the data is available or not. But perhaps there is no incentive to vote correctly. Then the result would be that the enemies of the task giver vote against and the friends vote for him.

Because of the incentive structure, it can be assumed that the verifiers and solvers will pay something for access to data. Perhaps this will make the problem easier.

If an actor is suspicious that data is not available, he could request a review, and then a random actor would test if the data is available or not.

Perhaps it must be assumed that most actors are quite neutral, otherwise the solvers could refuse to post the correct solution anyway.

https://www.researchgate.net/publication/318899222_Betrayal_Distrust_and_Rationality_Smart_Counter-Collusion_Contracts_for_Verifiable_Cloud_Computing

Perhaps this research has something that would be useful to implement for preventing collusion and bribing.

Relaxing the correctness requirement: the task giver will take care of the data availability, and then the correctness will basically be guaranteed for just the task giver. The task giver can be some kind of organization that has incentive to keep the data available.

