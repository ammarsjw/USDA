// SPDX-License-Identifier: GNU GPLv3

pragma solidity 0.8.17;

// import "./ERC20Upgradeable.sol";
import "./DividendPayingToken.sol";

// import "./OwnableUpgradeable.sol";
import "./PausableUpgradeable.sol";

// import "./SafeMathInt.sol";
// import "./SafeMathUpgradeable.sol";
import "./IterableMapping.sol";

import "./IUniswapV2Router02.sol";
import "./IUniswapV2Factory.sol";

contract USDA is OwnableUpgradeable, PausableUpgradeable, ERC20Upgradeable {

    USDADividendTracker public dividendTracker;

    IUniswapV2Router02 public uniswapV2Router;

    uint256 public botBlockingTime;

    uint256 public maxTransactionLimit;
    uint256 public maxWalletHolding;

    uint256 public buyIncentivePercentage;

    bool public isAutoProcess;
    uint256 public gasForProcessing;

    // internal storage

    /// @dev Addresses excluded from both max wallet holding and max transaction limits
    mapping (address => bool) private _isExcludedFromLimit;

    /// @dev Blacklisted from sending and recieving transactions
    mapping (address => bool) private _isBlacklisted;

    /// @dev Addresses included in blocking consecutive buy/sells
    mapping (address => bool) private _isIncludedInBotBlocking;

    /// @dev Timestamps for blocking consecutive buy/sells
    mapping (address => uint256) public getBotBlockings;

    /// @dev Pools
    mapping (address => bool) public automatedMarketMakerPairs;

    // events

    event UpdateDividendTracker(address indexed newAddress, address indexed oldAddress);

    event UpdateUniswapV2Router(address indexed newAddress, address indexed oldAddress);

    event UpdateBotBlockingTime(uint256 newBotBlockingTime, uint256 oldBotBlockingTime);

    event UpdateMaxTransactionLimit(uint256 newMaxTransactionLimit, uint256 oldMaxTransactionLimit);

    event UpdateMaxWalletHolding(uint256 newMaxWalletHolding, uint256 oldMaxWalletHolding);

    event UpdateBuyIncentivePercentage(uint256 newBuyIncentivePercentage, uint256 oldBuyIncentivePercentage);

    event UpdateIsAutoProcess(bool isAutoProcess);

    event GasForProcessingUpdated(uint256 newGas, uint256 oldGas);

    event ExcludeFromLimit(address account, bool isExcluded);

    event ExcludeMultipleAccountsFromLimit(address[] accounts, bool isExcluded);

    event BlackListAccount(address indexed account, bool isBlackListed);

    event BlackListMultipleAccounts(address[] accounts, bool isBlackListed);

    event IncludeInBotBlocking(address indexed account, bool isIncluded);

    event IncludeMultipleAccountsInBotBlocking(address[] accounts, bool isIncluded);

    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed state);

    event SendDividends(uint256 amount);

    event ProcessedDividendTracker(
    	uint256 iterations,
    	uint256 claims,
        uint256 lastProcessedIndex,
    	bool indexed automatic,
    	uint256 gas,
    	address indexed processor
    );

    // initialize

    function initialize() public initializer {
        __Ownable_init();
        __Pausable_init();
        __ERC20_init("USDA", "USDA", 6);

        dividendTracker = new USDADividendTracker();

        dividendTracker.initialize(address(this));

        // TODO mainnet
        // uniswapV2Router = IUniswapV2Router02();

        // TODO testnet
        uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

        // TODO
        maxTransactionLimit = 10_000 * (10 ** 6);
        maxWalletHolding = 1_000_000 * (10 ** 6);

        botBlockingTime = 5 minutes;

        gasForProcessing = 500_000;

        // exclude from both max wallet holding and max transaction limits
        excludeFromLimit(_msgSender(), true);
        excludeFromLimit(address(this), true);
        excludeFromLimit(address(dividendTracker), true);
        excludeFromLimit(address(uniswapV2Router), true);

        // exclude from receiving dividends
        dividendTracker.excludeFromDividends(_msgSender());
        dividendTracker.excludeFromDividends(address(this));
        dividendTracker.excludeFromDividends(address(dividendTracker));
        dividendTracker.excludeFromDividends(address(uniswapV2Router));

        // minting tokens for vesting
        _mint(_msgSender(), 100_000_000 * (10 ** 6));
    }

    function updateUniswapV2Router(address newAddress) public onlyOwner {
        require(newAddress != address(uniswapV2Router), "USDA: The router already has that address");
        emit UpdateUniswapV2Router(newAddress, address(uniswapV2Router));
        uniswapV2Router = IUniswapV2Router02(newAddress);
    }

    function updateDividendTracker(address newAddress) public onlyOwner {
        require(newAddress != address(dividendTracker), "USDA: The dividend tracker already has that address");

        USDADividendTracker newDividendTracker = USDADividendTracker(newAddress);

        require(newDividendTracker.owner() == address(this), "USDA: The new dividend tracker must be owned by the USDA token contract");

        // exclude all AMMs except for primary PancakePair manually
        newDividendTracker.excludeFromDividends(owner());
        newDividendTracker.excludeFromDividends(address(this));
        newDividendTracker.excludeFromDividends(address(newDividendTracker));
        newDividendTracker.excludeFromDividends(address(uniswapV2Router));

        emit UpdateDividendTracker(newAddress, address(dividendTracker));

        dividendTracker = newDividendTracker;
    }

    function updateBotBlockingTime(uint256 newBotBlockingTime) external onlyOwner {
        require(botBlockingTime != newBotBlockingTime, "USDA: Bot Blocking Time is already this value");
        emit UpdateBotBlockingTime(newBotBlockingTime, botBlockingTime);
        botBlockingTime = newBotBlockingTime;
    }

    function updateMaxTransactionLimit(uint256 newMaxTransactionLimit) external onlyOwner {
        require(maxTransactionLimit != newMaxTransactionLimit, "USDA: Max Transaction Limit is already this value");
        emit UpdateMaxTransactionLimit(newMaxTransactionLimit, maxTransactionLimit);
        maxTransactionLimit = newMaxTransactionLimit;
    }

    function updateMaxWalletHolding(uint256 newMaxWalletHolding) external onlyOwner {
        require(maxWalletHolding != newMaxWalletHolding, "USDA: Max Wallet Holding is already this value");
        emit UpdateMaxWalletHolding(newMaxWalletHolding, maxWalletHolding);
        maxWalletHolding = newMaxWalletHolding;
    }

    function updateBuyIncentivePercentage(uint256 newBuyIncentivePercentage) external onlyOwner {
        require(buyIncentivePercentage != newBuyIncentivePercentage, "USDA: Buy Incentive Percentage is alredy this value");
        emit UpdateBuyIncentivePercentage(newBuyIncentivePercentage, buyIncentivePercentage);
        buyIncentivePercentage = newBuyIncentivePercentage;
    }

    function updateIsAutoProcess(bool newIsAutoProcess) external onlyOwner {
        require(isAutoProcess != newIsAutoProcess, "USDA: Is Auto Process is already this state");
        isAutoProcess = newIsAutoProcess;
        emit UpdateIsAutoProcess(newIsAutoProcess);
    }

    function updateGasForProcessing(uint256 newGas) public onlyOwner {
        require(150000 <= newGas && newGas <= 900000, "USDA: gasForProcessing must be between 150,000 and 900,000");
        require(newGas != gasForProcessing, "USDA: gasForProcessing is already this value");
        emit GasForProcessingUpdated(newGas, gasForProcessing);
        gasForProcessing = newGas;
    }

    function isExcludedFromLimit(address account) public view returns (bool) {
        return _isExcludedFromLimit[account];
    }

    function excludeFromLimit(address account, bool excluded) public onlyOwner {
        require(_isExcludedFromLimit[account] != excluded, "USDA: Account is already the value of 'excluded'");
        _isExcludedFromLimit[account] = excluded;

        emit ExcludeFromLimit(account, excluded);
    }

    function excludeMultipleAccountsFromLimit(address[] calldata accounts, bool excluded) external onlyOwner {
        for(uint256 i = 0; i < accounts.length; i++) {
            _isExcludedFromLimit[accounts[i]] = excluded;
        }

        emit ExcludeMultipleAccountsFromLimit(accounts, excluded);
    }

    function isBlacklisted(address account) external view returns (bool) {
        return _isBlacklisted[account];
    }

    function blackListAccount(address account, bool blacklisted) external onlyOwner {
        require(_isBlacklisted[account] != blacklisted, "USDA: Account is already the value of 'blacklisted'");
        _isBlacklisted[account] = blacklisted;

        emit BlackListAccount(account, blacklisted);
    }

    function blackListMultipleAccounts(address[] calldata accounts, bool blacklisted) external onlyOwner {
        for(uint256 i = 0; i < accounts.length; i++) {
            _isBlacklisted[accounts[i]] = blacklisted;
        }

        emit BlackListMultipleAccounts(accounts, blacklisted);
    }

    function isIncludedInBotBlocking(address account) external view returns (bool) {
        return _isIncludedInBotBlocking[account];
    }

    function includeInBotBlocking(address account, bool included) external onlyOwner {
        require(_isIncludedInBotBlocking[account] != included, "USDA: Account is already the value of 'included'");
        _isIncludedInBotBlocking[account] = included;

        emit IncludeInBotBlocking(account, included);
    }

    function includeMultipleAccountsInBotBlocking(address[] calldata accounts, bool included) external onlyOwner {
        for(uint256 i = 0; i < accounts.length; i++) {
            _isIncludedInBotBlocking[accounts[i]] = included;
        }

        emit IncludeMultipleAccountsInBotBlocking(accounts, included);
    }

    function setAutomatedMarketMakerPair(address pair, bool value) public onlyOwner {
        require(automatedMarketMakerPairs[pair] != value, "USDA: Automated market maker pair is already set to that value");
        automatedMarketMakerPairs[pair] = value;

        if (value) {
            excludeFromLimit(pair, true);
            dividendTracker.excludeFromDividends(pair);
        }

        emit SetAutomatedMarketMakerPair(pair, value);
    }

    /* ========== DIVIDEND TRACKER FUNCTIONS ========== */

    function updateClaimWait(uint256 claimWait) external onlyOwner {
        dividendTracker.updateClaimWait(claimWait);
    }

    function getClaimWait() external view returns (uint256) {
        return dividendTracker.claimWait();
    }

    function getTotalDividendsDistributed() external view returns (uint256) {
        return dividendTracker.totalDividendsDistributed();
    }

    function withdrawableDividendOf(address account) public view returns (uint256) {
    	return dividendTracker.withdrawableDividendOf(account);
  	}

    function totalWithdrawableDividendOf(address account) public view returns (uint256) {
        return balanceOf(account) + dividendTracker.withdrawableDividendOf(account);
    }

    function dividendTokenBalanceOf(address account) public view returns (uint256) {
        return dividendTracker.balanceOf(account);
    }

    function getAccountDividendsInfo(address account) external view returns (
        address,
        int256,
        int256,
        uint256,
        uint256,
        uint256,
        uint256,
        uint256
    ) {
        return dividendTracker.getAccount(account);
    }

	function getAccountDividendsInfoAtIndex(uint256 index) external view returns (
        address,
        int256,
        int256,
        uint256,
        uint256,
        uint256,
        uint256,
        uint256
    ) {
        return dividendTracker.getAccountAtIndex(index);
    }

    function getLastProcessedIndex() external view returns (uint256) {
    	return dividendTracker.getLastProcessedIndex();
    }

    function getNumberOfDividendTokenHolders() external view returns (uint256) {
        return dividendTracker.getNumberOfTokenHolders();
    }

    function processDividendTracker(uint256 gas) external whenNotPaused {
		(uint256 iterations, uint256 claims, uint256 lastProcessedIndex) = dividendTracker.process(gas);
		emit ProcessedDividendTracker(iterations, claims, lastProcessedIndex, false, gas, tx.origin);
    }

    function claim() external whenNotPaused {
		dividendTracker.processAccount(_msgSender(), false);
    }

    /* ========== BOT BLOCKING HANDLER ========== */

    function _handleBotBlocking(address bot) internal {
        if (block.timestamp > getBotBlockings[bot] + botBlockingTime) {
            getBotBlockings[bot] = block.timestamp;
        }
        else {
            revert("USDA: Please wait a few minutes for consecutive exchanges");
        }
    }

    /* ========== HELPERS ========== */

    function _isBuy(address from) internal view returns (bool) {
        /// @dev Transfer from pair is a buy swap
        return automatedMarketMakerPairs[from];
    }

    function _isSell(address from, address to) internal view returns (bool) {
        /// @dev Transfer from non-router address to pair is a sell swap
        return from != address(uniswapV2Router) && automatedMarketMakerPairs[to];
    }

    /* ========== INTERNAL TRANSFER LOGIC ========== */

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        require(!_isBlacklisted[from], "USDA: Tranfer from a blacklisted address");
        require(!_isBlacklisted[to], "USDA: Tranfer to a blacklisted address");
        if (!_isExcludedFromLimit[from] && !_isExcludedFromLimit[to]) {
            require(amount <= maxTransactionLimit, "USDA: Transfer amount exceeds Max Transaction Limit");
            require(balanceOf(to) + amount <= maxWalletHolding, "USDA: Transfer amount will cause exceeds Max Wallet Holding");
        }

        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        bool isBuy = _isBuy(from);

        bool isSell = _isSell(from, to);

        if (isBuy) {
            if (_isIncludedInBotBlocking[to]) {
                _handleBotBlocking(to);
            }

            uint256 buyIncentive = (amount * buyIncentivePercentage) / 100;

            super._transfer(owner(), address(dividendTracker), buyIncentive);

            dividendTracker.distributeUSDADividends(buyIncentive);
        }

        if (isSell) {
            if (_isIncludedInBotBlocking[from]) {
                _handleBotBlocking(from);
            }
        }

        super._transfer(from, to, amount);

        if (isAutoProcess) {
            try dividendTracker.setBalance(from, balanceOf(from)) {
            } catch {}
            try dividendTracker.setBalance(to, balanceOf(to)) {
            } catch {}

            uint256 gas = gasForProcessing;

            try dividendTracker.process(gas) returns (uint256 iterations, uint256 claims, uint256 lastProcessedIndex) {
                emit ProcessedDividendTracker(iterations, claims, lastProcessedIndex, true, gas, tx.origin);
            } catch {}
        }
    }

    function mint(uint256 amount) external onlyOwner {
        _mint(owner(), amount);
    }

    function burn(uint256 amount) external whenNotPaused {
        _burn(_msgSender(), amount);
    }
}


contract USDADividendTracker is OwnableUpgradeable, PausableUpgradeable, DividendPayingToken {
    using SafeMathInt for int256;
    using SafeMathUpgradeable for uint256;
    using IterableMapping for IterableMapping.Map;

    IterableMapping.Map private tokenHoldersMap;
    uint256 public lastProcessedIndex;

    mapping (address => bool) public excludedFromDividends;

    mapping (address => uint256) public lastClaimTimes;

    uint256 public claimWait;
    uint256 public minimumTokenBalanceForDividends;

    event ExcludeFromDividends(address indexed account);

    event ClaimWaitUpdated(uint256 indexed newValue, uint256 indexed oldValue);

    event Claim(address indexed account, uint256 amount, bool indexed automatic);

    function initialize(address USDA_) public initializer {
        _transferOwnership(USDA_);
        __Pausable_init();
        __DividendPayingToken_init("USDA_Dividend_Tracker", "USDA_Dividend_Tracker", USDA_);

        claimWait = 1;
        minimumTokenBalanceForDividends = 1;
    }

    function _transfer(address, address, uint256) internal pure override {
        require(false, "USDA_Dividend_Tracker: No transfers allowed");
    }

    function withdrawDividend() public pure override {
        require(false, "USDA_Dividend_Tracker: withdrawDividend disabled. Use the 'claim' function on the main USDA contract.");
    }

    function excludeFromDividends(address account) external onlyOwner {
        require(!excludedFromDividends[account]);
        excludedFromDividends[account] = true;

        _setBalance(account, 0);
        tokenHoldersMap.remove(account);

        emit ExcludeFromDividends(account);
    }

    function updateClaimWait(uint256 newClaimWait) external onlyOwner {
        require(newClaimWait != claimWait, "USDA_Dividend_Tracker: Cannot update claimWait to same value");
        emit ClaimWaitUpdated(newClaimWait, claimWait);
        claimWait = newClaimWait;
    }

    function getLastProcessedIndex() external view returns (uint256) {
    	return lastProcessedIndex;
    }

    function getNumberOfTokenHolders() external view returns (uint256) {
        return tokenHoldersMap.keys.length;
    }

    function getAccount(address _account)
        public view returns (
            address account,
            int256 index,
            int256 iterationsUntilProcessed,
            uint256 withdrawableDividends,
            uint256 totalDividends,
            uint256 lastClaimTime,
            uint256 nextClaimTime,
            uint256 secondsUntilAutoClaimAvailable) {
        account = _account;

        index = tokenHoldersMap.getIndexOfKey(account);

        iterationsUntilProcessed = -1;

        if(index >= 0) {
            if(uint256(index) > lastProcessedIndex) {
                iterationsUntilProcessed = index.sub(int256(lastProcessedIndex));
            }
            else {
                uint256 processesUntilEndOfArray = tokenHoldersMap.keys.length > lastProcessedIndex ?
                                                        tokenHoldersMap.keys.length.sub(lastProcessedIndex) :
                                                        0;

                iterationsUntilProcessed = index.add(int256(processesUntilEndOfArray));
            }
        }

        withdrawableDividends = withdrawableDividendOf(account);
        totalDividends = accumulativeDividendOf(account);

        lastClaimTime = lastClaimTimes[account];

        nextClaimTime = lastClaimTime > 0 ?
                                    lastClaimTime.add(claimWait) :
                                    0;

        secondsUntilAutoClaimAvailable = nextClaimTime > block.timestamp ?
                                                    nextClaimTime.sub(block.timestamp) :
                                                    0;
    }

    function getAccountAtIndex(uint256 index)
        public view returns (
            address,
            int256,
            int256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256) {
    	if(index >= tokenHoldersMap.size()) {
            return (0x0000000000000000000000000000000000000000, -1, -1, 0, 0, 0, 0, 0);
        }

        address account = tokenHoldersMap.getKeyAtIndex(index);

        return getAccount(account);
    }

    function canAutoClaim(uint256 lastClaimTime) private view returns (bool) {
        if(lastClaimTime > block.timestamp)  {
            return false;
        }

    	return block.timestamp.sub(lastClaimTime) >= claimWait;
    }

    function setBalance(address account, uint256 newBalance) external onlyOwner {
        if(excludedFromDividends[account]) {
            return;
        }

        if(newBalance >= minimumTokenBalanceForDividends) {
            _setBalance(account, newBalance);
            tokenHoldersMap.set(account, newBalance);
        }
        else {
            _setBalance(account, 0);
            tokenHoldersMap.remove(account);
        }

        processAccount(account, true);
    }

    function process(uint256 gas) public whenNotPaused returns (uint256, uint256, uint256) {
        uint256 numberOfTokenHolders = tokenHoldersMap.keys.length;

        if(numberOfTokenHolders == 0) {
            return (0, 0, lastProcessedIndex);
        }

        uint256 _lastProcessedIndex = lastProcessedIndex;

        uint256 gasUsed = 0;

        uint256 gasLeft = gasleft();

        uint256 iterations = 0;
        uint256 claims = 0;

        while(gasUsed < gas && iterations < numberOfTokenHolders) {
            _lastProcessedIndex++;

            if(_lastProcessedIndex >= tokenHoldersMap.keys.length) {
                _lastProcessedIndex = 0;
            }

            address account = tokenHoldersMap.keys[_lastProcessedIndex];

            if(canAutoClaim(lastClaimTimes[account])) {
                if(processAccount(account, true)) {
                    claims++;
                }
            }

            iterations++;

            uint256 newGasLeft = gasleft();

            if(gasLeft > newGasLeft) {
                gasUsed = gasUsed.add(gasLeft.sub(newGasLeft));
            }

            gasLeft = newGasLeft;
        }

    	  lastProcessedIndex = _lastProcessedIndex;

    	  return (iterations, claims, lastProcessedIndex);
    }

    function processAccount(address account, bool automatic) public onlyOwner whenNotPaused returns (bool) {
        if (!canAutoClaim(lastClaimTimes[account])){
          return false;
        }

        uint256 amount = _withdrawDividendOfUser(account);

        if(amount > 0) {
            lastClaimTimes[account] = block.timestamp;
            emit Claim(account, amount, automatic);
            return true;
        }

    	return false;
    }
}