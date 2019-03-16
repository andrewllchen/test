pragma solidity ^0.4.24;

/*
/* Copyright (c) 0xGwei All rights reserved.
/*
/* Private sale platform open source contract
/*
/* auther: otus@0xgwei.io
*/
library SafeMath {
    function add(uint a, uint b) internal pure returns (uint c) {
        c = a + b;
        require(c >= a);
    }

    function sub(uint a, uint b) internal pure returns (uint c) {
        require(b <= a);
        c = a - b;
    }

    function mul(uint a, uint b) internal pure returns (uint c) {
        c = a * b;
        require(a == 0 || c / a == b);
    }

    function div(uint a, uint b) internal pure returns (uint c) {
        require(b > 0);
        c = a / b;
    }
}

contract Owned {
    address public owner;
    address public newOwner;

    event OwnershipTransferred(address indexed _from, address indexed _to);

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address _newOwner) public onlyOwner {
        newOwner = _newOwner;
    }

    function acceptOwnership() public {
        require(msg.sender == newOwner);
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
        newOwner = address(0);
    }
}

contract Car is Owned {
    using SafeMath for uint;

	event ValueTooHigh(address _from, uint _max);

	uint limit;
	uint lowbound;
	uint ethBullet;
	uint donateRatio;
	uint captainRatio;
	uint donateTips;
	uint captainTips;
	bool privilegeStage;
	bool shipping;
	bool activate;
	address[] accountList;
	mapping(address => bool) validPassengers;
	mapping(address => bool) childCarAccountList;
	mapping(address => bool) VIPList;
	mapping(address => uint) ethers;
	string parentCar;

	constructor (uint _limit, uint _lowbound, uint tipsRatio, uint personTipRate, address[] whiteList) public {
		limit = _limit;
		lowbound = _lowbound;
		donateRatio = tipsRatio;
		captainRatio = personTipRate;
		ethBullet = 0;
		shipping = false;
		activate = true;
		parentCar = "";
		if (0 < whiteList.length) {
			privilegeStage = true;
			for (uint i = 0; i < whiteList.length; i++) {
				VIPList[whiteList[i]] = true;
			}
		} else {
			privilegeStage = false;
		}
	}

	modifier isActivate {
		require(true == activate);
        _;
	}

	modifier hasDepartured {
		require(true == shipping);
        _;
	}

	modifier inHarbor {
		require(false == shipping);
        _;
	}

	/* view function used for checking car's availability */
	function getCarState() public constant returns (bool) {
		return activate;
	}

	/* view function used for checking the number of passengers in this car */
	function getPassengerNum() public constant returns (uint) {
		return accountList.length;
	}

	/* view if the car is in VIP stage */
	function getPrivilegeState() public constant returns (bool) {
		return privilegeStage;
	}

	/* view function used for checking number of ethers in specific car */
	function getEthBullet() public constant returns (uint) {
		return ethBullet;
	}

	function setPrivilegeState(bool state) public onlyOwner inHarbor isActivate {
		privilegeStage = state;
	}

	function setShippingState() public onlyOwner inHarbor isActivate {
		shipping = true;
	}

	function setParentCar(string _carName) public onlyOwner inHarbor isActivate {
		parentCar = _carName;
	}

	function carGetInCar(address _carAddress, uint _childCarEth) public inHarbor isActivate {
		getInCar(_carAddress, _childCarEth);
		childCarAccountList[_carAddress] = true;
	}

	function getInCar(address _passengerAddress, uint _value) public payable inHarbor isActivate {
		if (true == privilegeStage) {
			require(true == VIPList[_passengerAddress]);
		}
		require(0 < _value);
		require(lowbound <= _value);
		require(limit >= (_value).add(ethBullet));
		// FIXME: take care of re get in car
		if (0 == ethers[_passengerAddress]) {
			accountList.push(_passengerAddress);
			validPassengers[_passengerAddress] = true;
		}
		donateTips = donateTips.add(((_value).mul(donateRatio)).div(10000));
		ethers[_passengerAddress] = ethers[_passengerAddress].add(_value);
		ethBullet = ethBullet.add(_value);
	}

	function getOutCar(uint value) public inHarbor isActivate {
		if (ethers[msg.sender] < value) {
			emit ValueTooHigh(msg.sender, ethers[msg.sender]);
			revert();
		}
		donateTips = donateTips.sub(((value).mul(donateRatio)).div(10000));
		ethers[msg.sender] = ethers[msg.sender].sub(value);
		// Only end customter would get there ethers back
		require(false == childCarAccountList[msg.sender]);
		(msg.sender).transfer(value);
	}

	function driveCar() public onlyOwner inHarbor isActivate {
		(msg.sender).transfer(ethBullet.sub(donateTips));
		setShippingState();
	}

	function destroyCar() public payable onlyOwner isActivate {
		for (uint i = 0; i < accountList.length; i++) {
			if (0 < ethers[accountList[i]]) {
				ethers[accountList[i]] = 0;
				if (false == shipping || ethBullet <= msg.value) {
					accountList[i].transfer(ethers[accountList[i]]);
				} else {
					accountList[i].transfer((ethers[accountList[i]].mul(msg.value)).div(ethBullet));
				}
			}
		}
		activate = false;
	}

	function returnToken(address tokenAddress, uint totalNum) public onlyOwner hasDepartured isActivate returns (uint) {
		for (uint i = 0; i < accountList.length; i++) {
			if (0 < ethers[accountList[i]]) {
				// ERC20 transfer
				if (true == tokenAddress.call(bytes4(keccak256("transfer(address,uint)")),accountList[i],totalNum.mul(ethers[accountList[i]]).div(ethBullet))) {
					ethers[accountList[i]] = 0;
				}
			}
		}
		activate = false;
		return donateTips;
	}
}

contract PrivateSalePlatform is Owned {
    using SafeMath for uint;

	event StateChange(bool _value, address _addr);
	event WithDraw(uint _value, address _addr);

	mapping(string => bool) Car_exist;
	mapping(string => Car) Cars;
	uint public PlatformFee;
	uint public Statistics_TotalContribution;
	uint public Statistics_SuccessfulServiceCount;
	uint public Statistics_Fellowship;
	bool public Frozen;
	string constant public version = "0.01";

	constructor() public {
		Statistics_TotalContribution = 0;
		PlatformFee = 0;
		Frozen = false;
	}

	modifier isActivate() {
		require(false == Frozen);
        _;
	}

	modifier carExist(string carName) {
		require(true == Car_exist[carName]);
        _;
	}

	function donate(uint _value) public payable {
		PlatformFee = PlatformFee.add(_value);
	}

	// we treat missent ether as donation
	function () public payable {
		donate(msg.value);
	}

	function setState(bool _value) public onlyOwner {
		require(Frozen != _value);
		Frozen = _value;
		emit StateChange(_value, msg.sender);
	}

	function withdraw(uint _value) public onlyOwner {
		require(0 < _value);
		require(PlatformFee >= _value);
		PlatformFee = PlatformFee.sub(_value);
		(msg.sender).transfer(_value);
		emit WithDraw(_value, msg.sender);
	}

	/* view function used for checking car's availability */
	function getCarState(string carName) public constant carExist(carName) returns (bool) {
		return Cars[carName].getCarState();
	}

	/* view if the car is in VIP stage */
	function getPrivilegeState(string carName) public constant carExist(carName) returns (bool) {
		return Cars[carName].getPrivilegeState();
	}

	/* view function used for checking number of ethers in specific car */
	function getEthBullet(string carName) public constant carExist(carName) returns (uint) {
		return Cars[carName].getEthBullet();
	}

	function register(string carName, uint lowbound, uint limit, uint tipsRatio, uint personTipRate, address[] whiteList) public {
		uint carLimit;

		require(false == Car_exist[carName]);
		require(10000 > tipsRatio);
		if (0 == limit) {
			carLimit = 2**256 - 1;
		}
		require(lowbound <= carLimit);
		// FIXME: take care of ownership and public function safety
		Cars[carName] = new Car(lowbound, carLimit, tipsRatio, personTipRate, whiteList);
		Car_exist[carName] = true;
	}

	function devoteToCar(string carName) public payable carExist(carName) {
		Cars[carName].getInCar(msg.sender, msg.value);
	}

	function getInParentCar(string srcCarName, string dstCarName) public carExist(srcCarName) carExist(dstCarName) {
		Cars[dstCarName].carGetInCar(msg.sender, Cars[srcCarName].getEthBullet());
	}

	function getOutCar(string carName, uint value) public payable carExist(carName) {
		Cars[carName].getOutCar(value);
	}

	function driveCar(string carName) public carExist(carName) {
		Cars[carName].driveCar();
	}

	function failCar(string carName) public payable carExist(carName) {
		Cars[carName].destroyCar();
		Car_exist[carName] = false;
	}

    /// @dev Internal function to determine if an address is a contract
    /// @param _addr The address being queried
    /// @return True if `_addr` is a contract
    function isContract(address _addr) internal constant returns(bool) {
        uint size;
        if (0 == _addr) {
            return false;
        }
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }

	function returnToken(string carName, address tokenAddress, uint totalNum) public carExist(carName) {
		require(isContract(tokenAddress));
		PlatformFee = PlatformFee.add(Cars[carName].returnToken(tokenAddress, totalNum));
		Statistics_TotalContribution = Statistics_TotalContribution.add(Cars[carName].getEthBullet());
	}
}
