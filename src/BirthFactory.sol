pragma solidity ^0.8.21;

import {GoldenTop} from "./GoldenTop.sol";

contract BirthFactory is GoldenTop {
    struct HenCharacter {
        uint256 layingCycle;
        uint256 consumeFoodForOneBlock;
        uint256 maxFoodIntake;
        uint256 unitEggToken;
        uint256 unitLitterToken;
        uint256 protectShellPeriod;
        uint256 unitShellToken;
        uint256 purchaselimit;
        uint256 ethPrice;
        uint256 eggPrice;
        bool isOnSale;
    }

    struct DogCharacter {
        uint256 compensationPercentageMantissa;
        uint256 lostPercentageMantissa;
        uint256 ethPrice;
        uint256 eggPrice;
        bool isOnSale;
    }
    mapping(uint256 => HenCharacter) hensCatalog;
    mapping(uint256 => DogCharacter) dogsCatalog;

    uint256 public totalHenCharacters = 0;
    uint256 public totalDogCharacters = 0;

    /** admin only **/
    // 產生新的雞
    function createHen(
        uint256 _layingCycle,
        uint256 _consumeFoodForOneBlock,
        uint256 _maxFoodIntake,
        uint256 _unitEggToken,
        uint256 _unitLitterToken,
        uint256 _protectShellPeriod,
        uint256 _unitShellToken,
        uint256 _purchaseLimit,
        uint256 _ethPrice,
        uint256 _eggPrice,
        bool _isOnSale
    ) public {
        onlyAdmin();
        uint256 henIndex = totalHenCharacters;
        hensCatalog[henIndex] = HenCharacter({
            layingCycle: _layingCycle,
            consumeFoodForOneBlock: _consumeFoodForOneBlock,
            maxFoodIntake: _maxFoodIntake,
            unitEggToken: _unitEggToken,
            unitLitterToken: _unitLitterToken,
            protectShellPeriod: _protectShellPeriod,
            unitShellToken: _unitShellToken,
            purchaselimit: _purchaseLimit,
            ethPrice: _ethPrice,
            eggPrice: _eggPrice,
            isOnSale: _isOnSale
        });
        totalHenCharacters++;
        emit BirthHen(henIndex, _isOnSale);
    }

    // 調整雞的參數
    function adjustHen(
        uint256 _henId,
        uint256 _layingCycle,
        uint256 _consumeFoodForOneBlock,
        uint256 _maxFoodIntake,
        uint256 _unitEggToken,
        uint256 _unitLitterToken,
        uint256 _protectShellPeriod,
        uint256 _unitShellToken,
        uint256 _purchaseLimit,
        uint256 _ethPrice,
        uint256 _eggPrice,
        bool _isOnSale
    ) public {
        onlyAdmin();
        hensCatalog[_henId] = HenCharacter({
            layingCycle: _layingCycle,
            consumeFoodForOneBlock: _consumeFoodForOneBlock,
            maxFoodIntake: _maxFoodIntake,
            unitEggToken: _unitEggToken,
            unitLitterToken: _unitLitterToken,
            protectShellPeriod: _protectShellPeriod,
            unitShellToken: _unitShellToken,
            purchaselimit: _purchaseLimit,
            ethPrice: _ethPrice,
            eggPrice: _eggPrice,
            isOnSale: _isOnSale
        });
    }

    // 產生新的狗
    function createDog(
        uint256 _compensationPercentage,
        uint256 _lostPercentage,
        uint256 _ethPrice,
        uint256 _eggPrice,
        bool _isOnSale
    ) public {
        onlyAdmin();
        uint256 dogIndex = totalDogCharacters;
        dogsCatalog[dogIndex].compensationPercentageMantissa = _compensationPercentage * 1e16;
        dogsCatalog[dogIndex].lostPercentageMantissa = _lostPercentage * 1e16;
        dogsCatalog[dogIndex].ethPrice = _ethPrice;
        dogsCatalog[dogIndex].eggPrice = _eggPrice;
        dogsCatalog[dogIndex].isOnSale = _isOnSale;
        totalDogCharacters++;
        emit BirthDog(dogIndex, _isOnSale);
    }

    // 調整狗的參數
    function adjustDog(
        uint256 _dogId,
        uint256 _compensationPercentage,
        uint256 _lostPercentage,
        uint256 _ethPrice,
        uint256 _eggPrice,
        bool _isOnSale
    ) public {
        onlyAdmin();
        dogsCatalog[_dogId].compensationPercentageMantissa = _compensationPercentage * 1e16;
        dogsCatalog[_dogId].lostPercentageMantissa = _lostPercentage * 1e16;
        dogsCatalog[_dogId].ethPrice = _ethPrice;
        dogsCatalog[_dogId].eggPrice = _eggPrice;
        dogsCatalog[_dogId].isOnSale = _isOnSale;
    }

    // // 調整雞總供應量
    // function adjustHenTotalSupply(uint256 _totalSupply) public {
    //     onlyAdmin();
    //     totalHenCharacters = _totalSupply;
    // }
    // // 調整狗總供應量
    // function adjustDogTotalSupply(uint256 _totalSupply) public {
    //     onlyAdmin();
    //     totalDogCharacters = _totalSupply;
    // }

    // 確認雞是否存在
    function checkHenExists(uint256 _henId) internal view {
        if(hensCatalog[_henId].layingCycle == 0 &&
            hensCatalog[_henId].consumeFoodForOneBlock == 0 
        ) revert InvalidHenId(_henId);
    }
    // 確認狗是否存在
    function checkDogExists(uint256 _dogId) internal view {
        if(dogsCatalog[_dogId].compensationPercentageMantissa == 0 && 
        dogsCatalog[_dogId].lostPercentageMantissa == 0) 
            revert InvalidDogId(_dogId);
    }

    /** struct HenCharacter **/
    function getHenCatalog(uint _henId) public view returns (HenCharacter memory){
        checkHenExists(_henId);
        return hensCatalog[_henId];
    }

    /** struct DogCharacter **/
    function getDogCatalog(uint _dogId) public view returns (DogCharacter memory){
        checkDogExists(_dogId);
        return dogsCatalog[_dogId];
    }
}
