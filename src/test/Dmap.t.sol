// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.14;

import "forge-std/Test.sol";

contract ContractTest is Test {

    // Address of publicly deployed dmap
    address dmap_address = address(0x90949c9937A11BA943C7A72C3FA073a37E3FdD96);
    // selector is ignored by contract
    bytes4 SEL = bytes4(0x00000000);

    /// Tests set and get with fixed values (no storage inspection)
    function testBasicSetAndGet() public {
        bytes32 name = bytes32("name");
        bytes32 meta = bytes32("meta");
        bytes32 data = bytes32("data1");
        setAndGetTestBasic(name, meta, data);
    }

    /// Test set and get with fuzzed values (no storage inspection)
    function testBasicSetAndGetFuzzed(bytes32 name, bytes32 meta, bytes32 data) public {
        setAndGetTestBasic(name, meta, data);
    }

    /// Test set and get with fixed values (storage inspection)
    function testSetAndGetStorageInspection() public {
        bytes32 name = bytes32("name");
        bytes32 meta = bytes32("meta");
        bytes32 data = bytes32("data1");
        setAndGetTestStorageInspection(name, meta, data);
    }

    /// Test that locked meta cannot be written to twice, and that data doesn't change
    function testLockedSlot(bytes32 name, bytes32 meta, bytes32 data) public {
        bool locked;
        assembly {
            locked := and(meta, 0x1)
        }
        vm.assume(locked);

        // set once
        (bool ok1, ) = dmap_address.call(abi.encodePacked(SEL,name,meta,data));
        require(ok1);

        // try to set again
        (bool ok2, ) = dmap_address.call(abi.encodePacked(SEL,name,meta,bytes32("other data")));

        // expect a revert
        require(!ok2);

        // Check that data has not changed
        bytes32 data_slot;
        address testAddress = address(this);
        assembly {
            let ptr := mload(0x40)
            mstore(0x0, testAddress)
            mstore(0x20, name)
            mstore(ptr, keccak256(0x0, 0x40))
            data_slot := add(1, mload(ptr))
        } 
        (bool ok3, bytes memory get_return) = dmap_address.call(abi.encodePacked(SEL, data_slot));
        require(ok3); // should still be able to read
        bytes32 stored_data = abi.decode(get_return, (bytes32));
        assertEq(data, stored_data);
        // TODO: Check meta value too

    }

    /// Test set and get with fuzzed values (storage inspection)
    function testSetAndGetStorageInspectionFuzzed(bytes32 name, bytes32 meta, bytes32 data) public {
        setAndGetTestStorageInspection(name, meta, data);
    }

    /// Tests the dmap object using it's 'get' and 'set' fallback impl
    function setAndGetTestBasic(bytes32 name, bytes32 meta, bytes32 data) public {
        bytes memory call_data = abi.encodePacked(SEL,name,meta,data);
        (bool ok1, ) = dmap_address.call(call_data);
        require(ok1);

        // test get meta
        bytes32 meta_slot = keccak256(abi.encode(address(this), name));
        (bool ok2, bytes memory ret2) = dmap_address.call(abi.encodePacked(SEL, meta_slot));
        require(ok2);
        bytes32 returned_meta = abi.decode(ret2, (bytes32));
        assertEq(meta, returned_meta);

        // test get data
        bytes32 data_slot;
        assembly {
            data_slot := add(1, meta_slot)
        }
        (bool ok3, bytes memory ret3) = dmap_address.call(abi.encodePacked(SEL, data_slot));
        require(ok3);
        bytes32 returned_data = abi.decode(ret3, (bytes32));
        assertEq(data, returned_data);
    }

    // Tests the dmap object using it's fallback 'set' by using storage inspection
    function setAndGetTestStorageInspection(bytes32 name, bytes32 meta, bytes32 data) public {
        bytes memory call_data = abi.encodePacked(SEL,name,meta,data);
        (bool ok1, ) = dmap_address.call(call_data);
        require(ok1);

        bytes32 meta_slot = keccak256(abi.encode(address(this), name));
        bytes32 stored_meta = vm.load(dmap_address, meta_slot);
        assertEq(meta, stored_meta);

        bytes32 data_slot;
        assembly {
            data_slot := add(1, meta_slot)
        }
        bytes32 stored_data = vm.load(dmap_address, data_slot);
        assertEq(data, stored_data);
    }
}
