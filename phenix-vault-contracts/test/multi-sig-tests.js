const { expect, assert } = require("chai");
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

  it("Five signers can generate a MultiSig Wallet with a Quorum of 3 via the MultiSigFactory using ETH", async function () {
    const signers = await ethers.getSigners();

    const deployer = signers[0];
    const ownerSigners = [
      signers[1],
      signers[2],
      signers[3],
      signers[4],
      signers[5],
    ];
    const minNumConfirmations = 3;
    const walletType = 0;

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

    const phenixMultiSigFactory = await PhenixMultiSigFactory.connect(
      deployer
    ).deploy(
      ethers.utils.parseEther("100"),
      ethers.utils.parseEther("500"),
      token.address,
      nft.address,
      deployer.address
    );

    await phenixMultiSigFactory.deployed();

    // First of 5 owners to generate wallet with ETH

    // (1): Fetch Cost for Wallet Generation
    var walletGenerationETHCost = 0;

    await phenixMultiSigFactory
      .connect(ownerSigners[0])
      .multiSigTypeFees(walletType)
      .then((_feeType) => {
        walletGenerationETHCost = _feeType.feeETH;
      });

    // (2): Get user cost for Wallet generation based on initial expected amount
    await phenixMultiSigFactory
      .connect(ownerSigners[0])
      .userCost(walletGenerationETHCost, ownerSigners[0].address)
      .then((_userCost) => {
        walletGenerationETHCost = _userCost;
      });

    // (3): Generate Multi-Sig wallet with calculated user cost in ETH
    await phenixMultiSigFactory
      .connect(ownerSigners[0])
      .generateMultiSigWalletWithETH(
        "Multi-Sig Wallet",
        [
          ownerSigners[0].address,
          ownerSigners[1].address,
          ownerSigners[2].address,
          ownerSigners[3].address,
          ownerSigners[4].address,
        ],
        minNumConfirmations,
        walletType,
        { value: walletGenerationETHCost }
      );

    // (4): Fetch Contract Address of newly deployed MultiSig Wallet
    let deployedContract;
    await phenixMultiSigFactory
      .getContractsOfOwner(ownerSigners[0].address)
      .then((_contracts) => {
        deployedContract = _contracts[_contracts.length - 1];
      });

    // (5): Fetch owners of deployed contract
    await phenixMultiSigFactory
      .getOwnersOfContract(deployedContract)
      .then((_owners) => {
        for (var i = 0; i < _owners.length; i++) {
          expect(_owners[i]).to.equal(ownerSigners[i].address);
        }
      });
  });

  it("Five signers can generate a MultiSig Wallet with a Quorum of 3 via the MutliSigFactory using Tokens", async function () {
    const signers = await ethers.getSigners();

    const deployer = signers[0];
    const ownerSigners = [
      signers[1],
      signers[2],
      signers[3],
      signers[4],
      signers[5],
    ];
    const minNumConfirmations = 3;
    const walletType = 0;

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

    const phenixMultiSigFactory = await PhenixMultiSigFactory.connect(
      deployer
    ).deploy(
      ethers.utils.parseEther("100"),
      ethers.utils.parseEther("500"),
      token.address,
      nft.address,
      deployer.address
    );

    await phenixMultiSigFactory.deployed();

    await token
      .connect(deployer)
      .transfer(ownerSigners[0].address, ethers.utils.parseEther("1000"));

    await token
      .connect(ownerSigners[0])
      .increaseAllowance(
        phenixMultiSigFactory.address,
        ethers.utils.parseEther("1000")
      );

    // First of 5 owners to generate wallet with ETH

    // (1): Fetch Cost for Wallet Generation
    var walletGenerationTokenCost = 0;

    await phenixMultiSigFactory
      .connect(ownerSigners[0])
      .multiSigTypeFees(walletType)
      .then((_feeType) => {
        walletGenerationTokenCost = _feeType.feeToken;
      });

    // (2): Get user cost for Wallet generation based on initial expected amount
    await phenixMultiSigFactory
      .connect(ownerSigners[0])
      .userCost(walletGenerationTokenCost, ownerSigners[0].address)
      .then((_userCost) => {
        walletGenerationTokenCost = _userCost;
      });

    // (3): Generate Multi-Sig wallet with calculated user cost in ETH
    await phenixMultiSigFactory
      .connect(ownerSigners[0])
      .generateMultiSigWalletWithTokens(
        "Multi-Sig Wallet",
        [
          ownerSigners[0].address,
          ownerSigners[1].address,
          ownerSigners[2].address,
          ownerSigners[3].address,
          ownerSigners[4].address,
        ],
        minNumConfirmations,
        walletType
      );

    let tokenBalance;
    await token.balanceOf(ownerSigners[0].address).then((_balance) => {
      tokenBalance = _balance;
    });

    expect(tokenBalance).to.equal(ethers.utils.parseEther("500"));

    // (4): Fetch Contract Address of newly deployed MultiSig Wallet
    let deployedContract;
    await phenixMultiSigFactory
      .getContractsOfOwner(ownerSigners[0].address)
      .then((_contracts) => {
        deployedContract = _contracts[_contracts.length - 1];
      });

    // (5): Fetch owners of deployed contract
    await phenixMultiSigFactory
      .getOwnersOfContract(deployedContract)
      .then((_owners) => {
        for (var i = 0; i < _owners.length; i++) {
          expect(_owners[i]).to.equal(ownerSigners[i].address);
        }
      });
  });

  it("Five signers can generate a MultiSig Wallet with a Quorum of 3 via the MultiSigFactory using ETH with NFT Discount", async function () {
    const signers = await ethers.getSigners();

    const deployer = signers[0];
    const ownerSigners = [
      signers[1],
      signers[2],
      signers[3],
      signers[4],
      signers[5],
    ];
    const minNumConfirmations = 3;
    const walletType = 0;

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

    const phenixMultiSigFactory = await PhenixMultiSigFactory.connect(
      deployer
    ).deploy(
      ethers.utils.parseEther("100"),
      ethers.utils.parseEther("500"),
      token.address,
      nft.address,
      deployer.address
    );

    await phenixMultiSigFactory.deployed();

    await token
      .connect(deployer)
      .transfer(ownerSigners[0].address, ethers.utils.parseEther("1000"));

    await token
      .connect(ownerSigners[0])
      .increaseAllowance(
        phenixMultiSigFactory.address,
        ethers.utils.parseEther("1000")
      );

    // First of 5 owners to generate wallet with ETH

    await nft.connect(ownerSigners[0]).mint(1);

    let nftBalance;
    await nft.balanceOf(ownerSigners[0].address).then((_balance) => {
      nftBalance = _balance;
    });

    expect(nftBalance).to.equal(1);

    // (1): Fetch Cost for Wallet Generation
    var walletGenerationETHCost = 0;

    await phenixMultiSigFactory
      .connect(ownerSigners[0])
      .multiSigTypeFees(walletType)
      .then((_feeType) => {
        walletGenerationETHCost = _feeType.feeETH;
      });

    // (2): Get user cost for Wallet generation based on initial expected amount
    await phenixMultiSigFactory
      .connect(ownerSigners[0])
      .userCost(walletGenerationETHCost, ownerSigners[0].address)
      .then((_userCost) => {
        walletGenerationETHCost = _userCost;
      });

    expect(
      parseInt(ethers.utils.formatEther(walletGenerationETHCost))
    ).to.equal(100 * 0.75);

    // (3): Generate Multi-Sig wallet with calculated user cost in ETH
    await phenixMultiSigFactory
      .connect(ownerSigners[0])
      .generateMultiSigWalletWithETH(
        "Multi-Sig Wallet",
        [
          ownerSigners[0].address,
          ownerSigners[1].address,
          ownerSigners[2].address,
          ownerSigners[3].address,
          ownerSigners[4].address,
        ],
        minNumConfirmations,
        walletType,
        { value: walletGenerationETHCost }
      );

    // (4): Fetch Contract Address of newly deployed MultiSig Wallet
    let deployedContract;
    await phenixMultiSigFactory
      .getContractsOfOwner(ownerSigners[0].address)
      .then((_contracts) => {
        deployedContract = _contracts[_contracts.length - 1];
      });

    // (5): Fetch owners of deployed contract
    await phenixMultiSigFactory
      .getOwnersOfContract(deployedContract)
      .then((_owners) => {
        for (var i = 0; i < _owners.length; i++) {
          expect(_owners[i]).to.equal(ownerSigners[i].address);
        }
      });
  });

  it("Five signers can generate a MultiSig Wallet with a Quorum of 3 via the MutliSigFactory using Tokens with NFT Discount", async function () {
    const signers = await ethers.getSigners();

    const deployer = signers[0];
    const ownerSigners = [
      signers[1],
      signers[2],
      signers[3],
      signers[4],
      signers[5],
    ];
    const minNumConfirmations = 3;
    const walletType = 0;

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

    const phenixMultiSigFactory = await PhenixMultiSigFactory.connect(
      deployer
    ).deploy(
      ethers.utils.parseEther("100"),
      ethers.utils.parseEther("500"),
      token.address,
      nft.address,
      deployer.address
    );

    await phenixMultiSigFactory.deployed();

    await token
      .connect(deployer)
      .transfer(ownerSigners[0].address, ethers.utils.parseEther("1000"));

    await token
      .connect(ownerSigners[0])
      .increaseAllowance(
        phenixMultiSigFactory.address,
        ethers.utils.parseEther("1000")
      );

    // First of 5 owners to generate wallet with ETH

    await nft.connect(ownerSigners[0]).mint(1);

    let nftBalance;
    await nft.balanceOf(ownerSigners[0].address).then((_balance) => {
      nftBalance = _balance;
    });

    expect(nftBalance).to.equal(1);

    // (1): Fetch Cost for Wallet Generation
    var walletGenerationTokenCost = 0;

    await phenixMultiSigFactory
      .connect(ownerSigners[0])
      .multiSigTypeFees(walletType)
      .then((_feeType) => {
        walletGenerationTokenCost = _feeType.feeToken;
      });

    // (2): Get user cost for Wallet generation based on initial expected amount
    await phenixMultiSigFactory
      .connect(ownerSigners[0])
      .userCost(walletGenerationTokenCost, ownerSigners[0].address)
      .then((_userCost) => {
        walletGenerationTokenCost = _userCost;
      });

    expect(
      parseInt(ethers.utils.formatEther(walletGenerationTokenCost))
    ).to.equal(500 * 0.75);

    // (3): Generate Multi-Sig wallet with calculated user cost in ETH
    await phenixMultiSigFactory
      .connect(ownerSigners[0])
      .generateMultiSigWalletWithTokens(
        "Multi-Sig Wallet",
        [
          ownerSigners[0].address,
          ownerSigners[1].address,
          ownerSigners[2].address,
          ownerSigners[3].address,
          ownerSigners[4].address,
        ],
        minNumConfirmations,
        walletType
      );

    // (4): Fetch Contract Address of newly deployed MultiSig Wallet
    let deployedContract;
    await phenixMultiSigFactory
      .getContractsOfOwner(ownerSigners[0].address)
      .then((_contracts) => {
        deployedContract = _contracts[_contracts.length - 1];
      });

    // (5): Fetch owners of deployed contract
    await phenixMultiSigFactory
      .getOwnersOfContract(deployedContract)
      .then((_owners) => {
        for (var i = 0; i < _owners.length; i++) {
          expect(_owners[i]).to.equal(ownerSigners[i].address);
        }
      });
  });

  it("Five signers can generate a MultiSig Wallet with a Quorum of 3 via the MultiSigFactory using ETH with Admin Discount", async function () {
    const signers = await ethers.getSigners();

    const deployer = signers[0];
    const ownerSigners = [
      signers[1],
      signers[2],
      signers[3],
      signers[4],
      signers[5],
    ];
    const minNumConfirmations = 3;
    const walletType = 0;

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

    const phenixMultiSigFactory = await PhenixMultiSigFactory.connect(
      deployer
    ).deploy(
      ethers.utils.parseEther("100"),
      ethers.utils.parseEther("500"),
      token.address,
      nft.address,
      deployer.address
    );

    await phenixMultiSigFactory.deployed();

    await token
      .connect(deployer)
      .transfer(ownerSigners[0].address, ethers.utils.parseEther("1000"));

    await token
      .connect(ownerSigners[0])
      .increaseAllowance(
        phenixMultiSigFactory.address,
        ethers.utils.parseEther("1000")
      );

    // First of 5 owners to generate wallet with ETH

    await nft.connect(ownerSigners[0]).mint(1);

    let nftBalance;
    await nft.balanceOf(ownerSigners[0].address).then((_balance) => {
      nftBalance = _balance;
    });

    expect(nftBalance).to.equal(1);

    // set admin
    await phenixMultiSigFactory
      .connect(deployer)
      .setAdminAddress(ownerSigners[0].address, true);

    await phenixMultiSigFactory
      .factoryAdmins(ownerSigners[0].address)
      .then((_state) => {
        expect(_state).to.equal(true);
      });

    // (1): Fetch Cost for Wallet Generation
    var walletGenerationETHCost = 0;

    await phenixMultiSigFactory
      .connect(ownerSigners[0])
      .multiSigTypeFees(walletType)
      .then((_feeType) => {
        walletGenerationETHCost = _feeType.feeETH;
      });

    // (2): Get user cost for Wallet generation based on initial expected amount
    await phenixMultiSigFactory
      .connect(ownerSigners[0])
      .userCost(walletGenerationETHCost, ownerSigners[0].address)
      .then((_userCost) => {
        walletGenerationETHCost = _userCost;
      });

    expect(
      parseInt(ethers.utils.formatEther(walletGenerationETHCost))
    ).to.equal(0);

    // (3): Generate Multi-Sig wallet with calculated user cost in ETH
    await phenixMultiSigFactory
      .connect(ownerSigners[0])
      .generateMultiSigWalletWithETH(
        "Multi-Sig Wallet",
        [
          ownerSigners[0].address,
          ownerSigners[1].address,
          ownerSigners[2].address,
          ownerSigners[3].address,
          ownerSigners[4].address,
        ],
        minNumConfirmations,
        walletType,
        { value: walletGenerationETHCost }
      );

    // (4): Fetch Contract Address of newly deployed MultiSig Wallet
    let deployedContract;
    await phenixMultiSigFactory
      .getContractsOfOwner(ownerSigners[0].address)
      .then((_contracts) => {
        deployedContract = _contracts[_contracts.length - 1];
      });

    // (5): Fetch owners of deployed contract
    await phenixMultiSigFactory
      .getOwnersOfContract(deployedContract)
      .then((_owners) => {
        for (var i = 0; i < _owners.length; i++) {
          expect(_owners[i]).to.equal(ownerSigners[i].address);
        }
      });
  });
});
