// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract ZPGContract {

    struct CharacterAttributes {
        string name;
        uint256 hp;
        uint256 maxHp;
        uint256 attackDamage;
        uint256 characterBalance;
        uint256 lastBattle;
    }

    mapping(address => CharacterAttributes) public personHeroes;

    constructor() {

    }

    function createHero(uint seed, string name) public payable {
        require(personHeroes[address].isValue == false, 'Hero already created');

        uint256 balance = msg.value;

        uint256 currentPoints = balance / 10000;

        uint256 hp = random(currentPoints, seed);
        uint256 attack = random(currentPoints - hp, seed);
        
        personHeroes[address] = new CharacterAttributes(
          name,
          hp, 
          hp,
          attack,
          balance,
          block.timestamp);
    }

    function attack(address opponentAddress, uint seed) public {
        require(personHeroes[address].isValue == true, 'Hero is not created');
        require(personHeroes[opponentAddress].isValue == true, 'Opponent hero not found');
      
        CharacterAttributes hero = personHeroes[address];
        uint256 initHp = hero.hp + (hero.lastBattle - block.timestamp) / 60000;
        require(initHp > 0, 'HP is 0, cannot attack');

        CharacterAttributes opponent = personHeroes[opponentAddress];
        uint256 initOpponnentHp = opponent.hp + (opponent.lastBattle - block.timestamp) / 60000;
        require(initOpponnentHp > 0, 'Opponent HP is 0, cannot attack');

        while (initHp > 0 && initOpponnentHp > 0){
          uint256 turnAttack = (1 + (random(20, seed) - 10) / 100) * hero.attack;
          initOpponnentHp = max(0, initOpponnentHp - turnAttack);

          uint256 opponentTurnAttack = (1 + (random(20, seed) - 10) / 100) * opponent.attack;
          initHp = max(0, initHp - opponentTurnAttack);
        }

        bool playerWon = hero.hp > 0;

        if(playerWon == true) {
            uint256 wonAmount = (opponent.balance / 2);

            personHeroes[address] = new CharacterAttributes(
              hero.Name,
              initHp / 2,
              hero.maxHp,
              hero.attackDamage,
              hero.balance + wonAmount,
              block.timestamp);

            personHeroes[opponentAddress] = new CharacterAttributes(
              opponent.Name,
              initOpponentHp / 2,
              opponent.maxHp,
              opponent.attackDamage,
              opponent.balance - wonAmount,
              block.timestamp);
        } else if (player1Payout > 0) {
            uint256 wonAmount = (opponent.balance / 2);


            personHeroes[opponentAddress] = new CharacterAttributes(
              opponent.Name,
              initOpponentHp / 2,
              opponent.maxHp,
              opponent.attackDamage,
              opponent.balance + wonAmount,
              block.timestamp);

            personHeroes[address] = new CharacterAttributes(
              hero.Name,
              initHp / 2,
              hero.maxHp,
              hero.attackDamage,
              hero.balance - wonAmount,
              block.timestamp);
        }
    }


    function buff(uint seed) public payable {
        CharacterAttributes hero = personHeroes[address];
        require(hero.isValue == true, 'Hero needs to be created first');

        uint256 buffValue = msg.value;

        uint256 currentPoints = balance / 100000;

        uint256 hpBuff = random(currentPoints, seed);
        uint256 attackBuff = random(currentPoints, seed);
        
        personHeroes[address] = new CharacterAttributes(
          hero.name,
          hero.hp + hpBuff, 
          hero.maxHp + hpBuff,
          hero.attack + attackBuff,
          balance,
          hero.lastBattle);
    }

    function extract(uint256 extractedAmount) {
        // извлечение средств из аккаунта
        CharacterAttributes hero = personHeroes[address];

        require(extractedAmount < hero.characterBalance, "Cannot extract more than on balance");

        // Send the payouts
        (bool success, ) = playerTurns[0].playerAddress.call{value: extractedAmount}("");
        require(success, 'Payout failed');

        personHeroes[address] = new CharacterAttributes(
          hero.Name,
          hero.hp,
          hero.maxHp,
          hero.attackDamage,
          hero.balance -= extract,
          hero.lastBattle);
    }

    function max(uint256 a, uint256 b) private pure returns (uint256) {
        return a >= b ? a : b;
    }
}