local VOICE_OPCODE = 150
local voiceWindow = nil
local roomListWindow = nil
local currentRoom = nil
local availableRooms = {}
local playerPositions = {} -- Track positions of other players in world channel

function enableVoiceTest()
    if Voice.isConnected() then
        print("Enabling voice test mode...")
        local success = Voice.enableTest()
        if success then
            print("Test mode enabled! Speak into your microphone.")
            print("You should hear your voice played back after 2 seconds.")
        else
            print("ERROR: Failed to enable test mode!")
            print("Make sure you have joined a voice room first.")
        end
    else
        print("ERROR: Not connected to voice. Join a room first!")
    end
end

-- Disable test mode
function disableVoiceTest()
    if Voice.isTestMode() then
        print("Disabling voice test mode...")
        Voice.disableTest()
        print("Test mode disabled.")
    else
        print("Test mode is not currently active.")
    end
end

-- Check if test mode is active
function checkTestMode()
    if Voice.isTestMode() then
        print("========================================")
        print("WARNING: Voice test mode is ACTIVE!")
        print("This WILL cause echo!")
        print("Type: disableVoiceTest() to turn it off")
        print("========================================")
        return true
    else
        print("Voice test mode is INACTIVE (good)")
        return false
    end
end

-- Auto-check on init to warn users
local function autoCheckEcho()
    if Voice.isTestMode() then
        g_logger.warning("================================================")
        g_logger.warning("VOICE TEST MODE IS ENABLED - THIS CAUSES ECHO!")
        g_logger.warning("Type 'disableVoiceTest()' in console to disable")
        g_logger.warning("================================================")
    end
end

-- Example: Enable test mode and disable it after 10 seconds
function quickVoiceTest()
    if not Voice.isConnected() then
        print("ERROR: Not connected to voice. Join a room first!")
        return
    end
    
    print("Starting 10-second voice test...")
    Voice.enableTest()
    
    -- Schedule disable after 10 seconds
    scheduleEvent(function()
        Voice.disableTest()
        print("Voice test completed!")
    end, 10000)
end

-- Manual test: Call processAudio in a loop
function testAudioCapture()
    if not Voice.isConnected() then
        print("ERROR: Not connected to voice. Join a room first!")
        return
    end
    
    print("Testing audio capture... calling processAudio() 100 times")
    for i = 1, 100 do
        Voice.processAudio()
    end
    print("Done! Check console for audio capture stats.")
end


local voiceState = {
    connected = false,
    muted = false,
    room = nil,
    channelType = nil,
    myPosition = nil
}

-- Helper function to calculate distance between two positions
local function calculateDistance(pos1, pos2)
    if not pos1 or not pos2 then
        return math.huge
    end
    
    local dx = pos1.x - pos2.x
    local dy = pos1.y - pos2.y
    local dz = pos1.z - pos2.z
    
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

-- Helper function to calculate volume multiplier based on distance
local function calculateVolumeMultiplier(distance)
    local MAX_DISTANCE = 20 -- 20 SQM max range
    local VOLUME_DECREASE = 0.05 -- 5% decrease per SQM
    local DECREASE_INTERVAL = 1 -- Every 1 SQM
    
    if distance > MAX_DISTANCE then
        return 0.0 -- Too far, no audio
    end
    
    local intervals = math.floor(distance / DECREASE_INTERVAL)
    local volumeMultiplier = 1.0 - (intervals * VOLUME_DECREASE)
    
    return math.max(0.0, volumeMultiplier)
end

local audioProcessTimer = nil

function init()
    Voice.init()
    g_logger.info("Voice system initialized")
    
    g_keyboard.bindKeyDown('F6', function() showVoiceWindow() end)
    
    if g_game then
        ProtocolGame.registerExtendedOpcode(VOICE_OPCODE, onExtendedOpcode)
    end
    
    connect(g_game, {onGameUpdate = onGameUpdate})
    
    -- CRITICAL: Start a timer to process audio every 20ms (50 FPS)
    -- This ensures audio processing even when onGameUpdate doesn't fire
    audioProcessTimer = cycleEvent(function()
        onGameUpdate()
    end, 20)
    
    -- Check for test mode echo warning
    scheduleEvent(autoCheckEcho, 2000)
    
    g_logger.info("Audio processing timer started (20ms interval)")
end

function terminate()
    g_logger.info("Terminating voice system...")
    
    -- Stop audio processing timer
    if audioProcessTimer then
        removeEvent(audioProcessTimer)
        audioProcessTimer = nil
        g_logger.info("Audio processing timer stopped")
    end
    
    -- Leave voice room if connected
    if voiceState.connected then
        Voice.leave()
    end
    
    -- Clean up windows
    if voiceWindow then
        voiceWindow:destroy()
        voiceWindow = nil
    end
    
    if roomListWindow then
        roomListWindow:destroy()
        roomListWindow = nil
    end
    
    -- Clean up voice system
    Voice.cleanup()
    
    -- Unbind keys and disconnect events
    g_keyboard.unbindKeyDown('F6')
    
    if g_game then
        ProtocolGame.unregisterExtendedOpcode(VOICE_OPCODE)
    end
    
    disconnect(g_game, {onGameUpdate = onGameUpdate})
    
    -- Reset state
    voiceState.connected = false
    voiceState.room = nil
    voiceState.channelType = nil
    voiceState.myPosition = nil
    currentRoom = nil
    playerPositions = {}
    
    g_logger.info("Voice system terminated")
end

function onExtendedOpcode(protocol, opcode, buffer)
    if opcode == VOICE_OPCODE then
        local data = json.decode(buffer)
        
        -- Handle voice room join response
        if data.relay_host and data.relay_port and data.room and data.token then
            local player = g_game.getLocalPlayer()
            if player then
                local success = Voice.join(data.relay_host, data.relay_port, data.room, data.token, player:getId())
                if success then
                    voiceState.connected = true
                    voiceState.room = data.room
                    voiceState.channelType = data.channelType or "unknown"
                    currentRoom = data.room
                    
                    -- Store position for world channel
                    if data.position then
                        voiceState.myPosition = data.position
                    end
                    
                    -- Store nearby player positions for world channel
                    if data.nearbyPlayers then
                        playerPositions = {}
                        for _, p in ipairs(data.nearbyPlayers) do
                            playerPositions[p.cid] = {x = p.x, y = p.y, z = p.z}
                            -- Set initial volume based on distance
                            if voiceState.myPosition then
                                local distance = calculateDistance(voiceState.myPosition, {x = p.x, y = p.y, z = p.z})
                                local volume = calculateVolumeMultiplier(distance)
                                Voice.setPlayerVolume(p.cid, volume)
                                g_logger.info("Set initial volume for CID " .. p.cid .. ": " .. volume .. " (distance: " .. distance .. ")")
                            end
                        end
                        g_logger.info("Loaded " .. #data.nearbyPlayers .. " nearby player positions with volumes")
                    end
                    
                    g_logger.info("Joined voice room: " .. data.room .. " (type: " .. voiceState.channelType .. ")")
                    updateVoiceWindow()
                else
                    g_logger.error("Failed to join voice room")
                end
            end
        -- Handle position updates (for world channel)
        elseif data.action == "positionUpdate" then
            if data.cid and data.position then
                playerPositions[data.cid] = data.position
                -- Update volume for this player if needed
                if voiceState.channelType == "world" and voiceState.myPosition then
                    local distance = calculateDistance(voiceState.myPosition, data.position)
                    local volume = calculateVolumeMultiplier(distance)
                    -- Apply volume to the specific player's audio stream
                    Voice.setPlayerVolume(data.cid, volume)
                    g_logger.debug("Player " .. data.cid .. " moved to distance: " .. distance .. " (volume: " .. volume .. ")")
                end
            end
        -- Handle channel list response
        elseif data.action == "channelList" and data.channels then
            availableRooms = data.channels
            updateRoomList()
        -- Handle errors
        elseif data.error then
            g_logger.error("Voice error: " .. data.error)
            showVoiceError(data.error)
        end
    end
end

function onGameUpdate()
    Voice.processAudio()
    
    -- Update position if in world channel
    if voiceState.connected and voiceState.channelType == "world" then
        local player = g_game.getLocalPlayer()
        if player then
            local pos = player:getPosition()
            
            -- Check if floor changed - need to rejoin different room
            if voiceState.myPosition and pos.z ~= voiceState.myPosition.z then
                g_logger.info("Floor changed from " .. voiceState.myPosition.z .. " to " .. pos.z .. " - rejoining world channel")
                voiceState.myPosition = {x = pos.x, y = pos.y, z = pos.z}
                -- Leave and rejoin to get into correct floor room
                leaveVoiceRoom()
                scheduleEvent(function()
                    joinPublicVoiceRoom()
                end, 500)
                return
            end
            
            -- Check if position changed
            if not voiceState.myPosition or 
               pos.x ~= voiceState.myPosition.x or 
               pos.y ~= voiceState.myPosition.y or 
               pos.z ~= voiceState.myPosition.z then
                
                voiceState.myPosition = {x = pos.x, y = pos.y, z = pos.z}
                
                -- Send position update to server
                local data = {
                    action = "positionUpdate"
                }
                g_game.getProtocolGame():sendExtendedOpcode(VOICE_OPCODE, json.encode(data))
                
                -- Update volumes for all nearby players based on new position
                for cid, position in pairs(playerPositions) do
                    local distance = calculateDistance(voiceState.myPosition, position)
                    local volume = calculateVolumeMultiplier(distance)
                    Voice.setPlayerVolume(cid, volume)
                end
            end
        end
    end
end

function showVoiceWindow()
    if not voiceWindow then
        voiceWindow = g_ui.displayUI('voice')
        if not voiceWindow then
            g_logger.error("Failed to load voice window UI")
            return
        end
    end
    
    voiceWindow:show()
    voiceWindow:raise()
    voiceWindow:focus()
    updateVoiceWindow()
end

function hideVoiceWindow()
    if voiceWindow then
        voiceWindow:hide()
    end
end

function updateVoiceWindow()
    if not voiceWindow then return end
    
    local state = voiceState
    local statusLabel = voiceWindow:recursiveGetChildById('statusLabel')
    local roomLabel = voiceWindow:recursiveGetChildById('roomLabel')
    local muteButton = voiceWindow:recursiveGetChildById('muteButton')
    local leaveButton = voiceWindow:recursiveGetChildById('leaveButton')
    
    if state.connected then
        statusLabel:setText('Status: Connected')
        statusLabel:setColor('#00FF00')
        roomLabel:setText('Room: ' .. (state.room or 'Unknown'))
        roomLabel:setColor('#FFFFFF')
        muteButton:setEnabled(true)
        leaveButton:setEnabled(true)
    else
        statusLabel:setText('Status: Disconnected')
        statusLabel:setColor('#FF0000')
        roomLabel:setText('Room: None')
        roomLabel:setColor('#888888')
        muteButton:setEnabled(false)
        leaveButton:setEnabled(false)
    end
    
    if state.muted then
        muteButton:setText('Unmute')
        muteButton:setColor('#FF0000')
    else
        muteButton:setText('Mute')
        muteButton:setColor('#FFFFFF')
    end
end

function showVoiceError(message)
    if not voiceWindow then return end
    
    local infoLabel = voiceWindow:recursiveGetChildById('infoLabel')
    if infoLabel then
        infoLabel:setText('Error: ' .. message)
        infoLabel:setColor('#FF0000')
    end
end

function createVoiceRoom(roomName)
    local data = {
        action = "create",
        room = roomName
    }
    g_game.getProtocolGame():sendExtendedOpcode(VOICE_OPCODE, json.encode(data))
end

function joinPublicVoiceRoom()
    -- Join world channel based on player position
    local data = {
        action = "world"
    }
    g_game.getProtocolGame():sendExtendedOpcode(VOICE_OPCODE, json.encode(data))
end

function joinPartyVoiceRoom()
    -- Join party channel
    local data = {
        action = "party"
    }
    g_game.getProtocolGame():sendExtendedOpcode(VOICE_OPCODE, json.encode(data))
end

function joinGuildVoiceRoom()
    -- Join guild channel
    local data = {
        action = "guild"
    }
    g_game.getProtocolGame():sendExtendedOpcode(VOICE_OPCODE, json.encode(data))
end

function joinVoiceRoom(room)
    if not voiceState.connected then
        local data = {
            action = "join",
            room = room
        }
        g_game.getProtocolGame():sendExtendedOpcode(VOICE_OPCODE, json.encode(data))
    end
end

function leaveVoiceRoom()
    if voiceState.connected then
        g_logger.info("Leaving voice room...")
        
        -- Send leave request to server first
        local data = {
            action = "leave"
        }
        g_game.getProtocolGame():sendExtendedOpcode(VOICE_OPCODE, json.encode(data))
        
        -- Then leave the voice connection
        Voice.leave()
        
        -- Update local state
        voiceState.connected = false
        voiceState.room = nil
        voiceState.channelType = nil
        voiceState.myPosition = nil
        currentRoom = nil
        playerPositions = {} -- Clear player positions
        
        -- Update UI
        updateVoiceWindow()
        
        g_logger.info("Left voice room successfully")
    end
end

function toggleVoiceMute()
    if voiceState.connected then
        voiceState.muted = not voiceState.muted
        Voice.mute(voiceState.muted)
        updateVoiceWindow()
    end
end

function getVoiceState()
    return voiceState
end

function getCurrentRoom()
    return currentRoom
end

function createRoom()
    if not voiceWindow then return end
    
    local roomNameEdit = voiceWindow:recursiveGetChildById('roomNameEdit')
    local roomName = roomNameEdit:getText()
    
    if roomName and roomName:len() > 0 then
        createVoiceRoom(roomName)
        roomNameEdit:setText('')
        local infoLabel = voiceWindow:recursiveGetChildById('infoLabel')
        infoLabel:setText('Creating room: ' .. roomName)
        infoLabel:setColor('#FFFF00')
    else
        showVoiceError('Please enter a room name')
    end
end

function joinRoom()
    if not voiceWindow then return end
    
    local roomNameEdit = voiceWindow:recursiveGetChildById('roomNameEdit')
    local roomName = roomNameEdit:getText()
    
    if roomName and roomName:len() > 0 then
        joinVoiceRoom(roomName)
        roomNameEdit:setText('')
        local infoLabel = voiceWindow:recursiveGetChildById('infoLabel')
        infoLabel:setText('Joining room: ' .. roomName)
        infoLabel:setColor('#FFFF00')
    else
        showVoiceError('Please enter a room name')
    end
end

function joinPublicRoom()
    joinPublicVoiceRoom()
    if voiceWindow then
        local infoLabel = voiceWindow:recursiveGetChildById('infoLabel')
        if infoLabel then
            infoLabel:setText('Joining public room with nearby players')
            infoLabel:setColor('#FFFF00')
        end
    end
end

function toggleMute()
    toggleVoiceMute()
end

function leaveRoom()
    if voiceState.connected then
        leaveVoiceRoom()
        if voiceWindow then
            local infoLabel = voiceWindow:recursiveGetChildById('infoLabel')
            if infoLabel then
                infoLabel:setText('Left voice room')
                infoLabel:setColor('#FFFF00')
            end
        end
    else
        if voiceWindow then
            local infoLabel = voiceWindow:recursiveGetChildById('infoLabel')
            if infoLabel then
                infoLabel:setText('Not connected to any voice room')
                infoLabel:setColor('#FF0000')
            end
        end
    end
end

function createPrivateRoom()
    if not voiceWindow then return end
    
    local roomNameEdit = voiceWindow:recursiveGetChildById('roomNameEdit')
    local passwordEdit = voiceWindow:recursiveGetChildById('passwordEdit')
    if not roomNameEdit then return end
    
    local roomName = roomNameEdit:getText()
    local password = passwordEdit and passwordEdit:getText() or ""
    
    if roomName and roomName:len() > 0 then
        local data = {
            action = "private",
            room = roomName,
            password = password
        }
        g_game.getProtocolGame():sendExtendedOpcode(VOICE_OPCODE, json.encode(data))
        roomNameEdit:setText('')
        if passwordEdit then passwordEdit:setText('') end
        local infoLabel = voiceWindow:recursiveGetChildById('infoLabel')
        if infoLabel then
            infoLabel:setText('Creating private room: ' .. roomName)
            infoLabel:setColor('#FFFF00')
        end
    else
        showVoiceError('Please enter a room name')
    end
end

function joinPrivateRoom()
    if not voiceWindow then return end
    
    local roomNameEdit = voiceWindow:recursiveGetChildById('roomNameEdit')
    local passwordEdit = voiceWindow:recursiveGetChildById('passwordEdit')
    if not roomNameEdit then return end
    
    local roomName = roomNameEdit:getText()
    local password = passwordEdit and passwordEdit:getText() or ""
    
    if roomName and roomName:len() > 0 then
        local data = {
            action = "join",
            room = roomName,
            password = password
        }
        g_game.getProtocolGame():sendExtendedOpcode(VOICE_OPCODE, json.encode(data))
        roomNameEdit:setText('')
        if passwordEdit then passwordEdit:setText('') end
        local infoLabel = voiceWindow:recursiveGetChildById('infoLabel')
        if infoLabel then
            infoLabel:setText('Joining private room: ' .. roomName)
            infoLabel:setColor('#FFFF00')
        end
    else
        showVoiceError('Please enter a room name')
    end
end

function showRoomList()
    if not roomListWindow then
        roomListWindow = g_ui.displayUI('roomlist')
    end
    
    roomListWindow:show()
    roomListWindow:raise()
    roomListWindow:focus()
    
    -- Request room list from server
    getAvailableRooms()
end

function hideRoomList()
    if roomListWindow then
        roomListWindow:hide()
    end
end

function updateRoomList()
    if not roomListWindow then return end
    
    local roomList = roomListWindow:recursiveGetChildById('roomList')
    if not roomList then return end
    
    roomList:destroyChildren()
    
    for i, room in ipairs(availableRooms) do
        local roomText = string.format("%s (%d/%d)%s - by %s", 
            room.name,
            room.memberCount or 0,
            room.maxMembers or 8,
            room.hasPassword and " 🔒" or "",
            room.creator or "Unknown"
        )
        
        local label = g_ui.createWidget('Label', roomList)
        label:setText(roomText)
        label:setPhantom(false)
        label.roomId = room.id
        label.hasPassword = room.hasPassword
        
        label.onClick = function(widget)
            roomList:focusChild(widget)
        end
    end
end

function joinSelectedRoom()
    if not roomListWindow then return end
    
    local roomList = roomListWindow:recursiveGetChildById('roomList')
    if not roomList then return end
    
    local focusedChild = roomList:getFocusedChild()
    if not focusedChild then
        g_logger.warning("No room selected")
        return
    end
    
    local roomId = focusedChild.roomId
    local hasPassword = focusedChild.hasPassword
    
    if hasPassword then
        -- TODO: Show password dialog
        g_logger.info("Room requires password. Enter password in the main window.")
        hideRoomList()
        showVoiceWindow()
        local roomNameEdit = voiceWindow:recursiveGetChildById('roomNameEdit')
        if roomNameEdit then
            roomNameEdit:setText(roomId)
            roomNameEdit:focus()
        end
    else
        local data = {
            action = "join",
            room = roomId,
            password = ""
        }
        g_game.getProtocolGame():sendExtendedOpcode(VOICE_OPCODE, json.encode(data))
        hideRoomList()
    end
end

function getAvailableRooms()
    local data = {
        action = "channelList"
    }
    g_game.getProtocolGame():sendExtendedOpcode(VOICE_OPCODE, json.encode(data))
end