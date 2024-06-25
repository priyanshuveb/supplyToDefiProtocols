//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.2;

// 1. Write a contract for Polygon blockchain.
// 2. Users can deposit the funds - USDT, USDC, DAI, wBTC 
// 3. Based on the prevailing supply apr, the contract automatically identifies the pool(compound, aave, curve) with max return and forwards these funds to that pool.
// 4. You can batch the funds by value, or time.

// const blocksPerYear = 5 * 60 * 24 * 365; // 12 seconds per block
// const daysPerYear = 365;

// const cToken = new web3.eth.Contract(cZrxAbi, cZrxAddress);
// const supplyRatePerBlock = await cToken.methods.supplyRatePerBlock().call();
// const borrowRatePerBlock = await cToken.methods.borrowRatePerBlock().call();
// const supplyApr = supplyRatePerBlock / ethMantissa * blocksPerYear * 100;

interface ERC20 {
    function transfer(address to, uint256 amount) external;
    function approve(address spender, uint256 value) external returns(bool);
    function allowance(address owner, address spender) external returns(uint256);
}

interface compoundWrapper {
    function getUtilization() external view returns(uint256);
    function getSupplyRate(uint256 utilization) external view returns(uint64);
    function supply(address asset, uint256 amount)external;
    function supplyTo(address dst, address asset, uint amount) external;
}

interface aaveWrapper {
    function getReserveData(address token) external view returns(uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint40);
    function deposit(address token,uint256 value, address aTokenReceiver, uint16 referral) external;
}

// Adding it just for the reference, it is not available on the testnets to be queried
interface curveWrapper {
    function lend_apr() external view returns(uint256);
}

contract Lend {

    // Aave testnet deployed token addresses
    address public constant aUSDT = 0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0;
    address public constant aUSDC = 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8;
    address public constant aDAI = 0xFF34B3d4Aee8ddCd6F9AFFFB6Fe49bD371b8a357;
    address public constant aWBTC = 0x29f2D40B0605204364af54EC677bD022dA425d03;
    // Compound testnet USDC address
    address public constant cUSDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;

    mapping(address => bool) public aTokenLendingList;
    mapping(address => bool) public cTokenLendingList;

    // uint256 blocksPerYear = 5 * 60 * 24 * 365;
    // uint256 daysPerYear = 365;
    // uint256 ethMantissa = 1e18;
    uint256 constant secondsInYear = 365*24*60*60;

    constructor() {
        aTokenLendingList[aUSDT] = true;
        aTokenLendingList[aUSDC] = true;
        aTokenLendingList[aDAI] = true;
        aTokenLendingList[aWBTC] = true;
        cTokenLendingList[cUSDC] = true;
    }

    mapping(address => address[]) public shareTokenAddresses;

    // Value returned here can be converted to percent by dividing it by 100
    function getAPRCompoundUSDC() public view returns(uint256){
        uint256 utilization = compoundWrapper(0xAec1F48e02Cfb822Be958B68C7957156EB3F0b6e).getUtilization();
        uint64 supplyRate = compoundWrapper(0xAec1F48e02Cfb822Be958B68C7957156EB3F0b6e).getSupplyRate(utilization);
        uint256 apr = (supplyRate * secondsInYear * 10000)/1e18;
        return apr;
    }
    // Value returned here can be converted to percent by dividing it by 100
    function getAPRAave(address token) public view returns(uint256){
        (,,,,,uint256 liquidityRate,,,,,,) = aaveWrapper(0x3e9708d80f7B3e43118013075F7e95CE3AB31F31).getReserveData(token);
        uint256 apr = (liquidityRate * 10000)/1e27;
        //uint256 apr = (liquidityRate)/1e9;
        return apr;
    }
  
    // 1. Make sure user transfers the token funds to this contract
    // 2. Maintain a database for the above
    // 3.. Then call the deposit function giving user the rewards token
    function lendAave(address token, uint256 value) public {
        require(aTokenLendingList[token],"The token is not available for lending");
        ERC20(token).approve(0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951,value);
        require(ERC20(token).allowance(address(this),0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951)>=value,"Allowance not enough");
        aaveWrapper(0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951).deposit(token,value,msg.sender,0);
    }

    function lendCompound(address token, uint256 value) public {
        require(cTokenLendingList[token],"The token is not available for lending");
        ERC20(token).approve(0xAec1F48e02Cfb822Be958B68C7957156EB3F0b6e,value);
        require(ERC20(token).allowance(msg.sender,0xAec1F48e02Cfb822Be958B68C7957156EB3F0b6e)>=value,"Allowance not enough");
        compoundWrapper(0xAec1F48e02Cfb822Be958B68C7957156EB3F0b6e).supplyTo(msg.sender,token,value);
    }

}