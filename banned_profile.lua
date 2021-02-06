local steamworks = require 'gamesense/steamworks'
local http = require 'gamesense/http'
local js = panorama.open()

local ISteamFriends = steamworks.ISteamFriends

local BanCheck = { ui = {} }

BanCheck.init = function()
	local CurrentCheck, Started

	BanCheck.ui.enable = ui.new_checkbox('Lua', 'B', 'Delete Banned Friends')
	BanCheck.ui.delay = ui.new_slider('Lua', 'B', 'Delay', 100, 1000, 500, true, 'ms')
	BanCheck.ui.status = ui.new_label('Lua', 'B', 'Status: Idle')
	
	local StartStopToggle = function(status)
		ui.set_visible(BanCheck.ui.stop, not status)
		ui.set_visible(BanCheck.ui.start, status)
		Started = not status
	end

	local StartStop = function()
		if ( CurrentCheck and CurrentCheck.active and not CurrentCheck.finished and not CurrentCheck.stopped ) then
			ui.set(BanCheck.ui.status, 'Status: Stopped ' .. CurrentCheck.currentposition .. '/' .. CurrentCheck.totalcount .. '!')
			CurrentCheck:stop()
			StartStopToggle(true)
		elseif ( not CurrentCheck or ( CurrentCheck.active and CurrentCheck.finished ) or CurrentCheck.stopped ) then
			-- Finished / Not Started
			CurrentCheck = BanCheck.new()
			CurrentCheck.onUpdate = function()
				ui.set(BanCheck.ui.status, 'Status: Checking ' .. CurrentCheck.currentposition .. '/' .. CurrentCheck.totalcount .. '!')
			end
			CurrentCheck.onFinished = function()
				ui.set(BanCheck.ui.status, 'Status: Finished, unfriended ' .. CurrentCheck.bannedcount .. '/' .. CurrentCheck.totalcount .. ' accounts!')
				StartStopToggle(true)
			end
			CurrentCheck:start()

			StartStopToggle(false)
		end
	end

	BanCheck.ui.start = ui.new_button('Lua', 'B', 'Start', StartStop)
	BanCheck.ui.stop = ui.new_button('Lua', 'B', 'Stop', StartStop)

	local ShowUI = function(state)
		local State = type(state) == 'number' and ui.get(state) or type(state) == 'boolean' and state
		print(type(state), State)
		ui.set_visible(BanCheck.ui.delay, State)
		ui.set_visible(BanCheck.ui.status, State)
		ui.set_visible(BanCheck.ui.start, not ( CurrentCheck and Started ) and State)
		ui.set_visible(BanCheck.ui.stop, ( CurrentCheck and Started ) and State)
	end
	ShowUI(false)

	ui.set_callback(BanCheck.ui.enable, ShowUI)
end

BanCheck.new = function()
	local data = {}
	data.waiting = true
	data.active = false
	data.started = false
	data.finished = false
	data.stopped = false
	data.bannedcount = 0
	data.totalcount = 0
	data.currentposition = 0

	function data:start()
		self.waiting = false
		self.active = true
		self.started = true
		BanCheck.CheckAccounts(self)
	end

	function data:stop()
		self.stopped = true
		self.active = false
	end

	-- events
	data.onFinished = function() end
	data.onUpdate = function() end
	
	return data
end

BanCheck.CheckAccounts = function(data)
	local FriendCount = ISteamFriends.GetFriendCount(0x04)-1
	for i=0, FriendCount do
		local steamid = ISteamFriends.GetFriendByIndex(i, 0x04)
		data.totalcount = data.totalcount + 1
		client.delay_call(i * (BanCheck.ui.delay / 1000), function()
			if ( data.stopped ) then return end
			http.get('https://steamcommunity.com/profiles/' .. steamid:render_steam64(), function(success, response)
				if not success or response.status ~= 200 or data.stopped then return end
				data.currentposition = data.currentposition + 1

				if ( string.find(response.body, '<div class="profile_ban">') ) then
					ISteamFriends.RemoveFriend(steamid.steamid64)
					data.bannedcount = data.bannedcount + 1
				end
				
				data.onUpdate()
				
				if ( i == FriendCount ) then
					data.finished = true
					data.onFinished()
				end
			end)
		end)
	end

	data.onUpdate()
end

BanCheck.init()
