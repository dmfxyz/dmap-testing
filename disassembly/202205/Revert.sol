// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.14;

import "forge-std/Test.sol";

contract Revert is Test {
    address dmap_address = address(0x90949c9937A11BA943C7A72C3FA073a37E3FdD96);
    bytes4 SEL = bytes4(0x00000000);

    function setTwice() public {
        bytes32 name = 0x0000000000000000000000000000000000000000000000000000000000000045;
        bytes32 meta = 0x0000000000000000000000000000000000000000000000000000000000000001;
        bytes32 data = 0x000000000000000000000000000000000000000000000000000000000000002a;
        basicSet(name, meta, data);
        basicSet(name, meta, data);
    }

    function basicSet(bytes32 name, bytes32 meta, bytes32 data) public {
        bytes memory call_data = abi.encodePacked(SEL, name, meta, data);
        (bool ok1, ) = dmap_address.call(call_data);
        require(ok1);
    }
}
