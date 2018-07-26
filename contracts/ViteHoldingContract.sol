

pragma solidity ^0.4.11;

import './SafeMath.sol';
import './Math.sol';
import './Token.sol';

contract ViteHoldingContract {
	using SafeMath for uint;
	using Math for uint;

	// 锁仓功能开启时长
	uint public constant DEPOSIT_PERIOD				= 60 days;

	// 锁仓时长
	uint public constant HOLDING_DURATION			= 540 days;

	// 提现时兑换比例 1 eth = 75000 vite
	uint public constant WITHDRAWAL_SCALE			= 75000;

	// 锁仓多久之后的vite被认为是忘记密码的无主的，由合约地址无偿收回
	uint public constant DRAIN_DELAY				= 1080 days;

	address public viteTokenAddress = 0x0;
	address public owner			= 0x0;

	// 锁仓功能开启和结束时间
	uint public depositStartTime	= 0;
	uint public depositEndTime		= 0;

	// 锁仓的vite总量
	uint public viteDeposited		= 0;

	struct Record {
		uint viteAmount;
		uint timestamp;
	}

	// 存放每笔锁仓记录
	mapping (address => Record) records;

	mapping (address => bool) private whiteList;

	/*
	 * EVENTS
	 */


	/*
	 * public functions
	 */
	/// @dev Initialize the contract
	/// @param _viteTokenAddress ViteToken ERC20 token address
	/// @param _owner the owner of the contract
	function ViteHoldingContract(address _viteTokenAddress, address _owner) {
		require(_viteTokenAddress != address(0));
		require(_owner != address(0));

		viteTokenAddress = _viteTokenAddress;
		owner = _owner;
	}

	function addWhiteList(address[] addrList) public {
		require(msg.address == owner);
		for (uint i=0; i<addrList.length; i++) {
			whiteList[addrList[i]] = true;
		}
	}

	function isAddrExist(address addr) public returns (bool) {
		return whiteList[addr];
	}

	function removeWhiteName(address addr) public {
		require(msg.address == owner);
		delete whiteList[addr];
	}

	function viteBalance() public constant returns (uint) {
		return Token(viteTokenAddress).balanceOf(address(this));
	}


























}