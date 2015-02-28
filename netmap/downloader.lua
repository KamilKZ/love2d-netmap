local http = require "socket.http"
require "love.timer"
http.TIMEOUT = 1

local channel1 = love.thread.getChannel( "downloaders_in" )
while true do
	if channel1:getCount()>0 then
		local uri = channel1:pop()
		if uri then
			local resp = http.request( uri ) or "Failed"

			local channel2 = love.thread.getChannel( "downloaders_out" )
			channel2:push( resp )	
		end
	else
		love.timer.sleep(1)
	end
end