// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Định nghĩa smart contract cho sàn giao dịch
contract Exchange {
    HTK public htkToken; // Đối tượng đồng HTK
    LKK public lkkToken; // Đối tượng đồng KTK

    struct Trade {
        address seller; // Địa chỉ của người bán
        uint256 htkAmount; // Số lượng HTK muốn bán
        uint256 lkkPrice; // Giá đổi từ HTK sang KTK
    }
    
    struct TradeHistory {
        address buyer; // Địa chỉ của người mua
        address seller; // Địa chỉ của người bán
        uint256 htkAmount; // Số lượng HTK muốn bán
        uint256 lkkPrice; // Giá đổi từ HTK sang KTK
        uint256 timestamp; // thời gian
    }

    Trade[] public trades; // Danh sách các gói giao dịch
    TradeHistory[] public tradeHistory; //Lịch sử các gói giao dịch

    event TradeCreated(uint256 tradeId, address seller, uint256 htkAmount, uint256 lkkPrice);
    event TradeCompleted(uint256 tradeId, address seller, address buyer, uint256 htkAmount, uint256 ktkAmount);
    event TradeCancelled(uint256 tradeId, address seller);
    // Tạo một mapping để lưu trữ thông tin về gói HTK của người bán
    mapping(uint256 => uint256) public packageAmounts;

    constructor(address _htkToken, address _lkkToken) {
        htkToken = HTK(_htkToken);
        lkkToken = LKK(_lkkToken);
    }

    // Tạo một gói giao dịch mới
    function createTrade(uint256 _htkAmount, uint256 _lkkToken) external {
        require(htkToken.balanceOf(msg.sender) >= _htkAmount, "Insufficient HTK balance");

        // Chuyển số lượng HTK từ người bán vào sàn
        htkToken.transferFrom(msg.sender, address(this), _htkAmount);

        trades.push(Trade(msg.sender, _htkAmount, _lkkToken));
        
        uint256 tradeId = trades.length - 1;

        emit TradeCreated(tradeId, msg.sender, _htkAmount, _lkkToken);

        // Lưu trữ thông tin gói HTK vào mapping packageAmounts
        packageAmounts[tradeId] = _htkAmount;
    }

    // Lấy danh sách các gói giao dịch đang có trên sàn
    function getTrades() public view returns (uint256[] memory tradeIds, address[] memory sellers, uint256[] memory htkAmounts, uint256[] memory lkkPrices) {
        tradeIds = new uint256[](trades.length);
        sellers = new address[](trades.length);
        htkAmounts = new uint256[](trades.length);
        lkkPrices = new uint256[](trades.length);

        for (uint256 i = 0; i < trades.length; i++) {
            Trade storage trade = trades[i];
            tradeIds[i] = i;
            sellers[i] = trade.seller;
            htkAmounts[i] = trade.htkAmount;
            lkkPrices[i] = trade.lkkPrice;
        }

        return (tradeIds, sellers, htkAmounts, lkkPrices);
    }

    // Mua một gói giao dịch từ người bán
    function buyTrade(uint256 _tradeId) external {
        require(_tradeId < trades.length, "Invalid trade ID");
        Trade storage trade = trades[_tradeId];

        require(lkkToken.balanceOf(msg.sender) >= trade.lkkPrice, "Insufficient LKK balance");
        require(lkkToken.allowance(msg.sender, address(this)) >= trade.lkkPrice, "Insufficient allowance");

        // Chuyển số lượng KTK từ người mua vào sàn
        lkkToken.transferFrom(msg.sender, address(this), trade.lkkPrice);

        // Chuyển đồng HTK từ sàn cho người mua
        htkToken.transfer(msg.sender, trade.htkAmount);

        // Chuyển đồng KTK từ sàn cho người bán
        lkkToken.transfer(trade.seller, trade.lkkPrice);

        emit TradeCompleted(_tradeId, trade.seller, msg.sender, trade.htkAmount, trade.lkkPrice);

        delete trades[_tradeId];

        // lưu trữ thông tin giao dịch vào mảng tradeHistory
        tradeHistory.push(TradeHistory(msg.sender, trade.seller, trade.htkAmount, trade.lkkPrice, block.timestamp));
    }

    function cancelTrade(uint256 _tradeId) external {
        require(_tradeId < trades.length, "Invalid trade id");
        require(trades[_tradeId].seller == msg.sender, "Only the seller can cancel the trade");

        // Chuyển số HTK từ smart contract Exchange về người bán
        htkToken.transfer(trades[_tradeId].seller, packageAmounts[_tradeId]);

        // Xoá thông tin gói HTK từ mapping packageAmounts
        delete packageAmounts[_tradeId];

        // Xoá giao dịch từ mảng trades
        delete trades[_tradeId];

        // Gửi sự kiện thông báo rút gói thành công
        emit TradeCancelled(_tradeId, trades[_tradeId].seller);
    }

    function getHTKBalance() public view returns (uint256) {
        return htkToken.balanceOf(address(this));
    }

    function getKTKBalance() public view returns (uint256) {
        return lkkToken.balanceOf(address(this));
    }
    //hàm đổi kiểu thời gian Unix timestamp về dạng cụ thể
    function convertTimestamp(uint256 timestamp) internal pure returns (uint256 year, uint256 month, uint256 day, uint256 hour, uint256 minute, uint256 second) {
        year = uint256((timestamp / 31536000) + 1970);
        uint256 secondsRemaining = timestamp % 31536000;
        bool isLeapYear = ((year % 4 == 0) && (year % 100 != 0)) || (year % 400 == 0);
        if (isLeapYear && secondsRemaining >= 86400) {
            secondsRemaining -= 86400;
        }
        while (true) {
            uint256 secondsInMonth = isLeapYear ? 2505600 : 2419200;
            if (secondsRemaining < secondsInMonth) {
                break;
            }
            secondsRemaining -= secondsInMonth;
            month++;
        }
        month++;
        day = (secondsRemaining / 86400) + 1;
        secondsRemaining %= 86400;
        hour = secondsRemaining / 3600;
        secondsRemaining %= 3600;
        minute = secondsRemaining / 60;
        second = secondsRemaining % 60;
    }

    function getTradeHistory() public view returns (address[] memory buyers, address[] memory sellers, uint256[] memory htkAmounts, uint256[] memory lkkPrice, string[] memory timestamps) {
        buyers = new address[](tradeHistory.length);
        sellers = new address[](tradeHistory.length);
        htkAmounts = new uint256[](tradeHistory.length);
        lkkPrice = new uint256[](tradeHistory.length);
        timestamps = new string[](tradeHistory.length);

        for (uint256 i = 0; i < tradeHistory.length; i++) {
            buyers[i] = tradeHistory[i].buyer;
            sellers[i] = tradeHistory[i].seller;
            htkAmounts[i] = tradeHistory[i].htkAmount;
            lkkPrice[i] = tradeHistory[i].lkkPrice;

            uint256 year;
            uint256 month;
            uint256 day;
            uint256 hour;
            uint256 minute;
            uint256 second;
            (year, month, day, hour, minute, second) = convertTimestamp(tradeHistory[i].timestamp);

            timestamps[i] = string(abi.encodePacked(
                uint2str(hour), ":",
                uint2str(minute), ":",
                uint2str(second), " ",
                uint2str(day), "-",
                uint2str(month), "-",
                uint2str(year)
            ));
        }

        return (buyers, sellers, htkAmounts, lkkPrice, timestamps);
    }
    // thiết kế dịnh dạng
    function uint2str(uint256 num) internal pure returns (string memory str) {
        if (num == 0) {
            return "0";
        }
        uint256 j = num;
        uint256 length;
        while (j != 0) {
            length++;
            j /= 10;
        }
        bytes memory bstr = new bytes(length);
        uint256 k = length;
        while (num != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(num % 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            num /= 10;
        }
        str = string(bstr);
    }
}

contract HTK {
    string public name;
    string public symbol;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor() {
        name = "HoaToken";
        symbol = "HTK";
        totalSupply = 1000;
        balanceOf[msg.sender] = totalSupply;
        
    }

    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(_to != address(0), "Invalid address");
        require(balanceOf[msg.sender] >= _value, "Insufficient balance");

        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(_to != address(0), "Invalid address");
        require(balanceOf[_from] >= _value, "Insufficient balance");
        require(allowance[_from][msg.sender] >= _value, "Insufficient allowance");

        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        allowance[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value);
        return true;
    }
}

contract LKK {
    string public name;
    string public symbol;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor() {
        name = "LunKidToken";
        symbol = "LKK";
        totalSupply = 1000000;
        balanceOf[msg.sender] = totalSupply;
    }

    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(_to != address(0), "Invalid address");
        require(balanceOf[msg.sender] >= _value, "Insufficient balance");

        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(_to != address(0), "Invalid address");
        require(balanceOf[_from] >= _value, "Insufficient balance");
        require(allowance[_from][msg.sender] >= _value, "Insufficient allowance");

        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        allowance[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value);
        return true;
    }
}

