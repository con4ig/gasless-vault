# Gasless Vault with EIP 712

This is a project demonstrating how to execute gasless transactions for users, which is extremely important when implementing Account Abstraction technology. The main idea is that users often complain about the necessity of holding ETH just to do anything on chain. In this vault we use the EIP 712 standard, which allows the user to sign an off chain consent to transfer tokens entirely for free without interacting with the network directly.

The user then passes this free signature to a relayer, for example our backend, which subsequently submits it to the network and covers the transaction fee. Inside the contract itself we use cryptography, specifically the ecrecover function, to verify if the given signature matches the user, and we also use nonces to protect against replay attacks, which prevents using the same signature twice.

The project does not rely on massive dependency packages, everything is implemented manually with a focus on simplicity and gas optimization on the EVM. This makes it very easy to grasp the mechanics of permits in the DeFi space.

If you want to play with this code on your own machine, open the terminal and type forge test to see it pass rigorous tests using the forge signature simulation tool (vm.sign) covering various edge cases. I also included a straightforward deployment script.
