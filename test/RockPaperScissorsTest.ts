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

    const options = {value: ethers.utils.parseEther("200")}

    const player0Choice = Choice.Rock;
    const player0Payload = soliditySha256(["address", "uint", "bytes32"], [player0.address, player0Choice, blindingConstant]);
    const commit0 = await hardhatToken.connect(player0).commit(player0Payload, options);
    

    const player1Choice = Choice.Paper;
    const player1Payload = soliditySha256(["address", "uint", "bytes32"], [player1.address, player1Choice, blindingConstant]);
    const commit1 = await hardhatToken.connect(player1).commit(player1Payload,  options);

    const reveal0 = await hardhatToken.connect(player0).reveal(player0Choice, blindingConstant);

    const reveal1 = await hardhatToken.connect(player1).reveal(player1Choice, blindingConstant);

    // поскольку игрок 0 проиграл
    // Заложим стоимость газа
    const gasEpsilon = ethers.utils.parseEther("1")

    expect((await player0.getBalance()).add(lossAmount).add(gasEpsilon) > startBalancePlayer0);
    expect((await player0.getBalance()).sub(winningAmount).add(gasEpsilon) > startBalancePlayer1);
    expect(await player0.getBalance() < await player1.getBalance());
  });
});