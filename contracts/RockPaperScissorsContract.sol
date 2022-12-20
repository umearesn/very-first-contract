// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract RockPaperScissorsContract {

    // Modifiers
    modifier OnlyByPlayers(address player) {
        require(playerTurns[0].playerAddress == player || playerTurns[1].playerAddress == player);
    }

    // Initialisation args
    uint public bet;
    uint public deposit;
    uint public revealSpan;

    // State vars
    PlayerTurn[2] public playerTurns;
    uint public revealDeadline;
    GameStage public stage = GameStage.FirstTurn;

    constructor(uint _bet, uint _deposit, uint _revealSpan) {
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
        require(commitAmount >= bet, "Overflow error");
        require(msg.value >= commitAmount, "Value must be greater than commit amount");

        // Return excess funds transferred
        if(msg.value > commitAmount) {
            (bool success, ) = msg.sender.call{value: msg.value - commitAmount}("");
            require(success, "Return of excess failed");
        }

        // Store the commitment
        playerTurns[playerIndex] = PlayerTurn(msg.sender, commitment, Choice.None);

        stage = stage == GameStage.FirstTurn ? GameStage.SecondTurn : GameStage.FirstReveal;
    }


    function reveal(Choice choice, bytes32 blindingFactor) public OnlyByPlayers(msg.sender) {
        // Only run during reveal stages
        require(stage == GameStage.FirstReveal || stage == GameStage.SecondReveal, "Not at reveal stage");
        // Only accept valid choices
        require(choice == Choice.Rock || choice == Choice.Paper || choice == Choice.Scissors, "Invalid choice");

        // Find the player index
        uint playerIndex;
        if(playerTurns[0].playerAddress == msg.sender) {
            playerIndex = 0;
        }
        else if (playerTurns[1].playerAddress == msg.sender) {
            playerIndex = 1;
        }
        // Revert if unknown player
        else revert("Unknown player");

        // Find player data
        PlayerTurn storage commitChoice = playerTurns[playerIndex];

        // Check the hash to ensure the commitment is correct
        require(keccak256(abi.encodePacked(msg.sender, choice, blindingFactor)) == commitChoice.commitment, "Invalid hash");

        // Update choice if correct
        commitChoice.choice = choice;

        // Emit reveal event
        emit RevealTurn(msg.sender, commitChoice.choice);

        if(stage == GameStage.FirstReveal) {
            // If this is the first reveal, set the deadline for the second one
            revealDeadline = block.number + revealSpan;
            require(revealDeadline >= block.number, "Overflow error");
        }
        // If we're on second reveal, move to payout stage
        stage = 
            stage == GameStage.FirstReveal ? GameStage.SecondReveal : GameStage.Payout;
    }

    function distribute() public OnlyByPlayers(msg.sender) {
        // To distribute we need:
            // a) To be in the distribute stage OR
            // b) Still in the second reveal stage but past the deadline
        require(stage == GameStage.Payout || (stage == GameStage.SecondReveal && revealDeadline <= block.number), "Payout stage unavailable yet");

        // Calculate value of payouts for players
        uint player0Payout;
        uint player1Payout;
        uint winningAmount = deposit + 2 * bet;


        Choice player0Choice = playerTurns[0].choice;
        Choice player1Choice = playerTurns[0].choice;


        // If both players picked the same choice, return their deposits and bets
        if(player0Choice == player1Choice) {
            player0Payout = deposit + bet;
            player1Payout = deposit + bet;
        }

        // If only one player made a choice, they win
        else if(player0Choice == Choice.None) {
            player1Payout = winningAmount;
        }
        else if(player1Choice == Choice.None) {
            player0Payout = winningAmount;
        }

        // If Player 0 wins
        else if (doesPlayer0Win(player0Choice, player1Choice)) {
            player0Payout = winningAmount;
            player1Payout = deposit;
            
        }
        // Otherwise Player 1 wins
        else {
            player0Payout = deposit;
            player1Payout = winningAmount;
        }

        // Send the payouts
        if(player0Payout > 0) {
            (bool success, ) = playerTurns[0].playerAddress.call{value: player0Payout}("");
            require(success, 'Payout to player 0 failed');
            emit PayoutTurn(playerTurns[0].playerAddress, player0Payout);

        } else if (player1Payout > 0) {
            (bool success, ) = playerTurns[1].playerAddress.call{value: player1Payout}("");
            require(success, 'Payout to player 1 failed');
            emit PayoutTurn(playerTurns[1].playerAddress, player1Payout);
        }

        // Reset the state to play again
        delete playerTurns;
        revealDeadline = 0;
        stage = GameStage.FirstTurn;
    }

    // Does Player 0 wins in case of correct game and different choices.
    function doesPlayer0Win(
        Choice player0Choice,
        Choice player1Choice) private pure returns(bool) {
        
        // These variants assumed processed
        assert(player0Choice != Choice.None && player1Choice != Choice.None && player0Choice != player1Choice);

        // If player 0 chooses Rock
        if(player0Choice == Choice.Rock) {
            assert(player1Choice == Choice.Paper || player1Choice == Choice.Scissors);
            
            // Rock wins scissors, but loses to paper 
            return player1Choice == Choice.Scissors;
        }

        // If player 0 chooses Paper
        else if(player0Choice == Choice.Paper) {
            assert(player1Choice == Choice.Rock || player1Choice == Choice.Scissors);
            
            // Paper wins rock, but loses to scissors
            return player1Choice == Choice.Rock;
        }

        // If player 0 chooses Scissors
        else if(player0Choice == Choice.Scissors) {
            assert(player1Choice == Choice.Rock || player1Choice == Choice.Paper);
        
            // Scissors win paper, but lose to rock
            return player1Choice == Choice.Paper;
        }
        
        // Should not get here at all
        else revert("Invalid choice");
    } 
}