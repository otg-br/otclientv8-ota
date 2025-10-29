#ifndef VOICEMANAGER_H
#define VOICEMANAGER_H

#include <string>
#include <memory>
#include <thread>
#include <atomic>
#include <mutex>
#include <vector>
#include <map>
#include <queue>
#include <chrono>
#include <opus/opus.h>
#include <framework/core/eventdispatcher.h>
#include <framework/net/connection.h>
#include <AL/al.h>
#include <AL/alc.h>
#include <windows.h>
#include <mmsystem.h>
#include <boost/asio.hpp>

class VoiceManager : public stdext::shared_object
{
public:
    VoiceManager();
    ~VoiceManager();

    bool join(const std::string& host, uint16_t port, const std::string& room, const std::string& token, uint32_t cid);
    void leave();
    void mute(bool state);
    bool isConnected() const { return m_connected; }
    bool isAuthenticated() const { return m_authenticated; }
    bool isMuted() const { return m_muted; }
    
    // Test mode - echoes your own voice back after 2 seconds
    bool enableTest();  // Returns true if test mode was successfully enabled
    void disableTest();
    bool isTestMode() const { return m_testMode; }

    void processAudio();
    void sendVoicePacket(const std::vector<uint8_t>& opusData, uint32_t sequence, uint32_t timestamp);
    void receiveVoicePacket(const std::vector<uint8_t>& data);
    
    // Voice channel system - public access
    enum class VoiceChannelType {
        WORLD,
        PARTY,
        GUILD,
        PRIVATE
    };
    
    struct VoiceChannel {
        VoiceChannelType type;
        std::string channelId;
        std::string name;
        std::string password;
        std::vector<uint32_t> members;
        uint32_t creatorId;
        bool hasPassword;
    };
    
    // Channel management - public methods
    bool joinChannel(VoiceChannelType type, const std::string& channelId = "", const std::string& password = "");
    void leaveChannel();
    void createPrivateChannel(const std::string& name, const std::string& password = "");
    std::vector<VoiceChannel> getAvailableChannels();
    void setPlayerVolume(uint32_t cid, float volume);
    float getPlayerVolume(uint32_t cid) const;

private:
    bool initializeAudio();
    void cleanupAudio();
    bool initializeAudioCapture();
    void cleanupAudioCapture();
    bool initializeOpenAL();
    void cleanupOpenAL();
    bool captureAudio();
    std::vector<uint8_t> encodeAudio(const std::vector<int16_t>& pcmData);
    
    bool connectToRelay(const std::string& host, uint16_t port);
    void disconnectFromRelay();
    void sendPacket(const std::vector<uint8_t>& data);
    void receivePackets();
    void asyncJoinRoom(const std::string& host, uint16_t port, const std::string& room, const std::string& token, uint32_t cid);
    
    struct VoicePacket {
        uint8_t version;
        std::string roomId;
        uint32_t senderCid;
        uint32_t sequence;
        uint32_t timestamp;
        uint8_t flags;
        std::vector<uint8_t> payload;
    };
    
    VoicePacket parsePacket(const std::vector<uint8_t>& data);
    std::vector<uint8_t> createPacket(const std::vector<uint8_t>& opusData, uint32_t sequence, uint32_t timestamp);
    
    void playAudio(const std::vector<int16_t>& pcmData, uint32_t senderCid = 0);
    std::vector<int16_t> decodeAudio(const std::vector<uint8_t>& opusData);
    
    // Volume control per player

    bool verifyToken(const std::string& token);
    std::string generateHmac(const std::string& data, const std::string& secret);
    std::string generateHmacBinary(const std::string& data, const std::string& secret);
    
    void updatePlayerVolumes();
    float calculateVolumeMultiplier(uint32_t playerId, const std::string& channelId);
    
    void processTestPackets();

private:
    std::atomic<bool> m_connected;
    std::atomic<bool> m_authenticated;
    std::atomic<bool> m_muted;
    std::atomic<bool> m_leaving;
    std::atomic<bool> m_testMode;
    std::string m_relayHost;
    uint16_t m_relayPort;
    std::string m_roomId;
    std::string m_token;
    uint32_t m_cid;
    
    // Test mode delayed packet queue
    struct DelayedPacket {
        std::vector<uint8_t> opusData;
        uint32_t sequence;
        uint32_t timestamp;
        std::chrono::steady_clock::time_point playbackTime;
    };
    std::queue<DelayedPacket> m_testPacketQueue;
    std::mutex m_testQueueMutex;
    std::thread m_testPlaybackThread;
    std::atomic<bool> m_testThreadRunning;
    
    std::unique_ptr<Connection> m_connection;
    std::unique_ptr<boost::asio::ip::tcp::socket> m_socket;
    std::unique_ptr<boost::asio::io_context> m_ioContext;
    std::thread m_receiveThread;
    std::thread m_connectionThread;
    std::atomic<bool> m_shouldStop;
    std::atomic<bool> m_isJoining;
    
    OpusEncoder* m_encoder;
    OpusDecoder* m_decoder;
    std::vector<int16_t> m_captureBuffer;
    std::vector<int16_t> m_playbackBuffer;
    std::mutex m_audioMutex;
    
    // Audio capture using Windows API instead of PortAudio
    HWAVEIN m_waveIn;
    WAVEHDR m_waveHeader;
    std::vector<int16_t> m_waveInBuffer; // Dedicated buffer for WaveIn
    bool m_audioCaptureInitialized;
    
    ALCdevice* m_audioDevice;
    ALCcontext* m_audioContext;
    ALuint m_audioSource;
    std::queue<ALuint> m_availableBuffers;
    std::mutex m_playbackMutex;
    
    static constexpr int SAMPLE_RATE = 48000;
    static constexpr int CHANNELS = 1;
    static constexpr int FRAME_SIZE = 960;
    static constexpr int MAX_PACKET_SIZE = 4000;
    
    static constexpr uint8_t PROTOCOL_VERSION = 1;
    static constexpr uint32_t ROOM_ID_SIZE = 16;
    
    std::atomic<uint32_t> m_sequenceNumber;
    std::map<uint32_t, uint32_t> m_lastSequence;
    
    std::string m_voiceSecret;
    
    // Voice channel data
    VoiceChannelType m_currentChannelType;
    std::string m_currentChannelId;
    std::map<std::string, VoiceChannel> m_availableChannels;
    std::map<uint32_t, float> m_playerVolumes; // Player ID -> Volume multiplier
};

#endif // VOICEMANAGER_H
