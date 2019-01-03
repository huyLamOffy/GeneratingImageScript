#!/usr/bin/env xcrun --sdk macosx swift

import Foundation

//MARK: Helpers
func symbolName(_ string : String, leadingCapital: Bool) -> String {
    let parts = string.components(separatedBy: "_")
    var formattedParts : [String] = []
    var first = true
    for part in parts {
        if first && !leadingCapital {
            formattedParts.append(part.lowercased())
        }
        else {
            formattedParts.append(part.capitalized)
        }
        first = false
    }
    return formattedParts.joined(separator: "")
}

func className(_ string : String) -> String {
    return symbolName(string, leadingCapital: true)
}
func variableName(_ string : String) -> String {
    return symbolName(string, leadingCapital: false)
}

// Stream that writes to stderr.
class StandardErrorOutputStream: TextOutputStream {
    func write(_ string: String) {
        fputs(string, stderr)
    }
    
}

var errorStream = StandardErrorOutputStream()

// This makes it easy to ``print`` to a file
class FileOutputStream : TextOutputStream {
    let handle : FileHandle
    init?(path : String) {
        if !FileManager.default.createFile(atPath: path, contents:nil, attributes:nil) {
            self.handle = FileHandle.nullDevice
            return nil
        }
        if let handle = FileHandle(forWritingAtPath:path) {
            self.handle = handle
        }
        else {
            self.handle = FileHandle.nullDevice
            return nil
        }
    }
    
    func write(_ string: String) {
        handle.write(string.data(using: String.Encoding.utf8)!)
    }
    
    deinit {
        handle.closeFile()
    }
}

func listAllFileNamesExtension(nameDirectory: String, extensionWanted: String) -> (names : [String], paths : [URL]) {
    
    let documentURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let Path = documentURL.appendingPathComponent(nameDirectory).absoluteURL
    
    do {
        try FileManager.default.createDirectory(atPath: Path.relativePath, withIntermediateDirectories: true)
        // Get the directory contents urls (including subfolders urls)
        let directoryContents = try FileManager.default.contentsOfDirectory(at: Path, includingPropertiesForKeys: nil, options: [])
        
        // if you want to filter the directory contents you can do like this:
        let FilesPath = directoryContents.filter{ $0.pathExtension == extensionWanted }
        let FileNames = FilesPath.map{ $0.deletingPathExtension().lastPathComponent }
        
        return (names : FileNames, paths : FilesPath);
        
    } catch {
        print(error.localizedDescription)
    }
    
    return (names : [], paths : [])
}

// MARK: Load

let arguments = CommandLine.arguments

guard arguments.count > 1 else {
    print("error: Not enough arguments. Aborting")
    print("Usage: ")
    print("Localizations.swift <source_file> <dest_file>")
    exit(1)
}
let source = arguments[1]
let dest = arguments[2]
print("HuyLam's dev log: Loading imageName into \(dest)")

guard var output = FileOutputStream(path:dest) else {
    print("error: Couldn't open file \(dest) for writing", to: &errorStream)
    exit(1)
}
//MARK: Output

func tabs(_ number : UInt) -> String {
    var result : String = ""
    for _ in 0..<number {
        result += "\t"
    }
    return result
}

func printGroup(_ group : [String], depth : UInt = 0) {
    let indent = tabs(depth)
    
    print("\n\(indent)enum ImageName: String {", to: &output)
    for name in group {
        let childIndent = tabs(depth + 1)
        print("\(childIndent)case \(variableName(name)) = \"\(name)\"", to: &output)
    }
    print("\(indent)}", to: &output)
}

print("// This file is autogenerated. Do not modify.", to: &output)
print("import UIKit", to: &output)

if let url = URL(string: "\(source)"), let directoryContents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: []) {
    let group = directoryContents
        .filter({$0.lastPathComponent.contains(".imageset")})
        .map({$0.lastPathComponent.replacingOccurrences(of: ".imageset", with: "")})
    printGroup(group)
}

let extensionHelper =
"""
extension UIImageView {
    func setImage(_ name: ImageName) {
        guard let image = UIImage(named: name.rawValue) else {
            assertionFailure("Image not found")
        return
        }
        self.image = image
    }
}
"""
print("", to: &output)
print(extensionHelper, to: &output)
