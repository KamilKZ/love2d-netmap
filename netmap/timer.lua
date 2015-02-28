function timer(name)
	return {
	timer = name,
	startt = 0,
	seconadryStart = 0,
	stopt = 0,
	time = 0,
	running = false,
	isRunning = function(self)
		return self.running
	end,
	start = function(self)
		if self.startt == 0 then
			self.startt = love.timer.getTime()
		end
		self.seconadryStart = love.timer.getTime()
		self.running = true
	end,
	stop = function(self)
		self.stopt = love.timer.getTime()
		self.time = self:getTime()
		self.running = false
	end,
	getTime = function(self)
		if self.running then
			return self.time + ( love.timer.getTime() - self.seconadryStart )
		else
			return self.time
		end
	end,
	reset = function(self)
		self.startt = 0
		self.seconadryStart = 0
		self.stopt = 0
		self.time = 0
		self.running = false
	end,
	tostring = function(self)
		return string.format("Timer: %s, %.4f seconds", self.timer, self:getTime())
	end}
end

return timer