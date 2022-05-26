Testcase: `Revert.sol`. For conciseness, we are starting the stepthrough from the 2nd call, after sstoring `data`

Solidity / Yul
```
46 if iszero(or(xor(100, calldatasize()), and(LOCK, sload(slot)))) {
47    sstore(slot, meta)
48    return(0, 0)
49 }
50 if eq(100, calldatasize()) {
51    mstore(0, shl(224, 0xa1422f69))
52    revert(0, 4)
53 }
54 revert(0, 0)
```

```
// stack before 0x053 which corresponds after evaluting the condition in `if`
│00| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 58 | jump_to
│01| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 01 | if;  0x1 since 1st call locked `data`
│02| 04 cd 9e a8 81 3e e4 ea 1b e3 83 50 3a ad 53 9a fc 55 a7 9d c9 3f 1d b6 b3 92 0d 29 12 aa e4 b7 |        
│03| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 2a |        
│04| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 01 |        
│05| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 45 |        

// memory
│00| 00 00 00 00 00 00 00 00 00 00 00 00 b4 c7 9d ab 8f 25 9c 7a ee 6e 5b 2a a7 29 82 18 64 22 7e 84          
│20| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 45                     
│40| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 80                     

│053|▶JUMPI     // jumps to 0x58 because 0x1
```

```
│058| JUMPDEST
│059| POP       // Why pop 4 times? The compiler is likely popping usused values from the branch
│05a| POP                                                                                                                
│05b| POP                                                                                                                
│05c| POP                                                                                                                

// empty stack as expected
```

```
// To check for a `set` call


│05d| CALLDATASIZE     

│00| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 64  // because 100 byte calldata size


│05e| PUSH1(0x64)      // push 0x64 for comparison

│00| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 64 | a                 
│01| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 64 | b                 


│060| SUB                                                                                                                

│00| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 |                   


│061| PUSH1(0x74)                                                                                                        

│00| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 74 | jump_to           
│01| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | if                


│063| JUMPI           // doesn't jump. calldatasize == 100 byte

// empty stack as expected
```

```
│064| PUSH4(0xa1422f69) // this will be returned with `revert` as error code to represent lock error

│00| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 a1 42 2f 69 |                   


│069| PUSH1(0xe0)      // shift left, so the code can revert with the first 4 byte (up in memory address, because EVM is big endian)

│00| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 e0 | shift             
│01| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 a1 42 2f 69 | value             


│06b| SHL        

│00| a1 42 2f 69 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 |                   
```

```
│06c| PUSH1(0x00)      // offset for `mstore`

│00| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | offset            
│01| a1 42 2f 69 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | value             


│06e| MSTORE           // memory store to 1st word

// empty stack as expected


// memory - 1st word is 0xa1422f69'00'.repeat(28) as expected
│00| a1 42 2f 69 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00                     
│20| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 45                     
│40| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 80                     
```

```
│06f| PUSH1(0x04)
│071| PUSH1(0x00)

// stack
│00| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | offset            
│01| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 04 | size              

// memory
│00| a1 42 2f 69 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00                     
│20| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 45                     
│40| 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 80                     


│073| REVERT    // reverts with 1st 4 byte as return data i.e. 0xa1422f69 as expectd because we are setting a locked slot
```
