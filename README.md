# fabric network configs
:sparkles: Hyperledger fabric chaincode network config resources.From the simple to the complex, clustered network environment, the evolution of the structure of the hyperledger fabric network is gradually demonstrated.

## `basic` network

**single domain**

**OrdererType: solo**

+ ca service: 2
+ orderer service: 1
+ peer 4 org 2 service: 4
+ configtxlator: 1
+ ccenv: 1



## `simple` network

**mixing domain/multiple domain**

**OrdererType: solo**

- ca service: 2
- orderer service: 1
- peer 4 org 2 service: 4
- configtxlator: 1
- ccenv: 1



## `complex` network

**mixing domain/multiple domain**

**OrdererType: kafka**

- ca service: 2
- orderer service: 1
- peer 4 org 2 service: 4
- configtxlator: 1
- ccenv: 1
- zookeeper: 3
- kafka: 4
- couchdb: 4



## `swarm` network

***multiple node cluster docker swarm networks. docker swarm node: 4***

**mixing domain/multiple domain**

**OrdererType: kafka**

- ca service: 2, replicas: 4

- orderer service: 1, replicas: 4

- peer 4 org 2 service: 4, replicas: 4

- configtxlator: 1, replicas: 2

- ccenv: 1, replicas: 2

- zookeeper: 3, replicas: 4

- kafka: 4, replicas: 4

- couchdb: 4, replicas: 4


# `cluster ` networks

Used docker cluster network, Distributed on different machine nodes.

## `solo`  network

Do not use `zookeeper & kafka` service. ***docker swarm node: 4***

**mixing domain/multiple domain**

**OrdererType: solo**

- ca service: 2, replicas: 4
- orderer service: 1, replicas: 4
- peer 4 org 2 service: 4, replicas: 4
- configtxlator: 1, replicas: 2
- ccenv: 1, replicas: 2
- couchdb: 4, replicas: 4

## `single`  network

use `1 zookeeper & 1 kafka` service. ***docker swarm node: 4***

**mixing domain/multiple domain**

**OrdererType: kafka**

- ca service: 2, replicas: 4
- orderer service: 1, replicas: 4
- peer 4 org 2 service: 4, replicas: 4
- configtxlator: 1, replicas: 2
- ccenv: 1, replicas: 2
- couchdb: 4, replicas: 4

- zookeeper: 1, replicas: 4
- kafka: 1, replicas: 4

## `replicated`  network

Use replicated network, The same service exists for every machine. ***docker swarm node: 4***

**mixing domain/multiple domain**

**OrdererType: kafka**

- ca service: 2, replicas: 4
- orderer service: 1, replicas: 4
- peer 4 org 2 service: 4, replicas: 4
- configtxlator: 1, replicas: 1
- ccenv: 1, replicas: 1
- couchdb: 4, replicas: 4

- zookeeper: 3, replicas: 4
- kafka: 4, replicas: 4

## `distributed`  network

Use distributed network, Distribute services on different machine nodes. ***docker swarm node: 4***

![1538123014807](D:\work_private\notes\blockchain\.img\1538123014807.png)

**mixing domain/multiple domain**

**OrdererType: kafka**

- ca service: 2, replicas: 1
- orderer service: 1, replicas: 1
- peer 4 org 2 service: 4, replicas: 1
- configtxlator: 1, replicas: 1
- ccenv: 1, replicas: 1
- couchdb: 4, replicas: 1

- zookeeper: 3, replicas: 1
- kafka: 4, replicas: 1