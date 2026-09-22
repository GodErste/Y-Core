--//Variables
local UILib = {}

local DEFAULT_REPOSITORY = "https://raw.githubusercontent.com/GodErste/YLib/refs/heads/main/"
local DEFAULT_CACHE_FOLDER = "Y Hub/UILibCache"

--//Source
local function getEnvironment()
	return (getgenv and getgenv()) or _G
end

local function ensureSlash(text)
	text = tostring(text or "")

	if text:sub(-1) ~= "/" then
		text = text .. "/"
	end

	return text
end

local function ensureFolder(folderPath)
	if typeof(makefolder) ~= "function" then
		return
	end

	local currentPath = ""

	for folderName in tostring(folderPath or ""):gmatch("[^/\\]+") do
		currentPath = currentPath == "" and folderName or (currentPath .. "/" .. folderName)
		pcall(makefolder, currentPath)
	end
end

local function readCachedSource(cacheFolder, fileName)
	if typeof(isfile) ~= "function" or typeof(readfile) ~= "function" then
		return nil
	end

	local filePath = tostring(cacheFolder or DEFAULT_CACHE_FOLDER) .. "/" .. tostring(fileName)
	local success, source = pcall(function()
		return isfile(filePath) and readfile(filePath) or nil
	end)

	if success and typeof(source) == "string" and #source > 64 then
		return source
	end

	return nil
end

local function writeCachedSource(cacheFolder, fileName, source)
	if typeof(writefile) ~= "function" or typeof(source) ~= "string" or #source <= 64 then
		return
	end

	cacheFolder = tostring(cacheFolder or DEFAULT_CACHE_FOLDER)
	ensureFolder(cacheFolder)
	pcall(writefile, cacheFolder .. "/" .. tostring(fileName), source)
end

local assetMethods = {
	Library = "CreateWindow",
	SaveManager = "BuildConfigSection",
	ThemeManager = "ApplyToTab",
}

local function fetchSource(url, timeout)
	local completed, success, result = false, false, nil
	task.spawn(function()
		success, result = pcall(function() return game:HttpGet(url) end)
		completed = true
	end)
	local deadline = os.clock() + math.clamp(tonumber(timeout) or 30, 5, 120)
	while not completed and os.clock() < deadline do task.wait(0.1) end
	-- A late native HTTP response must not initialize an abandoned UI load.
	if not completed then return false, "download timed out; check the connection and retry" end
	return success, result
end

function UILib.LoadAsset(globalName, fileName, config)
	config = config or {}
	local environment = getEnvironment()
	local requiredVersion = config.AssetVersion
	local function valid(value)
		return type(value) == "table" and type(value[assetMethods[globalName]]) == "function"
			and value.Unloaded ~= true and (not requiredVersion or value.Version == requiredVersion)
	end
	local previous = environment[globalName]
	if valid(previous) then
		return previous
	end
	if globalName == "Library" and type(previous) == "table" and type(previous.Unload) == "function" then
		pcall(previous.Unload, previous)
	end
	local repository = ensureSlash(config.Repository or DEFAULT_REPOSITORY)
	local cacheFolder = config.CacheFolder or DEFAULT_CACHE_FOLDER
	if requiredVersion then
		cacheFolder = cacheFolder .. "/" .. tostring(requiredVersion):gsub("[^%w%-_.]", "_")
	end
	local cachedSource = readCachedSource(cacheFolder, fileName)
	local lastError
	for attempt = 1, 2 do
		local source = attempt == 1 and cachedSource or nil
		local fromCache = source ~= nil
		if not source then
			local fetched, result = fetchSource(repository .. fileName, config.DownloadTimeout)
			if not fetched then
				error("UI download failed: " .. fileName .. ": " .. tostring(result), 2)
			end
			source = result
		end
		local ok, result = pcall(function()
			local chunk, compileError = loadstring(source, "@" .. fileName)
			assert(chunk, compileError)
			return chunk()
		end)
		if ok and valid(result) then
			if not fromCache then writeCachedSource(cacheFolder, fileName, source) end
			environment[globalName] = result
			return result
		end
		lastError = ok and "incompatible UI version or module" or tostring(result)
		if type(result) == "table" and type(result.Unload) == "function" then pcall(result.Unload, result) end
		if not cachedSource then break end
	end
	error("UI load failed: " .. fileName .. ": " .. tostring(lastError), 2)
end

function UILib.LoadStandard(config, input)
	local assets = {
		Library = UILib.LoadAsset("Library", "Library.lua", config),
		ThemeManager = UILib.LoadAsset("ThemeManager", "ThemeManager.lua", config),
		SaveManager = UILib.LoadAsset("SaveManager", "SaveManager.lua", config),
	}
	if input and type(assets.Library.SetInputProfile) == "function" then
		local library = assets.Library
		local disconnect = input:Observe(function(profile)
			if not library.Unloaded then library:SetInputProfile(profile) end
		end)
		library:GiveSignal({ Disconnect = disconnect })
	end
	return assets
end

function UILib.SafeNotify(library, message, duration)
	if library and typeof(library.Notify) == "function" then
		pcall(function()
			library:Notify(tostring(message), duration or 3)
		end)
	end
end

return UILib
