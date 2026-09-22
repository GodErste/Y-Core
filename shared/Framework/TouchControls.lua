--//Imports
local Maid = yrequire("shared/Framework/Maid.lua")

--//Variables
local TouchControls = {}
TouchControls.__index = TouchControls

--//Source
function TouchControls.new(app, library, actions, enabled)
	local self = setmetatable({ App = app, Library = library, Actions = actions,
		Enabled = enabled, Maid = Maid.new(), Buttons = {}, Touch = false }, TouchControls)
	for _, action in ipairs(actions) do
		self.Maid:Give(app.Input:Register(action.Id, action.Run))
	end
	self.Maid:Give(app.Input:Observe(function(profile)
		self.Touch = profile.Touch == true
		if self.Touch and not self.Holder then self:Create() end
		self:Refresh()
	end))
	self.Maid:Give(app.UI.Window.Holder:GetPropertyChangedSignal("Visible"):Connect(function() self:Refresh() end))
	return self
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
		self.Maid:Give(library:BindPress(button, function(input)
			if not library:IsPrimaryInput(input) or self.App.Destroyed then return end
			local ok, err = self.App.Input:Invoke(action.Id)
			if not ok then library:Notify("Action failed: " .. tostring(err), 4) end
			self:Refresh()
		end))
		self.Maid:Give(function() library:RemoveFromRegistry(button) end)
	end
	self.Maid:Give(library.SafeRoot:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		local size = library.SafeRoot.AbsoluteSize
		local point = holder.AbsolutePosition - library.SafeRoot.AbsolutePosition
		holder.Position = UDim2.fromOffset(math.clamp(point.X, 0, math.max(0, size.X - 284)) + 142,
			math.clamp(point.Y, 0, math.max(0, size.Y - 114)))
	end))
end

function TouchControls:Refresh()
	if not self.Holder then return end
	self.Holder.Visible = self.Touch and self.Enabled() and not self.Library.IsOpen and not self.App.Destroyed
	for index, action in ipairs(self.Actions) do
		self.Buttons[index].BackgroundColor3 = action.Active and action.Active()
			and self.Library.AccentColor or self.Library.BackgroundColor
	end
end

function TouchControls:Destroy()
	self.Maid:Cleanup()
	self.Holder = nil
	table.clear(self.Buttons)
end

return TouchControls
