#include "voicemanager.h"
#include <framework/luaengine/luainterface.h>
#include <framework/luaengine/luaobject.h>
#include <framework/luaengine/luavaluecasts.h>
#include <framework/luaengine/luavaluecasts.h>

static VoiceManager* g_voiceManager = nullptr;

static int Voice_init(lua_State* L)
{
    if (!g_voiceManager) {
        g_voiceManager = new VoiceManager();
    }
    return 0;
}

static int Voice_join(lua_State* L)
{
    std::string host = g_lua.toString(1);
    uint16_t port = static_cast<uint16_t>(g_lua.toNumber(2));
    std::string room = g_lua.toString(3);
    std::string token = g_lua.toString(4);
    uint32_t cid = static_cast<uint32_t>(g_lua.toNumber(5));
    
    if (!g_voiceManager) {
        g_voiceManager = new VoiceManager();
    }
    
    bool result = g_voiceManager->join(host, port, room, token, cid);
    g_lua.pushBoolean(result);
    return 1;
}

static int Voice_leave(lua_State* L)
{
    if (g_voiceManager) {
        g_voiceManager->leave();
    }
    return 0;
}

static int Voice_mute(lua_State* L)
{
    bool state = g_lua.toBoolean(1);
    
    if (g_voiceManager) {
        g_voiceManager->mute(state);
    }
    return 0;
}

static int Voice_isConnected(lua_State* L)
{
    bool connected = false;
    if (g_voiceManager) {
        connected = g_voiceManager->isConnected();
    }
    g_lua.pushBoolean(connected);
    return 1;
}

static int Voice_isMuted(lua_State* L)
{
    bool muted = false;
    if (g_voiceManager) {
        muted = g_voiceManager->isMuted();
    }
    g_lua.pushBoolean(muted);
    return 1;
}

static int Voice_cleanup(lua_State* L)
{
    if (g_voiceManager) {
        delete g_voiceManager;
        g_voiceManager = nullptr;
    }
    return 0;
}

static int Voice_processAudio(lua_State* L)
{
    if (g_voiceManager) {
        g_voiceManager->processAudio();
    }
    return 0;
}

static int Voice_joinWorldChannel(lua_State* L)
{
    std::string channelId = g_lua.toString(1);
    
    if (g_voiceManager) {
        bool result = g_voiceManager->joinChannel(VoiceManager::VoiceChannelType::WORLD, channelId);
        g_lua.pushBoolean(result);
    } else {
        g_lua.pushBoolean(false);
    }
    return 1;
}

static int Voice_joinPartyChannel(lua_State* L)
{
    std::string channelId = g_lua.toString(1);
    
    if (g_voiceManager) {
        bool result = g_voiceManager->joinChannel(VoiceManager::VoiceChannelType::PARTY, channelId);
        g_lua.pushBoolean(result);
    } else {
        g_lua.pushBoolean(false);
    }
    return 1;
}

static int Voice_joinGuildChannel(lua_State* L)
{
    std::string channelId = g_lua.toString(1);
    
    if (g_voiceManager) {
        bool result = g_voiceManager->joinChannel(VoiceManager::VoiceChannelType::GUILD, channelId);
        g_lua.pushBoolean(result);
    } else {
        g_lua.pushBoolean(false);
    }
    return 1;
}

static int Voice_joinPrivateChannel(lua_State* L)
{
    std::string channelId = g_lua.toString(1);
    std::string password = g_lua.toString(2);
    
    if (g_voiceManager) {
        bool result = g_voiceManager->joinChannel(VoiceManager::VoiceChannelType::PRIVATE, channelId, password);
        g_lua.pushBoolean(result);
    } else {
        g_lua.pushBoolean(false);
    }
    return 1;
}

static int Voice_createPrivateChannel(lua_State* L)
{
    std::string name = g_lua.toString(1);
    std::string password = g_lua.toString(2);
    
    if (g_voiceManager) {
        g_voiceManager->createPrivateChannel(name, password);
        g_lua.pushBoolean(true);
    } else {
        g_lua.pushBoolean(false);
    }
    return 1;
}

static int Voice_leaveChannel(lua_State* L)
{
    if (g_voiceManager) {
        g_voiceManager->leaveChannel();
        g_lua.pushBoolean(true);
    } else {
        g_lua.pushBoolean(false);
    }
    return 1;
}

static int Voice_getAvailableChannels(lua_State* L)
{
    if (g_voiceManager) {
        auto channels = g_voiceManager->getAvailableChannels();
        g_lua.newTable();
        
        for (size_t i = 0; i < channels.size(); ++i) {
            g_lua.pushInteger(i + 1);
            g_lua.newTable();
            
            g_lua.pushString("channelId");
            g_lua.pushString(channels[i].channelId);
            g_lua.setTable();
            
            g_lua.pushString("name");
            g_lua.pushString(channels[i].name);
            g_lua.setTable();
            
            g_lua.pushString("hasPassword");
            g_lua.pushBoolean(channels[i].hasPassword);
            g_lua.setTable();
            
            g_lua.setTable();
        }
    } else {
        g_lua.pushNil();
    }
    return 1;
}

static int Voice_enableTest(lua_State* L)
{
    if (g_voiceManager) {
        bool result = g_voiceManager->enableTest();
        g_lua.pushBoolean(result);
    } else {
        g_lua.pushBoolean(false);
    }
    return 1;
}

static int Voice_disableTest(lua_State* L)
{
    if (g_voiceManager) {
        g_voiceManager->disableTest();
        g_lua.pushBoolean(true);
    } else {
        g_lua.pushBoolean(false);
    }
    return 1;
}

static int Voice_isTestMode(lua_State* L)
{
    bool testMode = false;
    if (g_voiceManager) {
        testMode = g_voiceManager->isTestMode();
    }
    g_lua.pushBoolean(testMode);
    return 1;
}

static int Voice_setPlayerVolume(lua_State* L)
{
    uint32_t cid = static_cast<uint32_t>(g_lua.toNumber(1));
    float volume = static_cast<float>(g_lua.toNumber(2));
    
    if (g_voiceManager) {
        g_voiceManager->setPlayerVolume(cid, volume);
        g_lua.pushBoolean(true);
    } else {
        g_lua.pushBoolean(false);
    }
    return 1;
}

void Voice_registerFunctions()
{
    g_lua.registerSingletonClass("Voice");
    
    // Register functions directly using pushCFunction and setField
    g_lua.getGlobal("Voice");
    g_lua.pushCFunction(Voice_init);
    g_lua.setField("init");
    g_lua.pushCFunction(Voice_join);
    g_lua.setField("join");
    g_lua.pushCFunction(Voice_leave);
    g_lua.setField("leave");
    g_lua.pushCFunction(Voice_mute);
    g_lua.setField("mute");
    g_lua.pushCFunction(Voice_isConnected);
    g_lua.setField("isConnected");
    g_lua.pushCFunction(Voice_isMuted);
    g_lua.setField("isMuted");
    g_lua.pushCFunction(Voice_cleanup);
    g_lua.setField("cleanup");
    g_lua.pushCFunction(Voice_processAudio);
    g_lua.setField("processAudio");
    g_lua.pushCFunction(Voice_joinWorldChannel);
    g_lua.setField("joinWorldChannel");
    g_lua.pushCFunction(Voice_joinPartyChannel);
    g_lua.setField("joinPartyChannel");
    g_lua.pushCFunction(Voice_joinGuildChannel);
    g_lua.setField("joinGuildChannel");
    g_lua.pushCFunction(Voice_joinPrivateChannel);
    g_lua.setField("joinPrivateChannel");
    g_lua.pushCFunction(Voice_createPrivateChannel);
    g_lua.setField("createPrivateChannel");
    g_lua.pushCFunction(Voice_leaveChannel);
    g_lua.setField("leaveChannel");
    g_lua.pushCFunction(Voice_getAvailableChannels);
    g_lua.setField("getAvailableChannels");
    g_lua.pushCFunction(Voice_enableTest);
    g_lua.setField("enableTest");
    g_lua.pushCFunction(Voice_disableTest);
    g_lua.setField("disableTest");
    g_lua.pushCFunction(Voice_isTestMode);
    g_lua.setField("isTestMode");
    g_lua.pushCFunction(Voice_setPlayerVolume);
    g_lua.setField("setPlayerVolume");
    g_lua.pop();
}
