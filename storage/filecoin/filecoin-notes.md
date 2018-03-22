---
title:
- Filecoin Summary
author:
- Truebit
theme:
- Copenhagen
---

## What is Filecoin?
Filecoin is a blockchain built on top of IPFS to further act as an incentivization layer for storage and retrieval of data.<br/>
Filecoin features two Proofs of Storage(PoS), namely Proof of Spacetime and Proof of Replication.<br/>
We will further discuss these PoSs in detail further one, but here's a short explanation for now:<br/>

### Proof Of Spacetime
It's used to prove that the storage miner is indeed storing the data for the agreed-upon duration.<br/>

### Proof Of Replication
It's used to prove that the storage miner is indeed storing the data in the agreed-upon number of physically distinct locations.<br/>

## Miners
Miners collectively and individually assume three separate roles in the Filecoin ecosystem:<br/>

* **Storage Miners**: The group of miners that pledge to store data.<br/>
* **Retrieval Miners**: The group of miners that pledge to retrieve data from the storage miners.<br/>
* **The Network**: The aggregate of all users that are running full nodes. The network handles the repair of data and validation of the proofs.<br/>

There are also the so called `clients` that use the retrieval and storage services without directly dealing with the blockchain itself.<br/>

## Definitions and Concepts

Next we will take a look at some definitions and concepts for Filecoin:<br/>

## Storage Miners

Storage miners pledge a certain amount of storage and put up the same amount in collateral proportional to their pledged storage amount.<br/>

Storage miners will post periodic proofs of space time that prove they are storing the data for the pledged amount of time onto the blockchain which is in turn verified by the `network`.<br/>

In case the proofs are invalid or missing, the storage miner will be penalized and loose part of their collateral.<br/>

Storage miners are eligible for mining new blocks in which case they will be given the reward for mining a new block and a percentage of the transaction fees inside the block.<br/>

## Retrieval Miners

Retrieval miners provide data retrieval to the network.<br/>

Retrieval miners are not required to provide proofs of storage. Clients pay them for every piece they retrieve, when they retrieve it.<br/>

Retrieval miners can also act as storage miners.<br/>

Retrieval miners can obtain pieces directly from clients(?) and the Retrieval market.<br/>

## The Network

The aggregate of all the Filecoin full nodes.<br/>

The network, at every new block, handles managing the available storage, validates pledges, audits the storage proofs and tries to repair possible faults.<br/>

## The Ledger

Is a sequence of transactions(TXs).<br/>

At any given time, the users have access to the ledger at the given time.<br/>

The ledger is append-only.<br/>

Filecoin's ledger is built using **useful work**.<br/>

## Markets

Filecoin features two separate decentralized exchange markets, namely the Storage Market and the Retrieval Market.<br/>

Clients and miners(storage and retrieval) set the prices for their services in the respective markets.<br/>

The exchanges provide a way for the clients and miners to see matching offers and initiate deals.<br/>

The network guarantees that the services are provided and that the miners get paid for the provided services.<br/>

## Data Structures
Filecoin features a number of prominent data structures. Knowing the contents and the role they play will help us have an overall better understanding of how Filecoin works so we will go through them one by one:<br/>

### Pieces
A `piece` is some part of data that a client is storing on the network. Data can be deliberately broken into many pieces and stored by different storage miners.<br/>

### Sectors
A `sector` is some disk space that a storage miner pledges to the network.<br/>

## Data Structures

### AllocationTable
The **AllocTable** is a data structure that keeps track of `piece`s and which `sector` they are being stored in.<br/>

The **AllocTable** is updated at every block in the ledger and its Merkle root is stored on the blockchain.<br/>

The table is used to keep the state of the DSN(**D**istributed **S**torage **N**etwork) allowing for quick look-ups during proof verification.<br/>

## Data Structures

### Orders
An `order` is a statement of intent to request or offer services.<br/>

#### Bid Orders
Clients submit `bid` orders to the networks depending on which service(storage or retrieval) they seek.<br/>

#### Ask Orders
Miners submit `ask` orders to offer their services.<br/>
After a pledge order appears in the blockchain and the miner has paid the collateral, they can offer storage via ask.<br/>

#### Deal Orders
After an ask and bid order are matched and after the miner receives the data to be stored, the client and miner sign a `deal` order.<br/>

## Data Structures

### Orderbook
Orderbooks(one for each market) are sets of orders.<br/>
For the Storage Market, the orderbook will contain `ask` orders from storage miners, `bid` orders from the clients who want to store data on the DSN and the matched orders(`deal` orders).<br/>
The orderbook for the retrieval market features the same set of orders, but the `ask` orders come from retrieval miners instead.<br/>

### Pledge
A `pledge` is a commitment to offer a `sector` to the network accompanied with a collateral respective to the actual size of the `sector`.<br/>

## Blockchain contents

* Merkle root of **AllocTable**.<br/>
* Periodic proofs of storage which the network will verify.<br/>
* A `deal` order for the retrieval scenario<br/>
* `orderbook`<br/>

## Consensus

* Useful work consensus protocol
* The probability that the network elects a miner to create the next block is proportional to their **storage currently in use**(not pledged) in relation to the rest of the network.<br/>
* The storage currently in use can be traced in **AllocTable**.<br/>

## Consensus

### Expected Consensus(EC)

The mathematical expectation of number of leaders for each epoch is 1 but some epochs might have 0 or more than one leaders. In case there are zero leaders, an empty block is created.<br/>

Leaders extend the chain by propagating a block to the network.<br/>

At each epoch, the chain is extended by one or more blocks.<br/>

The data structure is a directed acyclic graph.<br/>

EC is a probabilistic consensus. Each epoch introduces more certainty over the previous epochs' blocks until the likelihood of a different history is `sufficiently small`.<br/>

A block is committed if the majority of the participants add their weight on the chain where the block belongs to, by extending the chain or by signing the blocks.<br/>

## System Parameters

### A minimum amount of epoch of storage

### $\Delta$~proof~

The interval between proofs of storage.<br/>

## Smart Contracts

* Will feature a contract system based on Ethereum.<br/>
* Will provide a bridge system to bring Filecoin storage to other blockchains and to bring other blockchains' functionalities to Filecoin.<br/>

## Questions

* How does proof of spacetime prove that the replicas actually are physically stored separately?<br/>
* Who keeps the collateral storage miners pay via pledge?<br/>
* In case a piece is `faulty`, the network will introduce a new order. Is there a cap on how many times the network will retry?<br/>
* Is there an oracle for the storage miners to use to set their price?<br/>
* Deal orders are submitted after receiving and sending files. What if the receiver in the retrieval scenario and the receiver in the storage scenario are dishonest?<br/>
