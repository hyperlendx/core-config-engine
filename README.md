# HyperLend Config Engine

The contract is used to deploy add new tokens to the HyperLend markets

---

- deploy ConfigEngine instance
- setup proposal

- make ConfigEngine riskAdmin
- make ConfigEngine listingsAdmin

- make ReservesSetupHelper riskAdmin
- transfer ownership of ReservesSetupHelper to ConfigEngine

- do simulations...

- call executeProposal()

- remove ConfigEngine from riskAdmin
- remove ConfigEngine from listingsAdmin
- remove ReservesSetupHelper from riskAdmin
