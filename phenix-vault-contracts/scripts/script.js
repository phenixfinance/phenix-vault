// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  const currentTime = Math.floor(Date.now() / 1000);

  // owner signers
  const signer1 = await hre.ethers.getSigner(0);
  const signer2 = await hre.ethers.getSigner(1);
  const signer3 = await hre.ethers.getSigner(2);

  const owners = [
    await signer1.getAddress(),
    await signer2.getAddress(),
    await signer3.getAddress(),
  ];

  // We get the contract to deploy
  const Token = await hre.ethers.getContractFactory("ERC20_TEST_TOKEN");
  const NFT = await hre.ethers.getContractFactory("ERC721_TEST_NFT");
  const MultiSig = await hre.ethers.getContractFactory("PhenixMultiSig");
  const PhenixMultiSigFactory = await hre.ethers.getContractFactory(
    "PhenixMultiSigFactory"
  );
  const multisig = await MultiSig.deploy(owners, 3);

  await multisig.deployed();

  const token = await Token.deploy(
    "Test Token",
    "TTOK",
    hre.ethers.utils.parseEther("10000000000000")
  );

  await token.deployed();

  const nft = await NFT.deploy("NFT", "NFT");

  await nft.deployed();

  const phenixMultiSigFactory = await PhenixMultiSigFactory.deploy(
    hre.ethers.utils.parseEther("100"),
    hre.ethers.utils.parseEther("500"),
    token.address,
    nft.address,
    signer1.address
  );

  await phenixMultiSigFactory.deployed();

  // connect signers
  const mSigAsS1 = multisig.connect(signer1);
  const mSigAsS2 = multisig.connect(signer2);
  const mSigAsS3 = multisig.connect(signer3);

  console.log(await phenixMultiSigFactory.getContractsOfOwner(signer1.address));

  // send funds to multiSig wallet
  tx = {
    to: multisig.address,
    value: hre.ethers.utils.parseEther("100.0"),
  };

  await signer1.sendTransaction(tx);

  // submit transaction @ index 0
  await mSigAsS1.submitTransaction(
    signer2.address,
    hre.ethers.utils.parseEther("5.0"),
    "0x"
  );

  console.log("Signer 2 Balance:", await signer2.getBalance());
  console.log(
    "Multi-sig Balance:",
    await hre.ethers.provider.getBalance(multisig.address)
  );

  // signer 1 check cost
  console.log(
    "Signer 1 Cost:",
    await phenixMultiSigFactory.userCost(
      hre.ethers.utils.parseEther("100"),
      signer1.address
    )
  );

  await phenixMultiSigFactory
    .connect(signer1)
    .generateMultiSigWalletWithETH(owners, 3, {
      value: hre.ethers.utils.parseEther("75"),
    });

  // signer 1 mint NFT
  await nft.mint(1);

  // signer 1 check cost
  console.log(
    "Signer 1 Cost:",
    await phenixMultiSigFactory.userCost(
      hre.ethers.utils.parseEther("100"),
      signer1.address
    )
  );

  // fetch submitted transaction details
  console.log("Transaction: 0");
  await mSigAsS1.getTransaction(0).then((_transaction) => {
    console.log(_transaction);
  });

  // sign some messages

  // #1
  const s1HashMessage = await mSigAsS1.getMessageHash(
    "0",
    currentTime.toString()
  );
  const s1Signature = await signer1.signMessage(
    hre.ethers.utils.arrayify(s1HashMessage)
  );
  // console.log(s1Signature);

  // #2
  const s2HashMessage = await mSigAsS2.getMessageHash(
    "0",
    currentTime.toString()
  );
  const s2Signature = await signer2.signMessage(
    hre.ethers.utils.arrayify(s2HashMessage)
  );
  // console.log(s2Signature);

  // #3
  const s3HashMessage = await mSigAsS3.getMessageHash(
    "0",
    currentTime.toString()
  );
  const s3Signature = await signer3.signMessage(
    hre.ethers.utils.arrayify(s3HashMessage)
  );

  // prepare data
  const transactionIndex = "0";
  const timestamps = [currentTime, currentTime, currentTime];
  const signers = [owners[0], owners[1], owners[2]];
  const signatures = [s1Signature, s2Signature, s3Signature];

  await mSigAsS3.confirmAndExecuteTransaction(
    transactionIndex,
    timestamps,
    signers,
    signatures
  );

  // fetch submitted transaction details
  console.log("Transaction: 0");
  await mSigAsS1.getTransaction(0).then((_transaction) => {
    // console.log(_transaction);
  });

  // verify
  // console.log(await mSigAsS1.verify("0", currentTime.toString(), owners[0], s1Signature));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
