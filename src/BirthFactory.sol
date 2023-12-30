pragma solidity ^0.8.21;

import {GoldenCore} from "./GoldenCore.sol";

contract BirthFactory is GoldenCore {
    event BirthHen(uint256 henId, bool isOnSale);
    event BirthDog(uint256 dogId, bool isOnSale);
    event HenSaleStatus(uint256 henId, bool isOnSale);
    event DogSaleStatus(uint256 dogId, bool isOnSale);

    struct HenCharacter {
        uint256 layingCycle;
        uint256 consumeFoodForOneBlock;
        uint256 maxFoodIntake;
        uint256 unitEggToken;
        uint256 unitLitterToken;
        uint256 protectShellPeriod;
        uint256 purchaselimit;
        uint256 ethPrice;
        uint256 eggPrice;
        bool isOnSale;
    }

    struct DogCharacter {
        uint256 rewardPercentageMantissa;
        uint256 dumpPercentageMantissa;
        uint256 ethPrice;
        uint256 eggPrice;
        bool isOnSale;
    }
    // start from 1
    mapping(uint256 => HenCharacter) public hensCatalog;
    mapping(uint256 => DogCharacter) public dogsCatalog;

    uint256 totalHenCharacters;
    uint256 totalDogCharacters;

    /** owner only **/
    function createHen(
        uint256 _layingCycle,
        uint256 _consumeFoodForOneBlock,
        uint256 _maxFoodIntake,
        uint256 _unitEggToken,
        uint256 _unitLitterToken,
        uint256 _protectShellPeriod,
        uint256 _purchaseLimit,
        uint256 _ethPrice,
        uint256 _eggPrice,
        bool _isOnSale
    ) public onlyAdmin {
        totalHenCharacters++;
        hensCatalog[totalHenCharacters] = HenCharacter({
            layingCycle: _layingCycle,
            consumeFoodForOneBlock: _consumeFoodForOneBlock,
            maxFoodIntake: _maxFoodIntake,
            unitEggToken: _unitEggToken,
            unitLitterToken: _unitLitterToken,
            protectShellPeriod: _protectShellPeriod,
            purchaselimit: _purchaseLimit,
            ethPrice: _ethPrice,
            eggPrice: _eggPrice,
            isOnSale: _isOnSale
        });
        emit BirthHen(totalHenCharacters, _isOnSale);
    }

    function adjustHen(
        uint256 _henId,
        uint256 _layingCycle,
        uint256 _consumeFoodForOneBlock,
        uint256 _maxFoodIntake,
        uint256 _unitEggToken,
        uint256 _unitLitterToken,
        uint256 _protectShellPeriod,
        uint256 _purchaseLimit,
        uint256 _ethPrice,
        uint256 _eggPrice,
        bool _isOnSale
    ) public onlyAdmin {
        hensCatalog[_henId] = HenCharacter({
            layingCycle: _layingCycle,
            consumeFoodForOneBlock: _consumeFoodForOneBlock,
            maxFoodIntake: _maxFoodIntake,
            unitEggToken: _unitEggToken,
            unitLitterToken: _unitLitterToken,
            protectShellPeriod: _protectShellPeriod,
            purchaselimit: _purchaseLimit,
            ethPrice: _ethPrice,
            eggPrice: _eggPrice,
            isOnSale: _isOnSale
        });
    }

    function createDog(
        uint256 _rewardPercentage,
        uint256 _dumpPercentage,
        uint256 _ethPrice,
        uint256 _eggPrice,
        bool _isOnSale
    ) public onlyAdmin {
        totalDogCharacters++;
        dogsCatalog[totalDogCharacters].rewardPercentageMantissa = _rewardPercentage * 1e16;
        dogsCatalog[totalDogCharacters].dumpPercentageMantissa = _dumpPercentage * 1e16;
        dogsCatalog[totalDogCharacters].ethPrice = _ethPrice;
        dogsCatalog[totalDogCharacters].eggPrice = _eggPrice;
        dogsCatalog[totalDogCharacters].isOnSale = _isOnSale;
        emit BirthDog(totalDogCharacters, _isOnSale);
    }

    function adjustDog(
        uint256 _dogId,
        uint256 _rewardPercentage,
        uint256 _dumpPercentage,
        uint256 _ethPrice,
        uint256 _eggPrice,
        bool _isOnSale
    ) public onlyAdmin {
        dogsCatalog[_dogId].rewardPercentageMantissa = _rewardPercentage * 1e16;
        dogsCatalog[_dogId].dumpPercentageMantissa = _dumpPercentage * 1e16;
        dogsCatalog[_dogId].ethPrice = _ethPrice;
        dogsCatalog[_dogId].eggPrice = _eggPrice;
        dogsCatalog[_dogId].isOnSale = _isOnSale;
    }

    function setHenOnSale(uint256 _henId, bool _isOnSale) public onlyAdmin {
        checkHenExists(_henId);
        hensCatalog[_henId].isOnSale = _isOnSale;
        emit HenSaleStatus(_henId, _isOnSale);
    }

    function setDogOnSale(uint256 _dogId, bool _isOnSale) public onlyAdmin {
        checkDogExists(_dogId);
        dogsCatalog[_dogId].isOnSale = _isOnSale;
        emit DogSaleStatus(_dogId, _isOnSale);
    }

    function adjustHenTotalSupply(uint256 _totalSupply) public onlyAdmin {
        totalHenCharacters = _totalSupply;
    }

    function adjustDogTotalSupply(uint256 _totalSupply) public onlyAdmin {
        totalDogCharacters = _totalSupply;
    }

    function checkHenExists(uint256 _henId) internal view {
        require(_henId <= totalHenCharacters, "henId not exists");
    }

    function checkDogExists(uint256 _dogId) internal view {
        require(_dogId <= totalDogCharacters, "dogId not exists");
    }

}
