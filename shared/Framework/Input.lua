--//Variables
local Input = {}
Input.__index = Input

local function readProperty(object, name)
	local ok, value = pcall(function() return object[name] end)
	return ok and value or nil
end

local function inputFamily(inputType)
	local name = inputType and inputType.Name or ""
	if name == "Touch" then return "Touch" end
	if name:find("Gamepad", 1, true) then return "Gamepad" end
	return "KeyboardAndMouse"
end

--//Source
function Input.new(services)
	return setmetatable({
		Services = services,
		Actions = {},
		Bindings = {},
		Observers = {},
		Destroyed = false,
	}, Input)
end

function Input:GetProfile()
	local service = self.Services.UserInputService
	local preferred = readProperty(service, "PreferredInput")
	local touch = readProperty(service, "TouchEnabled") == true
	local keyboard = readProperty(service, "KeyboardEnabled") == true
	return {
		Touch = touch,
		Keyboard = keyboard,
		Mouse = readProperty(service, "MouseEnabled") == true,
		Gamepad = readProperty(service, "GamepadEnabled") == true,
		Preferred = preferred and preferred.Name or self.LastInputFamily or (touch and not keyboard and "Touch" or "KeyboardAndMouse"),
	}
end

function Input:Observe(callback)
	assert(not self.Destroyed, "input is destroyed")
	local token = {}
	self.Observers[token] = callback
	if not self.ProfileConnection then
		local service = self.Services.UserInputService
		local function changed(inputType)
			if inputType then self.LastInputFamily = inputFamily(inputType) end
			local profile = self:GetProfile()
			for _, observer in pairs(self.Observers) do pcall(observer, profile) end
		end
		local supported, connection = pcall(function()
			return service:GetPropertyChangedSignal("PreferredInput"):Connect(changed)
		end)
		self.ProfileConnection = supported and connection or service.LastInputTypeChanged:Connect(changed)
	end
	local ok, err = pcall(callback, self:GetProfile())
	if not ok then
		self.Observers[token] = nil
		if not next(self.Observers) and self.ProfileConnection then
			self.ProfileConnection:Disconnect()
			self.ProfileConnection = nil
		end
		error(err, 2)
	end
	return function()
		self.Observers[token] = nil
		if not next(self.Observers) and self.ProfileConnection then
			self.ProfileConnection:Disconnect()
			self.ProfileConnection = nil
		end
	end
end

function Input:Register(name, callback)
	assert(not self.Destroyed and type(name) == "string" and name ~= "", "invalid input action")
	assert(not self.Actions[name], "input action already registered: " .. name)
	local action = { Callback = callback }
	self.Actions[name] = action
	return function()
		if self.Actions[name] ~= action then return end
		self.Actions[name] = nil
		local binding = self.Bindings[name]
		if binding then binding() end
	end
end

function Input:Invoke(name, ...)
	local action = not self.Destroyed and self.Actions[name]
	if not action then return false, "action unavailable" end
	return pcall(action.Callback, ...)
end

-- Opt-in one-shot bindings. No game controls are bound or consumed by default.
function Input:Bind(name, options)
	assert(self.Actions[name], "input action not registered: " .. tostring(name))
	options = options or {}
	local previous = self.Bindings[name]
	if previous then previous() end
	local service = self.Services.ContextActionService
	local bindingName = "YHubAction:" .. self.Services.HttpService:GenerateGUID(false)
	local function activated(_, state)
		if state ~= Enum.UserInputState.Begin or self.Services.UserInputService:GetFocusedTextBox() then
			return Enum.ContextActionResult.Pass
		end
		local ok = self:Invoke(name, table.unpack(options.Arguments or {}))
		return ok and options.Consume == true and Enum.ContextActionResult.Sink or Enum.ContextActionResult.Pass
	end
	local cleanup
	cleanup = function()
		if self.Bindings[name] ~= cleanup then return end
		self.Bindings[name] = nil
		service:UnbindAction(bindingName)
	end
	self.Bindings[name] = cleanup
	local ok, err = pcall(function()
		service:BindAction(bindingName, activated, options.TouchButton == true, table.unpack(options.Keys or {}))
		if options.Title then service:SetTitle(bindingName, options.Title) end
		if options.Position then service:SetPosition(bindingName, options.Position) end
	end)
	if not ok then cleanup(); error(err, 2) end
	return cleanup
end

function Input:Destroy()
	if self.Destroyed then return end
	self.Destroyed = true
	for _, cleanup in pairs(self.Bindings) do cleanup() end
	if self.ProfileConnection then self.ProfileConnection:Disconnect(); self.ProfileConnection = nil end
	table.clear(self.Actions)
	table.clear(self.Observers)
end

return Input
