
pragma solidity 0.4.24;

/**
 * Math operations with safety checks
 */
library SafeMath {
  function mul(uint a, uint b) internal returns (uint) {
    uint c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }

  function div(uint a, uint b) internal returns (uint) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint a, uint b) internal returns (uint) {
    assert(b <= a);
    return a - b;
  }

  function add(uint a, uint b) internal returns (uint) {
    uint c = a + b;
    assert(c >= a);
    return c;
  }

  function max64(uint64 a, uint64 b) internal constant returns (uint64) {
    return a >= b ? a : b;
  }

  function min64(uint64 a, uint64 b) internal constant returns (uint64) {
    return a < b ? a : b;
  }

  function max256(uint256 a, uint256 b) internal constant returns (uint256) {
    return a >= b ? a : b;
  }

  function min256(uint256 a, uint256 b) internal constant returns (uint256) {
    return a < b ? a : b;
  }

  function assert(bool assertion) internal {
    if (!assertion) {
      throw;
    }
  }
}




// Abstract contract for the full ERC 20 Token standard
// https://github.com/ethereum/EIPs/issues/20

contract Token {
    /* This is a slight change to the ERC20 base standard.
    function totalSupply() constant returns (uint256 supply);
    is replaced with:
    uint256 public totalSupply;
    This automatically creates a getter function for the totalSupply.
    This is moved to the base contract since public getter functions are not
    currently recognised as an implementation of the matching abstract
    function by the compiler.
    */
    /// total amount of tokens
    uint256 public totalSupply;

    /// @param _owner The address from which the balance will be retrieved
    /// @return The balance
    function balanceOf(address _owner) constant returns (uint256 balance);

    /// @notice send `_value` token to `_to` from `msg.sender`
    /// @param _to The address of the recipient
    /// @param _value The amount of token to be transferred
    /// @return Whether the transfer was successful or not
    function transfer(address _to, uint256 _value) returns (bool success);

    /// @notice send `_value` token to `_to` from `_from` on the condition it is approved by `_from`
    /// @param _from The address of the sender
    /// @param _to The address of the recipient
    /// @param _value The amount of token to be transferred
    /// @return Whether the transfer was successful or not
    function transferFrom(address _from, address _to, uint256 _value) returns (bool success);

    /// @notice `msg.sender` approves `_spender` to spend `_value` tokens
    /// @param _spender The address of the account able to transfer the tokens
    /// @param _value The amount of tokens to be approved for transfer
    /// @return Whether the approval was successful or not
    function approve(address _spender, uint256 _value) returns (bool success);

    /// @param _owner The address of the account owning tokens
    /// @param _spender The address of the account able to transfer the tokens
    /// @return Amount of remaining tokens allowed to spent
    function allowance(address _owner, address _spender) constant returns (uint256 remaining);

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}

contract ViteHoldingContract {
	using SafeMath for uint;

	// 锁仓功能开启时长
	uint public constant DEPOSIT_PERIOD					= 60 days;

	// 锁仓时长
	uint public constant HOLDING_DURATION				= 180 days;

	// 提现时兑换比例 1 eth = 7500 vite
	uint public constant RATE							= 7500;

	// 锁仓多久之后的vite被认为是忘记密码的无主的，由合约地址无偿收回
	uint public constant DRAIN_DELAY					= 270 days;

	uint public constant MAX_VITE_DEPOSIT_PER_ADDRESS	= 150000;  // Each person can despoit 20 eth = 150000 vite

	address public viteTokenAddress = 0x0;
	address public owner			= 0x0;

	// 锁仓功能开启和结束时间
	uint public depositStartTime	= 0;
	uint public depositEndTime		= 0;

	
	uint public viteReceived		= 0;
	uint public viteSent			= 0;
	uint public ethReceived			= 0;
	uint public ethSent				= 0;

	bool public closed				= false;

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
	 // Emitted when program starts.
	 event Started(uint _time);

	 // Emitted when this contract is closed.
	 event Closed(uint _ethAmount, uint _viteAmount);

	 // Emitted when eth are drained.
	 event Drained(uint _ethAmount);

	 // 
	 uint public depositId = 0;
	 event Deposit(uint _depositId, address indexed _addr, uint _ethAmount, uint _viteAmount);

	 uint public withdrawId = 0;
	 event Withdrawal(uint _withdrawId, address indexed _addr, uint _ethAmount, uint _viteAmount);


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
		require(msg.sender == owner);
		for (uint i=0; i<addrList.length; i++) {
			whiteList[addrList[i]] = true;
		}
	}

	function isAddrExist(address addr) public returns (bool) {
		return whiteList[addr];
	}

	function removeWhiteName(address addr) public {
		require(msg.sender == owner);
		delete whiteList[addr];
	}

	function viteBalance() public constant returns (uint) {
		return Token(viteTokenAddress).balanceOf(address(this));
	}

	// @dev start the program
	function start() public {
		require(msg.sender == owner);
		require(depositStartTime == 0);

		depositStartTime = now;
		depositEndTime = depositStartTime + DEPOSIT_PERIOD;

		Started(depositStartTime);
	}

	// @dev Get back eth to 'owner'
	function drain(uint ethAmount) public payable {
		require(!closed);
		require(msg.sender == owner);

		uint amount = ethAmount.min256(this.balance);
		require(amount > 0);
		owner.transfer(amount);
		Drained(amount);
	}

	// @dev Close the program and get balance back to 'owner'
	function close() public payable {
		require(!closed);
		require(msg.sender == owner);
		require(now > depositEndTime + DRAIN_DELAY);

		uint ethAmount = this.balance;
		if (ethAmount > 0) {
			owner.transfer(ethAmount);
		}

		var viteToken = Token(viteTokenAddress);
		uint viteAmount = viteToken.balanceOf(address(this));
		if (viteAmount > 0) {
			require(viteToken.transfer(owner, viteAmount));
		} 

		closed = true;
		Closed(ethAmount, viteAmount);
	}

	function () payable {
		require(!closed);

		if (msg.sender != owner) {
			if (now <= depositEndTime) depositVite();
			else withdrawVite();
		}
	}

	// @dev Deposit Vite
	// User send vite and get eth back
	function depositVite() payable {
		require(!closed && msg.sender != owner);
		require(msg.value == 0);
		require(now <= depositEndTime);

		if (isAddrExist(msg.sender)) {
			var record = records[msg.sender];
			var viteToken = Token(viteTokenAddress);

			uint viteAmount = this.balance.mul(RATE)
				.min256(viteToken.balanceOf(msg.sender))
				.min256(viteToken.allowance(msg.sender, address(this)))
				.min256(MAX_VITE_DEPOSIT_PER_ADDRESS - record.viteAmount);

			uint ethAmount = viteAmount.div(RATE);
			viteAmount = ethAmount.mul(RATE);

			require(viteAmount > 0 && ethAmount > 0);

			record.viteAmount += viteAmount;
			record.timestamp = now;
			records[msg.sender] = record;

			viteReceived += viteAmount;
			ethSent += ethAmount;

			Deposit(
					depositId++,
					msg.sender,
					ethAmount,
					viteAmount);
			require(viteToken.transferFrom(msg.sender, address(this), viteAmount));
			msg.sender.transfer(ethAmount);
		}
	}

	/// @dev Withdraw vite with ETH transfer.
	function withdrawVite() payable {
		require(!closed && msg.sender != owner);
		require(now > depositEndTime);
		require(msg.value > 0);

		if (isAddrExist(msg.sender)) {
			var record = records[msg.sender];
			require(now >= record.timestamp + HOLDING_DURATION);
			require(now <= record.timestamp + DRAIN_DELAY);

			uint ethAmount = msg.value.min256(record.viteAmount.div(RATE));
			uint viteAmount = ethAmount.mul(RATE);

			record.viteAmount -= viteAmount;
			if (record.viteAmount == 0) {
				delete records[msg.sender];
			} else {
				records[msg.sender] = record;
			}

			viteSent += viteAmount;
			ethReceived += ethAmount;

			Withdrawal(
						withdrawId++,
						msg.sender,
						ethAmount,
						viteAmount
						);
			require(Token(viteTokenAddress).transfer(msg.sender, viteAmount));

			uint rest = msg.value - ethAmount;
			if (rest > 0) {
				msg.sender.transfer(rest);
			}
		}
	}

	function getViteAmount(address addr) public constant returns(uint) {
		return records[addr].viteAmount;
	}

	function getTimestamp(address addr) public constant returns(uint) {
		return records[addr].timestamp;
	}

}