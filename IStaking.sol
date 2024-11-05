// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

// El contrato tiene que aceptar el staking de los usuarios
// Para un determinado IERC20, no hace falta crear un token propio
// El flujo seria:
// El usuario stakea una cierta cantidad de tokens en el contrato
// Puede stakear por 1 año , 2 o 3. Y los respectivos rewards serian 25% extra, 50% extra y 75% extra
// Si alguien quiere retirar antes de tiempo, se le penaliza recibiendiendo solo lo que stakearon
// Para facilitar el desarrollo, nadie puede stakear menos de 1 año. Y no reciben rewards si no llegan a 1 año
// Cuando alguien hace unStake automaticamente se le pagan las rewards si corresponden
// Si alguien llama a claimReward, podra retirar las rewards que le correspondan pero el staked seguira generando rewards
// Recordad que suponemos que el owner tiene dinero infinito y puede depositar suficientes tokens para que cuando la gente haga unstake,
// siempre haya suficiente liquidez
// Sera necesario entregar el contrato con el natspec completo y los unit tests.

// Consejo, crear una funcion internal que calcule las rewards de un usuario dado que es logica compartida tanto en unStake como en claimReward

interface IStaking {

  
  /*///////////////////////////////////////////////////////////////
                              STRUCTS
  //////////////////////////////////////////////////////////////*/
  struct StakeInfo {
        uint256 amount;
        uint256 startTime;
        uint256 duration;
        uint256 rewardRate;
    }
  /*///////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/
    event Staked(address indexed user, uint256 amount, uint256 duration);
    event Unstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);
    event OwnerDeposited(uint256 amount);
  /*///////////////////////////////////////////////////////////////
                              ERRORS
  //////////////////////////////////////////////////////////////*/
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
  /*///////////////////////////////////////////////////////////////
                              VIEWS
  //////////////////////////////////////////////////////////////*/

  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice Stake a certain amount of tokens for a certain duration
   * @param _amount The amount of tokens to stake
   * @param _duration The duration of the stake
   */
  function stake(uint256 _amount, uint256 _duration) external override {
        require(_duration == 1 || _duration == 2 || _duration == 3, "Invalid duration");
        require(_amount > 0, "Amount must be greater than 0");

        uint256 rewardRate;
        if (_duration == 1) rewardRate = 25;
        else if (_duration == 2) rewardRate = 50;
        else if (_duration == 3) rewardRate = 75;

        require(stakingToken.transferFrom(msg.sender, address(this), _amount), "Transfer failed");

        stakes[msg.sender] = StakeInfo({
            amount: _amount,
            startTime: block.timestamp,
            duration: _duration * 365 days,
            rewardRate: rewardRate
        });

        totalStaked += _amount;

        emit Staked(msg.sender, _amount, _duration);
    }

  /**
   * @notice Unstake the tokens
   * @dev If the user unstakes before the duration, they will only get the staked amount
   * If the user unstakes after the duration, they will get the staked amount plus the rewards
   */
  function unStake() external;

  function unStake() external override {
        StakeInfo storage stakeInfo = stakes[msg.sender];
        require(stakeInfo.amount > 0, "No active stake");

        uint256 reward = _calculateReward(msg.sender);
        uint256 amountToReturn = stakeInfo.amount;

        if (block.timestamp < stakeInfo.startTime + stakeInfo.duration) {
            reward = 0; // No reward if unstaking before the duration
        } else {
            rewards[msg.sender] = 0; // Reset reward if unstaking after duration
        }

        delete stakes[msg.sender];
        totalStaked -= amountToReturn;

        require(stakingToken.transfer(msg.sender, amountToReturn + reward), "Transfer failed");

        emit Unstaked(msg.sender, amountToReturn);
        if (reward > 0) emit RewardClaimed(msg.sender, reward);
    }

  /**
   * @notice Claim the rewards
   */
  function claimReward() external;

  function claimReward() external override {
        uint256 reward = _calculateReward(msg.sender);
        require(reward > 0, "No rewards available");

        rewards[msg.sender] = 0;

        require(stakingToken.transfer(msg.sender, reward), "Transfer failed");

        emit RewardClaimed(msg.sender, reward);
    }

  /**
   * @notice Get the total amount of tokens staked
   * @param _amount The amount of tokens to stake
   */
  function ownerDeposit(uint256 _amount) external;
}
