//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/ERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Counters.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/AccessControl.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/AccessControlEnumerable.sol";

contract QLIPMarketplace is ERC721URIStorage, AccessControl{
	using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
	mapping(uint256 => uint256) private itemIndex;
	mapping(uint256 => uint256) private salePrice;
	mapping(uint256=> NFTDet) public TokenDetails;
    mapping(uint256 => NFTStateMapping) public NFTSTates;
	address public admin;
	
	enum NFTState {
	    MINTED,
	    ONSALE, 
	    SOLD, 
	    ARCHIVED
	}
	
	struct NFTDet{
      uint256 _id;
      uint16 _category;
      string tokenURI_;
  }
  
    struct NFTStateMapping {
        uint256 tokenId;
        NFTState nftState;
    }
    
    mapping(address => bool) QLIPMinters;
	
	NFTDet[] qlipNFTs;
	NFTStateMapping[] nftStates;
	
	
	modifier onlyAdmin() {
	    require(msg.sender == admin);
	    _;
	}

    
	constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {

        admin = msg.sender;
        
        //Need to fill this up based on Pinata
        //_setBaseURI("https://example.com/tokens/");
    }
    
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
    
    function whiteListQLIPMinters(address qlipMinter) public onlyAdmin {

        QLIPMinters[qlipMinter] = true;

    }
    

	function setSale(uint256 tokenId, uint256 price) public onlyAdmin {
	    //require(hasRole(ADMIN_ROLE, msg.sender), "QLIPMarketplace: Only the admin can set the token for sale");
		address owner = ownerOf(tokenId);
        require(owner != address(0), "setSale: nonexistent token");
        
        //Change the state of the minted NFT
        if(NFTSTates[tokenId].tokenId == 0) {
            NFTStateMapping memory nftStateChange = NFTStateMapping(tokenId, NFTState.ONSALE);
            NFTSTates[tokenId] = nftStateChange;
            nftStates.push(nftStateChange);
        }
        else {
            
            NFTStateMapping memory nftStateChange = NFTSTates[tokenId];
            nftStateChange.nftState = NFTState.ONSALE;
            NFTSTates[tokenId] = nftStateChange;
        }
		salePrice[tokenId] = price;
	}

	function buyTokenOnSale(uint256 tokenId) public payable {
		uint256 price = salePrice[tokenId];
        require(price != 0, "buyToken: price equals 0");
        require(msg.value == price, "buyToken: price doesn't equal salePrice[tokenId]");
		address payable owner = payable(address(uint160(ownerOf(tokenId))));
		approve(address(this), tokenId);
		salePrice[tokenId] = 0;
		
		NFTStateMapping memory nftStateChange = NFTSTates[tokenId];
        nftStateChange.nftState = NFTState.SOLD;
        NFTSTates[tokenId] = nftStateChange;
		
		transferFrom(owner, msg.sender, tokenId);
		uint256 qlipAmount = msg.value * (1 ether * 0.05);
		uint256 ownerAmount = msg.value - qlipAmount;
		address payable qlipAddress = payable(admin);
		
		//No royalty here, just flash sale and done!
		qlipAddress.transfer(qlipAmount);
        owner.transfer(ownerAmount);
	}

    function mintWithIndex(address to, string memory tokenURI,uint16 _category) public  {
       
        
        _tokenIds.increment();
        uint256 tokenId = _tokenIds.current();
        
        _mint(to, tokenId);
        
        TokenDetails[tokenId]._id=tokenId;
        TokenDetails[tokenId]._category=_category;
       _setTokenURI(tokenId, tokenURI);
         
        TokenDetails[tokenId].tokenURI_=tokenURI;
        
        NFTStateMapping memory nftStateChange = NFTStateMapping(tokenId,NFTState.MINTED);
        NFTSTates[tokenId] = nftStateChange;
        nftStates.push(nftStateChange);
        
        if(QLIPMinters[msg.sender] == true){
            qlipNFTs.push(TokenDetails[tokenId]);
        }
	}


	function getSalePrice(uint256 tokenId) public view returns (uint256) {
		return salePrice[tokenId];
	}
	
	
		function getAllTokenDetails(uint256 tokenId) public view returns(NFTDet memory Details){
	    Details._id=TokenDetails[tokenId]._id;
	    Details._category=TokenDetails[tokenId]._category;
	    Details.tokenURI_=TokenDetails[tokenId].tokenURI_;
	     //Here, we will set the metadata hash link of the token metadata from Pinata
        
	}
	
	    function getNFTState(uint256 tokenId) public view returns(NFTState) {
	        return NFTSTates[tokenId].nftState;
	    }
	    
	    function isQLIPMinted(address owner) public view returns(bool){
	        if(QLIPMinters[owner] == true){
	            return true;
	        }
	        else {
	            return false;
	        }
	    }
}
