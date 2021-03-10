local obs_websockets = require 'gamesense/obs_websockets'
local OBSFilters

-- START User Settings
local wsURL = 'ws://localhost:4444'
local wsPassword = 'GayForOxis31' -- Not relevant if authentication is disabled
local GameSourceName = 'Game'
local RenderDelay = 0 -- Most people will use 0, ill leave it at zero. I'm working on another lua that requires a render-delay, ill post more about that soon.
-- END User Settings

Connection = obs_websockets.connect(wsURL, wsPassword, function(success, err)
    if not success then return error(err) end
    
    Connection:call('GetSourceFilters', {sourceName = GameSourceName}, function(response)
        OBSFilters = {}
        for index, filter in ipairs(response.filters) do
            if ( filter.type == 'streamfx-filter-shader' ) then
                OBSFilters[#OBSFilters + 1] = {filter.name, filter.settings}
            end
        end
    end)
end)

function setBlurLocation(filterName, Range_StartXOffset, Range_StartYOffset, Range_EndXOffset, Range_EndYOffset)
    local Settings = {}
    Settings.Range_StartXOffset = Range_StartXOffset - 1
    Settings.Range_StartYOffset = Range_StartYOffset - 1
    Settings.Range_EndXOffset = Range_EndXOffset + 1
    Settings.Range_EndYOffset = Range_EndYOffset + 1
    Connection:emit('SetSourceFilterSettings', {sourceName = GameSourceName, filterName = filterName, filterSettings = Settings})
end

function setBlurVisible(filterName, visible)
    Connection:emit('SetSourceFilterVisibility', {sourceName = GameSourceName, filterName = filterName, filterEnabled = visible})
end

local LastOffsets = ''
local LastMenuState
local LastUpdate = globals.realtime()
client.set_event_callback('post_render', function()
    if not OBSFilters or #OBSFilters == 0 then return end
    if ( ui.is_menu_open() ~= LastMenuState ) then
        local NewState = ui.is_menu_open()
        client.delay_call(RenderDelay, setBlurVisible, OBSFilters[1][1], NewState)
        LastMenuState = NewState
    end
    if not ui.is_menu_open() or globals.realtime() - LastUpdate < 0.01 then return end

    local screenW, screenH = client.screen_size() -- its in the loop incase they change res, so don't ask why.
    local menuX, menuY = ui.menu_position()
    local menuW, menuH = ui.menu_size()

    local Range_StartXOffset = ( menuX / screenW ) * 100
    local Range_StartYOffset = ( menuY / screenH ) * 100
    local Range_EndXOffset = ( menuX + menuW ) / screenW * 100
    local Range_EndYOffset = ( menuY + menuH ) / screenH * 100

    -- I did this, bc fuck if I'm writing that many conditions, again.
    local CurrentOffsets = Range_StartXOffset .. Range_StartYOffset .. Range_EndXOffset .. Range_EndYOffset
    if ( LastOffsets ~= CurrentOffsets ) then
        client.delay_call(RenderDelay, setBlurLocation, OBSFilters[1][1], Range_StartXOffset, Range_StartYOffset, Range_EndXOffset, Range_EndYOffset)

        LastUpdate = globals.realtime()
        LastOffsets = CurrentOffsets
    end
end)
