require("@nomiclabs/hardhat-waffle");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: "0.8.4",
  settings: {
    optimizer: {
      enabled: true,
      runs: 200,
    },
  },
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
        blockGasLimit: 100000000429720, // whatever you want here,
        allowUnlimitedContractSize: true,
        accounts: {
          mnemonic:
            "phenix finance lotto test test test test test test test test test",
          initialIndex: 0,
          path: "m/44'/60'/0'/0",
          count: 200,
          accountsBalance: "100000000000000000000000000",
          passphrase: "phenix-finance-lotto-pass-phrase",
        },
    },
}
};
