//
//  AudioSinkNodeRecorder.swift
//  OnesecCore
//
//  Created by 王晓雨 on 2025/10/15.
//

import AVFoundation
import Foundation

enum RecordState {
    case idle
    case recording
    case processing
    case stopping
}

class AudioSinkNodeRecorder {
    private var audioEngine = AVAudioEngine()
    private var sinkNode: AVAudioSinkNode!
    private var converter: AVAudioConverter!
    
    private var recordState: RecordState = .idle
    private var bufferCount = 0
    private var firstBufferTime: Date?
    private var pendingAudioBuffers: [Data] = []
    
    // 录音统计数据
    private var totalPacketsSent = 0
    private var totalBytesSent = 0
    private var recordingStartTime: Date?
    
    // 识别结果存储
    private var recognitionResults: [String] = []
    private var currentRecognitionText: String = ""
    
    // 目标格式
    private let targetFormat: AVAudioFormat = .init(settings: [
        AVFormatIDKey: Int(kAudioFormatLinearPCM),
        AVSampleRateKey: 16000.0,
        AVNumberOfChannelsKey: 1,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsNonInterleaved: false
    ])!
    
    init() {
        setupSinkNodeAudioEngine()
    }
    
    private func setupSinkNodeAudioEngine() {
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        log.debug("输入格式: \(inputFormat.sampleRate)Hz, \(inputFormat.channelCount)声道")
        log.debug("目标格式: \(targetFormat.sampleRate)Hz, \(targetFormat.channelCount)声道")
        
        guard let audioConverter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            log.error("无法创建音频格式转换器")
            return
        }
        audioConverter.sampleRateConverterQuality = AVAudioQuality.high.rawValue
        converter = audioConverter
        
        // SinkNode Handle
        sinkNode = AVAudioSinkNode { [weak self] timestamp, frameCount, audioBufferList in
            guard let self, recordState == .recording else { return OSStatus(noErr) }
            processSinkNodeBuffer(audioBufferList, frameCount: frameCount, timestamp: timestamp)
            return OSStatus(noErr)
        }
        
        // 连接音频图
        audioEngine.attach(sinkNode)
        audioEngine.connect(inputNode, to: sinkNode, format: inputFormat)
        
        log.info("✅ SinkNode 音频引擎设置完成")
    }
    
    /// 处理SinkNode接收到的音频缓冲区
    private func processSinkNodeBuffer(_ audioBufferList: UnsafePointer<AudioBufferList>,
                                       frameCount: AVAudioFrameCount,
                                       timestamp: UnsafePointer<AudioTimeStamp>)
    {
        // 记录第一个缓冲区时间
        if firstBufferTime == nil {
            firstBufferTime = Date()
        }
        
        bufferCount += 1
        
        // 获取输入格式
        let inputFormat = audioEngine.inputNode.outputFormat(forBus: 0)
        
        // 创建输入缓冲区
        guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: frameCount) else {
            return
        }
        inputBuffer.frameLength = frameCount
        
        // 复制音频数据 - 从UnsafePointer读取
        let audioBuffer = audioBufferList.pointee.mBuffers
        let bytesToCopy = Int(audioBuffer.mDataByteSize)
        
        // 确保输入缓冲区有有效的数据指针
        guard let inputData = inputBuffer.audioBufferList.pointee.mBuffers.mData,
              let sourceData = audioBuffer.mData
        else {
            log.error("音频缓冲区数据指针为空")
            return
        }
        
        memcpy(inputData, sourceData, bytesToCopy)
        convertAndSendBuffer(inputBuffer)
    }
    
    /// 转换并发送音频缓冲区
    private func convertAndSendBuffer(_ inputBuffer: AVAudioPCMBuffer) {
        // 计算输出帧数
        let sampleRateRatio = targetFormat.sampleRate / inputBuffer.format.sampleRate
        let expectedOutputFrames = AVAudioFrameCount(Double(inputBuffer.frameLength) * sampleRateRatio)
        
        // 创建输出缓冲区 - 只分配需要的容量，避免浪费
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: expectedOutputFrames) else {
            return
        }
        
        // 执行格式转换
        var error: NSError?
        let status = converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            outStatus.pointee = .haveData
            return inputBuffer
        }

        if status == .error {
            log.error("音频格式转换失败: \(error?.localizedDescription ?? "未知错误")")
            return
        }
        
        // 确保输出缓冲区的 frameLength 正确设置
        if outputBuffer.frameLength == 0, expectedOutputFrames > 0 {
            outputBuffer.frameLength = expectedOutputFrames
        }
        
        // 计算音量并发送到UDS
        if recordState == .recording {
            let volume = calculateVolume(from: outputBuffer)
            EventBus.shared.publish(.volumeChanged(volume: volume))
        }
        
        // 转换为数据并发送
        let audioData = convertBufferToData(outputBuffer)
        if !audioData.isEmpty {
            if recordState == .recording {
                sendAudioData(audioData)
            } else if recordState == .stopping {
                pendingAudioBuffers.append(audioData)
            }
        }
    }
    
    /// 将音频缓冲区转换为Data
    private func convertBufferToData(_ buffer: AVAudioPCMBuffer) -> Data {
        guard buffer.frameLength > 0,
              let audioBuffer = buffer.audioBufferList.pointee.mBuffers.mData
        else {
            return Data()
        }
        
        // 使用实际帧长度计算数据大小，而不是缓冲区总容量
        let bytesPerFrame = Int(buffer.format.streamDescription.pointee.mBytesPerFrame)
        let actualDataSize = Int(buffer.frameLength) * bytesPerFrame
        
        return Data(bytes: audioBuffer, count: actualDataSize)
    }
    
    /// 发送音频数据
    private func sendAudioData(_ audioData: Data) {
        // 更新统计数据
        totalPacketsSent += 1
        totalBytesSent += audioData.count
        
        EventBus.shared.publish(.audioDataReceived(data: audioData))
    }
    
    // MARK: -

    func startRecording(appInfo: AppInfo? = nil, focusContext: FocusContext? = nil, focusElementInfo: FocusElementInfo? = nil, recordMode: RecordMode = .normal) {
        guard recordState != .recording else {
            log.warning("Recording is in progress")
            return
        }
        
        guard ConnectionCenter.shared.isWssServerConnected() else {
            log.warning("Websocket Server not connected")
            // TODO: send event
            return
        }
        
        log.info("🎙️ 开始录音...")
        
        // 重置状态
        resetState()
        recordState = .recording
        EventBus.shared.publish(.recordingStarted(
            appInfo: appInfo,
            focusContext: focusContext,
            focusElementInfo: focusElementInfo,
            recordMode: recordMode
        ))
        
        do {
            try audioEngine.start()
        } catch {
            log.error("🙅 录音启动失败: \(error.localizedDescription)")
        }
    }
    
    func stopRecording() {
        guard recordState == .recording else {
            log.warning("录音未在进行中")
            return
        }
        
        log.info("🛑 停止录音...")
        recordState = .stopping
        
        // 停止音频引擎
        audioEngine.stop()
        
        // 处理待发送的音频数据
        for audioData in pendingAudioBuffers {
            sendAudioData(audioData)
        }
        pendingAudioBuffers.removeAll()
        EventBus.shared.publish(.recordingStopped)
        
        // 计算录音统计信息
        if let startTime = recordingStartTime {
            let duration = Date().timeIntervalSince(startTime)
            let avgPacketSize = totalPacketsSent > 0 ? Double(totalBytesSent) / Double(totalPacketsSent) : 0
            let packetsPerSecond = duration > 0 ? Double(totalPacketsSent) / duration : 0
            let bytesPerSecond = duration > 0 ? Double(totalBytesSent) / duration : 0
            
            log.info("📊 录音统计报告:")
            log.info("   📦 总包数: \(totalPacketsSent) 个")
            log.info("   📁 总数据量: \(String(format: "%.2f", Double(totalBytesSent) / 1024.0)) KB (\(totalBytesSent) 字节)")
            log.info("   🤡 录音时长: \(String(format: "%.2f", duration)) 秒")
            log.info("   📊 平均包大小: \(String(format: "%.1f", avgPacketSize)) 字节")
            log.info("   📈 发送频率: \(String(format: "%.1f", packetsPerSecond)) 包/秒")
            log.info("   📈 数据速率: \(String(format: "%.1f", bytesPerSecond / 1024.0)) KB/秒")
            
            // 计算理论数据量对比
            let theoreticalBytes = Int(duration * 16000 * 2) // 16kHz * 2字节/样本
            let efficiency = Double(totalBytesSent) / Double(theoreticalBytes) * 100.0
            log.info("   🎯 数据完整性: \(String(format: "%.1f", efficiency))% (理论: \(String(format: "%.2f", Double(theoreticalBytes) / 1024.0)) KB)")
        }
        
        log.info("✅ 录音停止")
    }
    
    func resetState() {
        // 重置状态
        recordState = .idle
        bufferCount = 0
        firstBufferTime = nil
        pendingAudioBuffers.removeAll()
        
        // 重置统计数据
        totalPacketsSent = 0
        totalBytesSent = 0
        recordingStartTime = Date()
    }
    
    /// 获取当前识别结果
    func getCurrentRecognitionText() -> String {
        currentRecognitionText
    }
    
    /// 获取所有识别结果
    func getAllRecognitionResults() -> [String] {
        recognitionResults
    }
    
    /// 计算音频缓冲区的音量
    private func calculateVolume(from buffer: AVAudioPCMBuffer) -> Float {
        guard let audioBuffer = buffer.audioBufferList.pointee.mBuffers.mData else {
            return 0.0
        }
        
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        let bytesPerSample = Int(buffer.format.streamDescription.pointee.mBytesPerFrame) / channelCount
        
        var sum: Float = 0.0
        
        if bytesPerSample == 2 { // 16-bit
            let samples = audioBuffer.assumingMemoryBound(to: Int16.self)
            for i in 0..<frameCount {
                let sample = Float(samples[i]) / Float(Int16.max)
                sum += sample * sample
            }
        } else if bytesPerSample == 4 { // 32-bit float
            let samples = audioBuffer.assumingMemoryBound(to: Float.self)
            for i in 0..<frameCount {
                sum += samples[i] * samples[i]
            }
        }
        
        let rms = sqrt(sum / Float(frameCount))
        return min(1.0, rms * 10.0) // 放大音量并限制在 0-1 范围内
    }
}
