import Foundation
#if os(Linux)
import Glibc
#else
import Darwin
#endif

func printHelp(for command: String? = nil) {
    switch command {

    case "install":
        print("""
NAME
    bashket install — install a package

USAGE
    bashket install <package>

DESCRIPTION
    Installs a package onto your computer.

    After installation, the package may be executed directly like any
    other CLI tool, or via:

        bashket run <package> [args...]

FILES
    Installed binaries:
        /usr/local/bashket/bin/<package>

    Symlink created for direct execution:
        /usr/local/bin/<package>
""")

    case "rm":
        print("""
NAME
    bashket rm — remove an installed package

USAGE
    bashket rm <package>

DESCRIPTION
    Removes a package from your system.

    This command deletes:

        • The installed binary from:
            /usr/local/bashket/bin/

        • The symlink from:
            /usr/local/bin/

        • The package metadata file from:
            /usr/local/bashket/pakfiles/

ERRORS
    If the package is not installed, Bashket will report an error.
""")

    case "list":
        print("""
NAME
    bashket list — list installed packages

USAGE
    bashket list

DESCRIPTION
    Displays all packages currently installed via Bashket.

    Each entry represents a package installed through the Bashket
    package manager.
""")

    case "run":
        print("""
NAME
    bashket run — run an installed package

USAGE
    bashket run <package> [args...]

DESCRIPTION
    Runs an installed package through Bashket.

    Any arguments after the package name are forwarded directly to
    the package executable.

EXAMPLE
    bashket run mytool --help

NOTES
    Most packages can normally be executed directly using:

        <package> [args...]

    However, this command may be useful in certain environments or
    scripts.
""")

    case "publish":
        print("""
NAME
    bashket publish — publish a package to the Bashket registry

USAGE
    bashket publish <file.bpk>

DESCRIPTION
    Publishes a package to the Bashket registry.

    The provided `.bpk` file must contain JSON describing the package.

BPK FORMAT
    Example:

        {
          "name": "myPak",
          "binaryPath": "https://example.com/myPak",
          "dependencies": null
        }

FIELDS
    name
        The name of the package. This also determines the name of the
        executable users will run.

    binaryPath
        A direct URL pointing to the package binary.

    dependencies
        Optional dependencies required by the package.

PASSWORD
    When publishing a package, you will be prompted to create a password.

    This password is required if you later want to remove the package
    from the registry using:

        bashket teardown <package>

EXECUTABLE NAME
    The executable name is derived from `name`, not `binaryPath`.

    Example:

        name: "abc"
        binaryPath: "https://example.com/def"

    Users will run:

        abc

    Not:

        def

INSTALLATION
    Once published, users may install the package with:

        bashket install <package>
""")

        print()
        print("IMPORTANT".termStyled([.bold, .redText]))
        print("""
Bashket does NOT host binaries.

The `binaryPath` field must point to a binary hosted on a remote
server. If you do not have your own domain, hosting the binary on
GitHub and pointing `binaryPath` to the raw file is recommended.

Zipped archives are not currently supported.
""".termStyled([.bold]))

    case "teardown":
        print("""
NAME
    bashket teardown — remove a published package from the registry

USAGE
    bashket teardown <package>

DESCRIPTION
    Removes a package that you previously published from the Bashket
    registry.

AUTHENTICATION
    You must provide the password that was created when the package
    was originally published.

NOTES
    This command only removes the package from the remote registry.

    It does NOT affect installations that users already have on
    their systems.
""")

    case "help":
        print("""
NAME
    bashket help — display help information

USAGE
    bashket help [command]

DESCRIPTION
    Displays help documentation.

    If a command name is provided, detailed help for that specific
    command will be shown.

EXAMPLE
    bashket help install
""")

    default:
        print("""
NAME
    bashket — lightweight CLI package manager

USAGE
    bashket <command> [arguments]

COMMANDS
    install <package>
        Install a package

    rm <package>
        Remove an installed package

    publish <file.bpk>
        Publish a package to the Bashket registry

    teardown <package>
        Remove a package you previously published

    list
        List installed packages

    run <package> [args...]
        Run an installed package

    help [command]
        Show help information

MORE INFORMATION
    For detailed help on a specific command:

        bashket help <command>
""")
    }
}

func relaunchWithSudoIfNeededAndExit() -> Never {
    let executable = CommandLine.arguments[0]
    let args = CommandLine.arguments.dropFirst()

    var newArgs: [String] = []
    newArgs.append("sudo")
    newArgs.append("-E")
    newArgs.append(executable)
    newArgs.append(contentsOf: args)
    newArgs.append("--bashket-sudo-reexec")

    let cArgs = newArgs.map { strdup($0) } + [nil]
    execvp("/usr/bin/sudo", cArgs)

    perror("bashket")
    exit(1)
}

func isPermissionError(_ error: Error) -> Bool {
    let ns = error as NSError
    return
        (ns.domain == NSCocoaErrorDomain && ns.code == 513) ||
        (ns.domain == NSPOSIXErrorDomain && ns.code == 13)
}

@discardableResult
func initBashketDir() -> URL {
    let path = "/usr/local/bashket"
    let url = URL(fileURLWithPath: path, isDirectory: true)

    let alreadyReexeced = CommandLine.arguments.contains("--bashket-sudo-reexec")
    let fm = FileManager.default

    func isPermissionError(_ error: Error) -> Bool {
        let ns = error as NSError
        return ns.domain == NSCocoaErrorDomain && ns.code == 513
    }

    func relaunchWithSudo() -> Never {
        let executable = CommandLine.arguments[0]
        let args = CommandLine.arguments.dropFirst()

        var newArgs: [String] = []
        newArgs.append("sudo")
        newArgs.append("-E")
        newArgs.append(executable)
        newArgs.append(contentsOf: args)
        newArgs.append("--bashket-sudo-reexec")

        let cArgs = newArgs.map { strdup($0) } + [nil]
        execvp("/usr/bin/sudo", cArgs)

        perror("bashket")
        print("Error: Failed to relaunch with sudo".termStyled(TermStylePresets.error))
        exit(1)
    }

    var isDir: ObjCBool = false
    if fm.fileExists(atPath: path, isDirectory: &isDir) {
        if isDir.boolValue { return url }
        print("Error: \(path) exists but is not a directory".termStyled(TermStylePresets.error))
        exit(1)
    }

    do {
        try fm.createDirectory(at: url, withIntermediateDirectories: false, attributes: nil)
        createDir(parentDirectory: url, dirname: "bin")
        createDir(parentDirectory: url, dirname: "pakfiles")
        return url
    } catch {
        if !alreadyReexeced && isPermissionError(error) {
            relaunchWithSudo()
        }
        print("Error: Failed to create \(path): \(error)".termStyled(TermStylePresets.error))
        exit(1)
    }
}

func readAt(parentDirectory: URL, filename: String) -> String? {
    let url = parentDirectory.appendingPathComponent(filename)
    return try? String(contentsOf: url, encoding: .utf8)
}

func createDir(parentDirectory: URL, dirname: String) {
    let url = parentDirectory.appendingPathComponent(dirname, isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
}

func xor(_ data: Data, key: UInt8 = 0xAA) -> Data {
    var out = Data(capacity: data.count)
    for b in data { out.append(b ^ key) }
    return out
}

func installBinary(bashketHome: URL, package: Package) throws -> URL {
    let binDir = bashketHome.appendingPathComponent("bin", isDirectory: true)
    let dest = binDir.appendingPathComponent(package.name)
    let fm = FileManager.default

    if fm.fileExists(atPath: dest.path) {
        return dest
    }

    // Local file
    if package.binaryPath.isFileURL,
       fm.fileExists(atPath: package.binaryPath.path) {

        try fm.copyItem(at: package.binaryPath, to: dest)

    }
    // Remote (http / https)
    else if let scheme = package.binaryPath.scheme,
            scheme == "http" || scheme == "https" {

        let semaphore = DispatchSemaphore(value: 0)
        var resultError: Error?

        let task = URLSession.shared.downloadTask(with: package.binaryPath) {
            tmpURL, _, error in

            defer { semaphore.signal() }

            if let error = error {
                resultError = error
                return
            }

            guard let tmpURL = tmpURL else {
                resultError = NSError(domain: "bashket", code: 1)
                return
            }

            do {
                // If something exists (half install, retry, etc)
                if fm.fileExists(atPath: dest.path) {
                    try fm.removeItem(at: dest)
                }

                try fm.moveItem(at: tmpURL, to: dest)
            } catch {
                resultError = error
            }
        }

        task.resume()
        semaphore.wait()

        if let err = resultError {
            throw err
        }

    }
    // Fallback stub
    else {
        let stub = "#!/bin/sh\necho \"\(package.name) stub binary\"\n"
        try stub.data(using: .utf8)!.write(to: dest)
    }

    // Make executable
    try fm.setAttributes(
        [.posixPermissions: 0o755],
        ofItemAtPath: dest.path
    )

    return dest
}

func installAlias(forBinary binaryURL: URL, name: String) throws {
    let link = URL(fileURLWithPath: "/usr/local/bin").appendingPathComponent(name)

    let fm = FileManager.default

    // Replace existing link or file
    if fm.fileExists(atPath: link.path) {
        try fm.removeItem(at: link)
    }

    try fm.createSymbolicLink(
        at: link,
        withDestinationURL: binaryURL
    )
}

func removeAlias(name: String) throws {
    let link = URL(fileURLWithPath: "/usr/local/bin").appendingPathComponent(name)

    let fm = FileManager.default

    if fm.fileExists(atPath: link.path) {
        try fm.removeItem(at: link)
    }
}

func readPassword(prompt: String = "Enter password: ") -> String? {
    print(prompt, terminator: "")
    fflush(stdout)

    var term = termios()
    tcgetattr(STDIN_FILENO, &term)

    var raw = term
    raw.c_lflag &= ~UInt(ECHO | ICANON)

    tcsetattr(STDIN_FILENO, TCSANOW, &raw)

    defer {
        tcsetattr(STDIN_FILENO, TCSANOW, &term)
        print()
    }

    var password = ""
    var char: UInt8 = 0

    while read(STDIN_FILENO, &char, 1) == 1 {
        switch char {
        case 10, 13: // Enter
            return password

        case 127, 8: // Backspace/Delete
            if !password.isEmpty {
                password.removeLast()
                print("\u{8} \u{8}", terminator: "")
                fflush(stdout)
            }

        default:
            password.append(Character(UnicodeScalar(char)))
            print("*", terminator: "")
            fflush(stdout)
        }
    }

    return nil
}

func promptPackagePassword(create: Bool = false, teardown: Bool = false) -> String {
    let action = create ? "Create" : "Enter"

    let message: String
    if create {
        message = """
        This password allows future teardown. To manage your package in the future, you must store/remember this password. If you lose it, you will no longer be able to manage your package.
        """
    } else if teardown {
        message = """
        To teardown this package, you must enter the Bashket package password used when creating this package.
        """
    } else {
        message = ""
    }

    print("""
    🔐 \(action) Bashket package password
    \(message)
    """)
    print()
    
    guard let pw = readPassword(), !pw.isEmpty else {
        print("Password cannot be empty."
            .termStyled(TermStylePresets.error))
        exit(1)
    }

    return pw
}
