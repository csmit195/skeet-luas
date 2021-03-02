local steamworks = require 'gamesense/steamworks'
local http = require 'gamesense/http'
local js = panorama.open()

local ISteamFriends = steamworks.ISteamFriends

local BanCheck = { ui = {} }

BanCheck.initUI = function()
	BanCheck.ui.enable = ui.new_checkbox('Lua', 'B', 'Delete Banned Friends')
	BanCheck.ui.maximumDays = ui.new_slider('Lua', 'B', 'Maximum Days Since Ban', 0, 1000, 0, true, '', 1, {[0]='Infinite'})
	BanCheck.ui.status = ui.new_label('Lua', 'B', 'Status: Idle')
	
	BanCheck.ui.start = ui.new_button('Lua', 'B', 'Check', function()
		local CurrentCheck = BanCheck.new()
		CurrentCheck.onUpdate = function()
			ui.set(BanCheck.ui.status, 'Status: Checking ' .. CurrentCheck.currentposition .. '/' .. CurrentCheck.totalcount .. '!')
		end
		CurrentCheck.onFinished = function()
			ui.set(BanCheck.ui.status, 'Status: Finished, unfriended ' .. CurrentCheck.bannedcount .. ' accounts!')
		end
		CurrentCheck:start()
	end)

	local ShowUI = function(state)
		local State = type(state) == 'number' and ui.get(state) or type(state) == 'boolean' and State

		ui.set_visible(BanCheck.ui.status, State)
		ui.set_visible(BanCheck.ui.maximumDays, State)
		ui.set_visible(BanCheck.ui.start, State)
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
	local Steamids = {}

	for i=0, ISteamFriends.GetFriendCount(0x04)-1 do
		local Group = math.floor(i / 100)+1
		Steamids[Group] = Steamids[Group] or {}
		Steamids[Group][#Steamids[Group] + 1] = ISteamFriends.GetFriendByIndex(i, 0x04):render_steam64()

		data.totalcount = data.totalcount + 1
		data.onUpdate()
	end

	for GroupIndex, Group in ipairs(Steamids) do
		local steamidStr = table.concat(Group, ',')
		http.get('https://api.steampowered.com/ISteamUser/GetPlayerBans/v1/?key=' .. BanCheck.RandomWebKey() .. '&steamids=' .. steamidStr, function(success, response)
			if not success or response.status ~= 200 then return end
			local jsonData = json.parse(response.body)
			local MaximumDays = ui.get(BanCheck.ui.maximumDays)
			local InfiniteMaxDays = MaximumDays == 0
			if ( jsonData and jsonData.players ) then
				for index, Player in ipairs(jsonData.players) do
					data.currentposition = data.currentposition + 1
					if ( InfiniteMaxDays and (Player.NumberOfVACBans > 0 or Player.NumberOfGameBans > 0) ) then
						ISteamFriends.RemoveFriend(Player.SteamId)
						data.bannedcount = data.bannedcount + 1
					elseif ( ( Player.NumberOfGameBans > 0 and Player.NumberOfGameBans < MaximumDays ) or ( Player.NumberOfVACBans > 0 and Player.NumberOfVACBans < MaximumDays ) ) then
						ISteamFriends.RemoveFriend(Player.SteamId)
						data.bannedcount = data.bannedcount + 1
					end
					data.onUpdate()
					if ( data.currentposition == data.totalcount ) then
						data.onFinished()
					end
				end
			end
		end)
		
	end

	data.onUpdate()
end

local Keys = {
	'5DA40A4A4699DEE30C1C9A7BCE84C914',
	'5970533AA2A0651E9105E706D0F8EDDC',
	'2B3382EBA9E8C1B58054BD5C5EE1C36A'
}
local KeyIndex = 0
function BanCheck.RandomWebKey()
	KeyIndex = KeyIndex < #Keys and KeyIndex + 1 or 1
	return Keys[KeyIndex]
end

BanCheck.initUI()
