var ConvertLib = artifacts.require("./ConvertLib.sol");
var BadlaToken = artifacts.require("./BadlaToken.sol");
var ERCXToken = artifacts.require("./ERCXToken.sol");
var WETHToken = artifacts.require("./WETHToken.sol");
var Proposal = artifacts.require("./Proposal.sol");
var TokenContractRegistry = artifacts.require("./TokenContractRegistry.sol");
var Ledger = artifacts.require("./Ledger.sol");

module.exports = function (deployer) {
	var badlaToken,ercxToken,wethToken,tokenContractRegistry,proposal,ledger;
	deployer.deploy(BadlaToken)
	.then((value)=>{
		return BadlaToken.deployed();
	})
	.then((instance)=>{
		badlaToken = instance;
    return deployer.deploy(ERCXToken);
  })
	.then((value)=>{
		return ERCXToken.deployed();
	})
	.then((instance)=>{
		ercxToken = instance;
    return deployer.deploy(WETHToken);
	})
	.then((value)=>{
		return WETHToken.deployed();
	})
	.then((instance)=>{
		wethToken = instance;
		return deployer.deploy(Proposal,
													 "0x285c7a5115ce43fe2304312c1837cc56266097e6",
													 "",
													 "",
													 "0xdadbd4fb7d640c803b58a04fc4beaa00acf863b7",
													 "0x023d6d19061d446c0ad3a270a6182226abc85b13",
													 "",
													 0,
													 3);
	})
	.then((value)=>{
		return Proposal.deployed();
	})
	.then((instance)=>{
		proposal = instance;
		return deployer.deploy(Ledger);
	})
	.then((value)=>{
		return Ledger.deployed();
	})
	.then((instance)=>{
		ledger = instance;
		return deployer.deploy(TokenContractRegistry);
	})
	.then((value)=>{
		return TokenContractRegistry.deployed();
	})
	.then((instance)=>{
		tokenContractRegistry = instance;
	})
	.catch((value)=>{
		//console.log("Done");
	})
}
