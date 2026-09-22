--//Imports
local DescendantIndex = {}
DescendantIndex.__index = DescendantIndex

--//Source
function DescendantIndex.new(root, accepts, property)
	local self = setmetatable({ Root = root, Items = {}, Positions = {}, Revision = 0,
		Changes = {}, PropertyConnections = {} }, DescendantIndex)
	local function add(item)
		if self.Root and not self.Positions[item] and item:IsDescendantOf(root) and accepts(item) then
			self.Items[#self.Items + 1] = item
			self.Positions[item] = #self.Items
			self.Revision += 1
			if property then
				self.Changes[item] = true
				self.PropertyConnections[item] = item:GetPropertyChangedSignal(property):Connect(function()
					if self.Positions[item] then self.Changes[item] = true end
				end)
			end
		end
	end

	self.Added = root.DescendantAdded:Connect(add)
	self.Removing = root.DescendantRemoving:Connect(function(item)
		local position = self.Positions[item]
		if not position then return end
		local last = self.Items[#self.Items]
		self.Items[position] = last
		self.Positions[last] = position
		self.Items[#self.Items] = nil
		self.Positions[item] = nil
		self.Changes[item] = nil
		local connection = self.PropertyConnections[item]
		if connection then connection:Disconnect() end
		self.PropertyConnections[item] = nil
		self.Revision += 1
	end)
	for _, item in ipairs(root:GetDescendants()) do
		add(item)
	end
	return self
end

function DescendantIndex:TakeChanges(limit)
	local items = {}
	for item in pairs(self.Changes) do
		self.Changes[item] = nil
		items[#items + 1] = item
		if #items >= limit then break end
	end
	return items
end

function DescendantIndex:Destroy()
	if self.Added then self.Added:Disconnect() end
	if self.Removing then self.Removing:Disconnect() end
	self.Added = nil
	self.Removing = nil
	self.Root = nil
	for _, connection in pairs(self.PropertyConnections) do connection:Disconnect() end
	table.clear(self.PropertyConnections)
	table.clear(self.Changes)
	table.clear(self.Items)
	table.clear(self.Positions)
end

return DescendantIndex
