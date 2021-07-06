//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/ERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Counters.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/AccessControl.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/AccessControlEnumerable.sol";

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
  address payable public owner;


  event OwnershipRenounced(address indexed previousOwner);
  event OwnershipTransferred(
    address indexed previousOwner,
    address indexed newOwner
  );


  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  constructor() {
    owner = payable(msg.sender);
  }

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  /**
   * @dev Allows the current owner to relinquish control of the contract.
   */
  function renounceOwnership() public onlyOwner {
    emit OwnershipRenounced(owner);
    owner = payable(address(0));
  }

  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param _newOwner The address to transfer ownership to.
   */
  function transferOwnership(address payable _newOwner) public onlyOwner {
    _transferOwnership(_newOwner);
  }

  /**
   * @dev Transfers control of the contract to a newOwner.
   * @param _newOwner The address to transfer ownership to.
   */
  function _transferOwnership(address payable _newOwner) internal {
    require(_newOwner != address(0));
    emit OwnershipTransferred(owner, _newOwner);
    owner = _newOwner;
  }
}

/**
 * @title Pausable
 * @dev Base contract which allows children to implement an emergency stop mechanism.
 */
contract Pausable is Ownable {
  event Pause();
  event Unpause();

  bool public paused = false;


  /**
   * @dev Modifier to make a function callable only when the contract is not paused.
   */
  modifier whenNotPaused() {
    require(!paused);
    _;
  }

  /**
   * @dev Modifier to make a function callable only when the contract is paused.
   */
  modifier whenPaused() {
    require(paused);
    _;
  }

  /**
   * @dev called by the owner to pause, triggers stopped state
   */
  function pause() onlyOwner whenNotPaused public {
    paused = true;
    emit Pause();
  }

  /**
   * @dev called by the owner to unpause, returns to normal state
   */
  function unpause() onlyOwner whenPaused public {
    paused = false;
    emit Unpause();
  }
}

/**
 * @title Destructible
 * @dev Base contract that can be destroyed by owner. All funds in contract will be sent to the owner.
 */
contract Destructible is Ownable {

  constructor() payable { }

  /**
   * @dev Transfers the current balance to the owner and terminates the contract.
   */
  function destroy() onlyOwner public {
    selfdestruct(owner);
  }

  function destroyAndSend(address payable _recipient) onlyOwner public {
    selfdestruct(_recipient);
  }
}


contract QLIPAuction is Ownable, Pausable, Destructible, AccessControl {

    event SetSale(ERC721 nftAddress, uint256 tokenId, uint256 tokenPrice,address indexed biddingAddress);
    event TokenTransferred(address indexed owner, address indexed receiver, uint256 tokenId);
    
    struct Token {
        uint256 id;
        uint256 salePrice;
        bool active;
        
    }

    ERC721 public nftAddress;
    address payable nftOwner;
    address public admin;
    mapping(uint256 => uint256) private salePrice;
    mapping(uint256 => Token) public tokens;
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");
    
    //Holds a mapping between the tokenId and the bidding contract
    mapping(uint256 => Bidding) tokenBids;
    

    /**
    * @dev Contract Constructor
    */
    constructor() { 
        _setupRole(ADMIN_ROLE, msg.sender);
        admin = msg.sender;
    }

    function changeRole(address newAdmin) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "QLIPAuction: Only current admin can call this function");
        
        //Should we revoke older one and grant new one or have 2 admins for a fallback if required?
        grantRole(ADMIN_ROLE, newAdmin);
    }
    
    /**
     * @dev NFT Owner sets the price of the _tokenId to _price and the nftaddress is captured 
     * in the variable nftAddress
     */
    function setNFTDetailsForSale(uint256 _tokenId, address _nftAddress, uint256 _price) public {
        nftAddress = ERC721(_nftAddress);
        require(nftAddress.ownerOf(_tokenId) == msg.sender, "QLIPAuction: Only NFT Owner can set an NFT for sale");
        
        
        Token memory token;
		token.id = _tokenId;
		token.active = true;
		token.salePrice = _price;
		tokens[_tokenId] = token;
        
    }
    /**
     * @dev check the owner of a Token
     * @param _tokenId uint256 token representing an Object
     * Test function to check if the token address can be retrieved.
     */
    function getTokenSellerAddress(uint256 _tokenId) internal view returns(address) {
        address tokenSeller = nftAddress.ownerOf(_tokenId);
        return tokenSeller;
    }
    
    /**
     * @dev Sell _tokenId for price - called by QLIP Admin
     */
    function setSale(uint256 _tokenId, uint _biddingTime) public returns(address) {
		require(nftAddress.ownerOf(_tokenId) != address(0), "setSale: nonexistent token");
		require(hasRole(ADMIN_ROLE, msg.sender), "QLIPAuction: Only admin can set the token for sale");
		require(tokens[_tokenId].active == true, "Token As not up for sale");
		
        Token memory saleToken = tokens[_tokenId];
        
        nftOwner = payable(nftAddress.ownerOf(_tokenId));
		
		Bidding placeBids = new Bidding(_tokenId, _biddingTime, saleToken.salePrice, nftOwner, payable(admin));
		tokenBids[_tokenId] = placeBids;
    
        emit SetSale(nftAddress, _tokenId, saleToken.salePrice,address(placeBids));
        return(address(placeBids));
		
	} 

    /**
    * @dev Purchase _tokenId
    * @param _tokenId uint256 token ID representing an Object
    * Sends the extra bid amount to the charity address.
    */
    function transferToken(uint256 _tokenId) public whenNotPaused {
        require(msg.sender != address(0) && msg.sender != address(this));
        require(nftAddress.ownerOf(_tokenId) != address(0));
        require(tokens[_tokenId].active == true, "Token is not registered for sale!");
        
        require(hasRole(ADMIN_ROLE, msg.sender), "QLIPAuction: Only the admin can call this function");
        
        /*
        De-registering the token once it's purchased.
        */
        Token memory sellingToken = tokens[_tokenId];
        sellingToken.active = false;
        tokens[_tokenId] = sellingToken;
        address highestBidder;
        uint256 _amount;
               
        address tokenSeller = nftAddress.ownerOf(_tokenId);
        (highestBidder,_amount) = tokenBids[_tokenId].highestBidder();
        nftAddress.safeTransferFrom(tokenSeller, highestBidder, _tokenId);
        emit TokenTransferred(tokenSeller, highestBidder, _tokenId);
        
    }

    // SHOULD WE LET THE OWNER CHANGE THE PRICE OF THE TOKEN? - Maybe v2.0
    // function setCurrentPrice(uint256 _currentPrice) public onlyOwner {
    //     require(_currentPrice > 0);
    //     currentPrice = _currentPrice;
    // }  
    
    
    /*
    * @param _tokenId: Teokn ID to get the Bidding contract address
    */
    function getBiddingContractAddress(uint256 _tokenId) public view returns(address){
        require(hasRole(ADMIN_ROLE, msg.sender), "QLIPAuction: Only admin can call this function");
        return(address(tokenBids[_tokenId]));
    }

}

/* 
* This is the bidding contract 
*/

contract Bidding {
    // Parameters of the auction. Times are either
    // absolute unix timestamps (seconds since 1970-01-01)
    // or time periods in seconds.

    uint public auctionEnd;
    uint public tokenId;
    uint public reservePrice;
    uint bidCounter;
    address public highestBidAddress;
    uint public highestBid;
    address public admin;
    address public nftOwner;

    struct Bid {
        address payable bidder;
        uint bidAmount;
    }
   
    // Set to true at the end, disallows any change
    bool ended;
    
    // Recording all the bids
    mapping(uint => Bid) bids;


    // Events that  will be fired on changes.
    //event HighestBidIncreased(address bidder, uint amount);
    event AuctionEnded(address winner, uint amount);
    event newbid(address indexed bidder,uint256 amount);

    /*
    * Create a simple bidding contract
    * @param _tokenId: tokenId for which the bid is created
    * @param _biddingTime: Time period for the bidding to be kept open
    * @param _reservePrice: Minimum price set for the token
    */
    constructor(
       
        uint256 _tokenId,
        uint _biddingTime,
        uint _reservePrice,
        address payable _nftOwner,
        address payable _admin
    ) {
        reservePrice = _reservePrice;
        tokenId = _tokenId;
        bidCounter = 0;
        auctionEnd = block.timestamp + _biddingTime;
        //Explicitly setting the owner to our address for now
        // msg.sender is coming as the address of the contract
        nftOwner = _nftOwner;
        admin = _admin;
        
    }

    modifier onlyAdmin() {
        require(msg.sender == admin);
        _;
    }
    
    //ONLY FOR TESTING
    function getAdmin() public view returns(address){
      return admin;
    }   

    /// Bid on the auction with the value sent
    /// together with this transaction.
    /// The value will only be refunded if the
    /// auction is not won.
    function bid() public payable {
        // No arguments are necessary, all
        // information is already part of
        // the transaction. The keyword payable
        // is required for the function to
        // be able to receive Ether.

        // Revert the call if the bidding
        // period is over.
        require(
            block.timestamp <= auctionEnd,
            "Auction already ended."
        );

        // If the bid is not higher than 0, revert
        require(
            msg.value > 0,
            "You cannot bid 0 as the price."
        );

       Bid storage newBid = bids[bidCounter+1];
       newBid.bidder = payable(msg.sender);
       newBid.bidAmount = msg.value;
       emit newbid(msg.sender, msg.value);
       bidCounter++;
    }
    
    /*
    * Get the address and bid of the highest bidder
    */
    function highestBidder() onlyAdmin public returns(address,uint) {
        
        uint highestBidValue;
        
        //highestBidValue = bids[0].bidAmount;
        highestBidAddress = address(0);
        
        for(uint i = 0; i <= bidCounter ; i ++){
            
            if(bids[i].bidAmount > highestBidValue) {
                highestBid = bids[i].bidAmount;
                highestBidAddress = bids[i].bidder;
            }
                
        }
        
        return (highestBidAddress,highestBid);
        
    }
    
    
    /*
    * Get the highest bid amount
    * @param _highestBidder address of the highest bidder
    */
    function highestBidAmount(address _highestBidder) onlyAdmin public view returns(uint)  {
        
        for(uint i = 0; i <= bidCounter ; i ++){
            
            if(bids[i].bidder == _highestBidder) {
               return bids[i].bidAmount;
            }
                
        }
        return 0;
    }
    
    /*
    * Function to send the bidAmount to the NFT owner
    * @param _nftOwner: address of the NFT Owner
    */
     function sendMoneyToOwner(uint salePrice) onlyAdmin public {
        require(block.timestamp >= auctionEnd, "Auction not yet ended.");
        require(ended, "Auction end has not been called.");
        //Send the money to the nftOwner
        payable(nftOwner).transfer(salePrice);
        
    }

    /*
    * Function to send the royalty amount to the artist
    * @param _royalty: address of the royalty
    * @param _royaltyAmount: amount of money to be sent to the royalty
    */
    function sendRoyaltyMoney(address payable _royalty, uint _royaltyAmount) onlyAdmin public {
        require(block.timestamp >= auctionEnd, "Auction not yet ended.");
        require(ended, "Auction end has not been called.");
        _royalty.transfer(_royaltyAmount);
    }
    
    /*
    * Function to send a percentage cut to QLIPIt.io
    * @param _qlipAddress: QLIP Address
    * @param _qlipAmount: amount of money to be sent to QLIP
    */
    function sendQLIPMoney(uint _qlipAmount) onlyAdmin public {
        require(block.timestamp >= auctionEnd, "Auction not yet ended.");
        require(ended, "Auction end has not been called.");
        payable(admin).transfer(_qlipAmount);
    }
    
    /*
    * Withdraw bids that were not the winners.
    */
    function disperseFunds() onlyAdmin public returns (bool) {
        require(block.timestamp >= auctionEnd, "Auction not yet ended.");
        require(ended, "Auction end has not been called.");
        uint amount = 0;
        for(uint i = 0; i <= bidCounter; i ++){
            amount = bids[i].bidAmount;
            
            if(amount < 0){
                return false;
            }
          
            if(bids[i].bidder != highestBidAddress){
                
                bids[i].bidder.transfer(amount);
            }
            
        }
        return true;
    }
    
    /*
    * In case of an emergency, this function can be called to send all
    * the funds from the contract to the owner address.
    */
    function finalize() onlyAdmin public  {
        selfdestruct(payable(admin));
    }
    
    
    /* 
    * @param _charity - Address of the charity organisation chosen by the NFT Owner
    * End the auction and send the highest bid to the nftOwner.
    */
    function auctionEnded() onlyAdmin public {

        // 1. Conditions
        require(block.timestamp >= auctionEnd, "Auction not yet ended.");
        require(!ended, "auctionEnd has already been called.");

        // 2. Effects
        ended = true;

        // 3. Get the highest bidder and amount
        (highestBidAddress,highestBid) = highestBidder();
        
         //4. Send the money to the owner and the charity
        highestBid = highestBidAmount(highestBidAddress);
        
    }

    function geReservePrice() onlyAdmin  public view returns(uint){
      return reservePrice;
    }

    function getHighestBid() onlyAdmin public view returns(uint){
      require(ended, "Auction end has not been called.");
      return highestBid;
    }

}
