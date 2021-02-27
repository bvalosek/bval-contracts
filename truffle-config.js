module.exports = {
  networks: {
    development: {
      host: '127.0.0.1',
      port: 7545,
      network_id: 5777,
      skipDryRun: true,
    },
  },
  compilers: {
    solc: {
      version: '0.8.1',
      settings: {
        optimizer: {
          enabled: true,
          runs: 1,
        },
      },
    },
  },
  plugins: ['truffle-plugin-verify']
};
