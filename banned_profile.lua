local steamworks = require 'gamesense/steamworks'
local http = require 'gamesense/http'
local js = panorama.open()

local ISteamFriends = steamworks.ISteamFriends

local BanCheck = { ui = {} }

BanCheck.initWebAPIKey = function(callback)
	local Browser = panorama.loadstring([[
		let APIKey = '';

		const Browser = $.CreatePanel('HTML', $.GetContextPanel(), '', {
			url: 'https://steamcommunity.com/dev/apikey',
			acceptsinput: 'false',
			acceptsfocus: 'false',
			mousetracking: 'false',
			focusonhover: 'false',
			width: '100px',
			height: '100px',
		})
		Browser.visible = false

		let finish_handler = $.RegisterEventHandler('HTMLFinishRequest', Browser, function(a, url, title){
			if(url == 'https://steamcommunity.com/dev/apikey'){
				Browser.RunJavascript(`alert(jQuery('#bodyContents_ex > p:nth-child(2)').text().substr(5))`);
			}
		});

		let alert_handler = $.RegisterEventHandler('HTMLJSAlert', Browser, function(id, WebAPIKey){
			APIKey = WebAPIKey;

			$.UnregisterEventHandler('HTMLFinishRequest', Browser, finish_handler);
			Browser.DeleteAsync(0.0);
		});


		return {
			get_key: () => {
				return APIKey
			}
		}
	]], 'CSGOMainMenu')()

	function loopCheck()
		local Key = Browser.get_key()
		if ( Key:len() == 32 ) then
			callback(Key)
		else
			client.delay_call(0.1, loopCheck)
		end
	end
	loopCheck()
end

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
		http.get('https://api.steampowered.com/ISteamUser/GetPlayerBans/v1/?key=' .. BanCheck.APIKey .. '&steamids=' .. steamidStr, function(success, response)
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

BanCheck.initWebAPIKey(function(APIKey)
	BanCheck.APIKey = APIKey
	BanCheck.initUI()
end)
