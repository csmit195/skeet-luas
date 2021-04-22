local steamworks = require "gamesense/steamworks"
local ISteamNetworking = steamworks.ISteamNetworking

local js = panorama.open()
local MyPersonaAPI = js.MyPersonaAPI
local PartyListAPI = js.PartyListAPI
local GameStateAPI = js.GameStateAPI

local EP2PSessionError = steamworks.EP2PSessionError
local EP2PSend = steamworks.EP2PSend

local Targets = {}
local Names = {} -- Cringe, but lazy
local IPs = {}

steamworks.set_callback("P2PSessionConnectFail_t", function(request) 
	local reason = tostring(EP2PSessionError[request.m_eP2PSessionError])
	if reason == 'Timeout' and IPs[request.m_steamIDRemote] and #IPs[request.m_steamIDRemote] == 0 then
		local steamid = tostring(request.m_steamIDRemote)
		local name = PartyListAPI.GetFriendName(ip)

    	print('[IP Grabber] ', name, ' (', steamid, ') seems to be blocking us.')
	end
end)

function Loop()
	for index, target in ipairs(Targets) do
		local success, result = ISteamNetworking.GetP2PSessionState(target)
		if result.m_nRemoteIP ~= 0 then
			IPs[target] = IPs[target] or {}
			local Exists = false
			for index, IP in ipairs(IPs[target]) do
				if IP == result.m_nRemoteIP then
					Exists = true
				end
			end
			if not Exists then
				table.insert(IPs[target], result.m_nRemoteIP)
			end
		end
	end
	client.delay_call(0.1, Loop)
end
Loop()

function intToIp(n)
    n = tonumber(n)
    local n1 = math.floor(n / (2^24)) 
    local n2 = math.floor((n - n1*(2^24)) / (2^16))
    local n3 = math.floor((n - n1*(2^24) - n2*(2^16)) / (2^8))
    local n4 = math.floor((n - n1*(2^24) - n2*(2^16) - n3*(2^8)))
    return n1.."."..n2..'.'..n3.."."..n4
end

client.set_event_callback("console_input", function(text)
	if text == 'lobby' then
		for index=0, PartyListAPI.GetCount()-1 do
			local SteamXUID = PartyListAPI.GetXuidByIndex(index)
			if SteamXUID:len() > 7 and SteamXUID ~= MyPersonaAPI.GetXuid() then
				local target = steamworks.SteamID(SteamXUID)
				
				print('[IP Grabber] ','queued target: ', SteamXUID)
				
				Targets[#Targets + 1] = target
				Names[target] = PartyListAPI.GetFriendName(SteamXUID)
				ISteamNetworking.SendP2PPacket(target, "asdf", 4, EP2PSend.UnreliableNoDelay, 0)
			end
		end
		print('[IP Grabber] ','wait for about 2-3 seconds. then use `grab`')
	end

    if text == 'grab' then
		for target, ips in pairs(IPs) do
			print('=== STEAMID: ', target, ' - ', Names[target], ' ===')
			for index, ip in ipairs(ips) do
				local LanOrWan = #ips == 1 and 'WAN: ' or ( index == 1 and 'LAN: ' or 'WAN: ' )
				print(LanOrWan, ' ', intToIp(ip))
			end
		end
		-- reset
		Targets = {}
		Names = {}
		IPs = {}
	end
end)