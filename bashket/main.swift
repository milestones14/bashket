import Foundation

let args = CommandLine.arguments
let bashketHome = initBashketDir()

if args.safeGetAtRange(1) == "install" {
    // MARK: - Install
    
    guard let packageName = args.safeGetAtRange(2) else {
        print("Please specify a package to install.".termStyled(TermStylePresets.error))
        exit(1)
    }

    let findLoader = BrailleLoader(message: "Trying \(packageName)...")
    if !CommandLine.arguments.contains("--bashket-sudo-reexec") {
        findLoader.start()
    }
    
    let endpoint = URL(string: "http://bashket-api.atwebpages.com/get_package.php")!
    guard let packageToInstall =
        try getRemotePackageByName(packageName, endpoint: endpoint)
    else {
        findLoader.stop(clearLine: true)
        print("A package with name '\(packageName)' could not be found."
            .termStyled(TermStylePresets.error))
        exit(1)
    }

    findLoader.stop(clearLine: true)
    
    let loader = BrailleLoader(message: "Installing \(packageToInstall.name)...")
    loader.start()
    
    Thread.sleep(forTimeInterval: 0.25)
    
    do {
        try installPackage(bashketHome: bashketHome, package: packageToInstall)
    } catch {
        if !CommandLine.arguments.contains("--bashket-sudo-reexec"),
           isPermissionError(error) {

            loader.stop(clearLine: true)
            relaunchWithSudoIfNeededAndExit()
        }

        loader.stop(clearLine: true)
        print("Install failed: \(error)".termStyled(TermStylePresets.error))
        exit(1)
    }
    
    Thread.sleep(forTimeInterval: 0.25)

    loader.stop(clearLine: true)
    print("\(packageName) installed successfully!".termStyled(TermStylePresets.success))
} else if args.safeGetAtRange(1) == "rm" {
    // MARK: - Uninstall
    
    guard let packageName = args.safeGetAtRange(2) else {
        print("Please specify a package to remove."
            .termStyled(TermStylePresets.error))
        exit(1)
    }
    
    let loader = BrailleLoader(message: "Removing \(packageName)...")
    loader.start()
    
    do {
        try removePackage(
            bashketHome: bashketHome,
            packageName: packageName
        )
    } catch {
        if !CommandLine.arguments.contains("--bashket-sudo-reexec"),
           isPermissionError(error) {
            
            loader.stop(clearLine: true)
            relaunchWithSudoIfNeededAndExit()
        }
        
        loader.stop(clearLine: true)
        
        // pakfile missing is the most common error
        print("Package '\(packageName)' is not installed."
            .termStyled(TermStylePresets.error))
        exit(1)
    }
    
    loader.stop(clearLine: true)
    
    print("\(packageName) removed successfully!"
        .termStyled(TermStylePresets.success))
} else if args.safeGetAtRange(1) == "list" {
    // MARK: - List
    
    print("Installed packages:".termStyled([.bold]))
    print()
    let pakDir = bashketHome.appendingPathComponent("pakfiles", isDirectory: true)
    let fm = FileManager.default
    var found = false
    var count = 0
    
    if let files = try? fm.contentsOfDirectory(atPath: pakDir.path) {
        for f in files where f.hasSuffix(".bpkc") {
            let name = String(f.dropLast(5))
            found = true
            count += 1
            print(name)
        }
    }
    
    if !found {
        print("No installed packages.".termStyled(TermStylePresets.error))
    } else {
        print()
        print("Total: \(count)".termStyled([.bold]))
    }
} else if args.safeGetAtRange(1) == "help" {
    // MARK: - Print help
    
    printHelp(for: args.safeGetAtRange(2))
} else if args.safeGetAtRange(1) == "run" {
    // MARK: - Run
    
    guard let pkgName = args.safeGetAtRange(2) else {
        print("Please specify a package to run.".termStyled(TermStylePresets.error))
        exit(1)
    }

    runPkg(pkgName, bashketHome: bashketHome)
} else if args.safeGetAtRange(1) == "publish" {
    // MARK: - Publish
    
    guard let path = args.safeGetAtRange(2) else {
        print("Please specify a .bpk file."
            .termStyled(TermStylePresets.error))
        exit(1)
    }
    
    guard path.hasSuffix(".bpk") else {
        print("Must be a .bpk file."
            .termStyled(TermStylePresets.error))
        exit(1)
    }

    let password = promptPackagePassword(create: true, teardown: false)

    let fileURL = URL(fileURLWithPath: path)

    let loader = BrailleLoader(message: "Publishing package...")
    loader.start()

    do {
        let endpoint = URL(
            string: "http://bashket-api.atwebpages.com/add_package.php"
        )!

        try publishPackage(
            pakFile: fileURL,
            endpoint: endpoint,
            password: password
        )

        loader.stop(clearLine: true)
        print("Package published successfully!"
            .termStyled(TermStylePresets.success))
    } catch {
        loader.stop(clearLine: true)
        print("Publish failed: \(error.localizedDescription)"
            .termStyled(TermStylePresets.error))
        exit(1)
    }
} else if args.safeGetAtRange(1) == "teardown" {
    // MARK: - Teardown
    
    guard let packageName = args.safeGetAtRange(2) else {
        print("Please specify a package."
            .termStyled(TermStylePresets.error))
        exit(1)
    }
    
    let password = promptPackagePassword(create: false, teardown: true)
    
    let loader = BrailleLoader(message: "Removing package from registry...")
    loader.start()
    
    do {
        let endpoint = URL(
            string: "http://bashket-api.atwebpages.com/teardown_package.php"
        )!
        
        try teardownPackage(
            name: packageName,
            password: password,
            endpoint: endpoint
        )
        
        loader.stop(clearLine: true)
        
        print("Package removed from Bashket registry."
            .termStyled(TermStylePresets.success))
    } catch {
        loader.stop(clearLine: true)

        let message = error.localizedDescription.replacingOccurrences(
            of: "{\"error\":\"Invalid password\"}",
            with: "Invalid password"
        )

        print("Teardown failed: \(message)".termStyled(TermStylePresets.error))

        exit(1)
    }
} else {
    print("Please specify a command.".termStyled(TermStylePresets.error))
    print()
    printHelp()
    exit(1)
}

exit(0)
