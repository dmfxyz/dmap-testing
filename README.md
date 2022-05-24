## Fuzz Tests against deployed dmap object
### What does this repo do?
This repo is designed to fork the mainnet deploy of [dmap](https://github.com/dapphub/dmap) and run various fuzzed tests against it. For example
* It tests that the `get` and `set` functions of dmap work as expected
* It further verifies the `set` function using storage inspection within our fork
* It tests that entries with locked metadata (LSB of meta set to `0x1`) revert on 2nd write and data is not changed

There are more tests to be written. 

## How to use this repo
This repo uses [Foundry](https://github.com/foundry-rs/foundry). Look in that repo for install instructions.

To run them, go to the root of the repo and do:
```
$> forge install
```

Then do
```
$> forge test -f <YOUR RPC URL> test
```

optionally pass `-vvvv` to see fork and call details.

If you don't have an ethereum node running for the rpc url and really don't want to run one, you can look at the Ethereum Foundation's [Node as a service](https://ethereum.org/en/developers/docs/nodes-and-clients/nodes-as-a-service/) article.

## Example Output
Here's the example output with high verbosity. In this example we run each fuzzed test 10,000 times with different inputs. By default 256 runs are used as 10,000 takes some time. I do not recommend running it 10,000 times by default.

For reference, running 256 iterations for all tests only takes about 10 seconds. 10,000 times takes 7+ minutes depending on your machine.

```sh
$> FOUNDRY_FUZZ_RUNS=10000 forge test -f $ETH_RPC_URL -vvvv
[⠑] Compiling...
[⠰] Compiling 1 files with 0.8.14
[⠒] Solc 0.8.14 finished in 1.72s
Compiler run successful

Running 5 tests for src/test/Dmap.t.sol:ContractTest
[PASS] testBasicSetAndGet() (gas: 57097)
Traces:
  [57097] ContractTest::testBasicSetAndGet() 
    ├─ [46266] 0x9094…dd96::00000000(6e616d65000000000000000000000000000000000000000000000000000000006d657461000000000000000000000000000000000000000000000000000000006461746131000000000000000000000000000000000000000000000000000000) 
    │   ├─  emit topic 0: 0x000000000000000000000000b4c79dab8f259c7aee6e5b2aa729821864227e84
    │   │       topic 1: 0x6e616d6500000000000000000000000000000000000000000000000000000000
    │   │       topic 2: 0x6d65746100000000000000000000000000000000000000000000000000000000
    │   │       topic 3: 0x6461746131000000000000000000000000000000000000000000000000000000
    │   │           data: 0x
    │   └─ ← ()
    ├─ [275] 0x9094…dd96::00000000(e5ea0e2e475545ad8f17dc5c8715fbe19059cd94087d116068caa6cbaf092175) 
    │   └─ ← 0x6d657461000000000000000000000000000000000000000000000000000000006461746131000000000000000000000000000000000000000000000000000000
    ├─ [2275] 0x9094…dd96::00000000(e5ea0e2e475545ad8f17dc5c8715fbe19059cd94087d116068caa6cbaf092176) 
    │   └─ ← 0x64617461310000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
    └─ ← ()

[PASS] testBasicSetAndGetFuzzed(bytes32,bytes32,bytes32) (runs: 10000, μ: 57128, ~: 57128)
[PASS] testLockedSlot(bytes32,bytes32,bytes32) (runs: 10000, μ: 62143, ~: 62143)
[PASS] testSetAndGetStorageInspection() (gas: 56207)
Traces:
  [56207] ContractTest::testSetAndGetStorageInspection() 
    ├─ [46266] 0x9094…dd96::00000000(6e616d65000000000000000000000000000000000000000000000000000000006d657461000000000000000000000000000000000000000000000000000000006461746131000000000000000000000000000000000000000000000000000000) 
    │   ├─  emit topic 0: 0x000000000000000000000000b4c79dab8f259c7aee6e5b2aa729821864227e84
    │   │       topic 1: 0x6e616d6500000000000000000000000000000000000000000000000000000000
    │   │       topic 2: 0x6d65746100000000000000000000000000000000000000000000000000000000
    │   │       topic 3: 0x6461746131000000000000000000000000000000000000000000000000000000
    │   │           data: 0x
    │   └─ ← ()
    ├─ [0] VM::load(0x90949c9937a11ba943c7a72c3fa073a37e3fdd96, 0xe5ea0e2e475545ad8f17dc5c8715fbe19059cd94087d116068caa6cbaf092175) 
    │   └─ ← 0x6d65746100000000000000000000000000000000000000000000000000000000
    ├─ [0] VM::load(0x90949c9937a11ba943c7a72c3fa073a37e3fdd96, 0xe5ea0e2e475545ad8f17dc5c8715fbe19059cd94087d116068caa6cbaf092176) 
    │   └─ ← 0x6461746131000000000000000000000000000000000000000000000000000000
    └─ ← ()

[PASS] testSetAndGetStorageInspectionFuzzed(bytes32,bytes32,bytes32) (runs: 10000, μ: 56368, ~: 56368)
Test result: ok. 5 passed; 0 failed; finished in 487.97s
```