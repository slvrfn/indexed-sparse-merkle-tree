// SPDX-License-Identifier: GPL-3.0-only
// Copyright (c) Tim Daubenschütz.
pragma solidity ^0.8.6;

import "ds-test/test.sol";
import "./StateTree.sol";

contract StateTreeTest is DSTest {
    uint256 constant DEPTH = 8;

    function setUp() public {}

    function testBitwiseProofBitGeneration() public {
        // eval pos 0
        uint256 value = StateTree.bitmap(0, DEPTH);
        value += StateTree.bitmap(4, DEPTH);
        assertEq(value % 2, 1);

        // eval pos 1
        value = value / 2;
        assertEq(value % 2, 0);

        // eval pos 2
        value = value / 2;
        assertEq(value % 2, 0);

        // eval pos 3
        value = value / 2;
        assertEq(value % 2, 0);

        // eval pos 4
        value = value / 2;
        assertEq(value % 2, 1);

        // eval pos 5
        value = value / 2;
        assertEq(value % 2, 0);

        // eval pos 6
        value = value / 2;
        assertEq(value % 2, 0);

        // eval pos 7
        value = value / 2;
        assertEq(value % 2, 0);
    }

    function testGasCostEmpty() public {
        uint startGas = gasleft();
        bytes32 empty = StateTree.empty();
        uint endGas = gasleft();
        emit log_named_uint("empty()", startGas - endGas);
		assertEq(empty, 0);
    }

    function testGasCostCompute() public {
		bytes32[] memory proofs = new bytes32[](0);

        uint startGas = gasleft();
		StateTree.compute(proofs, 0, 0, 0, DEPTH);
        uint endGas = gasleft();
        emit log_named_uint("compute() best case", startGas - endGas);
    }

    function testGasCostValidate() public {
		bytes32[] memory proofs = new bytes32[](0);

        uint startGas = gasleft();
		StateTree.validate(proofs, 0, 0, 0, 0, DEPTH);
        uint endGas = gasleft();
        emit log_named_uint("validate() best case", startGas - endGas);
    }

	function testGasWrite() public {
		bytes32[] memory proofs = new bytes32[](0);

		bytes32 NEXT_LEAF = 0x0000000000000000000000000000000000000000000000000000000000000001;
		bytes32 NEXT_LEAF_HASH = keccak256(abi.encode(NEXT_LEAF));

		bytes32 PREV_ROOT = StateTree.empty();
        uint startGas = gasleft();
		StateTree.write(proofs, 0, 0, NEXT_LEAF_HASH, 0, PREV_ROOT, DEPTH);
        uint endGas = gasleft();
        emit log_named_uint("write best case()", startGas - endGas);
	}

	function testComputeEmpty() public {
		bytes32[] memory proofs = new bytes32[](0);

		bytes32 expectedRoot = StateTree.empty();
		assertEq(StateTree.compute(proofs, 0, 0, 0, DEPTH), expectedRoot);
	}

	function testValidateEmpty() public {
		bytes32[] memory proofs = new bytes32[](0);

		bytes32 expectedRoot = StateTree.empty();
		assertTrue(StateTree.validate(proofs, 0, 0, 0, expectedRoot, DEPTH));
	}

	function testComputeInsertFirst() public {
		bytes32[] memory proofs = new bytes32[](0);

		bytes32 LEAF = 0x0000000000000000000000000000000000000000000000000000000000000001;
		bytes32 LEAF_HASH = keccak256(abi.encode(LEAF));

		bytes32 expectedRoot = LEAF_HASH;
     	for (uint256 i = 0; i < DEPTH; i++) {
			expectedRoot = keccak256(abi.encode(expectedRoot, 0));
		}

		assertEq(StateTree.compute(proofs, 0, 0, LEAF_HASH, DEPTH), expectedRoot);
	}

	function testWriteFirst() public {
		bytes32[] memory proofs = new bytes32[](0);

		bytes32 NEXT_LEAF = 0x0000000000000000000000000000000000000000000000000000000000000001;
		bytes32 NEXT_LEAF_HASH = keccak256(abi.encode(NEXT_LEAF));

		bytes32 PREV_ROOT = StateTree.empty();
		bytes32 NEXT_ROOT = StateTree.write(proofs, 0, 0, NEXT_LEAF_HASH, 0, PREV_ROOT, DEPTH);

		bytes32 expectedRoot = NEXT_LEAF_HASH;
     	for (uint256 i = 0; i < DEPTH; i++) {
			expectedRoot = keccak256(abi.encode(expectedRoot, 0));
		}
		assertEq(NEXT_ROOT, expectedRoot);
	}

	function testWriteTwo() public pure {
		bytes32[] memory proofs = new bytes32[](0);

		bytes32 NEXT_LEAF = 0x0000000000000000000000000000000000000000000000000000000000000001;
		bytes32 NEXT_LEAF_HASH = keccak256(abi.encode(NEXT_LEAF));

		bytes32 ROOT1 = StateTree.empty();
		bytes32 ROOT2 = StateTree.write(proofs, 0, 0, NEXT_LEAF_HASH, 0, ROOT1, DEPTH);

        uint256 bits = StateTree.bitmap(0, DEPTH);
		bytes32[] memory proofs1 = new bytes32[](1);
        proofs1[0] = NEXT_LEAF_HASH;
		StateTree.write(proofs1, bits, 1, NEXT_LEAF_HASH, 0, ROOT2, DEPTH);
	}

	function testFillUpTree8() public pure {
        fillUpTreeAtDepth(8);
	}

	function testFillUpTree16() public pure {
        fillUpTreeAtDepth(16);
	}

	function testFillUpTree4() public pure {
        fillUpTreeAtDepth(4);
	}

	function fillUpTreeAtDepth(uint256 depth) public pure {
	    bytes32 LEAF = 0x0000000000000000000000000000000000000000000000000000000000000001;
		bytes32 LEAF_HASH = keccak256(abi.encode(LEAF));

        bytes32[] memory ones = new bytes32[](depth);
        ones[0] = LEAF_HASH;

        for(uint256 i = 1; i < depth; i++) {
            ones[i] = keccak256(abi.encode(ones[i-1], ones[i-1]));
        }

 		bytes32 prevRoot = StateTree.empty();
        for(uint256 i = 0; i < (2**depth)-1; i++) {
            bytes32[] memory proofs = new bytes32[](depth);

            uint256 bits;
            uint256 pointer = i;
            for(uint8 j = 0; j < depth; j++) {
                if(pointer % 2 == 0) {
                    //proofs[j] = zeros[j];
                } else {
                	bits += StateTree.bitmap(j, depth);
                    proofs[j] = ones[j];
                }
                pointer = pointer / 2;
            }

            prevRoot = StateTree.write(proofs, bits, i, LEAF_HASH, 0, prevRoot, depth);
        }

	}

    function testFailHijackingHash() public {
		bytes32[] memory proofs = new bytes32[](0);
        uint256 bits = StateTree.bitmap(0, DEPTH);

	    bytes32 LEAF = 0x0000000000000000000000000000000000000000000000000000000000001337;
		bytes32 LEAF_HASH = keccak256(abi.encode(LEAF));

	    bytes32 newRoot = StateTree.write(proofs, bits, 0, LEAF_HASH, 0, 0, DEPTH);
        assertEq(newRoot, LEAF_HASH);
    }

	function testUpdatingFirstEntryAfterAdditionalWrite() public pure {
		bytes32[] memory proofs = new bytes32[](0);

		bytes32 NEXT_LEAF = 0x0000000000000000000000000000000000000000000000000000000000000001;
		bytes32 NEXT_LEAF_HASH = keccak256(abi.encode(NEXT_LEAF));

		bytes32 ROOT1 = StateTree.empty();
		bytes32 ROOT2 = StateTree.write(proofs, 0, 0, NEXT_LEAF_HASH, 0, ROOT1, DEPTH);

        uint256 bits = StateTree.bitmap(0, DEPTH);
		bytes32[] memory proofs1 = new bytes32[](1);
        proofs1[0] = NEXT_LEAF_HASH;
		bytes32 ROOT3 = StateTree.write(proofs1, bits, 1, NEXT_LEAF_HASH, 0, ROOT2, DEPTH);

		bytes32 UPDATE_LEAF = 0x0000000000000000000000000000000000000000000000000000000000000002;
		bytes32 UPDATE_LEAF_HASH = keccak256(abi.encode(UPDATE_LEAF));
        uint256 bits2 = StateTree.bitmap(0, DEPTH);
		bytes32[] memory proofs2 = new bytes32[](1);
        proofs2[0] = NEXT_LEAF_HASH;
		StateTree.write(proofs2, bits2, 0, UPDATE_LEAF_HASH, proofs2[0], ROOT3, DEPTH);
	}
}
