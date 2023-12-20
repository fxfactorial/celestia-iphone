//
//  CelestiaLightApp.swift
//  CelestiaLight
//
//  Created by Edgar Aroutionian on 11/21/23.
//

import SwiftUI
import SwiftData
import Celestia
import AsyncAlgorithms

extension Bool {
    func to_go_bool() -> GoUint8 {
        self ? GoUint8(1) : GoUint8(0)
    }
}

@Observable final class CelestiaRunControls {
    static let shared = CelestiaRunControls()
    var run_error = ""
    var show_error_sheet = false
    
    var headers : [String] = []
}

@_cdecl("send_error_back")
public func send_error_back(reply: UnsafeMutablePointer<CChar>) {
    let rpy = String(cString: reply)
    free(reply)
    
    DispatchQueue.main.async {
        CelestiaRunControls.shared.run_error = rpy
        CelestiaRunControls.shared.show_error_sheet = true
    }
    
}

@_cdecl("send_cmd_back")
public func send_cmd_back(reply: UnsafeMutablePointer<CChar>) {
    let rpy = String(cString: reply)
    free(reply)
    CelestiaDriver.shared.ui_work_queue.async {
        do_work(rpy: rpy)
    }
}

func do_work(rpy: String) {
    let decoded = try! JSONDecoder().decode(BridgeMessage<AnyDecodable>.self, from: rpy.data(using: .utf8)!)
    switch decoded.Cmd  {
    case .CMD_INIT_NODE:
        print("node init")
    case .CMD_START_NODE:
        print("started node")
    case .CMD_STOP_NODE:
        print("stop node")
    case .RUN_RECEIVE_HEADER:
        let reply = decoded.Payload!.value as! Dictionary<String, String>
        DispatchQueue.main.async {
            CelestiaRunControls.shared.headers.append(reply["header"]!)
        }
    }
}

final class CelestiaDriver {
    static let shared = CelestiaDriver()
    let comm_channel = AsyncChannel<Data>()
    let ui_work_queue = DispatchQueue(label: "com.hyegar.celestia-light")
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    let driver = CelestiaDriver.shared
    
    func start_handling_bridge() {
        Task.detached {
            Celestia.MakeChannelAndListenThread(true.to_go_bool())
            Celestia.MakeChannelAndReplyThread(true.to_go_bool())
            
            for await msg in self.driver.comm_channel {
                String(data: msg, encoding: .utf8)!.withCString {
                    $0.withMemoryRebound(to: CChar.self, capacity: msg.count) {
                        Celestia.UISendCmd(GoString(p: $0, n: msg.count))
                    }
                }
            }
        }
    }
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        start_handling_bridge()
        return true
    }
    
    
}

@main
struct CelestiaLightApp: App {
    // Only works on :App/@main thing
    @UIApplicationDelegateAdaptor(AppDelegate.self) var app_delegate
    @Bindable private var run_controls = CelestiaRunControls.shared
    @Environment(\.dismiss) var dismiss
    
    func load_node() {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let doc_dir = urls[0]
        print(doc_dir)

        Task {
            let msg = try! JSONEncoder().encode(
              BridgeMessage<BridgeCmdLoadNode>(
                c: .CMD_INIT_NODE, p: BridgeCmdLoadNode(store_path: "\(doc_dir)")
              )
            )
            await app_delegate.driver.comm_channel.send(msg)
        }
    }
    
    func start_node() {
        Task {
            let msg = try! JSONEncoder().encode(BridgeMessage<Int>(c: .CMD_START_NODE, p: 0))
            await app_delegate.driver.comm_channel.send(msg)
        }
    }
    
    func stop_node() {
        Task {
            let msg = try! JSONEncoder().encode(BridgeMessage<Int>(c: .CMD_STOP_NODE, p: 0))
            await app_delegate.driver.comm_channel.send(msg)
        }
    }
    
    
    var body: some Scene {
        WindowGroup {
            VStack {
                Spacer().frame(height: 50)
                Form {
                    Section("Controls") {
                        Button("Load Celestia Node") {
                            print("load node")
                            load_node()
                        }
                        Button("Start Celestia Node") {
                            print("start node")
                            start_node()
                        }
                        Button("Stop Celestia Node") {
                            print("stop celestia")
                            stop_node()
                        }
                    }
                }
                List(run_controls.headers, id: \.self) {header in
                    Text(header)
                }
            }
        }
    }
}

public enum BridgeCommand : String, Codable {
    case CMD_INIT_NODE = "load_celestia_node"
    case CMD_START_NODE = "start_celestia_node"
    case CMD_STOP_NODE = "stop_celestia_node"
    case RUN_RECEIVE_HEADER = "celestia_new_header"
}

public struct BridgeMessage<P: Codable> : Codable {
    public let Cmd: BridgeCommand
    public let Payload: P?
    public init(c : BridgeCommand, p: P?) {
        self.Cmd = c
        self.Payload = p
    }
    
}

struct BridgeCmdLoadNode : Codable {
    let StorePath: string
    init(store_path: String) {
        self.StorePath = store_path
    }
}


public struct AnyDecodable : Codable {
    
    public let value : Any
    
    public init<T>(_ value :T?) {
        self.value = value ?? ()
    }
    
    public func encode(to encoder: Encoder) throws {
        //
    }
    
    
    public init(from decoder :Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let string = try? container.decode(String.self) {
            self.init(string)
        } else if let strs = try? container.decode([String].self) {
            self.init(strs)
        } else if let ints = try? container.decode([Int].self) {
            self.init(ints)
        } else if let int = try? container.decode(Int.self) {
            self.init(int)
        } else if let kv = try? container.decode([String:String].self) {
            self.init(kv)
        } else if let kv = try? container.decode([String:String?].self) {
            self.init(kv)
        } else if let kv = try? container.decode([String: AnyDecodable].self) {
            self.init(kv)
        } else if let kv = try? container.decode([AnyDecodable].self) {
            self.init(kv)
        } else {
            self.init(())
        }
    }
}
