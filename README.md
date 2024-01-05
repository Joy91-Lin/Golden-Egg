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
- ChickenCoop：每個雞舍最多20個位置，可以在已購買的位子上自由替換、飼養擁有的雞，或是去餵養其他農場正在下蛋的雞，並幫助雞產生獎勵。
- WatchDog：負責看守農場、進攻其他農場，並可以自由的替換擁有的狗。
  - 看守
    - 可以利用ProtectShellToken去開啟農場防護罩防禦攻擊。
    - 若被進攻成功，會被偷走EggToken和被倒LitterToken，與此同時會依據watchDog的獎勵數值，給予ProtectShellToken補償。
  - 進攻
    - 進攻其他農場的防禦數字，若隨機進攻的數字被目標農場成功防禦(進攻失敗)，則會讓目標農場防禦數字掉一點護甲值
    - 若進攻成功，則會依據watchDog的數值獲得目標農場的EggToken並將自己的LitterToken垃圾倒到目標農場的垃圾桶
- GoldenEgg：玩家進入遊戲點和購物商場。

#### Development
- Contract
	
	Sepolia
  
    modify .env.example to .env
    ```
    PRIVATE_KEY = [YOUR_PRIVATE_KEY]
    OWNER = [YOUR_ADDRESS]
    ```
    modify foundry.toml.example to foundry.toml
    ```
    etherscan_api_key = [YOUR_ETHERSCAN_API_KEY]
    rpc_endpoints = {sepolia = [YOUR_RPC_URL]}
    ```
    execute forge script to deploy contract on Sepolia testnet
	```
	forge script script/GoldenEgg.s.sol:GoldenEggScript --broadcast --verify
	```

- Contract Address (Sepolia):
	- GoldenEgg:
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
