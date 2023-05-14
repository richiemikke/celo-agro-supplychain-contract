// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SupplyChain is AccessControl {
    
    IERC20 private currencyToken; 

    bytes32 public constant PRODUCER_ROLE = keccak256("PRODUCER_ROLE");
    bytes32 public constant SHIPPER_ROLE = keccak256("SHIPPER_ROLE");
    bytes32 public constant BUYER_ROLE = keccak256("BUYER_ROLE");

    struct Product {
        string name;
        address producer;
        address shipper;
        address buyer;
        string origin;
        string location;
        uint256 price;
        bool isReceived;
        bool isPaid;
        bool isDisputed;
    }

    uint public productCount = 0;
    mapping(uint => Product) public products;
    mapping(address => bool) public verifiedUsers;

    event ProductCreated(
        uint productId,
        string name,
        address producer,
        string origin,
        uint256 price
    );

    event ProductShipped(
        uint productId,
        address shipper,
        string location
    );

    event ProductReceived(
        uint productId,
        address buyer
    );

    event PaymentTransferred(
        uint productId,
        address buyer,
        address producer,
        uint256 amount
    );

    event DisputeRaised(
        uint productId,
        address disputer
    );

    event DisputeResolved(
        uint productId
    );

    constructor(IERC20 _currencyToken) {
        currencyToken = _currencyToken;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function verifyUser(address user) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not an admin");
        verifiedUsers[user] = true;
    }

    function createProduct(string memory _name, string memory _origin, uint256 _price) public {
        require(hasRole(PRODUCER_ROLE, msg.sender), "Caller is not a producer");
        require(verifiedUsers[msg.sender], "Caller is not verified");

        productCount++;
        products[productCount] = Product(_name, msg.sender, address(0), address(0), _origin, _origin, _price, false, false, false);

        emit ProductCreated(productCount, _name, msg.sender, _origin, _price);
    }
    
    function shipProduct(uint _productId, string memory _location) public {
        require(hasRole(SHIPPER_ROLE, msg.sender), "Caller is not a shipper");
        require(verifiedUsers[msg.sender], "Caller is not verified");

        Product memory _product = products[_productId];
        require(_product.producer != address(0), "This product does not exist");
        require(_product.isReceived == false, "This product has already been received");
        require(_product.isPaid == true, "This product has not been paid for");
        require(_product.isDisputed == false, "This product is under dispute");

        _product.shipper = msg.sender;
        _product.location = _location;
        products[_productId] = _product;

        emit ProductShipped(_productId, msg.sender, _location);
    }
    
    function receiveProduct(uint _productId) public {
        require(hasRole(BUYER_ROLE,
        msg.sender), "Caller is not a buyer");
        require(verifiedUsers[msg.sender], "Caller is not verified");

        Product memory _product = products[_productId];
        require(_product.producer != address(0), "This product does not exist");
        require(_product.isReceived == false, "This product has already been received");
        require(_product.isPaid == true, "This product has not been paid for");
        require(_product.isDisputed == false, "This product is under dispute");

        _product.buyer = msg.sender;
        _product.isReceived = true;
        products[_productId] = _product;

        emit ProductReceived(_productId, msg.sender);
    }

    function payForProduct(uint _productId) public {
        Product memory _product = products[_productId];
        require(_product.producer != address(0), "This product does not exist");
        require(_product.isReceived == false, "This product has already been received");
        require(_product.isPaid == false, "This product has already been paid for");

        uint256 price = _product.price;
        require(currencyToken.balanceOf(msg.sender) >= price, "Insufficient balance to pay for this product");

        currencyToken.transferFrom(msg.sender, _product.producer, price);
        _product.isPaid = true;
        products[_productId] = _product;

        emit PaymentTransferred(_productId, msg.sender, _product.producer, price);
    }

    function raiseDispute(uint _productId) public {
        Product memory _product = products[_productId];
        require(_product.producer != address(0), "This product does not exist");
        require((_product.buyer == msg.sender || _product.producer == msg.sender), "Only buyer or producer can raise a dispute");
        require(_product.isDisputed == false, "This product is already under dispute");

        _product.isDisputed = true;
        products[_productId] = _product;

        emit DisputeRaised(_productId, msg.sender);
    }

    function resolveDispute(uint _productId) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not an admin");

        Product memory _product = products[_productId];
        require(_product.producer != address(0), "This product does not exist");
        require(_product.isDisputed == true, "This product is not under dispute");

        _product.isDisputed = false;
        products[_productId] = _product;

        emit DisputeResolved(_productId);
    }
}
