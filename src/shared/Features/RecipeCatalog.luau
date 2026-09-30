--!strict
-- 요리 레시피와 "먹기" 버프 수치. 서버(CampfireService)만 이 표를 보고 판정한다.

export type Recipe = {
	id: string,
	resultItemId: string,
	displayName: string,
	description: string,
	ingredients: { [string]: number }, -- ItemId -> 필요 개수
}

local RECIPES: { [string]: Recipe } = {
	recipe_grilled_fish = {
		id = "recipe_grilled_fish",
		resultItemId = "food_grilled_fish",
		displayName = "구운 생선",
		description = "배스 1마리를 모닥불에 구워요.",
		ingredients = { fish_bass = 1 },
	},
	recipe_mushroom_stew = {
		id = "recipe_mushroom_stew",
		resultItemId = "food_mushroom_stew",
		displayName = "버섯 스튜",
		description = "흰 버섯 2개를 끓여요.",
		ingredients = { mushroom_white = 2 },
	},
	recipe_flower_tea = {
		id = "recipe_flower_tea",
		resultItemId = "food_flower_tea",
		displayName = "꽃차",
		description = "해바라기 1송이를 우려내요.",
		ingredients = { flower_sunflower = 1 },
	},
	recipe_berry_pie = {
		id = "recipe_berry_pie",
		resultItemId = "food_berry_pie",
		displayName = "베리 파이",
		description = "찔레꽃 1송이와 황금 버섯 1개로 정성껏 구워요.",
		ingredients = { flower_rosehip = 1, mushroom_gold = 1 },
	},
}

local RECIPE_ORDER: { string } = {
	"recipe_grilled_fish",
	"recipe_mushroom_stew",
	"recipe_flower_tea",
	"recipe_berry_pie",
}

local RecipeCatalog = {}

RecipeCatalog.EAT_WALKSPEED_BONUS = 2
RecipeCatalog.EAT_BUFF_DURATION = 180 -- 초

function RecipeCatalog.Get(recipeId: string): Recipe?
	return RECIPES[recipeId]
end

function RecipeCatalog.GetAllInOrder(): { Recipe }
	local list: { Recipe } = {}
	for _, id in RECIPE_ORDER do
		local recipe = RECIPES[id]
		if recipe then
			table.insert(list, recipe)
		end
	end
	return list
end

return RecipeCatalog
