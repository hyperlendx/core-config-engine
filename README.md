# HyperLend Config Engine

The contract is used to add new assets to the HyperLend markets

---

```
- Create proposal
- Deploy ConfigEngine instance

- Make ConfigEngine riskAdmin
- Make ConfigEngine listingsAdmin

- do simulations...

- call executeProposal()

- Remove ConfigEngine from riskAdmin
- Remove ConfigEngine from listingsAdmin
```

---

Run simulations: `npx hardhat run scripts/simulation.js --network hardhat`
