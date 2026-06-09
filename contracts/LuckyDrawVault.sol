// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IOpenFourVault.sol";
import "./interfaces/IOpenFourModuleSchema.sol";
import "./interfaces/ITagDescriptor.sol";

/// @title LuckyDrawVault — 质押抽奖金库
/// @notice 质押越多中奖概率越高。中奖者平分80%奖池并保留质押代币。解押需24小时延迟
contract LuckyDrawVault is IOpenFourVault, IOpenFourModuleSchema, ITagDescriptor {
    struct LuckyDrawConfig {
        uint16 maxParticipants;    // 最大参与者 (默认4096)
        uint256 unstakingDelay;    // 解押延迟 (默认24小时)
        uint16 winnerShareBps;     // 中奖者分成 (默认80%=8000)
    }

    struct Participant {
        uint256 staked;
        uint256 stakeTime;
        uint256 unstakeRequestTime;
        uint256 unstakeAmount;
    }

    mapping(address => LuckyDrawConfig) internal _configs;
    mapping(address => mapping(address => Participant)) internal _participants;
    mapping(address => uint256) internal _accumulated;     // 累积税BNB
    mapping(address => uint256) internal _totalStaked;
    mapping(address => uint256) internal _participantCount;
    mapping(address => uint256) internal _drawRound;
    address internal _fourCore;

    uint256 internal constant BPS_BASE = 10000;

    modifier onlyCore() { require(msg.sender == _fourCore, "!core"); _; }
    error AlreadyInitialized();

    function init(address token, address fourCore, bytes calldata params, string calldata) external {
        if (address(_fourCore) != address(0)) revert AlreadyInitialized();
        _fourCore = fourCore;
        _configs[token] = abi.decode(params, (LuckyDrawConfig));
    }

    function onBuy(address, uint256, uint256 payment, uint256, bytes calldata) external onlyCore {
        _accumulated[msg.sender] += payment;
    }

    function onSell(address, uint256, uint256 payment, uint256, bytes calldata) external onlyCore {
        _accumulated[msg.sender] += payment;
    }

    function vaultBalance() external view returns (uint256) {
        return _accumulated[msg.sender];
    }

    function stake(address token, uint256 amount) external {
        LuckyDrawConfig storage cfg = _configs[token];
        require(_participantCount[token] < cfg.maxParticipants || _participants[token][msg.sender].staked > 0, "max participants");
        Participant storage p = _participants[token][msg.sender];
        if (p.staked == 0) _participantCount[token]++;
        p.staked += amount;
        p.stakeTime = block.timestamp;
        _totalStaked[token] += amount;
    }

    function requestUnstake(address token, uint256 amount) external {
        Participant storage p = _participants[token][msg.sender];
        require(p.staked >= amount, "insufficient");
        p.unstakeRequestTime = block.timestamp;
        p.unstakeAmount = amount;
    }

    function executeUnstake(address token) external {
        Participant storage p = _participants[token][msg.sender];
        require(p.unstakeAmount > 0, "no request");
        require(block.timestamp >= p.unstakeRequestTime + _configs[token].unstakingDelay, "delay active");
        uint256 amount = p.unstakeAmount;
        p.staked -= amount;
        p.unstakeAmount = 0;
        _totalStaked[token] -= amount;
        if (p.staked == 0) _participantCount[token]--;
    }

    /// @notice 执行抽奖（由Core或定时触发）
    function executeDraw(address token, address[] calldata winners) external onlyCore {
        LuckyDrawConfig storage cfg = _configs[token];
        uint256 prize = _accumulated[token] * cfg.winnerShareBps / BPS_BASE;
        uint256 share = winners.length > 0 ? prize / winners.length : 0;
        for (uint256 i = 0; i < winners.length; i++) {
            _accumulated[token] -= share;
            payable(winners[i]).transfer(share);
        }
        _drawRound[token]++;
    }

    function getInitParams() external pure returns (bytes memory) {
        return abi.encode(LuckyDrawConfig({maxParticipants: 4096, unstakingDelay: 24 hours, winnerShareBps: 8000}));
    }

    function moduleEncodeSchema() external pure returns (ModuleEncodeSchema memory) {
        ParamDescriptor[] memory params = new ParamDescriptor[](3);
        params[0] = ParamDescriptor("maxParticipants", "最大参与者", "最多参与人数", "uint16", false, bytes32(uint256(4096)), bytes32(uint256(10)), bytes32(uint256(65535)));
        params[1] = ParamDescriptor("unstakingDelay", "解押延迟(秒)", "申请解押后等待时间", "uint256", false, bytes32(uint256(24 hours)), bytes32(uint256(0)), bytes32(uint256(30 days)));
        params[2] = ParamDescriptor("winnerShareBps", "中奖者分成(bps)", "80%=8000", "uint16", false, bytes32(uint256(8000)), bytes32(uint256(0)), bytes32(uint256(10000)));
        return ModuleEncodeSchema(1, "module.vault.lucky-draw", params);
    }

    function descriptor() external pure returns (bytes8 tagId, string memory tag, string memory version) {
        tagId = bytes8(keccak256(bytes("module.vault.lucky-draw")));
        tag = "module.vault.lucky-draw";
        version = "v1.0.0";
    }
}
