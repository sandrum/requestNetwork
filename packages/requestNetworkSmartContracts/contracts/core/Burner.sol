pragma solidity ^0.4.18;

import "../vendor/KyberNetwork.sol";


/// @title Contract for a burnable ERC
/// @dev From https://github.com/KyberNetwork/smart-contracts/blob/master/contracts/ERC20Interface.sol
/// @dev Added burn function
interface BurnableErc20 {
    function totalSupply() public view returns (uint supply);
    function balanceOf(address _owner) public view returns (uint balance);
    function transfer(address _to, uint _value) public returns (bool success);
    function transferFrom(address _from, address _to, uint _value) public returns (bool success);
    function approve(address _spender, uint _value) public returns (bool success);
    function allowance(address _owner, address _spender) public view returns (uint remaining);
    function decimals() public view returns(uint digits);
    event Approval(address indexed _owner, address indexed _spender, uint _value);

    function burn(uint _value) public;
}


/// @title A contract to burn ERC20 tokens from ETH
/// @notice Sends the ETH on the contract to kyber for conversion to ERC20
///  The converted ERC20 is then burned
/// @author Request Network
contract Burner {
    /// Kyber contract that will be used for the conversion
    KyberNetwork public kyberContract;

    // Contract for the ERC20
    BurnableErc20 public destErc20;

    /// @param _destErc20 Destination token
    /// @param _kyberContract Kyber contract to use
    function Burner(address _destErc20, address _kyberContract) public {
        // Check inputs
        require(_destErc20 != address(0));
        require(_kyberContract != address(0));

        destErc20 = BurnableErc20(_destErc20);
        kyberContract = KyberNetwork(_kyberContract);
    }
    
    /// Fallback function to receive the ETH to burn later
    function() public payable { }

    /// @dev Main function. Trade the ETH for ERC20 and burn them
    /// @param _maxSrcAmount Maximum amount of ETH to convert. If set to 0, all ETH on the
    ///  contract will be burned
    /// @param _maxDestAmount A limit on the amount of converted ERC20 tokens. Default value is MAX_UINT
    /// @param _minConversionRate The minimal conversion rate. Default value is 1 (market rate)
    /// @return amount of dest ERC20 tokens burned
    function burn(uint _maxSrcAmount, uint _maxDestAmount, uint _minConversionRate)
        external
        returns(uint)
    {
        // ETH to convert on Kyber, by default the amount of ETH on the contract
        // If _maxSrcAmount is defined, ethToConvert = min(balance on contract, _maxSrcAmount)
        uint ethToConvert = this.balance;
        if (_maxSrcAmount != 0 && _maxSrcAmount < ethToConvert) {
            ethToConvert = _maxSrcAmount;
        }

        // Set maxDestAmount to MAX_UINT if not sent as parameter
        uint maxDestAmount = _maxDestAmount != 0 ? _maxDestAmount : 2**256 - 1;

        // Set minConversionRate to 1 if not sent as parameter
        // A value of 1 will execute the trade according to market price in the time of the transaction confirmation
        uint minConversionRate = _minConversionRate != 0 ? _minConversionRate : 1;

        // Convert the ETH to ERC20
        // erc20ToBurn is the amount of the ERC20 tokens converted by Kyber that will be burned
        uint erc20ToBurn = kyberContract.trade.value(ethToConvert)(
            // Source. From Kyber docs, this value denotes ETH
            ERC20(0x00eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee),
            
            // Source amount
            ethToConvert,

            // Destination. Downcast BurnableErc20 to ERC20
            ERC20(destErc20),
            
            // destAddress: this contract
            this,
            
            // maxDestAmount
            maxDestAmount,
            
            // minConversionRate 
            minConversionRate,
            
            // walletId
            0
        );

        // Burn the converted ERC20 tokens
        destErc20.burn(erc20ToBurn);

        return erc20ToBurn;
    }
}
