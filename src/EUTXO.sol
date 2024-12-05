// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";

contract EUTXO {
    // UTXO
    mapping(bytes32 => eUTXO) public utxos;

    struct eUTXO {
        euint128 amount;
        eaddress owner;
        // transaction that created it
        bytes32[] inputIds;
        bytes32 id;
    }

    function spend(bytes32[] calldata inputIds, euint128 value, eaddress from, eaddress to) external {
        bytes32 txid = keccak256(abi.encodePacked(inputIds, value, from, to));
        bytes32 outputId = txid ^ bytes32(0);
        bytes32 changeId = txid ^ 0x0000000000000000000000000000000000000000000000000000000000000001;
        // Do a whole load of selects
        euint128 total = TFHE.asEuint128(0);
        for (uint i = 0; i < inputIds.length; i++) {
            eUTXO memory utxo = utxos[inputIds[i]];
            total = TFHE.add(total, TFHE.select(TFHE.eq(utxo.owner, from), utxo.amount, TFHE.asEuint128(0)));
            delete utxos[inputIds[i]];
        }
        // Create output
        utxos[outputId] = eUTXO(TFHE.select(TFHE.ge(total, value), value, TFHE.asEuint128(0)), to, inputIds, outputId);
        // Create change
        utxos[changeId] = eUTXO(
            TFHE.select(TFHE.ge(total, value), TFHE.sub(total, value), total),
            from,
            inputIds,
            changeId
        );
    }

    function cashoutToConfidentialERC20(bytes32[] calldata inputIds) external {
        // Verify addresses against msg.sender and mint corresponding ConfidentialERC20
        // But note this would doxx the owner of the UTXOs and reveal something about transaction history
    }
}
