# **GrantFlow – Smart NGO Grant Disbursement System**

*A transparent, milestone-based grant management contract built on the Stacks blockchain.*

##  **Overview**

GrantFlow is a decentralized smart contract designed to manage NGO registrations, donations, milestone verification, and conditional fund releases using Clarity. It ensures **transparency**, **donor confidence**, and **accountability** by enforcing on-chain workflows.

This contract solves the common issues in NGO funding:

* Lack of transparency
* Mismanagement of funds
* Poor milestone verification
* Donor uncertainty

With GrantFlow, **funds are only released when milestones are verified by an admin**, ensuring controlled and transparent disbursement.

##  **Features**

### **✔ NGO Registration & Approval**

* Anyone can register an NGO ID
* Only admin can approve NGOs
* Stores NGO ownership and approval state

### **✔ Donation Tracking**

* Donors send STX directly to the contract
* Contract holds STX balances per NGO
* All donation events are logged

### **✔ Milestone Management**

* NGO owners create milestones (description + amount)
* Each milestone must be verified by the admin
* Prevents double creation

### **✔ Conditional Fund Release**

* Funds released **only after verification**
* Released directly to the NGO owner
* Prevents double-release
* Ensures contract has enough balance

### **✔ Admin Controls**

* Transfer admin rights
* Verify milestones
* Approve NGOs

##  **Contract Structure**

### **Data Maps**

| Map            | Purpose                                                   |
| -------------- | --------------------------------------------------------- |
| `ngos`         | Stores registered NGOs with owner + approval status       |
| `ngo-balances` | Tracks STX balances donated to each NGO                   |
| `milestones`   | Stores milestone details, verification, and release state |

### **Events (printed tuples)**

* `ngo-registered`
* `ngo-approved`
* `milestone-created`
* `milestone-verified`
* `funds-donated`
* `funds-released`

---

##  **Public Functions**

### **NGO Management**

* `register-ngo (ngo-id)`
* `approve-ngo (ngo-id)`

### **Donations**

* `donate (ngo-id amount)`

### **Milestones**

* `create-milestone (ngo-id milestone-id description amount)`
* `verify-milestone (ngo-id milestone-id)`
* `release-funds (ngo-id milestone-id)`

### **Admin**

* `transfer-admin (new-admin)`

---

##  **Read-Only Functions**

Useful for frontend integrations or dashboards:

* `get-admin`
* `is-admin`
* `ngo-exists`
* `get-ngo`
* `get-ngo-balance`
* `get-milestone`
* `list-ngo`
* `list-milestone`
* `contract-balance`

##  **Security Considerations**

* Admin-only functions protected by checks
* Prevents double-voting, double-release, and milestone duplication
* Ensures contract holds enough balance before releasing funds
* Explicit error codes for predictable handling

##  **Deployment**

```bash
clarinet integrate
clarinet deploy


Ensure your environment is configured for the Stacks blockchain and Clarity contract deployment.

---

##  **Contributing**

Pull requests are welcome!
Please open an issue for major changes or discussions.

---

##  **License**

MIT License — You are free to use, modify, and distribute under the terms of the license.
