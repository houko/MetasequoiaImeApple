import Carbon
import Foundation

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("Usage: register_input_source.swift INPUT_METHOD_BUNDLE\n".utf8))
    exit(64)
}

let bundleURL = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let status = TISRegisterInputSource(bundleURL as CFURL)
guard status == noErr else {
    FileHandle.standardError.write(Data("TISRegisterInputSource failed with OSStatus \(status).\n".utf8))
    exit(1)
}

print("Registered \(bundleURL.path)")
