//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/ERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Counters.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/AccessControl.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/AccessControlEnumerable.sol";

contract QLIPMarketplace is ERC721URIStorage, AccessControl{
	//maps tokenIds to item indexes
	//maps tokenIds to item indexes
	using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
	mapping(uint256 => uint256) private itemIndex;
	mapping(uint256 => uint256) private salePrice;
	mapping(uint256=> NFTDet) public TokenDetails;
	address public admin;
	struct NFTDet{
      uint256 _id;
      uint16 _category;
      string tokenURI_;
  }
	
    //Setting the MINTER_ROLE as onlyMinter is deprecated 
    //in the recent Solidity releases
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");
    
	constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {
        _setupRole(ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        admin = msg.sender;
        
        //Need to fill this up based on Pinata
        //_setBaseURI("https://example.com/tokens/");
    }
    
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
    
    function whiteListMinters(address minter) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "QLIPMarketplace: Only admin can whitelist a minter");
        grantRole(MINTER_ROLE, minter);
    }
    
    
    function changeRole(address newAdmin) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "QLIPAuction: Only current admin can call this function");
        
        //Should we revoke older one and grant new one or have 2 admins for a fallback if required?
        grantRole(ADMIN_ROLE, newAdmin);
    }

	function setSale(uint256 tokenId, uint256 price) public {
	    require(hasRole(ADMIN_ROLE, msg.sender), "QLIPMarketplace: Only the admin can set the token for sale");
		address owner = ownerOf(tokenId);
        require(owner != address(0), "setSale: nonexistent token");
        require(owner == msg.sender, "setSale: msg.sender is not the owner of the token");
		salePrice[tokenId] = price;
	}

	function buyTokenOnSale(uint256 tokenId) public payable {
		uint256 price = salePrice[tokenId];
        require(price != 0, "buyToken: price equals 0");
        require(msg.value == price, "buyToken: price doesn't equal salePrice[tokenId]");
		address payable owner = payable(address(uint160(ownerOf(tokenId))));
		approve(address(this), tokenId);
		salePrice[tokenId] = 0;
		
		transferFrom(owner, msg.sender, tokenId);
		uint256 qlipAmount = msg.value * (1 ether * 0.05);
		uint256 ownerAmount = msg.value - qlipAmount;
		address payable qlipAddress = payable(admin);
		
		//No royalty here, just flash sale and done!
		qlipAddress.transfer(qlipAmount);
        owner.transfer(ownerAmount);
	}

    function mintWithIndex(address to, string memory tokenURI,uint16 _category) public  {
        require(hasRole(MINTER_ROLE, msg.sender), "QLIPMarketplace: Only whitelisted minters can mint a token");
        _tokenIds.increment();
        uint256 tokenId = _tokenIds.current();
        _mint(to, tokenId);
        TokenDetails[tokenId]._id=tokenId;
        TokenDetails[tokenId]._category=_category;
        
        //Here, we will set the metadata hash link of the token metadata from Pinata
        _setTokenURI(tokenId, tokenURI);
         TokenDetails[tokenId].tokenURI_=tokenURI;
	}


	function getSalePrice(uint256 tokenId) public view returns (uint256) {
		return salePrice[tokenId];
	}
	
	function getAllTokenDetails(uint256 tokenId) public view returns(NFTDet memory Details){
	    Details._id=TokenDetails[tokenId]._id;
	    Details._category=TokenDetails[tokenId]._category;
	    Details.tokenURI_=TokenDetails[tokenId].tokenURI_;
	}
}
