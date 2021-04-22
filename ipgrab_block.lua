local steamworks = require "gamesense/steamworks"
local ISteamNetworking = steamworks.ISteamNetworking

local js = panorama.open()
local PartyListAPI = js.PartyListAPI

local EP2PSessionError = steamworks.EP2PSessionError

steamworks.set_callback("P2PSessionRequest_t", function(request)
	local name = PartyListAPI.GetFriendName(tostring(request.m_steamIDRemote))
	
    print('[POTENTIAL GRABBER] ', name, ' (', request.m_steamIDRemote, ') might be trying to steal your ip!')
	
	ISteamNetworking.CloseP2PSessionWithUser(request.m_steamIDRemote)
end)

steamworks.set_callback("P2PSessionConnectFail_t", function(request)
    print("P2PSessionConnectFail_t: ", tostring(request.m_steamIDRemote), " (", tostring(EP2PSessionError[request.m_eP2PSessionError]), ")")
end)