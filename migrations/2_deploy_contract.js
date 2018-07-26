var TestERC20Token		= artifacts.require("./TestERC20Token.sol")
var ViteHoldContract	= artifacts.require("./ViteHoldingContract.sol")

module.exports = function(deployer, network, accounts) {
	console.log("network: " + network);
	console.log(accounts)

	if (network == "live") {

	} else {
		deployer.deploy(TestERC20Token)
		.then(function() {
			return deployer.deploy(
				ViteHoldContract,
				TestERC20Token.address,
				accounts[0]);
		});
	}
};