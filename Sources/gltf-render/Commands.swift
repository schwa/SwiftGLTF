import ArgumentParser
import Foundation
import SwiftGLTF

struct Convert: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Convert between .gltf and .glb (format chosen by the output extension).",
        discussion: """
        .glb output packs all buffers into one BIN chunk. .gltf output embeds buffers
        and images as data URIs unless --external is given, in which case URIs are
        kept, relative files are copied next to the output, and a GLB BIN chunk is
        written as a sidecar .bin.
        """
    )

    @Argument(help: "Input .gltf or .glb.")
    var input: String

    @Argument(help: "Output path ending in .gltf or .glb.")
    var output: String

    @Flag(help: "For .gltf output: keep external files instead of embedding data URIs.")
    var external = false

    @Flag(help: "Validate the input first and refuse to convert if it has errors.")
    var validate = false

    func run() async throws {
        let container = try Container(url: URL(fileURLWithPath: input))
        if validate {
            let errors = try container.validate().filter { $0.severity == .error }
            if !errors.isEmpty {
                errors.forEach { print($0) }
                throw ValidationError("Input has \(errors.count) validation error(s); not converting")
            }
        }
        let outputURL = URL(fileURLWithPath: output)
        try container.write(to: outputURL, embedResources: !external)
        print("wrote \(outputURL.path)")
    }
}

struct Validate: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Validate a glTF/GLB model and print issues. Exits non-zero on errors."
    )

    @Argument(help: "Path to the .gltf or .glb model.")
    var model: String

    @Flag(help: "Also exit non-zero when there are warnings.")
    var warningsAsErrors = false

    func run() async throws {
        let container = try Container(url: URL(fileURLWithPath: model))
        try report(container.validate(), warningsAsErrors: warningsAsErrors)
    }
}

// Prints validation issues and a summary; throws a failure exit code on errors.
func report(_ issues: [ValidationIssue], warningsAsErrors: Bool) throws {
    issues.forEach { print($0) }
    let errorCount = issues.filter { $0.severity == .error }.count
    let warningCount = issues.count - errorCount
    print("\(errorCount) error(s), \(warningCount) warning(s)")
    if errorCount > 0 || (warningsAsErrors && warningCount > 0) {
        throw ExitCode.failure
    }
}
