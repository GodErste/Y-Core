--//Imports
local Maid = yrequire("shared/Framework/Maid.lua")

--//Variables
local TouchControls = {}
TouchControls.__index = TouchControls

--//Source
function TouchControls.new(app, library, actions, enabled)
	local self = setmetatable({ App = app, Library = library, Actions = actions,
		Enabled = enabled, Maid = Maid.new(), Buttons = {}, Held = {}, Busy = {}, Touch = false }, TouchControls)
	for _, action in ipairs(actions) do
		self.Maid:Give(app.Input:Register(action.Id, action.Run))
	end
	self.Maid:Give(app.Input:Observe(function(profile)
		self.Touch = profile.Touch == true
		if self.Touch and not self.Holder then self:Create() end
		self:Refresh()
	end))
	self.Maid:Give(app.UI.Window.Holder:GetPropertyChangedSignal("Visible"):Connect(function() self:Refresh() end))
	self.Maid:Give(app.Services.UserInputService.InputEnded:Connect(function(input)
		for _, action in ipairs(self.Actions) do self:Release(action, input) end
	end))
	self.Maid:Give(app.Services.UserInputService.WindowFocusReleased:Connect(function() self:ReleaseAll() end))
	self.Maid:Give(app.Services.LocalPlayer.CharacterRemoving:Connect(function() self:ReleaseAll() end))
	return self
end

function TouchControls:Invoke(action, pressed)
	local ok, result, detail = self.App.Input:Invoke(action.Id, pressed)
	if not self.Destroyed and (not ok or (result == false and detail)) then
		self.Library:Notify(tostring(not ok and result or detail), 3)
	end
end

function TouchControls:Press(action, input)
	if self.Destroyed or self.App.Destroyed or not self.Holder or not self.Holder.Visible
		or not self.Library:IsPrimaryInput(input) or self.Held[action.Id] or self.Busy[action.Id]
		or (action.Visible and not action.Visible()) then return end
	if action.Hold then
		local held = { Input = input }
		self.Held[action.Id] = held
		held.Connection = input:GetPropertyChangedSignal("UserInputState"):Connect(function()
			local state = input.UserInputState
			if state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then self:Release(action, input) end
		end)
		self:Invoke(action, true)
	else
		self.Busy[action.Id] = true
		self:Invoke(action)
		self.Busy[action.Id] = nil
	end
	if not self.Destroyed then self:Refresh() end
end

function TouchControls:Release(action, input)
	local held = self.Held[action.Id]
	if not held or (input and input ~= held.Input) then return end
	self.Held[action.Id] = nil
	if held.Connection then held.Connection:Disconnect() end
	self:Invoke(action, false)
end

function TouchControls:ReleaseAll()
	for _, action in ipairs(self.Actions) do self:Release(action) end
end

function TouchControls:Layout()
	local holder = self.Holder
	local area = self.Library.SafeRoot
	local width = math.min(284, math.max(120, area.AbsoluteSize.X - 12))
	local columns = math.max(1, math.min(3, math.floor((width - 8) / 92)))
	local cell = (width - 12 - (columns - 1) * 4) / columns
	local count = 0
	for _, button in ipairs(self.Buttons) do
		if button.Visible then
			button.Size = UDim2.fromOffset(cell, 44)
			button.Position = UDim2.fromOffset(6 + (count % columns) * (cell + 4), 24 + math.floor(count / columns) * 48)
			count += 1
		end
	end
	local height = 28 + math.ceil(count / columns) * 48
	holder.Size = UDim2.fromOffset(width, height)
	local point = holder.AbsolutePosition - area.AbsolutePosition
	holder.Position = UDim2.fromOffset(math.clamp(point.X, 0, math.max(0, area.AbsoluteSize.X - width)) + width / 2,
		math.clamp(point.Y, 0, math.max(0, area.AbsoluteSize.Y - height)))
end

function TouchControls:Create()
	local library = self.Library
	local holder = library:Create("Frame", {
		Name = "QuickControls", Size = UDim2.fromOffset(284, 114),
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8),
		BackgroundColor3 = library.MainColor, BorderColor3 = library.OutlineColor,
		ZIndex = 60, Parent = library.SafeRoot,
	})
	self.Holder = holder
	library:AddToRegistry(holder, { BackgroundColor3 = "MainColor", BorderColor3 = "OutlineColor" })
	library:MakeDraggable(holder, 24)
	local title = library:CreateLabel({ Text = "Quick Controls", TextSize = 13,
		Size = UDim2.new(1, 0, 0, 24), ZIndex = 61, Parent = holder })
	self.Maid:Give(function()
		library:RemoveFromRegistry(title)
		library:RemoveFromRegistry(holder)
		holder:Destroy()
	end)
	for index, action in ipairs(self.Actions) do
		local button = library:Create("TextButton", {
			Name = action.Id, Text = action.Text, Font = library.Font, TextSize = 14,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = library.FontColor, BackgroundColor3 = library.BackgroundColor,
			BorderColor3 = library.OutlineColor, AutoButtonColor = false,
			Size = UDim2.fromOffset(88, 40),
			Position = UDim2.fromOffset(6 + ((index - 1) % 3) * 92, 24 + math.floor((index - 1) / 3) * 44),
			ZIndex = 61, Parent = holder,
		})
		library:AddToRegistry(button, { TextColor3 = "FontColor", BackgroundColor3 = function()
			return action.Active and action.Active() and library.AccentColor or library.BackgroundColor
		end, BorderColor3 = "OutlineColor" })
		library:AddToolTip(action.Tip or action.Text, button)
		self.Buttons[index] = button
		local function press(input) self:Press(action, input) end
		self.Maid:Give(action.Hold and button.InputBegan:Connect(press) or library:BindPress(button, press))
		self.Maid:Give(function() library:RemoveFromRegistry(button) end)
	end
	self.Maid:Give(library.SafeRoot:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:Layout()
	end))
end

function TouchControls:Refresh()
	if self.Destroyed or not self.Holder then return end
	self.Holder.Visible = self.Touch and self.Enabled() and not self.Library.IsOpen and not self.App.Destroyed
	if not self.Holder.Visible then self:ReleaseAll() end
	for index, action in ipairs(self.Actions) do
		self.Buttons[index].Visible = not action.Visible or action.Visible() == true
		if not self.Buttons[index].Visible then self:Release(action) end
		self.Buttons[index].BackgroundColor3 = action.Active and action.Active()
			and self.Library.AccentColor or self.Library.BackgroundColor
	end
	self:Layout()
end

function TouchControls:Destroy()
	if self.Destroyed then return end
	self.Destroyed = true
	self:ReleaseAll()
	self.Maid:Cleanup()
	self.Holder = nil
	table.clear(self.Buttons)
end

return TouchControls
