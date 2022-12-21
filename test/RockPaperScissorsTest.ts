const { expect } = require("chai");
const { ethers } = require("hardhat");

import { keccak256, solidityKeccak256, formatBytes32String, soliditySha256 } from 'ethers/lib/utils';

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

describe("RockPaperScissorsContract tests", function () {
  it("Happy flow", async function () {
    const provider = ethers.getDefaultProvider();
    const [owner, player0, player1] = await ethers.getSigners();

    const startBalancePlayer0 = await player0.getBalance();
    const startBalancePlayer1 = await player1.getBalance();
    const winningAmount = ethers.utils.parseEther("300");
    const lossAmount =  ethers.utils.parseEther("100");

    const Token = await ethers.getContractFactory("RockPaperScissorsContract");

    const hardhatToken = await Token.deploy(ethers.utils.parseEther("100"), ethers.utils.parseEther("100"), 1000);
    await hardhatToken.deployed();

    expect(await hardhatToken.stage()).to.be.equal(GameStage.FirstTurn);

    const options = {value: ethers.utils.parseEther("200")}

    const player0Choice = Choice.Rock;
    const player0Payload = soliditySha256(["address", "uint", "bytes32"], [player0.address, player0Choice, blindingConstant]);
    const commit0 = await hardhatToken.connect(player0).commit(player0Payload, options);

    expect(await hardhatToken.stage()).to.be.equal(GameStage.SecondTurn);

    const player1Choice = Choice.Paper;
    const player1Payload = soliditySha256(["address", "uint", "bytes32"], [player1.address, player1Choice, blindingConstant]);
    const commit1 = await hardhatToken.connect(player1).commit(player1Payload,  options);

    expect(await hardhatToken.stage()).to.be.equal(GameStage.FirstReveal);

    const reveal0 = await hardhatToken.connect(player0).reveal(player0Choice, blindingConstant);

    expect(await hardhatToken.stage()).to.be.equal(GameStage.SecondReveal);

    const reveal1 = await hardhatToken.connect(player1).reveal(player1Choice, blindingConstant);

    expect(await hardhatToken.stage()).to.be.equal(GameStage.Payout);

    // поскольку игрок 0 проиграл
    // Заложим стоимость газа
    const gasEpsilon = ethers.utils.parseEther("1")

    expect((await player0.getBalance()).add(lossAmount).add(gasEpsilon) > startBalancePlayer0);
    expect((await player0.getBalance()).sub(winningAmount).add(gasEpsilon) > startBalancePlayer1);
    expect(await player0.getBalance() < await player1.getBalance());
  });

  it("Third commit (negative)", async function () {
    const provider = ethers.getDefaultProvider();
    const [owner, player0, player1, player2] = await ethers.getSigners();

    const startBalancePlayer0 = await player0.getBalance();
    const startBalancePlayer1 = await player1.getBalance();
    const winningAmount = ethers.utils.parseEther("300");
    const lossAmount =  ethers.utils.parseEther("100");


    const Token = await ethers.getContractFactory("RockPaperScissorsContract");

    const hardhatToken = await Token.deploy(ethers.utils.parseEther("100"), ethers.utils.parseEther("100"), 1000);
    await hardhatToken.deployed();

    const options = {value: ethers.utils.parseEther("200")}

    const player0Choice = Choice.Paper;
    const player0Payload = soliditySha256(["address", "uint", "bytes32"], [player0.address, player0Choice, blindingConstant]);
    const commit0 = await hardhatToken.connect(player0).commit(player0Payload, options);

    const player1Choice = Choice.Scissors;
    const player1Payload = soliditySha256(["address", "uint", "bytes32"], [player1.address, player1Choice, blindingConstant]);
    const commit1 = await hardhatToken.connect(player1).commit(player1Payload,  options);

    const player2Choice = Choice.Paper;
    const player2Payload = soliditySha256(["address", "uint", "bytes32"], [player2.address, player2Choice, blindingConstant]);
    
    // ход третьего должен заблокироваться
    await expect(
      hardhatToken.connect(player2).commit(player2Payload,  options)
    ).to.be.revertedWith("Both players have made their turns");

    // проверим штатное завершение - заодно и новые пары ходов
    expect(await hardhatToken.stage()).to.be.equal(GameStage.FirstReveal);

    const reveal0 = await hardhatToken.connect(player0).reveal(player0Choice, blindingConstant);

    expect(await hardhatToken.stage()).to.be.equal(GameStage.SecondReveal);

    const reveal1 = await hardhatToken.connect(player1).reveal(player1Choice, blindingConstant);

    expect(await hardhatToken.stage()).to.be.equal(GameStage.Payout);

    // поскольку игрок 0 проиграл
    // Заложим стоимость газа
    const gasEpsilon = ethers.utils.parseEther("1")

    expect((await player0.getBalance()).add(lossAmount).add(gasEpsilon) > startBalancePlayer0);
    expect((await player0.getBalance()).sub(winningAmount).add(gasEpsilon) > startBalancePlayer1);
    expect(await player0.getBalance() < await player1.getBalance());
  });

  it("Doubled commit (negative)", async function () {
    const provider = ethers.getDefaultProvider();
    const [owner, player0, player1, player2] = await ethers.getSigners();

    const startBalancePlayer0 = await player0.getBalance();
    const startBalancePlayer1 = await player1.getBalance();
    const winningAmount = ethers.utils.parseEther("300");
    const lossAmount =  ethers.utils.parseEther("100");

    const Token = await ethers.getContractFactory("RockPaperScissorsContract");

    const hardhatToken = await Token.deploy(ethers.utils.parseEther("100"), ethers.utils.parseEther("100"), 1000);
    await hardhatToken.deployed();

    const options = {value: ethers.utils.parseEther("200")}

    const player0Choice = Choice.Scissors;
    const player0Payload = soliditySha256(["address", "uint", "bytes32"], [player0.address, player0Choice, blindingConstant]);
    const commit0 = await hardhatToken.connect(player0).commit(player0Payload, options);

    const player1Choice = Choice.Rock;
    const player1Payload = soliditySha256(["address", "uint", "bytes32"], [player1.address, player1Choice, blindingConstant]);
    const commit1 = await hardhatToken.connect(player1).commit(player1Payload,  options);
    
    // повторный ход первого должен заблокироваться
    const player0SecondChoice = Choice.Paper;
    const player0SecondPayload = soliditySha256(["address", "uint", "bytes32"], [player0.address, player0SecondChoice, blindingConstant]);
    await expect(
      hardhatToken.connect(player0).commit(player0SecondPayload,  options)
    ).to.be.revertedWith("Both players have made their turns");

    // проверим штатное завершение - заодно и новые пары ходов
    expect(await hardhatToken.stage()).to.be.equal(GameStage.FirstReveal);

    const reveal0 = await hardhatToken.connect(player0).reveal(player0Choice, blindingConstant);

    expect(await hardhatToken.stage()).to.be.equal(GameStage.SecondReveal);

    const reveal1 = await hardhatToken.connect(player1).reveal(player1Choice, blindingConstant);

    expect(await hardhatToken.stage()).to.be.equal(GameStage.Payout);

    // поскольку игрок 0 проиграл
    // Заложим стоимость газа
    const gasEpsilon = ethers.utils.parseEther("1")

    expect((await player0.getBalance()).add(lossAmount).add(gasEpsilon) > startBalancePlayer0);
    expect((await player0.getBalance()).sub(winningAmount).add(gasEpsilon) > startBalancePlayer1);
    expect(await player0.getBalance() < await player1.getBalance());
  });

  it("Not enough tokens (negative)", async function () {
    const provider = ethers.getDefaultProvider();
    const [owner, player0] = await ethers.getSigners();

    const Token = await ethers.getContractFactory("RockPaperScissorsContract");

    const hardhatToken = await Token.deploy(ethers.utils.parseEther("100"), ethers.utils.parseEther("100"), 1000);
    await hardhatToken.deployed();

    const options = {value: ethers.utils.parseEther("10")}

    const player0Choice = Choice.Rock;
    const player0Payload = soliditySha256(["address", "uint", "bytes32"], [player0.address, player0Choice, blindingConstant]);
    
    // ход первого должен откатиться должен заблокироваться
    await expect(
      hardhatToken.connect(player0).commit(player0Payload,  options)
    ).to.be.revertedWith("Value must be greater than commit amount");
  });

  it("Early reveal: zero commits (negative)", async function () {
    const provider = ethers.getDefaultProvider();
    const [owner, player0] = await ethers.getSigners();

    const Token = await ethers.getContractFactory("RockPaperScissorsContract");

    const hardhatToken = await Token.deploy(ethers.utils.parseEther("100"), ethers.utils.parseEther("100"), 1000);
    await hardhatToken.deployed();

    const options = {value: ethers.utils.parseEther("500")}

    const player0Choice = Choice.Rock;
    
    // reveal раньше времени должен заблокироваться
    await expect(
      hardhatToken.connect(player0).reveal(player0Choice, blindingConstant)
    ).to.be.revertedWith("Not at reveal stage");
  });

  it("Early reveal: only one commit (negative)", async function () {
    const provider = ethers.getDefaultProvider();
    const [owner, player0] = await ethers.getSigners();

    const Token = await ethers.getContractFactory("RockPaperScissorsContract");

    const hardhatToken = await Token.deploy(ethers.utils.parseEther("100"), ethers.utils.parseEther("100"), 1000);
    await hardhatToken.deployed();

    const options = {value: ethers.utils.parseEther("500")}

    const player0Choice = Choice.Rock;
    const player0Payload = soliditySha256(["address", "uint", "bytes32"], [player0.address, player0Choice, blindingConstant]);
    const commit0 = await hardhatToken.connect(player0).commit(player0Payload, options);
    
    // reveal раньше времени должен заблокироваться
    await expect(
      hardhatToken.connect(player0).reveal(player0Choice, blindingConstant)
    ).to.be.revertedWith("Not at reveal stage");
  });
});