--//Source
local StepRunner = {}
StepRunner.__index = StepRunner

function StepRunner.new(callback, onError)
	return setmetatable({
		Callback = callback,
		OnError = onError,
		Stats = { Frames = 0, FrameSeconds = 0, LongFrames = 0, Steps = 0, Skipped = 0,
			Errors = 0, SlowSteps = 0, MaxWallMs = 0, TotalWallMs = 0 },
	}, StepRunner)
end

StepRunner.Step = YHUB_NO_VIRTUALIZE(function(self, dt)
	LPH_ATTRIBUTES(VM(NONE))
	local stats = self.Stats
	stats.Frames += 1
	stats.FrameSeconds += dt
	if dt > 0.1 then stats.LongFrames += 1 end
	if self.Running then
		stats.Skipped += 1
		return false
	end
	self.Running = true
	local started = os.clock()
	self.StartedAt = started
	local ok, result = pcall(self.Callback, dt)
	local wallMs = (os.clock() - started) * 1000
	self.Running = false
	self.StartedAt = nil
	stats.Steps += 1
	stats.TotalWallMs += wallMs
	stats.MaxWallMs = math.max(stats.MaxWallMs, wallMs)
	if wallMs > 16.7 then stats.SlowSteps += 1 end
	if not ok then
		stats.Errors += 1
		stats.LastError = tostring(result)
		if self.OnError and (not self.LastErrorAt or os.clock() - self.LastErrorAt >= 10) then
			self.LastErrorAt = os.clock()
			pcall(self.OnError, result)
		end
	end
	return ok, result
end)

function StepRunner:Snapshot()
	local snapshot = table.clone(self.Stats)
	snapshot.RunningMs = self.StartedAt and (os.clock() - self.StartedAt) * 1000 or 0
	snapshot.AverageWallMs = snapshot.TotalWallMs / math.max(snapshot.Steps, 1)
	snapshot.AverageFps = snapshot.Frames / math.max(snapshot.FrameSeconds, 0.001)
	return snapshot
end

return StepRunner
