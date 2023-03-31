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

    // CharacterAttributes[] personHeroes;
    mapping(address => CharacterAttributes) public personHeroes;
    

    constructor() {

    }

    function createHero(uint seed, string calldata name) public payable {
        address add = payable(msg.sender);

        bool characterExists = ifCharacterExists(add);
        require(characterExists == false, 'Hero already created');

        uint256 balance = msg.value;
        uint256 currentPoints = balance / 10000;

        uint256 hp = getRandom(currentPoints, seed) + 1;
        uint256 attackPoints = getRandom(currentPoints - hp, seed) + 1;
        
        CharacterAttributes memory newHero = CharacterAttributes({
          name: name,
          hp: hp, 
          maxHp: hp,
          attackDamage: attackPoints,
          characterBalance: balance,
          lastBattle: block.timestamp});

        personHeroes[add] = newHero;
    }

    function attack(address opponentAddress, uint seed) public {
        address add = payable(msg.sender);

        CharacterAttributes memory hero = getCharacter(add);
        CharacterAttributes memory opponent = getCharacter(opponentAddress);
      
        uint256 initHp = hero.hp + (block.timestamp - hero.lastBattle) / 60000;
        require(initHp > 0, 'HP is 0, cannot attack');

        uint256 initOpponentHp = opponent.hp + (block.timestamp - opponent.lastBattle) / 60000;
        require(initOpponentHp > 0, 'Opponent HP is 0, cannot attack');

        while (initHp > 0 && initOpponentHp > 0){
          uint256 turnAttack = (1 + (getRandom(20, seed) - 10) / 100) * hero.attackDamage;
          initOpponentHp = max(0, initOpponentHp - turnAttack);

          uint256 opponentTurnAttack = (1 + (getRandom(20, seed) - 10) / 100) * opponent.attackDamage;
          initHp = max(0, initHp - opponentTurnAttack);
        }

        bool playerWon = hero.hp > 0;

        if(playerWon == true) {
            uint256 wonAmount = (opponent.characterBalance / 2);

            personHeroes[add] = CharacterAttributes(
              hero.name,
              initHp / 2,
              hero.maxHp,
              hero.attackDamage,
              hero.characterBalance + wonAmount,
              block.timestamp);

            personHeroes[opponentAddress] = CharacterAttributes(
              opponent.name,
              initOpponentHp / 2,
              opponent.maxHp,
              opponent.attackDamage,
              opponent.characterBalance - wonAmount,
              block.timestamp);
        } else {
            uint256 wonAmount = (hero.characterBalance / 2);

            personHeroes[opponentAddress] = CharacterAttributes(
              opponent.name,
              initOpponentHp / 2,
              opponent.maxHp,
              opponent.attackDamage,
              opponent.characterBalance + wonAmount,
              block.timestamp);

            personHeroes[add] = CharacterAttributes(
              hero.name,
              initHp / 2,
              hero.maxHp,
              hero.attackDamage,
              hero.characterBalance - wonAmount,
              block.timestamp);
        }
    }


    function buff(uint seed) public payable {
        address add = payable(msg.sender);

        CharacterAttributes memory hero = getCharacter(add);

        uint256 currentPoints = msg.value / 100000;

        uint256 hpBuff = getRandom(currentPoints, seed);
        uint256 attackBuff = getRandom(currentPoints, seed);
        
        personHeroes[add] = CharacterAttributes(
          hero.name,
          hero.hp + hpBuff, 
          hero.maxHp + hpBuff,
          hero.attackDamage + attackBuff,
          hero.characterBalance,
          hero.lastBattle);
    }

    function extract(uint256 extractedAmount) public {
        // извлечение средств из аккаунта
        address add = payable(msg.sender);
        CharacterAttributes memory hero = getCharacter(add);

        require(extractedAmount < hero.characterBalance, "Cannot extract more than on balance");

        // Send the payouts
        (bool success, ) = add.call{value: extractedAmount}("");
        require(success, 'Payout failed');

        personHeroes[add] = CharacterAttributes(
          hero.name,
          hero.hp,
          hero.maxHp,
          hero.attackDamage,
          hero.characterBalance - extractedAmount,
          hero.lastBattle);
    }

    function max(uint256 a, uint256 b) private pure returns (uint256) {
        return a >= b ? a : b;
    }
    
    function getRandom(uint256 limit, uint256 seed) private view returns(uint256){
        return uint(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender, seed))) % limit;
    }

    function getCharacter(address add) private view returns(CharacterAttributes memory){
        CharacterAttributes memory hero = personHeroes[add];
        require(hero.maxHp == 0, 'Hero not found');
        return hero;
    }

    function ifCharacterExists(address add) private view returns(bool){
        CharacterAttributes memory hero = personHeroes[add];
        return hero.maxHp != 0;
    }
}