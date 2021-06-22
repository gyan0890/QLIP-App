//SPDX-License-Identifier: QLIPIT.io
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/ERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Counters.sol";


contract QLIPMarketplace is ERC721URIStorage{
	//maps tokenIds to item indexes
	using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
	mapping(uint256 => uint256) private itemIndex;
	mapping(uint256 => uint256) private salePrice;
	mapping(uint256=> NFTDet) public TokenDetails;

    struct NFTDet{
      uint256 _id;
      uint16 _category;
      string tokenURI_;
  }

	constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {

    }

	function setSale(uint256 tokenId, uint256 price) public {
		address owner = ownerOf(tokenId);
        require(owner != address(0), "setSale: nonexistent token");
        require(owner == msg.sender, "setSale: msg.sender is not the owner of the token");
		salePrice[tokenId] = price;
	}

	function buyTokenOnSale(uint256 tokenId) public payable {
		uint256 price = salePrice[tokenId];
        require(price != 0, "buyToken: price equals 0");
        require(msg.value == price, "buyToken: price doesn't equal salePrice[tokenId]");
		address payable owner = payable((ownerOf(tokenId)));
		approve(address(this), tokenId);
		salePrice[tokenId] = 0;
		transferFrom(owner, msg.sender, tokenId);
        owner.transfer(msg.value);
	}

	function mintWithIndex(address to, string memory tokenURI,uint16 _category) public  {
        
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
	
	//resolve this in the frontend
	function getTokenCategory(uint256 tokenId) public view returns(uint256){
	    return TokenDetails[tokenId]._category;
	}
	
	function getAllTokenDetails(uint256 tokenId) public view returns(NFTDet memory Details){
	    Details._id=TokenDetails[tokenId]._id;
	    Details._category=TokenDetails[tokenId]._category;
	    Details.tokenURI_=TokenDetails[tokenId].tokenURI_;
	}
}
