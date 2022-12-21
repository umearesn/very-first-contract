const { expect } = require("chai");
const { ethers } = require("hardhat");

import { soliditySha256 } from 'ethers/lib/utils';
import { Contract, Signer } from 'ethers';

const blindingConstant = "0x3132333435000000000000000000000000000000000000000000000000000000";

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

let owner : Signer;
let smartPlayer : Signer;
let dummyPlayer : Signer;
let gameContract : Contract;
let dummyPlayerContract : Contract;

beforeEach(async () => {
    [owner, smartPlayer, dummyPlayer] = await ethers.getSigners();

    const gameContactFactory = await ethers.getContractFactory("RockPaperScissorsContract");
    gameContract = await gameContactFactory.deploy(ethers.utils.parseEther("100"), ethers.utils.parseEther("100"), 1000);
    await gameContract.deployed();
   
    const dummyPlayerContractFactory = await ethers.getContractFactory("DummyRockPaperScissorsPlayer");
    dummyPlayerContract = await dummyPlayerContractFactory.deploy(Choice.Rock);
    await dummyPlayerContract.deployed();
  
});

describe("Intercontract tests", function () {
  it("Happy flow", async function () {
    const options = {value: ethers.utils.parseEther("200")}

    // На начало игры балансы равны
    expect(await smartPlayer.getBalance()).to.be.equal(await dummyPlayer.getBalance());

    expect(await gameContract.stage()).to.be.equal(GameStage.FirstTurn);

    await dummyPlayerContract.connect(dummyPlayer).makeDummyTurn(gameContract.address, options);

    expect(await gameContract.stage()).to.be.equal(GameStage.SecondTurn);

    const smartPlayerChoice = Choice.Paper;
    const smartPlayerPayload = soliditySha256(["address", "uint", "bytes32"], [await smartPlayer.getAddress(), smartPlayerChoice, blindingConstant]);
    const smartPlayerCommit = await (gameContract.connect(smartPlayer)).commit(smartPlayerPayload, options);

    expect(await gameContract.stage()).to.be.equal(GameStage.FirstReveal);

    await dummyPlayerContract.makeDummyReveal(gameContract.address);

    expect(await gameContract.stage()).to.be.equal(GameStage.SecondReveal);

    const smartPlayerReveal = await gameContract.connect(smartPlayer).reveal(smartPlayerChoice, blindingConstant);

    expect(await gameContract.stage()).to.be.equal(GameStage.Payout);

    // DummyPlayer должен проиграть
    expect(await smartPlayer.getBalance() > await dummyPlayer.getBalance());
  });

  it("Dummy commits twice (negative)", async function () {
    const options = {value: ethers.utils.parseEther("200")}

    await dummyPlayerContract.connect(dummyPlayer).makeDummyTurn(gameContract.address, options);

    expect(await gameContract.stage()).to.be.equal(GameStage.SecondTurn);

    const smartPlayerChoice = Choice.Paper;
    const smartPlayerPayload = soliditySha256(["address", "uint", "bytes32"], [await smartPlayer.getAddress(), smartPlayerChoice, blindingConstant]);
    const smartPlayerCommit = await (gameContract.connect(smartPlayer)).commit(smartPlayerPayload, options);

    expect(await gameContract.stage()).to.be.equal(GameStage.FirstReveal);

    await expect(
      dummyPlayerContract.connect(dummyPlayer).makeDummyTurn(gameContract.address, options)
    ).to.be.revertedWith("Dummy commit call failed");
  });
});
