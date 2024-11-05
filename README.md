# Listings Config Engine

The contract is used to add new assets to the HyperLend markets

---

ListingsConfigEngine can either be deployed on it's own or using the ConfigEngineFactory contract.

```
- Create & encode the proposal
- Deploy ConfigEngine instance (or use ConfigEngineFactory)

- Make ConfigEngine contract riskAdmin on the pool using PoolConfigurator
- Make ConfigEngine contract listingsAdmin on the pool using PoolConfigurator

- run simulations...
- call executeProposal()

- Remove ConfigEngine from riskAdmin
- Remove ConfigEngine from listingsAdmin
```

---

Run simulations: `npx hardhat run scripts/simulation.js --network hyperEvmTestnetFork`

---

Tests:

`npx hardhat test`

In case of `TypeError: Cannot read properties of undefined (reading 'map')` error, try running the tests again, this might happen if external contracts are not compiled yet.
If that doesn't fix it, delete `artifacts/` folder and try again.