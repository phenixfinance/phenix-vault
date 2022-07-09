const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("MultiSigFactory Contract + MultiSig Contract Test Cases", function () {
  /*it("Should return the new greeting once it's changed", async function () {
    const Greeter = await ethers.getContractFactory("Greeter");
    const greeter = await Greeter.deploy("Hello, world!");
    await greeter.deployed();

    expect(await greeter.greet()).to.equal("Hello, world!");

    const setGreetingTx = await greeter.setGreeting("Hola, mundo!");

    // wait until the transaction is mined
    await setGreetingTx.wait();

    expect(await greeter.greet()).to.equal("Hola, mundo!");
  });*/

  // Test Cases to create:
  /* (1) Five signers can generate a MultiSig Wallet with a Quorum of 3 via the MultiSigFactory using ETH
  *  (2) Five signers can generate a MultiSig Wallet with a Quorum of 3 via the MutliSigFactory using Tokens
  *  (3) Five signers can generate a MultiSig Wallet with a Quorum of 3 via the MultiSigFactory using ETH with NFT Discount
  *  (4) Five signers can generate a MultiSig Wallet with a Quorum of 3 via the MutliSigFactory using Tokens with NFT Discount
  *  (5) Five signers can generate a MultiSig Wallet with a Quorum of 3 via the MultiSigFactory using ETH with Admin Discount
  *  (6) Five signers can generate a MultiSig Wallet with a Quorum of 3 via the MutliSigFactory using Tokens with Admin Discount
  *  (7) Five signers cannot generate a MultiSig Walet with a Quorum of 3 via the MultiSigFactory using Tokens while disabled
  *  (8) Five signers can generate a MultiSig Wallet with a Quorum of 3 via the MultiSigFactory using ETH with with new type (1000 ETH/10000 TOKENS)
  *  (9) Five signers cannot generate a MultiSig Wallet with a Quorum of 3 via the MultiSigFactory using ETH with with new type (0 ETH/10000 TOKENS)
  *  (10) Five signers cannot generate a MultiSig Wallet with a Quorum of 3 via the MultiSigFactory using Tokens with with new type (1000 ETH/0 TOKENS)
  */

  it("Five signers can generate a MultiSig Wallet with a Quorum of 3 via the MultiSigFactory using ETH", async function() {
    const signers = await ethers.getSigners();
    console.log(signers[0].address);

    const deployer = signers[0];
    const ownerSigners = [signers[1], signers[2], signers[3], signers[4], signers[5]];
    const minNumConfirmations = 3;

    const Token = await ethers.getContractFactory("ERC20_TEST_TOKEN");
    const NFT = await ethers.getContractFactory("ERC721_TEST_NFT");
    const PhenixMultiSigFactory = await ethers.getContractFactory(
      "PhenixMultiSigFactory"
    );
    const token = await Token.connect(deployer).deploy(
      "Test Token",
      "TTOK",
      ethers.utils.parseEther("10000000000000")
    );
    const nft = await NFT.connect(deployer).deploy("NFT", "NFT");

    await token.deployed();
    await nft.deployed();

    const phenixMultiSigFactory = await PhenixMultiSigFactory.connect(deployer).deploy(
      ethers.utils.parseEther("100"),
      ethers.utils.parseEther("500"),
      token.address,
      nft.address,
      deployer.address
    );

  await phenixMultiSigFactory.deployed();

  });
});
