// beak: Flinesoft/HandySwift @ .upToNextMajor(from: "2.6.0")
// beak: onevcat/Rainbow @ .upToNextMajor(from: "3.0.3")

import Foundation
import HandySwift
import Rainbow

// MARK: - Print Helpers
private enum PrintLevel {
    case info
    case warning
    case error
}

private func print(_ message: String, level: PrintLevel) {
    switch level {
    case .info:
        print("ℹ️ ", message.lightBlue)

    case .warning:
        print("⚠️ ", message.yellow)

    case .error:
        print("❌ ", message.red)
    }
}


// MARK: - Command Helpers
typealias CommandResult = (output: String?, error: String?, exitCode: Int32)

@discardableResult
func run(_ command: String) -> CommandResult {
    let commandComponents = command.components(separatedBy: .whitespaces)

    let commandLineTask = Process()
    commandLineTask.launchPath = "/usr/bin/env"
    commandLineTask.arguments = commandComponents

    let outputPipe = Pipe()
    commandLineTask.standardOutput = outputPipe
    let errorPipe = Pipe()
    commandLineTask.standardError = errorPipe

    commandLineTask.launch()

    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
    let error = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .newlines)

    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .newlines)

    commandLineTask.waitUntilExit()
    let exitCode = commandLineTask.terminationStatus

    return (output, error, exitCode)
}

// MARK: - GitHub Helpers
let semanticVersionRegex = try Regex("(\\d+)\\.(\\d+)\\.(\\d+)\\s")

struct SemanticVersion: Comparable, CustomStringConvertible {
    let major: Int
    let minor: Int
    let patch: Int

    init(_ string: String) {
        guard let captures = semanticVersionRegex.firstMatch(in: string)?.captures else {
            fatalError("SemanticVersion initializer was used without checking the structure.")
        }

        major = Int(captures[0]!)!
        minor = Int(captures[1]!)!
        patch = Int(captures[2]!)!
    }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        guard lhs.major == rhs.major else { return lhs.major < rhs.major }
        guard lhs.minor == rhs.minor else { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }

    static func == (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        return lhs.major == rhs.major && lhs.minor == rhs.minor && lhs.patch == rhs.patch
    }

    var description: String {
        return "\(major).\(minor).\(patch)"
    }
}

func fetchGitHubLatestVersion(subpath: String) -> SemanticVersion {
    let tagListCommand = "git ls-remote --tags https://github.com/\(subpath).git"
    let commandOutput = run(tagListCommand).output!
    let availableSemanticVersions = semanticVersionRegex.matches(in: commandOutput).map { SemanticVersion($0.string) }
    guard !availableSemanticVersions.isEmpty else {
        print("Dependency '\(subpath)' has no tagged versions.", level: .error)
        fatalError()
    }
    return availableSemanticVersions.sorted().last!
}

func fetchGitHubTagline(subpath: String) throws -> String? {
    let taglineRegex = try Regex("<title>[^\\:]+\\: (.*)<\\/title>")
    let url = URL(string: "https://github.com/\(subpath)")!
    let html = try String(contentsOf: url, encoding: .utf8)
    guard let firstMatch = taglineRegex.firstMatch(in: html) else { return nil }
    guard let firstCapture = firstMatch.captures.first else { return nil }
    return firstCapture!
}

// MARK: - SPM Helpers
extension SemanticVersion {
    var recommendedVersionSpecifier: String {
        guard major >= 1 else { return ".upToNextMinor(\(description)" }
        return ".upToNextMajor(\(description))"
    }
}

func renameTool(to toolName: String) throws {
    let currentDirectoryUrl = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let enclosingDirectoryName = currentDirectoryUrl
    try replaceInFile(path: "Package.swift", substring: enclosingDirectoryName, replacement: toolName)

    let escapedEnclosingDirectoryName = enclosingDirectoryName.lastPathComponent.replacingOccurrences(of: " ", with: "\\ ")
    let escapedToolName = toolName.lastPathComponent.replacingOccurrences(of: " ", with: "\\ ")
    run("mkdir Sources/\(escapedToolName)")
    run("mv Sources/\(escapedEnclosingDirectoryName)/main.swift Sources/\(escapedToolName)/main.swift")
}

func sortDependencies() {
    // TODO: not yet implemented
}

func appendDependencyToPackageFile(tagline: String?, githubSubpath: String, version: SemanticVersion) {
    // TODO: not yet implemented
}

func initializeLicenseFile(organization: String) throws {
    try deleteFile("LICENSE.md")
    run("mv LICENSE.md.sample LICENSE.md")
    try replaceInFile(path: "LICENSE.md", substring: "{RIGHTHOLDER}", replacement: organization)
    let currentYear = Calendar(identifier: .gregorian).component(.year, from: Date())
    try replaceInFile(path: "LICENSE.md", substring: "{YEAR}", replacement: String(currentYear))
}

func initializeReadMe(toolName: String) throws {
    try deleteFile("README.md")
    run("mv README.md.sample README.md")
    try replaceInFile(path: "README.md", substring: "{TOOL_NAME}", replacement: toolName)
}

// MARK: - File Helpers
func deleteFile(_ filePath: String) throws {
    run("[ ! -e \(filePath) ] || rm \(filePath)")
}

private func replaceInFile(path: String, substring: String, replacement: String) throws {
    let fileUrl = URL(fileURLWithPath: path)
    var content = try String(contentsOf: fileUrl, encoding: .utf8)
    content = content.replacingOccurrences(of: substring, with: replacement)
    try content.write(to: fileUrl, atomically: false, encoding: .utf8)
}

// MARK: - Beak Commands
/// Initializes the command line tool.
public func initialize(toolName: String, organization: String) throws {
    run("swift package init --type executable")
    makeEditable()
    try renameTool(to: toolName)
    try initializeLicenseFile(organization: organization)
    try initializeReadMe(toolName: toolName)
}

/// Prepares project for editing using Xcode with all dependencies configured.
public func makeEditable() {
    run("swift package generate-xcodeproj")
}

/// Adds a new dependency hosted on GitHub with most current version and recommended update path preconfigured.
public func addDependency(github githubSubpath: String, version: String = "latest") throws {
    let tagline = try fetchGitHubTagline(subpath: githubSubpath)
    let latestVersion = fetchGitHubLatestVersion(subpath: githubSubpath)
    appendDependencyToPackageFile(tagline: tagline, githubSubpath: githubSubpath, version: latestVersion)
    sortDependencies()
}
