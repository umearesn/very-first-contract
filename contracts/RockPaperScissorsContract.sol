// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract RockPaperScissorsContract {

    // Initialisation args
    uint public bet;
    uint public deposit;
    uint public revealSpan;

    // State vars
    PlayerTurn[2] public players;
    uint public revealDeadline;
    //uint private turnsStored = 0;
    GameStage public stage = GameStage.FirstTurn;

    constructor(uint _bet, uint _deposit, uint _revealSpan) public {
        bet = _bet;
        deposit = _deposit;
        revealSpan = _revealSpan;
    }

    enum Choice {
        None,
        Rock,
        Paper,
        Scissors
    }

    enum GameStage {
        FirstTurn,
        SecondTurn,
        FirstReveal,
        SecondReveal,
        Payout
    }

    struct PlayerTurn {
        address playerAddress;
        bytes32 commitment;
        Choice choice;
    }

    PlayerTurn[2] public playerTurns;

    event CommitTurn(address player);
    event RevealTurn(address player, Choice choice);
    event PayoutTurn(address player, uint amount);

    function commit(bytes32 commitment) public payable {
        // Only run during commit stages
        
        require(stage == GameStage.FirstTurn || stage == GameStage.SecondTurn, "Both players have made their turns");
        
        // Зафиксировали индекс
        uint playerIndex = 
            stage == GameStage.FirstTurn ? 0 : 1;

        uint commitAmount = bet + deposit;
        require(commitAmount >= bet, "overflow error");
        require(msg.value >= commitAmount, "value must be greater than commit amount");

        // Return additional funds transferred
        if(msg.value > commitAmount) {
            (bool success, ) = msg.sender.call{value: msg.value - commitAmount}("");
            require(success, "call failed");
        }

        // Store the commitment
        players[playerIndex] = PlayerTurn(msg.sender, commitment, Choice.None);

        stage = stage == GameStage.FirstTurn ? GameStage.SecondTurn : GameStage.FirstReveal;
    }


    function reveal(Choice choice, bytes32 blindingFactor) public {
        // Only run during reveal stages
        require(stage == GameStage.FirstReveal || stage == GameStage.SecondReveal, "Not at reveal stage");
        // Only accept valid choices
        require(choice == Choice.Rock || choice == Choice.Paper || choice == Choice.Scissors, "Invalid choice");

        // Find the player index
        uint playerIndex;
        if(players[0].playerAddress == msg.sender) playerIndex = 0;
        else if (players[1].playerAddress == msg.sender) playerIndex = 1;
        // Revert if unknown player
        else revert("Unknown player");

        // Find player data
        PlayerTurn storage commitChoice = players[playerIndex];

        // Check the hash to ensure the commitment is correct
        require(keccak256(abi.encodePacked(msg.sender, choice, blindingFactor)) == commitChoice.commitment, "invalid hash");

        // Update choice if correct
        commitChoice.choice = choice;

        // Emit reveal event
        emit RevealTurn(msg.sender, commitChoice.choice);

        if(stage == GameStage.FirstReveal) {
            // If this is the first reveal, set the deadline for the second one
            revealDeadline = block.number + revealSpan;
            require(revealDeadline >= block.number, "overflow error");
        }
        // If we're on second reveal, move to payout stage
        stage = stage == GameStage.FirstReveal ? GameStage.SecondReveal : GameStage.Payout;
    }

    function distribute() public {
        // To distribute we need:
            // a) To be in the distribute stage OR
            // b) Still in the second reveal stage but past the deadline
        require(stage == GameStage.Payout || (stage == GameStage.SecondReveal && revealDeadline <= block.number), "Payout stage unavailable yet");

        // Calculate value of payouts for players
        uint player0Payout;
        uint player1Payout;
        uint winningAmount = deposit + 2 * bet;
        require(winningAmount / deposit == 2 * bet, "overflow error");

        // If both players picked the same choice, return their deposits and bets
        if(players[0].choice == players[1].choice) {
            player0Payout = deposit + bet;
            player1Payout = deposit + bet;
        }
        // If only one player made a choice, they win
        else if(players[0].choice == Choice.None) {
            player1Payout = winningAmount;
        }
        else if(players[1].choice == Choice.None) {
            player0Payout = winningAmount;
        }
        else if(players[0].choice == Choice.Rock) {
            assert(players[1].choice == Choice.Paper || players[1].choice == Choice.Scissors);
            if(players[1].choice == Choice.Paper) {
                // Rock loses to paper
                player0Payout = deposit;
                player1Payout = winningAmount;
            }
            else if(players[1].choice == Choice.Scissors) {
                // Rock beats scissors
                player0Payout = winningAmount;
                player1Payout = deposit;
            }

        }
        else if(players[0].choice == Choice.Paper) {
            assert(players[1].choice == Choice.Rock || players[1].choice == Choice.Scissors);
            if(players[1].choice == Choice.Rock) {
                // Paper beats rock
                player0Payout = winningAmount;
                player1Payout = deposit;
            }
            else if(players[1].choice == Choice.Scissors) {
                // Paper loses to scissors
                player0Payout = deposit;
                player1Payout = winningAmount;
            }
        }
        else if(players[0].choice == Choice.Scissors) {
            assert(players[1].choice == Choice.Paper || players[1].choice == Choice.Rock);
            if(players[1].choice == Choice.Rock) {
                // Scissors lose to rock
                player0Payout = deposit;
                player1Payout = winningAmount;
            }
            else if(players[1].choice == Choice.Paper) {
                // Scissors beats paper
                player0Payout = winningAmount;
                player1Payout = deposit;
            }
        }
        else revert("invalid choice");

        // Send the payouts
        if(player0Payout > 0) {
            (bool success, ) = players[0].playerAddress.call.value(player0Payout)("");
            require(success, 'call failed');
            emit Payout(players[0].playerAddress, player0Payout);
        } else if (player1Payout > 0) {
            (bool success, ) = players[1].playerAddress.call.value(player1Payout)("");
            require(success, 'call failed');
            emit Payout(players[1].playerAddress, player1Payout);
        }

        // Reset the state to play again
        delete players;
        revealDeadline = 0;
        stage = Stage.FirstCommit;
    }

    function isFirstPlayerWon() private view returns(bool) {
        
    } 

}