// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IERC20 {
    function totalSupply() external view returns (uint);

    function balanceOf(address account) external view returns (uint);

    function transfer(address recipient, uint amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
}

interface IUserInfo {
    struct UserInfo {
        uint amount;
        uint rewardDebt;
    }
}

interface IMasterChefV2 is IUserInfo {
    function deposit(uint pid, uint amount, address to) external;
    function withdraw(uint pid, uint amount, address to) external;
    function userInfo(uint pid, address account) external view returns (UserInfo memory);
}

contract SpookyDepositTest is IUserInfo {
    address constant masterChefV2 = 0x18b4f774fdC7BF685daeeF66c2990b1dDd9ea6aD;

    mapping(address => uint) public pidByPairAddress;
    mapping(uint => address) public PairAddressByPid;
    mapping(address => uint) public balance;

    address immutable owner;

    // TODO: Just use ERC20
    uint totalSupply;

    uint constant PERCENT_DIVISOR = 1000;

    modifier onlyOwner {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier pidCheck(address pair) {
        require(pidByPairAddress[pair] != 0, "No pid for this pair");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function setPid(address pair, uint pid) onlyOwner public {
        pidByPairAddress[pair] = pid;
        PairAddressByPid[pid] = pair;
        IERC20(pair).approve(masterChefV2, type(uint).max);
    }

    // Need to approve directly from pair contract - use ethers (security thing)
    // TODO: Add reentrancy guard
    function deposit(address pair, uint amount) pidCheck(pair) public {
        require(amount > 0, "amount is 0");

        uint balanceBefore = pairBalance(pair);
        IERC20(pair).transferFrom(msg.sender, address(this), amount);
        amount = pairBalance(pair) - balanceBefore;

        uint amountAfterDeposit = (amount * PERCENT_DIVISOR) / PERCENT_DIVISOR;
        uint shares;

        if (totalSupply == 0) {
            shares = amountAfterDeposit;
        } else {
            shares = (amountAfterDeposit * totalSupply) / totalBalance(pair);
        }

        // Could make this contract an ERC20 and _mint(msg.sender, shares)
        balance[msg.sender] += shares;
        totalSupply += shares;

        // Don't deposit to spooky for now
        //IMasterChefV2(masterChefV2).deposit(pidByPairAddress[pair], amount, address(this));
    }

    // TODO: Add reentrancy guard
    function withdraw(address pair, uint amount) pidCheck(pair) public {
        assert(balance[msg.sender] >= amount);
        uint b = pairBalance(pair);
        uint r = (b * amount) / totalSupply;
        balance[msg.sender] -= amount;

        if (b < r) {
            uint withdrawalAmount = r - b;
            //IMasterChefV2(masterChefV2).withdraw(pidByPairAddress[pair], withdrawalAmount, address(this));
            uint balanceAfter = pairBalance(pair);
            uint diff = balanceAfter - b;
            if (diff < withdrawalAmount) {
                r = b + diff;
            }
        }

        IERC20(pair).transfer(msg.sender, r);
    }

    function withdrawAll(address pair) pidCheck(pair) public {
        withdraw(pair, balance[msg.sender]);
    }

    function emergencyWithdrawAll(address pair) public onlyOwner {
        IERC20(pair).transfer(owner, balance[owner]);
    }

    function totalBalance(address pair) internal view returns (uint) {
        return pairBalance(pair) + IMasterChefV2(masterChefV2).userInfo(pidByPairAddress[pair], address(this)).amount;
    }

    function pairBalance(address pair) internal view returns (uint) {
        return IERC20(pair).balanceOf(address(this));
    }
}
