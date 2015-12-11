
local updateTime = 15 --0 or a small value will still wait for the current cycle to finish ( multithreading would help )
local width = 1920
local height = 1080
local numberOfThreads = 10 --this can eat cpu
local SAVE_ALL = false --save all (timestamped) images to %APPDATA%/Love/netmap, or just the most current (overwrite)

_DEBUG = false
_DEBUG_VERBOSE = false
_DEBUG_SKIP = false
_DEBUG_QUERY_LIMIT = 0

--Includes
ltc 	= require( "lTcpConnections")
http 	= require( "socket.http" )
json 	= require( "json" )
timer 	= require( "timer" )
http.TIMEOUT = 5

local httpRequestTTime = timer("http requests")
local drawMapTime = timer("map draw")
local totalUpdateTime = timer("map update")

local lastUpdate = -100
local mappedPoints = {}
local threads = {}
local connections = {}

Debugs = {}
Debugs["connection.new"] = false
Debugs["connection.coordinates"] = false

Debugs["response.raw"] = false
Debugs["response.late"] = false
Debugs["response.invalid"] = false

Debugs["table.filter"] = false
Debugs["table.filter.dump"] = false

function Debug(id, func, ...)
	if Debugs[id] then
		func(...)
	end
end

function table.print( t, n )
	n = n or "table"
	local str = "["..n.."]\n" 
	for k,v in pairs( t ) do
		str = str .. "\t["..k.."]=>"..tostring(v).."\n"
	end
	print(str)
end

function table.filter( t, filter, filter_func )
	filter_func = filter_func or function(k,v) return k end
	local t1 = {}
	Debug("table.filter", print, "filtering table")
	Debug("table.filter.dump", table.print, t, "table-before")
	Debug("table.filter.dump", table.print, filter, "filter")
	
	for k,v in pairs( filter ) do
		local i = filter_func(k,v)
		if t[i] then
			t1[i] = t[i]
			Debug("table.filter", print, "keeping: ["..k.."] "..i)
		else
			Debug("table.filter", print, "discarding: ["..k.."] "..i)
		end
	end
	Debug("table.filter.dump", table.print, t1, "table-after")
	
	return t1
end

function HSL(h, s, l)
   if s == 0 then return l,l,l end
   h, s, l = h/256*6, s/255, l/255
   local c = (1-math.abs(2*l-1))*s
   local x = (1-math.abs(h%2-1))*c
   local m,r,g,b = (l-.5*c), 0,0,0
   if h < 1     then r,g,b = c,x,0
   elseif h < 2 then r,g,b = x,c,0
   elseif h < 3 then r,g,b = 0,c,x
   elseif h < 4 then r,g,b = 0,x,c
   elseif h < 5 then r,g,b = x,0,c
   else              r,g,b = c,0,x
   end
   return math.ceil((r+m)*256),math.ceil((g+m)*256),math.ceil((b+m)*256)
end

function math.dist(x1,y1, x2,y2) return ((x2-x1)^2+(y2-y1)^2)^0.5 end
function math.angle(x1,y1, x2,y2) return math.atan2(x2-x1, y2-y1) end
function geoTo2D( longitude, latitude ) return (longitude + 180) * (width / 360), ((latitude * -1) + 90) * (height / 180); end
function generateColor() local r,g,b = HSL( math.random( 0, 360 ), math.random( 0, 150 ) + 100, math.random( 0, 150 ) + 100 ) return {r, g, b} end


if(_DEBUG_SKIP) then
	mappedPoints = {{ip="255.255.255.255", latitude="200", longitude="15"},
	{ip="255.255.255.255", latitude="15", longitude="35"}}
end
	
function love.load()
	earth_mask_shader = love.graphics.newShader("earth_mask_shader.frag")
	
	channel_in = love.thread.getChannel("downloaders_in")
	channel_out = love.thread.getChannel("downloaders_out")

	love.filesystem.setIdentity("netmap")
	
	mapColor = { 200, 200, 200 }
	mapImage = love.graphics.newImage( "map.png" )
	map = love.graphics.newCanvas( width, height )
	font = love.graphics.newFont(12)
	love.graphics.setLineWidth(2)
	love.graphics.setPointSize(5)
	
	scale_x = width  / mapImage:getWidth()
	scale_y = height / mapImage:getHeight()  
	
	local js = http.request('http://freegeoip.net/json/')
	client = decode(js)
	client_x, client_y = geoTo2D( client["longitude"], client["latitude"] )
	
	pathToAppdata = love.filesystem.getAppdataDirectory().."/LOVE/netmap/"
	
	createThreads( numberOfThreads )
end


function drawTick()
	drawMapTime:reset()
	drawMapTime:start()
	
	map:clear()
	love.graphics.setCanvas( map )
	
	love.graphics.setColor( mapColor )
	love.graphics.setShader(earth_mask_shader)
	love.graphics.draw( mapImage, 0, 0, 0, scale_x, scale_y )
	love.graphics.setShader()
	
	local count = 0
	for k,v in pairs(connections) do
		if not v.draw and v.data then
			local x,y = geoTo2D( v["data"]["longitude"], v["data"]["latitude"] )
			local distance = math.dist( client_x, client_y, x, y )
			local direction = math.angle( client_x, client_y, x, y )
			local r,g,b = generateColor()
			connections[k].draw = {x=x,y=y,distance=distance,direction=direction,r=r,g=g,b=b}
		end
		if not v.data then
			connections[k] = nil
		elseif v.draw then
			local e = v.draw
			--local segments = math.floor( distance / 10 )+1
			--local aoa = math.sin(direction)* 2*math.pi * segments
			
			love.graphics.setColor( e.r, e.g, e.b, 150 )
			love.graphics.point( e.x, e.y )
			love.graphics.line( client_x, client_y, e.x, e.y )
			love.graphics.setColor( e.r, e.g, e.b, 255 )
			love.graphics.print( string.format("%s", v["data"]["city"] or "N/A"), e.x, e.y )
			count = count + 1
		end
	end
	
	local dateTime = os.date("%Y-%m-%d %H:%M:%S")
	
	love.graphics.setColor(255,255,255,255)
	love.graphics.print( dateTime, 10, 10 )
	love.graphics.print( "Number of connections: "..#allConnections, 10, 24 )
	love.graphics.print( "Number of external connections: "..count, 10, 38 )
	love.graphics.print( "Number of http requests: "..#getURL, 10, 52 )
	love.graphics.print( httpRequestTTime:tostring(), 10, 66 )
	love.graphics.print( drawMapTime:tostring(), 10, 80 )
	love.graphics.print( totalUpdateTime:tostring(), 10, 94 )
	if totalUpdateTime:getTime() > updateTime then
		love.graphics.setColor( 255,50,50,255 )
		love.graphics.print( string.format("Time behind: %.4f seconds", totalUpdateTime:getTime()-updateTime), 10, 108 )
	end
	
	love.graphics.setCanvas()
	
	local file = string.format( "netmap %s.png", os.date("%Y-%m-%d_%H-%M-%S") )
	local filedir = pathToAppdata..file

	if SAVE_ALL then
		map:getImageData():encode(file)
	end
	map:getImageData():encode("current.png")
	
	print("Setting as wallpaper")
	--os.execute([["netmap\setWallpaper.bat"]])
	os.execute("cd")
	os.execute([[type NUL && "netmap\WallpaperChanger.exe" "%AppData%\LOVE\netmap/current.png" 4]])
	
	drawMapTime:stop()
end

getURL = {}

function get( uri )
	table.insert( getURL, uri )
end

function createThreads( n )
	for i=1, n do
		local t = love.thread.newThread( "downloader.lua" )
		table.insert( threads, {t,i} )
		threads[i][1]:start()
	end
end

function dispatcher()
	httpRequestTTime:reset()
	httpRequestTTime:start()
	
	local time = love.timer.getTime()
	
	--The reason for using feed-receive-process over feed-receive and process
	--was that I thought not clearing the pipe would cause corruption,
	--but in actual fact, there is nothing to feed, so there would be no /more/
	--data being fed and therefore no corruption. Meaning it's safer and more efficient
	--to use a single loop for receive-and-procces
	
	for k,v in pairs( getURL ) do --feed threads
		channel_in:push(v)
	end
	
	local received = 0
	while (	not ( _DEBUG_QUERY_LIMIT > 0 and received > _DEBUG_QUERY_LIMIT ) and
			not ( #getURL == received )) do -- no more threads to run
			--take cotton from threads
			--master/slave right?
			
		if channel_out:getCount()>0 then
			local response = channel_out:pop()
			received = received + 1
			
			Debug( "response.raw", print, response )
	
			local t = (string.sub(response, 0, 1) == "{") and decode(response) or nil --json curlie, something fucks up in the decorder otherwise
			if ( type(t) == "table" ) then
				
				if connections[t["ip"]] then
					connections[t["ip"]].data=t
					connections[t["ip"]].update=time
					Debug( "connection.coordinates", print, t["latitude"], t["longitude"] )
				else
					Debug( "response.late", print, "Response for "..t["ip"].." returned late!" )
				end
			else
				Debug( "response.invalid", print, "Exception, invalid data received:\n"..response )
			end
		end
	end
	
	httpRequestTTime:stop()
end

function getConnections()
	getURL = {}

	allConnections = ltc.getConnections()
	
	local time = love.timer.getTime()
	for k,v in pairs( allConnections ) do
		if not(string.match( v["remote"]["address"], '192%.168%.%d+%d-%d-%.%d+%d-%d-' ) 
			or string.match( v["remote"]["address"], '127%.%d+%d-%d-%.%d+%d-%d-%.%d+%d-%d-' ) 
			or v["remote"]["address"] == "255.255.255.255" ) then

			if (not connections[v["remote"]["address"]] and v["state"] == "Established") then --if not update/new connection
				Debug( "connection.new", print, "New connection: " .. v["remote"]["address"] )
				
				connections[v["remote"]["address"]]=v--create table
				get('http://freegeoip.net/json/'..v["remote"]["address"]) --GET
			--elseif  connections[v["remote"]["address"]["update"]] and ((connections[v["remote"]["address"]["update"]]+60) < time) then --if update
			--	get('http://freegeoip.net/json/'..v["remote"]["address"]) --GET, dont reset table!
			end
		else
			if _DEBUG then
				print("Discarding remote IP address: "..v["remote"]["address"])
			end
		end
	end
	
	connections = table.filter( connections, allConnections, function(k,v) return v.remote.address end )
	
	dispatcher()
end

function love.update(dt)
	if love.timer.getTime() > lastUpdate + updateTime then
		totalUpdateTime:reset()
		totalUpdateTime:start()
		lastUpdate = love.timer.getTime()
		startTime = lastUpdate
		
		if not _DEBUG_SKIP or not _DEBUG then
			getConnections()
		end
		
		drawTick()
		totalUpdateTime:stop()
	else
		love.timer.sleep(1)
	end
end

function love.draw()
	love.graphics.setColor(255,255,255)
	love.graphics.draw(map, 0, 0, 0, love.window.getWidth()/mapImage:getWidth(), love.window.getHeight()/mapImage:getHeight())
end