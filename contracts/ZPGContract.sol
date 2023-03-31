// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract ZPGContract {

    struct CharacterAttributes {
        address ownerAddress;
        uint256 hp;
        uint256 attackPoints;
        uint256 balance;
    }


    enum GameStage {
        CreatedZero,
        CreatedOne,
        CreatedTwo
    }

    // Initialisation args
    uint public revealSpan;
    uint public nextFight;
    uint256 public buffLimit;
    uint256 public participationFee;
    GameStage public stage = GameStage.CreatedZero;

    CharacterAttributes[2] personHeroesList;
    mapping(address => uint256) public personHeroes;

    constructor(uint _revealSpan, uint256 _buffLimit) {
        nextFight = block.number + _revealSpan;
        buffLimit = _buffLimit;
        participationFee = 100;
    }

    function createHero(uint256 seed) public payable {
        
        require(stage == GameStage.CreatedZero || stage == GameStage.CreatedOne, "Both heroes created");
        require(msg.value > participationFee, "Bet is too small");

        // Зафиксировали индекс
        uint heroIndex = 
            stage == GameStage.CreatedZero ? 0 : 1;

        if(heroIndex == 1) {
            require(personHeroesList[0].ownerAddress != msg.sender, "You already created player!");
        }
        
        uint256 currentPoints = msg.value - participationFee;

        uint256 hp = getRandom(currentPoints, seed) + 1;
        uint256 attackPoints = getRandom(currentPoints - hp, seed) + 1;
        
        personHeroesList[heroIndex] = CharacterAttributes(msg.sender, hp, attackPoints, currentPoints);

        // Чтобы драка не была доступна сразу после регистрации - сделаем так
        if(block.number < nextFight){
            nextFight = block.number + revealSpan;
        }
       
        stage = 
            stage == GameStage.CreatedZero ? GameStage.CreatedOne : GameStage.CreatedTwo;
    }

    // Атака одного пользователя другим
    function attack(uint seed) public {
        require(stage == GameStage.CreatedTwo && nextFight <= block.number, "Too early to attack!");
        require(personHeroesList[0].ownerAddress == msg.sender || personHeroesList[1].ownerAddress == msg.sender , "You do not take part!");

        CharacterAttributes storage hero = 
            personHeroesList[0].ownerAddress == msg.sender ? personHeroesList[0] : personHeroesList[1];
        CharacterAttributes storage opponent = 
            personHeroesList[0].ownerAddress == msg.sender ? personHeroesList[1] : personHeroesList[0];

        uint256 initHp = hero.hp;
        uint256 initOpponentHp = opponent.hp;

        // имитируем битву
        while (initHp > 0 && initOpponentHp > 0){
          uint256 turnAttack = getRandom(buffLimit, seed) + hero.attackPoints;
          initOpponentHp = max(0, initOpponentHp - turnAttack);

          uint256 opponentTurnAttack = getRandom(buffLimit, seed) + opponent.attackPoints;
          initHp = max(0, initHp - opponentTurnAttack);
        }

        uint256 prize = hero.balance + opponent.balance;

        // проигравший выбывает
        bool playerWon = hero.hp > 0;

        delete personHeroesList;
        stage = GameStage.CreatedOne;
        nextFight = block.number + revealSpan;
        
        if(playerWon) {
            personHeroesList[0] = CharacterAttributes(hero.ownerAddress, hero.hp + getRandom(buffLimit, seed), hero.attackPoints + getRandom(buffLimit, seed), prize);
        } else {
            personHeroesList[0] = CharacterAttributes(opponent.ownerAddress, opponent.hp + getRandom(buffLimit, seed), opponent.attackPoints + getRandom(buffLimit, seed), prize);
        }
    }

    function buff(uint seed) public payable {
        require(nextFight > block.number, "Only figth is possible, too late to buff!");
        require(personHeroesList[0].ownerAddress == msg.sender || personHeroesList[1].ownerAddress == msg.sender , "You do not take part!");

        uint256 heroIndex = 
            personHeroesList[0].ownerAddress == msg.sender ? 0 : 1;

        CharacterAttributes storage hero = personHeroesList[heroIndex];

        uint256 addedPoints = msg.value;

        uint256 hpBuff = getRandom(addedPoints, seed);
        uint256 attackBuff = getRandom(addedPoints - hpBuff, seed);
        
        personHeroesList[heroIndex] = CharacterAttributes(msg.sender, hero.hp + hpBuff, hero.attackPoints + attackBuff, hero.balance + addedPoints);
    }

    // выход из игры
    function quitGame() public {
        require(stage == GameStage.CreatedOne, "Quit allowed only when opponent is not found!");
        require(personHeroesList[0].ownerAddress == msg.sender || personHeroesList[1].ownerAddress == msg.sender , "You do not take part!");

        uint256 heroIndex = 
            personHeroesList[0].ownerAddress == msg.sender ? 0 : 1;

        CharacterAttributes storage hero = personHeroesList[heroIndex];

        // Send the payouts
        (bool success, ) = msg.sender.call{value: hero.balance}("");
        require(success, "Payout failed");

        delete personHeroesList;
        stage = GameStage.CreatedZero;
        nextFight = block.number + revealSpan;
    }

    function max(uint256 a, uint256 b) private pure returns (uint256) {
        return a >= b ? a : b;
    }
    
    function getRandom(uint256 limit, uint256 seed) public view returns(uint256){
        return uint(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender, seed))) % limit;
    }
}