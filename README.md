# Arbitrage

Open source tool for arbitraging between Numoen and external liquidity pools.

## Deployments

`Arbitrage` has been deployed to `0x29874Aa4cc27D7294929Ed01d11C3749f5eca8E0` on the following networks:

- Ethereum Goerli Testnet
- Arbitrum Mainnet

## Installation

To install with [Foundry](https://github.com/foundry-rs/foundry):

```bash
forge install numoen/arbitrage
```

## Local development

This project uses [Foundry](https://github.com/foundry-rs/foundry) as the development framework.

### Dependencies

```bash
forge install
```

### Compilation

```bash
forge build
```

### Test

```bash
forge test -f goerli
```

### Deployment

Make sure that the network is defined in foundry.toml, and dependency addresses updated in `Deploy.s.sol` then run:

```bash
sh deploy.sh [network]
```
