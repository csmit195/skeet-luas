local steamworks = require "gamesense/steamworks"
local ISteamMatchmaking = steamworks.ISteamMatchmaking

local js = panorama.open()
MyPersonaAPI = js.MyPersonaAPI
PartyListAPI = js.PartyListAPI

local P = panorama.loadstring([[
    let _ActionInviteFriend = FriendsListAPI.ActionInviteFriend;
    let Invites = [];
    
    FriendsListAPI.ActionInviteFriend = (xuid)=>{
        if ( !LobbyAPI.CreateSession() ) {
            LobbyAPI.CreateSession();
            PartyListAPI.SessionCommand('MakeOnline', '');
        }
        Invites.push(xuid);
    };

    return {
        get: ()=>{
            let inviteCache = Invites;
            Invites = [];
            return inviteCache;
        },
        old: (xuid)=>{
            _ActionInviteFriend(xuid);
        },
        shutdown: ()=>{
            FriendsListAPI.ActionInviteFriend = _ActionInviteFriend;
        }
    }
]])()

local function InvitePlayer(xuid)
    local lobby = ISteamMatchmaking.GetLobbyID()
    if lobby ~= nil then
        PartyListAPI.SessionCommand('Game::ChatInviteMessage', string.format('run all xuid %s %s %s', MyPersonaAPI.GetXuid(), 'friend', xuid))
        ISteamMatchmaking.InviteUserToLobby(lobby, xuid)
    else
        client.delay_call(0.1, InvitePlayer, xuid)
    end
end

local function InviteLoop()
    local Invites = P.get()
    for i=0, Invites.length-1 do
        InvitePlayer(Invites[i])
    end
    client.delay_call(0.05, InviteLoop)
end
InviteLoop()

client.set_event_callback('shutdown', function() P.shutdown() end)