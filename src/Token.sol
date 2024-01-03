pragma solidity ^0.8.21;

import {GoldenCore} from "./GoldenCore.sol";

interface IToken{
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns(uint8);
    function totalSupply() external view returns(uint256);
    function balanceOf(address account) external view returns(uint256);
    function getRatioOfEth() external view returns(uint256);
    /** Admin only **/
    function transfer(address from, address to, uint256 value) external;
    function mint(address account, uint256 value) external;
    function burn(address account, uint256 value) external;
}

interface ITokenError{
    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param caller Address who is trying to interact with the token.
     */
    // error SenderMustBeAdmin(address caller);
    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error InvalidSender(address sender);
    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error InvalidReceiver(address receiver);
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     */
    error InsufficientBalance(address sender, uint256 balance, uint256 needed);
}

interface ITokenEvent{
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);
}

contract Token is  ITokenError, ITokenEvent, IToken, GoldenCore{
    mapping(address account => uint256) private _balances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    uint256 private ratioOfEth;
    
    constructor(string memory name_, string memory symbol_, uint256 _ratioOfEth, address _goldenEggAddress) {
        _name = name_;
        _symbol = symbol_;
        ratioOfEth = _ratioOfEth;
        allowers[msg.sender] = true;
        allowers[_goldenEggAddress] = true;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return 18;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function setRatioOfEth(uint256 _ratioOfEth) public onlyAdmin{
        ratioOfEth = _ratioOfEth;
    }

    function getRatioOfEth() public view returns(uint256){
        return ratioOfEth;
    }

    function transfer(address from, address to, uint256 value) public onlyAdmin {
        if (from == address(0)) {
            revert InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert InvalidReceiver(address(0));
        }
        _update(from, to, value);
    }
    function mint(address account, uint256 value) public onlyAdmin {
        if (account == address(0)) {
            revert InvalidReceiver(address(0));
        }
        _update(address(0), account, value);
    }
    function burn(address account, uint256 value) public onlyAdmin {
        if (account == address(0)) {
            revert InvalidSender(address(0));
        }
        _update(account, address(0), value);
    }

    function _update(address from, address to, uint256 value) internal {
        if (from == address(0)) {
            // Overflow check required: The rest of the code assumes that totalSupply never overflows
            _totalSupply += value;
        } else {
            uint256 fromBalance = _balances[from];
            if (fromBalance < value) {
                revert InsufficientBalance(from, fromBalance, value);
            }
            unchecked {
                // Overflow not possible: value <= fromBalance <= totalSupply.
                _balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                // Overflow not possible: value <= totalSupply or value <= fromBalance <= totalSupply.
                _totalSupply -= value;
            }
        } else {
            unchecked {
                // Overflow not possible: balance + value is at most totalSupply, which we know fits into a uint256.
                _balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }
    
}