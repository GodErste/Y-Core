-- Generated from catalog/games.json by tools/catalog/sync.mjs.
--//Variables
local GameRegistry = {
	Default = "shinsei",
	PublicBaseUrl = "https://raw.githubusercontent.com/GodErste/Y-Core/main/",
	Games = {
		slayers2 = {
			Name = "Y Hub - Slayers 2",
			DisplayName = "Slayers 2",
			Version = "0.1.1",
			UpdatedAt = "2026-09-24",
			Entry = "games/Slayers2/init.lua",
			BundleName = "Slayers2.luau",
			BundleUrl = "https://raw.githubusercontent.com/GodErste/Y-Core-Builds/main/Slayers2.luau",
			Manifest = "games/Slayers2/Metadatas/Manifest.lua",
			PlaceIds = { 136406881576517, 75556147183481 },
		},
		bridger = {
			Name = "Y Hub - Bridger",
			DisplayName = "Bridger",
			Version = "0.1.4",
			UpdatedAt = "2026-09-25",
			Entry = "games/Bridger/init.lua",
			BundleName = "Bridger.luau",
			BundleUrl = "https://raw.githubusercontent.com/GodErste/Y-Core-Builds/main/Bridger.luau",
			Manifest = "games/Bridger/Metadatas/Manifest.lua",
			PlaceIds = { 133950099874787 },
		},
		shinsei = {
			Name = "Y Auto Signal",
			DisplayName = "Shinsei",
			Version = "0.1.0",
			UpdatedAt = "2026-09-22",
			Entry = "games/Shinsei/init.lua",
			BundleName = "Shinsei.luau",
			BundleUrl = "https://raw.githubusercontent.com/GodErste/Y-Core-Builds/main/Shinsei.luau",
			Manifest = "games/Shinsei/Metadatas/Manifest.lua",
			PlaceIds = { 136532079004320 },
		},
		shindolife = {
			Name = "Y Hub - Shindo Life",
			DisplayName = "Shindo Life",
			Version = "0.1.0",
			UpdatedAt = "2026-09-22",
			Entry = "games/ShindoLife/init.lua",
			BundleName = "ShindoLife.luau",
			BundleUrl = "https://raw.githubusercontent.com/GodErste/Y-Core-Builds/main/ShindoLife.luau",
			Manifest = "games/ShindoLife/Metadatas/Manifest.lua",
			PlaceIds = { 4616652839 },
		},
		gakuran = {
			Name = "Y Hub - Gakuran",
			DisplayName = "Gakuran",
			Version = "0.3.3",
			UpdatedAt = "2026-09-22",
			Entry = "games/Gakuran/init.lua",
			BundleName = "Gakuran.luau",
			BundleUrl = "https://raw.githubusercontent.com/GodErste/Y-Core-Builds/main/Gakuran.luau",
			Manifest = "games/Gakuran/Metadatas/Manifest.lua",
			PlaceIds = { 128736949265057 },
		},
	},
}

--//Source
function GameRegistry.NormalizeGameId(GameId)
	local Id = tostring(GameId or ""):lower()
	if Id == "ouwland" or Id == "slayers 2" then return "slayers2" end
	return Id == "bridge" and "bridger" or Id
end

function GameRegistry.GetGame(GameId)
	return GameRegistry.Games[GameRegistry.NormalizeGameId(GameId)]
end

function GameRegistry.FindByPlaceId(PlaceId)
	local Id = tonumber(PlaceId)
	if not Id then return nil end
	for GameId, Info in pairs(GameRegistry.Games) do
		for _, Registered in ipairs(Info.PlaceIds) do
			if Registered == Id then return GameId end
		end
	end
	return nil
end

return GameRegistry
