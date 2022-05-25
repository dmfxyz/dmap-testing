// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.14;

import "forge-std/Test.sol";

contract DebuggerStepping is Test {
    // Address of publicly deployed dmap
    address dmap_address = address(0x90949c9937A11BA943C7A72C3FA073a37E3FdD96);
    // selector is ignored by contract
    bytes4 SEL = bytes4(0x00000000);

    function testSetBasic() public {
        bytes32 name = bytes32("1");
        bytes32 meta = bytes32("2");
        bytes32 data = bytes32("3");
        setBasic(name, meta, data);
    }

    function setBasic(bytes32 name, bytes32 meta, bytes32 data) public {
        bytes memory call_data = abi.encodePacked(SEL, name, meta, data);
        (bool ok1, ) = dmap_address.call(call_data);
        require(ok1);
    }
}
