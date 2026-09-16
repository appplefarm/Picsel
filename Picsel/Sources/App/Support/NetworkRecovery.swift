//
//  NetworkRecovery.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 9/17/26.
//

import Network
import Observation
import SwiftUI

/// 연결 상태는 복구 신호로만 사용합니다. 실제 성공/실패는 각 요청의 응답으로 판별합니다.
@MainActor
@Observable
final class NetworkRecovery {
    static let shared = NetworkRecovery()
    private(set) var isConnected: Bool?
    private(set) var generation = 0
    @ObservationIgnored private let monitor = NWPathMonitor()

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.isConnected == false, connected { self.generation += 1 }
                self.isConnected = connected
            }
        }
        monitor.start(queue: DispatchQueue(label: "picsel.network-path"))
    }
}

/// 공급자의 원문/키가 포함된 URL 대신 사용자에게 필요한 실패 원인만 표시합니다.
nonisolated enum RequestFailure: LocalizedError, Equatable, Sendable {
    case offline, timedOut, connection, server, invalidResponse, configuration, unavailable
    /// 경유지 주변에 자동차로 갈 수 있는 도로가 없는 경우입니다.
    case unreachableWaypoint

    init(_ error: Error) {
        if let failure = error as? Self { self = failure; return }
        if error is DecodingError { self = .invalidResponse; return }
        let error = error as NSError
        if error.domain == NSURLErrorDomain {
            switch error.code {
            case NSURLErrorNotConnectedToInternet: self = .offline
            case NSURLErrorTimedOut: self = .timedOut
            case NSURLErrorNetworkConnectionLost, NSURLErrorCannotFindHost,
                 NSURLErrorCannotConnectToHost, NSURLErrorDNSLookupFailed: self = .connection
            default: self = .server
            }
        } else { self = .server }
    }

    var retriesOnReconnect: Bool {
        self == .offline || self == .timedOut || self == .connection
    }

    /// 같은 요청을 다시 보냈을 때 결과가 달라질 수 있는 실패인지입니다.
    ///
    /// 보낸 값이 그대로면 대답도 그대로인 실패가 있습니다.
    /// 그런 화면에 「다시 시도」를 두면 눌러도 아무 일이 없어, 사용자는
    /// 무엇이 잘못됐는지도 모른 채 같은 자리에 갇힙니다.
    var isRetryable: Bool {
        switch self {
        case .unreachableWaypoint, .unavailable, .configuration: false
        case .offline, .timedOut, .connection, .server, .invalidResponse: true
        }
    }

    var errorDescription: String? {
        switch self {
        case .offline: "인터넷 연결을 확인해 주세요."
        case .timedOut: "응답이 늦어지고 있어요. 잠시 후 다시 시도해 주세요."
        case .connection: "서버에 연결하지 못했어요. 네트워크 상태를 확인해 주세요."
        case .server: "서비스에 일시적인 문제가 있어요. 잠시 후 다시 시도해 주세요."
        case .invalidResponse: "정보를 정상적으로 읽지 못했어요. 다시 시도해 주세요."
        case .configuration: "서비스 설정을 확인하지 못했어요. 잠시 후 다시 이용해 주세요."
        case .unavailable: "이 경로는 길찾기를 지원하지 않아요. 목적지나 경유지를 확인해 주세요."
        case .unreachableWaypoint: "자동차로 갈 수 없는 장소가 있어 경로를 만들지 못했어요."
        }
    }

    static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError
            || ((error as NSError).domain == NSURLErrorDomain
                && (error as NSError).code == NSURLErrorCancelled)
    }
}

struct RequestFailureView: View {
    let failure: RequestFailure
    var foregroundColor: Color = .secondary
    var retry: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            if failure.retriesOnReconnect {
                Image(systemName: "wifi.exclamationmark")
                    .font(.title2)
                    .accessibilityHidden(true)
            }
            Text(failure.localizedDescription)
                .font(.subheadline)
                .multilineTextAlignment(.center)

            // 눌러도 같은 결과가 나오는 실패에는 버튼을 두지 않습니다.
            if failure.isRetryable {
                Button("다시 시도", action: retry)
                    .buttonStyle(.bordered)
            }
        }
        .foregroundStyle(foregroundColor)
        .padding()
    }
}

extension View {
    /// 폴링 없이 연결 복구/포그라운드 복귀 때만 호출합니다. 실패 여부는 호출자가 검사합니다.
    func onNetworkRecovery(_ action: @escaping @MainActor () async -> Void) -> some View {
        modifier(NetworkRecoveryModifier(action: action))
    }
}

private struct NetworkRecoveryModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @State private var visible = false
    private let network = NetworkRecovery.shared
    let action: @MainActor () async -> Void

    private struct Trigger: Equatable {
        let generation: Int
        let active: Bool
    }

    func body(content: Content) -> some View {
        content
            .onAppear { visible = true }
            .onDisappear { visible = false }
            .task(id: Trigger(generation: network.generation, active: visible && scenePhase == .active)) {
                guard visible, scenePhase == .active, network.isConnected == true else { return }
                await action()
            }
    }
}
