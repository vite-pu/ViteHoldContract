
pragma solidity 0.4.24;


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


contract AirDropContract {

    event AirDropped(address addr, uint amount);
    
    address viteTokenAddress;
    address owner;  // OK address
    
    uint private dropNum                    = 6;  // the number of issue
    
    // uint public constant DROP_PERIOD        = 30 days;  // the period of issue
    uint public constant DROP_PERIOD        = 10;
    
    uint private lastIssueTime              = 0;    // the last issue time 
    
    uint private constant AMOUNT_PER_TIME   = 10000;  // the amount of per issue
    
    
    function AirDropContract(address _viteTokenAddress, address _owner) payable {
        viteTokenAddress = _viteTokenAddress;
        owner = _owner;
    }
    
    function viteBalance() public view returns (uint) {
        return Token(viteTokenAddress).balanceOf(address(this));
    }
    
    function issueVite() public {
        
        require(msg.sender == owner); // Only OK can emit
        require(viteTokenAddress != 0x0);
        require(dropNum > 0);
        
        uint balance = viteBalance();
        require(balance > 0);
        
        if (lastIssueTime == 0 || now >= lastIssueTime + DROP_PERIOD) {  // the first time to issue
            require(Token(viteTokenAddress).transfer(owner, AMOUNT_PER_TIME));
            
            dropNum = dropNum - 1;
            lastIssueTime = now;
        }
    }
    
    function getNum() public view returns(uint) {
        return dropNum;
    }

    function () payable public {
        revert();
    }
}
