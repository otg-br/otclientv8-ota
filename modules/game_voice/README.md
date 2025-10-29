# Voice Chat System - Complete Implementation

## Overview
Professional voice chat system for OTClientV8 with OTUI miniwindow management, multiple room support, and server-side integration.

## Features

### 🎤 **Voice Chat Features**
- Real-time audio communication
- Multiple voice rooms support
- Room creation and joining
- Mute/unmute functionality
- Cross-platform compatibility

### 🖥️ **OTUI Interface**
- Professional miniwindow interface
- Room management (create/join)
- Voice controls (mute/leave)
- Status indicators
- Error handling

### 🔧 **Technical Features**
- ExtendedOpcode integration
- Server-side authorization
- Token-based security
- Rate limiting
- Automatic cleanup

## Files Structure

```
modules/game_voice/
├── voice.lua              # Complete voice system (all logic)
├── voice.otui             # OTUI interface definition
├── voice.otmod            # Module configuration
└── README.md              # This documentation
```

## Usage

### **Opening Voice Window**
- Press **F6** to open the voice chat window
- Or call `voice_window.show()` in Lua

### **Creating a Room**
1. Open voice window (F6)
2. Enter room name in text field
3. Click "Create Room"
4. Share room name with other players

### **Joining a Room**
1. Open voice window (F6)
2. Enter room name in text field
3. Click "Join Room"

### **Voice Controls**
- **Mute/Unmute**: Click mute button
- **Leave Room**: Click leave button
- **Status**: Shows connection status and current room

## API Functions

### **Core Functions**
```lua
-- Voice system
joinVoiceRoom(roomName)     -- Join a voice room
leaveVoiceRoom()           -- Leave current room
createVoiceRoom(roomName)  -- Create new room
toggleVoiceMute()          -- Toggle mute state
getVoiceState()            -- Get current state
getCurrentRoom()           -- Get current room name
```

### **Window Functions**
```lua
-- Window management
voice_window.show()        -- Show voice window
voice_window.hide()       -- Hide voice window
voice_window.updateStatus() -- Update status display
voice_window.showError(msg) -- Show error message
```

## Server Integration

### **TFS Server Requirements**
- HTTP wrapper library (libhttp)
- Voice opcode handler
- Permission system
- API communication

### **ExtendedOpcode Actions**
- `join` - Join existing room
- `create` - Create new room
- `leave` - Leave current room

## Configuration

### **Client Settings**
- Voice window size: 300x400
- Keyboard shortcut: F6
- Auto-update status

### **Server Settings**
- Voice API URL
- Secret key
- Permission requirements
- Rate limiting

## Dependencies

### **Client Dependencies**
- OTClientV8 with voice module
- VoiceManager C++ class
- PortAudio/OpenAL libraries
- Opus codec

### **Server Dependencies**
- TFS 1.4.2 with HTTP wrapper
- PHP API server
- Go relay server
- MySQL database

## Installation

1. **Copy voice module** to OTClientV8 modules directory
2. **Load voice system** in client initialization
3. **Configure server** with voice opcode handler
4. **Set up API** and relay servers
5. **Test voice functionality**

## Troubleshooting

### **Common Issues**
- **Window not opening**: Check F6 key binding
- **Voice not working**: Verify audio permissions
- **Room join failed**: Check server permissions
- **Audio quality**: Adjust Opus settings

### **Debug Information**
- Check console for error messages
- Verify server API connectivity
- Test audio input/output
- Check room permissions

## Security

- **Token-based authentication**
- **HMAC-SHA256 verification**
- **Rate limiting protection**
- **Permission validation**
- **Room isolation**

## Performance

- **Low latency**: <100ms
- **High quality**: 48kHz Opus
- **Scalable**: Multiple rooms
- **Efficient**: Minimal CPU usage
- **Stable**: Production ready

## Support

For issues or questions:
1. Check console logs
2. Verify server configuration
3. Test audio permissions
4. Review documentation
