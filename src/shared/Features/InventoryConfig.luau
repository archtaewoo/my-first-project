--!strict
-- 인벤토리 총 용량 설정. "칸"이 아니라 아이템 총 개수 기준 상한이다.
-- 서버(PlayerData의 용량 검증)와 클라이언트(도감 상단 용량 표시)가 이 표 하나만 보고
-- 판단하도록 해서, 둘이 서로 다른 숫자를 쓰는 일이 없게 한다.
--
-- 수레 업그레이드(ShopCatalog: cart_basic -> cart_large)는 단계형이라 더 큰 수레를 가지고
-- 있으면 그 값만 적용한다(합산 아님). cart_large는 상점에서 cart_basic을 먼저 사야만
-- 살 수 있게 되어 있어(requires = "cart_basic"), 실제로는 둘 다 가지고 있는 상태가 보통이다.

local InventoryConfig = {}

InventoryConfig.BASE_CAPACITY = 50
InventoryConfig.CART_BASIC_UPGRADE_ID = "cart_basic"
InventoryConfig.CART_BASIC_CAPACITY = 100
InventoryConfig.CART_LARGE_UPGRADE_ID = "cart_large"
InventoryConfig.CART_LARGE_CAPACITY = 200

function InventoryConfig.CapacityFor(upgrades: { [string]: boolean }): number
	if upgrades[InventoryConfig.CART_LARGE_UPGRADE_ID] then
		return InventoryConfig.CART_LARGE_CAPACITY
	end
	if upgrades[InventoryConfig.CART_BASIC_UPGRADE_ID] then
		return InventoryConfig.CART_BASIC_CAPACITY
	end
	return InventoryConfig.BASE_CAPACITY
end

return InventoryConfig
