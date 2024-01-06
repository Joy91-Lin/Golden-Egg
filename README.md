# Golden-Egg （偷雞摸狗）
#### Description
- Golden-Egg是一款模擬農場遊戲的GameFi。
- 玩家扮演農場主，通過養雞來獲得下蛋獎勵，在飼養的過程中獎勵會因為飢餓或環境髒亂而不下蛋。
- 玩家透過內部的攻擊遊戲向其他農場主發起進攻，偷取他們的獎勵並將垃圾丟到其農場。
- 玩家可以購買自己的幸運數字來抵禦其他農場主的攻擊。

**目標：維持農場的整潔、防禦數字、飼養雞、拜訪(aka攻擊)其他農場，體驗模擬農場經營的樂趣**。
#### Framework
- AdminControl：負責記錄Admin。
- Token：本專案共有3種token，繼承AdminControl。
  - EggToken：專案中的通用幣，可用來購物、餵食、養雞獎勵。
  - LitterToken：養雞成本(垃圾)，每個農場會垃圾桶，當垃圾集滿時雞就不會下蛋。
  - ProtectShellToken：養雞獎勵，在特定的下蛋次數後會得到的高級獎勵，可作為防護罩消耗保護農場。
- GoldenTop：負責記錄用戶資料、農場防禦數字，繼承AdminControl。
- BirthFactory：負責生產Hen、WatchDog並紀錄Hen、WatchDog型錄，繼承GoldenTop。
- ChickenCoop：每個雞舍最多20個位置，可以在已購買的位子上自由替換、飼養擁有的雞，或是去餵養其他農場正在下蛋的雞，並幫助雞產生獎勵，繼承 BirthFactory。
- WatchDog：負責看守農場，可以自由的替換擁有的狗、開啟防護罩，繼承 BirthFactory。
- AttackGame：進攻其他農場，成功攻擊者會從目標農場獲得部分獎勵(EggToken)並將農場中的部分垃圾(LitterToken)轉移到目標農場，目標農場會在被攻擊後開啟防護罩並另外得到ProtectShellToken作為補償，以上數值依據目標農場的看守狗計算。
- GoldenEgg：玩家進入遊戲點和購物商場，繼承 ChickenCoop, WatchDog。

#### Development
- Contract
  
    modify .env.example to .env
    ```
    PRIVATE_KEY = [YOUR_PRIVATE_KEY]
    OWNER = [YOUR_ADDRESS]
    ETHERSCAN_API_KEY = [YOUR_ETHERSCAN_API_KEY]
    ```
    
    execute forge script to deploy contract on Sepolia testnet
    ```
    forge script script/GoldenEgg.s.sol:GoldenEggScript --broadcast --verify --rpc-url https://eth-sepolia.g.alchemy.com/v2/{api_key} 
    ```

- Contract Address:
	- GoldenEgg:
	- AttackGame:
	- EggToken:
	- LitterToken:
	- ProtectShellToken:

#### Testing
+ GoldenEgg.t.sol
  - setUp() - user1, user2 進入遊戲，檢查獲得初始防禦數字和護甲
  - test_ownerAdmin() - 檢查Admin身份
  - test_entryGameInitValue - 檢查進入遊戲後初始數值，給予一隻雞和狗，並將雞上架飼養、上架狗。
  - test_checkUserJoinGame() - 檢查isAccountJoinGame()
  - test_feedHen() - 檢查餵食雞消耗的eggToken
#### Usage

+ 遊戲主軸
  - 飼養
    - 自由替換當前飼養的雞
    - 被動產出獎勵 (需被觸發)，會產出獎勵(eggToken/ProtectShellToken)及垃圾(LitterToken)
    - 餵食自己或他人正在飼養的雞
    - 垃圾桶滿時，雞就不會產生獎勵和垃圾，但仍會消耗已餵食的飼料
    - 雞飢餓時，即使有被放在雞舍的位子上，也不會產生獎勵
  - 購物
    - 購買雞 - 依據型錄id購買，有個別個購買上限
    - 購買看守狗 - 依據型錄id購買，不可重複購買
    - 購買防禦數字 - 指定購買數字，範圍為全部攻擊範圍，一次提供10點護甲值，不可重複購買，防禦數字最多數量為攻擊範圍的一半，在被攻擊狀態時不可執行。
    - 移除防禦數字 - 指定移除數字，在被攻擊狀態時不可執行。
    - 購買垃圾桶容量 - 指定購買容量個數(以10 ** 18單位加成)，單次購買單位不可超過上限
    - 購買農場飼養位子 - 
    - 
  - 看守
  - 攻擊
    - 有可能目標農場垃圾桶已滿，就不會再轉移攻擊者的垃圾到目標農場了

+ 初始玩家配置
  - 給予單位 3,000 個 EggToken (3000 * 10 ** 18)
  - 給予單位 300 個 ShellToken (300 * 10 ** 18) 
  - 購買一隻 id = 0 的雞
  - 購買一隻 id = 0 的狗
  - 一個帶有 10 點護甲值的隨機防護數字
  - 一個農場位子
  - 將購買的雞放上農場位子，滿腹飼料，開始飼養
  - 初始垃圾容量為1000個垃圾單位
  - 開啟新手防護罩 (250 個區塊時間)

