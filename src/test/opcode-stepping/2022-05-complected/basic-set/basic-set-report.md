# Introduction

- The goal here is to analyze:
  - the `dmap.sol` contract's Solidity source, as verified on Etherscan
  - the corresponding opcodes, as decompiled from the contract object on Mainnet, using Foundry's debugger 
  - the memory and stack state that the opcodes manipulate, in order to check if the contract object correctly implements the most basic set call
- This document is structured in the order of the Solidity source
- For each section, I will show:
  1. the Solidity code being analyzed
  1. the opcodes
  1. then the stack and memory state before/after the important instructions

# dmap.sol:L33

This checks for a `get` call, by looking at whether `calldatasize()` is `36` byte = 4 (method selector) + 32 (the slot argument).

```
L33 if eq(36, calldatasize()) {
    ...
}
```

```
│00|▶PUSH1(0x80)   // Bytecode 0x00-0x04 are boilerplate in most contracts for finding free memory pointer. FIXME: source.                                                                                                                                             
│02| PUSH1(0x40)                                                                                                                                               
│04| MSTORE
│05| CALLDATASIZE  // L33 starts here.
│06| PUSH1(0x24)                                                                                                                                               
│08| SUB                                                                                                                                                       
│09| PUSH1(0x22)   
│0b| JUMPI         // Only jump when `CALLDATASIZE` is not 36 byte.

```

Before `0x00`
```
// Stack and memory begin empty in a contract call.
```

# dmp.sol:L38-L40

This loads arguments from `message`.
```
L38 let name := calldataload(4)
L39 let meta := calldataload(36)
L40 let data := calldataload(68)
```

```
│22|▶JUMPDEST      // Just a jump label.
│23| PUSH1(0x04)
│25| CALLDATALOAD  // Push calldata[4:36].
│26| PUSH1(0x24)                                                                                                                                               
│28| CALLDATALOAD  // Push calldata[36:68].                                                                                                                                           
│29| PUSH1(0x44)                                                                                                                                               
│2b| CALLDATALOAD  // Push calldata[68:100].
```

Before `0x22`
```
// Stack is empty.

┌Memory (max expansion: 96 bytes)───────────────────────────────────────────────────────────────────
│00| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00     
│20| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00     
│40| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 80 // memory[0x40] will stay the same through the life of the call
```

After `0x2b`
```
┌Stack: 3───────────────────────────────────────────────────────────────────────────────────────────
│00| 33 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 // correctly loads arugument `data`
│01| 32 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 // `meta`                                                           
│02| 31 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 // `name`                                                          

┌Memory (max expansion: 96 bytes)───────────────────────────────────────────────────────────────────
│00| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
│20| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
│40| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 80
```

# IMPORTANT: dmap.sol:L41-L43

// FIXME: make it more clear.

The goal for this block is to compute the slot number. And the `slot` number is **particularly important**.

Since slot number is keccak256 of caller address and `name`. this in effect implements authorization for writing to `slot`s.  For any given slot x (and x + 1) already set by EOA1, malicious EOA2 practically cannot set the x without breaking `keecak256`.

Because setting x requires EOA2 to either:

> 1. find `call2_name` such that `slot2 = keecak256(EOA2 + call2_name)` == `slot1 = keecak256(EOA1 + call1_name)` 
>     1. The attack works by simply writing over `slot2` and `slot2 + 1`. Note the attack requires `slot1` be unlocked (or not `0x1`) before `slot2` gets overwritten
>     1. In other words, the attack works because the lock is not set and the only requirement is the attacker finds the right name to overwrite the slots
> 1. find `call2_name ` such that `slot2 = keecak256(EOA2 + call2_name)` == `slot1 + 1 = keecak256(EOA1 + call1_name) + 1` 
>     1. This case is more subtle. For this attack to work, EOA1 has to first set `slot1 + 1`, i.e. the data slot for call1, to a non `0x1` 
>     1. `slot2` == `slot1 + 1` being unlocked implies both `slot2` (call2's meta) can now write over (call1's data). (`slot2 + 1` doesn't cause any harm in this case)

For reference, these are known as preimage attacks - given y, find an x such that h(x) = y. 

`keecak256/sha3-256` are known to have 256-bit preimage resistance, meaning time complexity 2^256. Source: [wikipedia](https://en.wikipedia.org/wiki/SHA-3#Instances), [wikipedia](https://en.wikipedia.org/wiki/Preimage_attack).

Finally, the actually intented effect of this auth system: 

> to set at e.g. dpath `.free`, an EOA must call the root zone contract object to `set`. since EOA needs the root zone contract object to set name under the root zone, and you need the free zone contract object to set name under the free zone etc.

> The application of this effect is that a `get` user can rely on the locked values that are `walk`ed from root zone being immutable, provided all of these "work":
>   1. Ethereum consensus
>   1. user's Ethereum client
>   1. every zone contract object involved in the dpath

```
L41: mstore(0, caller())
L42: mstore(32, name)
L43: let slot := keccak256(0, 64)
```

```
│2c|▶CALLER                                                                                                                                                    
│2d| PUSH1(0x00)                                                                                                                                               
│2f| MSTORE      // memory[0:32] = CALLER i.e. zone or end user data                                                                                                                         
│30| DUP3                                                                                                                                                      
│31| PUSH1(0x20)                                                                                                                                               
│33| MSTORE      // memory[32:64] = 0x31... i.e. name                                                                                                                           
│34| PUSH1(0x40) // Push 64.
│36| PUSH1(0x00) // Push 0.
│38| SHA3        // Push to stack, keccak256 of the byte seqence `zone` followed by `name`.
```

Before `0x2c`
```
┌Stack: 3───────────────────────────────────────────────────────────────────────────────────────────
│00| 33 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  
│01| 32 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  
│02| 31 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  

┌Memory (max expansion: 96 bytes)───────────────────────────────────────────────────────────────────
│00| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
│20| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
│40| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 80
```

Before `0x38`
```
┌Stack: 5──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│00| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | offset                                                  │
│01| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 40 | size                                                    │
│02| 33 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 |                                                         │
│03| 32 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 |                                                         │
│04| 31 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 |                                                         │
│                                                                                                                                                              │
│                                                                                                                                                              │
│                                                                                                                                                              │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

┌Memory (max expansion: 96 bytes)──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│00| 00 00 00 00 00 00 00 00 00 00 00 00 b4 c7 9d ab 8f 25 9c 7a ee 6e 5b 2a a7 29 82 18 64 22 7e 84                                                           │
│20| 31 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00                                                           │
│40| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 80                                                           │

```

# dmap.sol:L44

```
L44 log4(0, 0, caller(), name, meta, data)
```

```
│39|▶DUP2                                                                                           
│3a| DUP4                                                                                           
│3b| DUP6                                                                                           
│3c| CALLER                                                                                         
│3d| PUSH1(0x00)                                                                                    
│3f| DUP1                                                                                           
│40| LOG4                                                                                           
```

Before `0x39`
```
┌Stack: 4──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│00| 89 96 19 c3 e7 fd 33 9f 93 01 af 06 29 79 50 0f 51 ce d5 ed 61 f1 14 ff 8e 8a c9 98 d6 b2 de ef |                                                         │
│01| 33 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | dup_value                                               │
│02| 32 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 |                                                         │
│03| 31 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 |                                                         │
│                                                                                                                                                              │
│                                                                                                                                                              │
│                                                                                                                                                              │
│                                                                                                                                                              │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

┌Memory (max expansion: 96 bytes)──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│00| 00 00 00 00 00 00 00 00 00 00 00 00 b4 c7 9d ab 8f 25 9c 7a ee 6e 5b 2a a7 29 82 18 64 22 7e 84                                                           │
│20| 31 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00                                                           │
│40| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 80                                                           │

```

Before `0x40`
```
┌Stack: 10─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│00| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | offset                                                  │
│01| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | size                                                    │
│02| 00 00 00 00 00 00 00 00 00 00 00 00 b4 c7 9d ab 8f 25 9c 7a ee 6e 5b 2a a7 29 82 18 64 22 7e 84 | topic1                                                  │
│03| 31 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | topic2                                                  │
│04| 32 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | topic3                                                  │
│05| 33 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | topic4                                                  │
│06| 89 96 19 c3 e7 fd 33 9f 93 01 af 06 29 79 50 0f 51 ce d5 ed 61 f1 14 ff 8e 8a c9 98 d6 b2 de ef |                                                         │
│07| 33 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 |                                                         │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

┌Memory (max expansion: 96 bytes)──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│00| 00 00 00 00 00 00 00 00 00 00 00 00 b4 c7 9d ab 8f 25 9c 7a ee 6e 5b 2a a7 29 82 18 64 22 7e 84                                                           │
│20| 31 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00                                                           │
│40| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 80                                                           │
```



# IMPORTANT: dmap.sol:L45

Sstoring `data` at `slot + 1`
```
L45 sstore(add(slot, 1), data)
```

```
│41|▶DUP2        // DUP 0x33... i.e. data
│42| PUSH1(0x01)                                                                                                                                               
│44| DUP3        // DUP 0x8969...deef i.e. slot
│45| ADD   
│46| SSTORE      // offset: slot + 1, value: data
```

Before `0x41`
```
┌Stack: 4──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│00| 89 96 19 c3 e7 fd 33 9f 93 01 af 06 29 79 50 0f 51 ce d5 ed 61 f1 14 ff 8e 8a c9 98 d6 b2 de ef |                                                         │
│01| 33 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | dup_value                                               │
│02| 32 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 |                                                         │
│03| 31 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 |                                                         │

┌Memory (max expansion: 96 bytes)──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│00| 00 00 00 00 00 00 00 00 00 00 00 00 b4 c7 9d ab 8f 25 9c 7a ee 6e 5b 2a a7 29 82 18 64 22 7e 84                                                           │
│20| 31 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00                                                           │
│40| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 80                                                           │
```

Before `0x46`
```
┌Stack: 6──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│00| 89 96 19 c3 e7 fd 33 9f 93 01 af 06 29 79 50 0f 51 ce d5 ed 61 f1 14 ff 8e 8a c9 98 d6 b2 de f0 | key                                                     │
│01| 33 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | value                                                   │
│02| 89 96 19 c3 e7 fd 33 9f 93 01 af 06 29 79 50 0f 51 ce d5 ed 61 f1 14 ff 8e 8a c9 98 d6 b2 de ef |                                                         │
│03| 33 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 |                                                         │
│04| 32 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 |                                                         │
│05| 31 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 |                                                         │

┌Memory (max expansion: 96 bytes)──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│00| 00 00 00 00 00 00 00 00 00 00 00 00 b4 c7 9d ab 8f 25 9c 7a ee 6e 5b 2a a7 29 82 18 64 22 7e 84                                                           │
│20| 31 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00                                                           │
│40| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 80                                                           │
```

# IMPORTANT: dmap.sol:L46-L49

Check if:
1. this call is a `set` call
1. `slot` is "locked" / non 0x1,

and if so, set `meta` at `slot`.

```
L46 if iszero(or(xor(100, calldatasize()), and(LOCK, sload(slot)))) {
L47     sstore(slot, meta)
L48     return(0, 0)
L49 }
```

```
│47|▶DUP1                                                                                                                                                       
│48| SLOAD         // sload(slot)                                                                                                                                            
│49| PUSH1(0x01)                                                                                                                                               
│4b| AND           // and(LOCK, sload(slot))                                                                                                                               
│4c| CALLDATASIZE                                                                                                                                              
│4d| PUSH1(0x64)                                                                                                                                               
│4f| XOR           // 0 if CALLDATASIZE is 100                                                                                                                                           
│50| OR            // 0 because both 0
│51| PUSH1(0x58)                                                                                                                                               
│53| JUMPI         // Doesn't jump because of 0
│54| DUP3          // DUP 0x32... i.e. meta                                                                                                                                          
│55| DUP2          // DUP 0x8996...deef i.e. slot                                                                                                                                       
│56| SSTORE                                                                                                                                                    
│57| STOP         // contract finishes                                                                                                                                             
│END CALL                                                                                                                                                      
```

Before `0x47`
```
┌Stack: 4──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│00| 89 96 19 c3 e7 fd 33 9f 93 01 af 06 29 79 50 0f 51 ce d5 ed 61 f1 14 ff 8e 8a c9 98 d6 b2 de ef | dup_value                                               │
│01| 33 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 |                                                         │
│02| 32 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 |                                                         │
│03| 31 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 |                                                         │

┌Memory (max expansion: 96 bytes)──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│00| 00 00 00 00 00 00 00 00 00 00 00 00 b4 c7 9d ab 8f 25 9c 7a ee 6e 5b 2a a7 29 82 18 64 22 7e 84                                                           │
│20| 31 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00                                                           │
│40| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 80                                                           │
```

Before `0x50`
```
┌Stack: 6──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│00| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | a                                                       │
│01| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | b                                                       │
│02| 89 96 19 c3 e7 fd 33 9f 93 01 af 06 29 79 50 0f 51 ce d5 ed 61 f1 14 ff 8e 8a c9 98 d6 b2 de ef |                                                         │
│03| 33 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 |                                                         │
│04| 32 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 |                                                         │
│05| 31 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 |                                                         │

┌Memory (max expansion: 96 bytes)──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│00| 00 00 00 00 00 00 00 00 00 00 00 00 b4 c7 9d ab 8f 25 9c 7a ee 6e 5b 2a a7 29 82 18 64 22 7e 84                                                           │
│20| 31 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00                                                           │
│40| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 80                                                           │
```

Before `0x56` / `SSTORE`
```
┌Stack: 6──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│00| 89 96 19 c3 e7 fd 33 9f 93 01 af 06 29 79 50 0f 51 ce d5 ed 61 f1 14 ff 8e 8a c9 98 d6 b2 de ef | key                                                     │
│01| 32 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | value                                                   │
│02| 89 96 19 c3 e7 fd 33 9f 93 01 af 06 29 79 50 0f 51 ce d5 ed 61 f1 14 ff 8e 8a c9 98 d6 b2 de ef |                                                         │
│03| 33 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 |                                                         │
│04| 32 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 |                                                         │
│05| 31 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 |                                                         │

┌Memory (max expansion: 96 bytes)──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│00| 00 00 00 00 00 00 00 00 00 00 00 00 b4 c7 9d ab 8f 25 9c 7a ee 6e 5b 2a a7 29 82 18 64 22 7e 84                                                           │
│20| 31 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00                                                           │
│40| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 80                                                           │
```

# Appendiex

- Deployed `dmap` contract object: https://etherscan.io/address/0x90949c9937A11BA943C7A72C3FA073a37E3FdD96#code
- Tools:
  - code stepper: https://book.getfoundry.sh/forge/debugger.html.
  - Opcode reference: https://ethervm.io/
  - I find Geth implementation helpful for clarifying the opcode's semantics - https://github.com/ethereum/go-ethereum/blob/master/core/vm/instructions.go
  - Future reading: https://docs.soliditylang.org/en/v0.8.14/yul.html
