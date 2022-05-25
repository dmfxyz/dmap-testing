# Introduction

- The goal here is to analyze:
  - the dmap Solidity/Yul codes
  - the corresponding opcodes
  - the memory and stack opcodes manipulate, in order to check if the contract correctly implements the most basic set call.
- This document is structured line by line in the dmap contract.
- I will present the code being analyzed, then usually the stack state before the corresponding opcodes run, and finally the opcodes.

# dmap.sol:L33

- Check for a get call, by looking at whether calldatasize is 36 byte = 4 (method selector) + 32 (the slot argument).
```
L33 if eq(36, calldatasize()) {
    ...
}
```

```
// stack and memory begin empty
```

```
│00|▶PUSH1(0x80)                                                                                                                                               
│02| PUSH1(0x40)                                                                                                                                               
│04| MSTORE        // memory[0x40:0x40+32] = 0x80; FIXME: I need to double check whether this is the return address.
│05| CALLDATASIZE  // L33 starts herek                                                                                                                                            
│06| PUSH1(0x24)                                                                                                                                               
│08| SUB                                                                                                                                                       
│09| PUSH1(0x22)   
│0b| JUMPI         // dest: 0x22, condition: sub(0x24, CALLDATASIZE). In other words, only jump when CALLDATASIZE is 36 byte.
```

# dmp.sol:L38-L40

- Load message call arguments
```
L38 let name := calldataload(4)
L39 let meta := calldataload(36)
L40 let data := calldataload(68)
```
```
┌Stack: 0──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

┌Memory (max expansion: 96 bytes)──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│00| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00                                                           │
│20| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00                                                           │
│40| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 80                                                           │
```

```
│22|▶JUMPDEST      // after get call check, execution jumps to here
│23| PUSH1(0x04)                                                                                                                                               
│25| CALLDATALOAD                                                                                                                                              
│26| PUSH1(0x24)                                                                                                                                               
│28| CALLDATALOAD                                                                                                                                              
│29| PUSH1(0x44)                                                                                                                                               
│2b| CALLDATALOAD                                                                                                                                              
```

```
┌Stack: 3──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
│00| 33 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 // correctly loads arugument `data`
│01| 32 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 // `meta`                                                           
│02| 31 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 // `name`                                                          
```

# IMPORTANT: dmap.sol:L41-L43

- Compute the slot
  - FIXME: work on this more.
    - This in effect implements access control for setting data under the root tree - set('free', 0x1, 'fish_zone_addr') are different user_addr1 and user_addr2.
    - If I am not wrong, the intented and second order effect is, with dmap.js, to write the value at `free`, you must have the root zone contract to set it.

```
L41: mstore(0, caller())
L42: mstore(32, name)
L43: let slot := keccak256(0, 64)
```

```
┌Stack: 3──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│00| 33 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00                                                           │
│01| 32 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00                                                           │
│02| 31 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00                                                           │
```

```
│2c|▶CALLER                                                                                                                                                    
│2d| PUSH1(0x00)                                                                                                                                               
│2f| MSTORE  // memory[0:32] = CALLER i.e. zone                                                                                                                         
│30| DUP3                                                                                                                                                      
│31| PUSH1(0x20)                                                                                                                                               
│33| MSTORE // memory[32:64] = 0x31 i.e. name                                                                                                                           
│34| PUSH1(0x40)                                                                                                                                               
│36| PUSH1(0x00)                                                                                                                                               
│38| SHA3  // keccak256 on (zone followed by name)
```

# dmap.sol:L44

```
L44 log4(0, 0, caller(), name, meta, data)
```

```
┌Stack: 4──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│00| 89 96 19 c3 e7 fd 33 9f 93 01 af 06 29 79 50 0f 51 ce d5 ed 61 f1 14 ff 8e 8a c9 98 d6 b2 de ef                                                           │
│01| 33 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00                                                           │
│02| 32 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00                                                           │
│03| 31 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00                                                           │
```

```
│39| DUP2                                                                                                                                                      │
│3a| DUP4                                                                                                                                                      │
│3b| DUP6                                                                                                                                                      │
│3c| CALLER                                                                                                                                                    │
│3d| PUSH1(0x00)                                                                                                                                               │
│3f| DUP1                                                                                                                                                      │
│40| LOG4                                                                                                                                                      │
```

# IMPORTANT: dmap.sol:L45

```
L45 sstore(add(slot, 1), data) // storing `data` into persistent storage
```

```
┌Stack: 4──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│00| 89 96 19 c3 e7 fd 33 9f 93 01 af 06 29 79 50 0f 51 ce d5 ed 61 f1 14 ff 8e 8a c9 98 d6 b2 de ef                                                           │
│01| 33 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00                                                           │
│02| 32 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00                                                           │
│03| 31 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00                                                           │
```
```
│41|▶DUP2        // DUP 0x33... i.e. data
│42| PUSH1(0x01)                                                                                                                                               
│44| DUP3        // DUP 0x8969...deef i.e. slot
│45| ADD   
│46| SSTORE      // offset: slot + 1, value: data
```

- Just to double check, this is the stack state right before SSTORE
```
┌Address: 0x9094…dd96 | PC: 70 | Gas used in call: 2027────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│40| LOG4                                                                                                                                                      │
│41| DUP2                                                                                                                                                      │
│42| PUSH1(0x01)                                                                                                                                               │
│44| DUP3                                                                                                                                                      │
│45| ADD                                                                                                                                                       │
│46|▶SSTORE                                                                                                                                                    │
│47| DUP1                                                                                                                                                      │
│48| SLOAD                                                                                                                                                     │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
┌Stack: 6──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│00| 89 96 19 c3 e7 fd 33 9f 93 01 af 06 29 79 50 0f 51 ce d5 ed 61 f1 14 ff 8e 8a c9 98 d6 b2 de f0                                                           │
│01| 33 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00                                                           │
│02| 89 96 19 c3 e7 fd 33 9f 93 01 af 06 29 79 50 0f 51 ce d5 ed 61 f1 14 ff 8e 8a c9 98 d6 b2 de ef                                                           │
│03| 33 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00                                                           │
│04| 32 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00                                                           │
│05| 31 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00                                                           │
```

# IMPORTANT: dmap.sol:L46-L49

- Check if a) slot is locked and b) this call is a `set` call (if CALLDATASIZE is 100 byte), if so set `meta` at `slot`.
```
L46 if iszero(or(xor(100, calldatasize()), and(LOCK, sload(slot)))) {
L47     sstore(slot, meta)
L48     return(0, 0)
L49 }
```

```
┌Stack: 6──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│00| 89 96 19 c3 e7 fd 33 9f 93 01 af 06 29 79 50 0f 51 ce d5 ed 61 f1 14 ff 8e 8a c9 98 d6 b2 de f0                                                           │
│01| 33 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00                                                           │
│02| 89 96 19 c3 e7 fd 33 9f 93 01 af 06 29 79 50 0f 51 ce d5 ed 61 f1 14 ff 8e 8a c9 98 d6 b2 de ef                                                           │
│03| 33 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00                                                           │
│04| 32 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00                                                           │
│05| 31 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00                                                           │
```

```
│47|▶DUP1                                                                                                                                                       
│48| SLOAD         // sload(slot)                                                                                                                                            
│49| PUSH1(0x01)                                                                                                                                               
│4b| AND           // and(LOCK, sload(slot))                                                                                                                               
│4c| CALLDATASIZE                                                                                                                                              
│4d| PUSH1(0x64)                                                                                                                                               
│4f| XOR           // 0 if CALLDATASIZE is 100                                                                                                                                           
│50| OR            // OR pushes a 0x0 indeed                                                                                                                                             
│51| PUSH1(0x58)                                                                                                                                               
│53| JUMPI         // Doesn't jump because condition is 0                                                                                                                                             
```
```
┌Stack: 4──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│00| 89 96 19 c3 e7 fd 33 9f 93 01 af 06 29 79 50 0f 51 ce d5 ed 61 f1 14 ff 8e 8a c9 98 d6 b2 de ef                                                           │
│01| 33 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00                                                           │
│02| 32 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00                                                           │
│03| 31 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00                                                           │
```

```
│54|▶DUP3          // DUP 0x32... i.e. meta                                                                                                                                          
│55| DUP2          // DUP 0x8996...deef i.e. slot                                                                                                                                       
```
Stack before SSTORE:
```
┌Stack: 6──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│00| 89 96 19 c3 e7 fd 33 9f 93 01 af 06 29 79 50 0f 51 ce d5 ed 61 f1 14 ff 8e 8a c9 98 d6 b2 de ef                                                           │
│01| 32 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00                                                           │
│02| 89 96 19 c3 e7 fd 33 9f 93 01 af 06 29 79 50 0f 51 ce d5 ed 61 f1 14 ff 8e 8a c9 98 d6 b2 de ef                                                           │
│03| 33 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00                                                           │
│04| 32 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00                                                           │
│05| 31 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00                                                           │
```
```
│56| SSTORE                                                                                                                                                    
│57| STOP         // contract finishes                                                                                                                                             
│END CALL                                                                                                                                                      
```

# Appendiex

- Deployed `dmap` contract object: https://etherscan.io/address/0x90949c9937A11BA943C7A72C3FA073a37E3FdD96#code
- The report is roughly sectioned by units of YUL expressions.
- `//` are comments.
- Tools:
  - code stepper: https://book.getfoundry.sh/forge/debugger.html.
  - Opcode reference: https://ethervm.io/
  - I find Geth implementation helpful for clarifying the opcode's semantics - https://github.com/ethereum/go-ethereum/blob/master/core/vm/instructions.go
