
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

/// 锁仓vite兑换eth激励计划
contract ViteIncentivePlan2 {
	using SafeMath for uint;

	// 锁仓时长
	uint public constant HOLDING_DURATION		= 90 days;

	// 锁仓功能结束后，用户的提现时间
	// 超过 depositEndTime + HOLDING_DURATION + WITHDRAW_DELAY时间后，认为用户丢失密码
	// 剩余vite由owner回收
	uint public constant WITHDRAW_DELAY			= 30 days;

	// 兑换eth时兑换比例 1 eth = 7000 vite
	uint public constant RATE					= 7000;


	address public viteTokenAddress = 0x0;
	address public owner			= 0x0;

	// 锁仓计划开启和结束时间（结束是指不能再往合约充值vite）
	uint public depositStartTime	= 0;
	uint public depositEndTime		= 0;

	// 合约收到和转出vite总量
	uint public viteReceived		= 0;
	uint public viteSent			= 0;

	// 兑换eth总量
	uint public ethTotal			= 0;

	// 锁仓计划是否关闭
	bool public closed				= false;

	// 用户充值vite记录(同一用户多笔充值，时间以最后一次为准)
	struct DespoitRecord {
		uint viteAmount;
		uint timestamp;
	}

	// 存放每笔锁仓记录
	mapping (address => DespoitRecord) records;


	/*
	 * EVENTS
	 */
	 // Emitted when program starts.
	 event Started(uint _time);

	 // Emitted when this plan is closed.
	 event Closed(uint _time);

	 /// Emitted when all vite are drained.
     event Drained(uint _viteAmount);

	 // 
	 uint public depositId = 0;
	 event Deposit(uint _depositId, address indexed _addr, uint _viteAmount);

	 uint public withdrawId = 0;
	 event Withdrawal(uint _withdrawId, address indexed _addr, uint _viteAmount);

	 uint public withdrawEthId = 0;
	 event WithdrawalETH(uint _withdrawETHId, address indexed _addr, uint _ethAmount);

	 uint public depositEthId = 0;
	 event DepositEth(uint _depositEthId, address indexed _addr, uint _ethAmount);


	/*
	 * public functions
	 */
	/// @dev Initialize the contract
	/// @param _viteTokenAddress ViteToken ERC20 token address
	/// @param _owner the owner of the contract
	function ViteIncentivePlan2(address _viteTokenAddress, address _owner) {
		require(_viteTokenAddress != address(0));
		require(_owner != address(0));

		viteTokenAddress = _viteTokenAddress;
		owner = _owner;
	}

	// 合约vite余额
	function viteBalance() public constant returns (uint) {
		return Token(viteTokenAddress).balanceOf(address(this));
	}

	// drain vite after closed the plan.
	function drain() public payable {
		require(msg.sender == owner);
		require(closed && now > depositEndTime + HOLDING_DURATION + WITHDRAW_DELAY);

		uint balance = viteBalance();
		if (balance > 0) {
			require(Token(viteTokenAddress).transfer(owner, balance));
			viteSent += balance;
			Drained(balance);
		}

		uint rest = this.balance;
		if (rest > 0) {
			owner.transfer(rest);
			WithdrawalETH(withdrawEthId++, owner, rest);
		}
	}

	/// @dev start the program
	function start() public {
		require(msg.sender == owner);
		require(depositStartTime == 0);

		depositStartTime = now;

		Started(depositStartTime);
	}

	/// @dev Close the program
	// 只是不能再锁仓了，提现功能还可以
	function close() public {
		require(!closed);
		require(msg.sender == owner);

		depositEndTime = now;
		closed = true;
		Closed(depositEndTime);
	}

	function () payable {
		if (msg.sender != owner) {
			revert();
		}
	}

	/// @dev Deposit Vite
	// 用户往合约充值vite，每次会记录下来，同一用户多笔充值以最后一笔的时间为准，并记录下合约收到vite总量
	// 前置条件是用户授权此合约能够转移vite
	function depositVite() {
		require(!closed && msg.sender != owner);
		require(msg.value == 0);
		require(depositStartTime != 0);

		var record = records[msg.sender];
		var viteToken = Token(viteTokenAddress);

		uint viteAmount = viteToken.balanceOf(msg.sender)
		.min256(viteToken.allowance(msg.sender, address(this)));

		require(viteAmount > 0);

		record.viteAmount += viteAmount;
		record.timestamp = now;
		records[msg.sender] = record;

		viteReceived += viteAmount;

		require(viteToken.transferFrom(msg.sender, address(this), viteAmount));
		Deposit(
			depositId++,
			msg.sender,
			viteAmount);
	}

	/// @dev Withdraw all vite after HOLDING_DURATION.
	// 锁仓时间结束之后用户提取所有的vite余额
	function withdrawVite() {
		require(msg.sender != owner);
		require(now > depositStartTime + HOLDING_DURATION);

		var record = records[msg.sender];
		require(now >= record.timestamp + HOLDING_DURATION);

		uint viteAmount = record.viteAmount;

		if (viteAmount > 0) {
			viteSent += viteAmount;  // 记录下合约转出vite总量

			delete records[msg.sender];  // 删除此用户记录信息
			require(Token(viteTokenAddress).transfer(msg.sender, viteAmount));
			Withdrawal(
				withdrawId++,
				msg.sender,
				viteAmount
			);
		}
	}

	/// @dev Withdraw _amount vite after HOLDING_DURATION.
	// 用户提取指定数量的vite，若余额为0则删除该用户的记录
	function withdrawViteByAmount(uint _amount) {
		require(msg.sender != owner);
		require(now > depositStartTime + HOLDING_DURATION);

		var record = records[msg.sender];
		require(now >= record.timestamp + HOLDING_DURATION);

		uint viteAmount = record.viteAmount;
		require(_amount > 0 && _amount <= viteAmount);

		viteSent += _amount;
		record.viteAmount -= _amount;

		if (record.viteAmount == 0) {
			delete records[msg.sender];
		} else {
			records[msg.sender] = record;
		}

		require(Token(viteTokenAddress).transfer(msg.sender, _amount));
		Withdrawal(
			withdrawId++,
			msg.sender,
			_amount
		);
	}

	// 在HOLDING_DURATION时间内，用_amountVite数量的vite来置换eth
	function withdrawEth(uint _amountVite) {
		// require(!closed);
		require(depositStartTime != 0);

		var record = records[msg.sender];
		uint viteAmount = record.viteAmount;
		require(now <= record.timestamp + HOLDING_DURATION);
		require(_amountVite > 0);
		require(_amountVite <= viteAmount);

		uint ethAmount = _amountVite.div(RATE);  //本身单位就是wei

		require(Token(viteTokenAddress).transfer(owner, _amountVite));

		msg.sender.transfer(ethAmount);

		viteSent += _amountVite;

		// 记录兑换的eth总量
		ethTotal += ethAmount;

		record.viteAmount -= _amountVite;
		if (record.viteAmount == 0) {
			delete records[msg.sender];
		} else {
			records[msg.sender] = record;
		}

		WithdrawalETH(withdrawEthId++, msg.sender, ethAmount);
		Withdrawal(
			withdrawId++,
			owner,
			_amountVite
		);
	}

	// 由owner触发，然后给提取的用户转币
	// 
	function depositEth() payable {
		require(msg.sender == owner);
		require(depositStartTime != 0);

		DepositEth(depositEthId++, owner, msg.value);
	}

	// 获得addr在此合约中的vite量
	function getViteAmount(address addr) public constant returns(uint) {
		return records[addr].viteAmount;
	}
	// 获得addr充值vite的时间戳
	function getTimestamp(address addr) public constant returns(uint) {
		return records[addr].timestamp;
	}

}