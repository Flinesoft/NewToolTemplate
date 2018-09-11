import CLISpinner
import Foundation
import Rainbow

// swiftlint:disable leveled_print

enum OutputFormatTarget {
    case human
    case xcode
}

enum PrintLevel {
    case verbose
    case info
    case warning
    case error

    var color: Color {
        switch self {
        case .verbose:
            return Color.lightCyan

        case .info:
            return Color.lightBlue

        case .warning:
            return Color.yellow

        case .error:
            return Color.red
        }
    }
}

func print(_ message: String, level: PrintLevel, file: String? = nil, line: Int? = nil) {
    switch Globals.outputFormatTarget {
    case .human:
        humanPrint(message, level: level, file: file, line: line)

    case .xcode:
        xcodePrint(message, level: level, file: file, line: line)
    }
}

private func humanPrint(_ message: String, level: PrintLevel, file: String? = nil, line: Int? = nil) {
    let location = locationInfo(file: file, line: line)
    let message = location != nil ? [location!, message].joined(separator: " ") : message

    switch level {
    case .verbose:
        if GlobalOptions.verbose.value {
            print("🗣 ", message.lightCyan)
        }

    case .info:
        print("ℹ️ ", message.lightBlue)

    case .warning:
        print("⚠️ ", message.yellow)

    case .error:
        print("❌ ", message.red)
    }
}

private func xcodePrint(_ message: String, level: PrintLevel, file: String? = nil, line: Int? = nil) {
    let location = locationInfo(file: file, line: line)

    switch level {
    case .verbose:
        if GlobalOptions.verbose.value {
            if let location = location {
                print(location, "verbose: NewToolTemplate: ", message)
            } else {
                print("verbose: NewToolTemplate: ", message)
            }
        }

    case .info:
        if let location = location {
            print(location, "info: NewToolTemplate: ", message)
        } else {
            print("info: NewToolTemplate: ", message)
        }

    case .warning:
        if let location = location {
            print(location, "warning: NewToolTemplate: ", message)
        } else {
            print("warning: NewToolTemplate: ", message)
        }

    case .error:
        if let location = location {
            print(location, "error: NewToolTemplate: ", message)
        } else {
            print("error: NewToolTemplate: ", message)
        }
    }
}

private func locationInfo(file: String?, line: Int?) -> String? {
    guard let file = file else { return nil }
    guard let line = line else { return "\(file): " }
    return "\(file):\(line): "
}

private let dispatchGroup = DispatchGroup()

func performWithSpinner(
    _ message: String,
    level: PrintLevel = .info,
    pattern: CLISpinner.Pattern = .dots,
    _ body: @escaping (@escaping (() -> Void) -> Void) -> Void
) {
    let spinner = Spinner(pattern: pattern, text: message, color: level.color)
    spinner.start()
    spinner.unhideCursor()

    dispatchGroup.enter()
    body { completion in
        spinner.stopAndClear()
        completion()
        dispatchGroup.leave()
    }

    dispatchGroup.wait()
}