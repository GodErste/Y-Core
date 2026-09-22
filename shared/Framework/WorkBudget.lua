--//Variables
local WorkBudget = {}

--//Source
WorkBudget.Iterate = YHUB_NO_VIRTUALIZE(function(objects, canContinue, stats)
	LPH_ATTRIBUTES(VM(NONE))
	local started = os.clock()
	return YHUB_NO_VIRTUALIZE(function(_, key)
		LPH_ATTRIBUTES(VM(NONE))
		if canContinue and not canContinue() then return nil end
		local elapsed = os.clock() - started
		if elapsed >= 0.002 then
			if stats then
				stats.ScanYields = (stats.ScanYields or 0) + 1
				stats.MaxScanChunkMs = math.max(stats.MaxScanChunkMs or 0, elapsed * 1000)
			end
			task.wait()
			started = os.clock()
			if canContinue and not canContinue() then return nil end
		end
		return next(objects, key)
	end), nil, nil
end)

return WorkBudget
