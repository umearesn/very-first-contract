// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract DummyRockPaperScissorsPlayer {

    enum Choice {
        None,
        Rock,
        Paper,
        Scissors
    }

    Choice shouldChoose;
    bytes32 blindingFactor = '12345';

    constructor(Choice _shouldChoose) {
        shouldChoose = _shouldChoose;
    }


    function makeDummyTurn(address gameAddress) public payable {
        bytes32 commitment = sha256(abi.encodePacked(address(this), uint(shouldChoose), blindingFactor));

        (bool success, ) = payable(gameAddress).call{value: msg.value}(
            abi.encodeWithSignature("commit(bytes32)", commitment)
        ); 

        require(success, 'Dummy commit call failed');

    }

    function makeDummyReveal(address gameAddress) public payable {

        console.logString('address on dummy reveal');
        console.logAddress(address(this));
        console.logString('');

        console.logString('target address on dummy reveal');
        console.logAddress(gameAddress);
         console.logString('');

        (bool success, ) = payable(gameAddress).call{value: msg.value}(
            abi.encodeWithSignature("reveal(uint8,bytes32)", uint(shouldChoose), blindingFactor)
        ); 

        require(success, 'dummy reveal call failed');
    }
}