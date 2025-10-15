//
//  EventBus.swift
//  OnesecCore
//
//  Created by 王晓雨 on 2025/10/16.
//

import Combine

enum AppEvent {
    case audioVoiceChange(voice: Int)
}

actor EventBus {
    static let shared = EventBus()
    let eventSubject = PassthroughSubject<AppEvent, Never>()

    // 发布事件
    func publish(_ event: AppEvent) {
        eventSubject.send(event)
    }

    // 订阅所有事件
    var events: AnyPublisher<AppEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    func subscribe<T>(to eventType: T.Type) -> AnyPublisher<T, Never> {
        eventSubject
            .compactMap { event in
                if case let loginEvent as T = event {
                    return loginEvent
                }
                return nil
            }
            .eraseToAnyPublisher()
    }
}

extension EventBus {
    var voiceChanges: AnyPublisher<Int, Never> {
        eventSubject
            .compactMap { event in
                guard case .audioVoiceChange(let voice) = event else { return nil }
                return voice
            }
            .eraseToAnyPublisher()
    }
}
