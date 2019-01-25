pragma solidity ^0.4.21;

contract ERC875Interface {
    function trade(uint256 expiry, uint256[] tokenIndices, uint8 v, bytes32 r, bytes32 s) public payable;
    function passTo(uint256 expiry, uint256[] tokenIndices, uint8 v, bytes32 r, bytes32 s, address recipient) public;
    function name() public view returns(string);
    function symbol() public view returns(string);
    function getAmountTransferred() public view returns (uint);
    function balanceOf(address _owner) public view returns (uint256[]);
    function myBalance() public view returns(uint256[]);
    function transfer(address _to, uint256[] tokenIndices) public;
    function transferFrom(address _from, address _to, uint256[] tokenIndices) public;
    function approve(address _approved, uint256[] tokenIndices) public;
    function endContract() public;
    function contractType() public pure returns (string);
    function getContractAddress() public view returns(address);
 }

contract ERC875Auction 
{
    address public beneficiary;
    uint public biddingEnd;
    bool public ended;
    uint public minimumBidIncrement;
    address public holdingContract;
    uint256[] public contractIndices;

    mapping(address => uint) public bids;

    // Events that will be fired on changes.
    event HighestBidIncreased(address bidder, uint amount);
    event AuctionEnded(address winner, uint highestBid);

    address public highestBidder;
    uint public highestBid;

    modifier onlyBefore(uint _time) {require(now < _time); _;}
    modifier onlyAfter(uint _time) {require(now > _time); _;}
    modifier notBeneficiary(address addr) {require(addr != beneficiary); _;}
    modifier bidIsSufficientlyHiger(uint value) {require(value > (highestBid + minimumBidIncrement)); _;}
    modifier notAlreadyEnded() {require(ended == false); _;}
    modifier addressHasSufficientBalance(address bidder, uint value) {require(bidder.balance >= value); _;}
    modifier auctionHasEnded() {require(ended == true); _;}
    modifier organiserOrBeneficiaryOnly()
    {
        if(!(msg.sender == beneficiary || msg.sender == holdingContract)) revert();
        else _;
    }

    constructor(
        uint _biddingTime,
        address _beneficiary,
        uint _minBidIncrement,
        address _ERC875ContractAddr,
        uint256[] _tokenIndices
    ) public 
    {
        beneficiary = _beneficiary;
        biddingEnd = block.timestamp + _biddingTime;
        minimumBidIncrement = _minBidIncrement;
        ended = false;
        holdingContract = _ERC875ContractAddr;
        contractIndices = _tokenIndices;
    }

    // Auction participant submits their bid.
    // This only needs to be the value for this single use auction contract
    function bid(uint value)
        public
        onlyBefore(biddingEnd)
        notBeneficiary(msg.sender) // beneficiary can't participate in auction
        bidIsSufficientlyHiger(value) // bid must be <minimumBidIncrement> greater than the last one
        addressHasSufficientBalance(msg.sender, value) // check that bidder has the required balance
    {
        bids[msg.sender] = value;
        highestBid = value;
        highestBidder = msg.sender;
        emit HighestBidIncreased(highestBidder, highestBid);
    }

    // Contract can be killed at any time - note that no assets are held by the contract
    function endContract() public organiserOrBeneficiaryOnly
    {
        selfdestruct(beneficiary);
    }

    /// End the auction - called by the winner, send eth to the beneficiatiary and send ERC875 tokens to the highest bidder
    /// Can only be called by the winner, who must attach the ETH amount to the transaction
    function auctionEnd()
        public
        onlyAfter(biddingEnd)
        notAlreadyEnded() payable
    {
        require(!ended);
        require(msg.value >= highestBid);
        require(msg.sender == highestBidder);
        
        ERC875Interface tokenContract = ERC875Interface(holdingContract);
        
        //Atomic swap the ERC875 token(s) and the highestBidder's ETH 
        bool completed = tokenContract.transferFrom(beneficiary, highestBidder, contractIndices);
        //only have two outcomes from transferFromContract() - all tokenss are transferred or none (uses revert)
        if (completed) beneficiary.transfer(msg.value);

        ended = true;
        emit AuctionEnded(highestBidder, highestBid);
    }

    // Start new auction
    function startNewAuction(
        uint _biddingTime,
        address _beneficiary,
        uint _minBidIncrement,
        address _ERC875ContractAddr,
        uint256[] _tokenIndices) public
        auctionHasEnded()
    {
        beneficiary = _beneficiary;
        biddingEnd = block.timestamp + _biddingTime;
        minimumBidIncrement = _minBidIncrement;
        ended = false;
        holdingContract = _ERC875ContractAddr;
        contractIndices = _tokenIndices;
        bids.delete();
        highestBid = 0;
        highestBidder = 0;
    }
}
