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
  const MultiSig = await hre.ethers.getContractFactory("PhenixMultiSig");
  const multisig = await MultiSig.deploy(owners, 2);

  await multisig.deployed();

  // connect signers
  const mSigAsS1 = multisig.connect(signer1);
  const mSigAsS2 = multisig.connect(signer2);
  const mSigAsS3 = multisig.connect(signer3);

  // submit transaction @ index 0
  await mSigAsS1.submitTransaction(owners[2], 0, '0x');

  // fetch submitted transaction details
  await mSigAsS1.getTransaction(0).then((_transaction) => {
    console.log(_transaction);
  });

  // sign some messages

  // #1
  const s1HashMessage = await mSigAsS1.getMessageHash('0', currentTime.toString());
  const s1Signature = await signer1.signMessage(ethers.utils.arrayify(s1HashMessage));
  console.log(s1Signature);

  // #2
  const s2HashMessage = await mSigAsS2.getMessageHash('0', currentTime.toString());
  const s2Signature = await signer2.signMessage(ethers.utils.arrayify(s2HashMessage));
  console.log(s2Signature);

  // #3
  const s3HashMessage = await mSigAsS3.getMessageHash('0', currentTime.toString());
  const s3Signature = await signer3.signMessage(ethers.utils.arrayify(s3HashMessage));
  console.log(s3Signature);

  // prepare data
  const transactionIndex = '0';
  const timestamps = [currentTime, currentTime, currentTime];
  const signers = owners;
  const signatures = [s1Signature, s2Signature, s3Signature];


  await mSigAsS3.confirmAndExecuteTransaction(transactionIndex, timestamps, signers, signatures);
  console.log(await mSigAsS1.verify('0', currentTime.toString(), owners[0], s1Signature));

  console.log("MultiSig deployed to:", multisig.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
