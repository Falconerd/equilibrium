// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

contract SpookyFarmProxy {
    address constant MCV1 = 0x2b2929E785374c651a81A63878Ab22742656DcDd;
    IMasterChefV2 constant MCV2 = IMasterChefV2(0x18b4f774fdC7BF685daeeF66c2990b1dDd9ea6aD);
    address constant MCV3 = 0x9C9C920E51778c4ABF727b8Bb223e78132F00aA4;
    address constant BOO = 0x841FAD6EAe12c286d1Fd18d1d525DFfA75C7EFFE;
    uint private constant ACC_BOO_PRECISION = 1e12;

    IERC20 public immutable depositToken; // Spooky spLP pair
    uint public immutable pid;
    mapping(address => uint) public balanceOf;
    uint public totalSupply;
    address[] public rewardTokens;
    // Token => value
    mapping(address => uint) public rewardRate;
    mapping(address => uint) public rewardPerTokenStored;
    mapping(address => uint) public updatedAt;
    // User => Token => value
    mapping(address => mapping(address => uint)) public userRewardPerTokenPaid;
    mapping(address => mapping(address => uint)) public rewards;

    address public owner;
    bool public isPaused = false;

    constructor(uint pid_) {
        pid = pid_;
        depositToken = IERC20(MCV2.lpToken(pid_));
        rewardRate[BOO] = getBooRewardRate();
        rewardTokens.push(BOO);
        // TODO: RewardsToken (EQL)
    }

    modifier onlyOwner {
        require(msg.sender == owner, "not owner");
        _;
    }

    modifier updateReward(address account) {
        for (uint i = 0; i < rewardTokens.length; ++i) {
            address token = rewardTokens[i];
            rewardPerTokenStored[token] = rewardPerToken(token);
            updatedAt[token] = block.timestamp;
            if (account != address(0)) {
                rewards[account][token] = earned(account, token);
                userRewardPerTokenPaid[account][token] = rewardPerTokenStored[token];
            }
        }
        _;
    }

    function rewardPerToken(address token) public view returns (uint) {
        if (totalSupply == 0) {
            return rewardPerTokenStored[token];
        }

        return rewardPerTokenStored[token] + (rewardRate[token] * (block.timestamp - updatedAt[token]) * 1e18) / totalSupply;
    }

    function earned(address account, address token) public view returns (uint) {
        return ((balanceOf[account] * (rewardPerToken(token) - userRewardPerTokenPaid[account][token])) / 1e18) + rewards[account][token];
    }

    function getReward(address token) external updateReward(msg.sender) {
        uint reward = rewards[msg.sender][token];
        if (reward > 0) {
            rewards[msg.sender][token] = 0;
            IERC20(token).transfer(msg.sender, reward);
        }
    }

    modifier checkBooRewardRate() {
        if (getBooRewardRate() != rewardRate[BOO]) {
            _pause();
        }
        _;
    }

    // I THINK I KNOW THE PROBLEM.
    // I can't use the boo reward rate of the pool because that's allocated to EVERYONE in the pool.
    // That means the emissions for THIS contract is (this_contract_percentage_of_tvl_in_spooky * booRewardRate * seconds in pool)
    // Emissions don't happen if nobody is in the pool.
    // This is all very obvious in hindsight...
    // So basically we need to figure out each user's percentage of rewards. The rewards will vary depending on pool size...
    // Look into those contracts that use "shares" - reaper farm, old tomb farm contracts

    // Seems like pointless OOP nonsense but I'd rather keep the setting of the pause flag in one place.
    function _pause() internal {
        isPaused = true;
    }

    function unpause() public onlyOwner {
        isPaused = false;
    }

    function emergencyPauseContract() public onlyOwner {
        _pause();
    }

    function getBooRewardRate() public view returns (uint) {
        IMasterChefV2DataTypes.PoolInfo memory poolInfo = MCV2.poolInfo(pid);
        return poolInfo.allocPoint * ACC_BOO_PRECISION / MCV2.totalAllocPoint() * MCV2.booPerSecond() / ACC_BOO_PRECISION;
    }

    function deposit(uint amount) external checkBooRewardRate updateReward(msg.sender) {
        require(isPaused == false, "deposits are paused");
        require(amount > 0, "amount = 0");

        depositToken.transferFrom(msg.sender, address(this), amount);
        depositToken.approve(address(MCV2), type(uint).max);
        MCV2.deposit(pid, amount);
        
        balanceOf[msg.sender] += amount;
        totalSupply += amount;
    }

    function withdraw(uint amount) external updateReward(msg.sender) {
        require(amount > 0, "amount = 0");
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        MCV2.withdraw(pid, amount);
        depositToken.transfer(msg.sender, amount);
    }
}

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

interface IMasterChefV2DataTypes {
    struct UserInfo {
        uint amount;
        uint rewardDebt;
    }
    struct PoolInfo {
        uint128 accBooPerShare;
        uint64 lastRewardTime;
        uint64 allocPoint;
    }
}

interface IMasterChefV2 is IMasterChefV2DataTypes {
    function deposit(uint pid, uint amount) external;
    function withdraw(uint pid, uint amount) external;
    function userInfo(uint pid, address account) external view returns (UserInfo memory);
    function poolInfo(uint pid) external view returns (PoolInfo memory);
    function lpToken(uint pid) external view returns (address);
    function totalAllocPoint() external view returns (uint);
    function booPerSecond() external view returns (uint);
}
