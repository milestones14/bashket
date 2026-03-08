import Foundation

struct Package {
    let name: String
    let id: Int
    let binaryPath: URL
    let dependencies: [Package]?
}

struct PackageDTO: Codable {
    let name: String
    let id: Int
    let binaryPath: String
    let dependencies: [PackageDTO]?
}

struct PublishPackageDTO: Codable {
    let name: String
    let binaryPath: String
    let dependencies: [String]?
}

extension Package {
    func toDTO() -> PackageDTO {
        PackageDTO(
            name: name,
            id: id,
            binaryPath: binaryPath.absoluteString,
            dependencies: dependencies?.map { $0.toDTO() }
        )
    }

    static func fromDTO(_ dto: PackageDTO) -> Package {
        Package(
            name: dto.name,
            id: dto.id,
            binaryPath: URL(string: dto.binaryPath)!,
            dependencies: dto.dependencies?.map { Package.fromDTO($0) }
        )
    }
}

func getRemotePackageByName(
    _ name: String,
    endpoint: URL
) throws -> Package? {
    var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
    components.queryItems = [
        URLQueryItem(name: "name", value: name)
    ]

    let url = components.url!

    let sem = DispatchSemaphore(value: 0)

    var result: Package?
    var resultError: Error?

    let task = URLSession.shared.dataTask(with: url) { data, _, error in
        defer { sem.signal() }

        if let error = error {
            resultError = error
            return
        }

        guard let data = data else {
            return
        }

        do {
            let dto = try JSONDecoder().decode(PackageDTO.self, from: data)
            result = Package.fromDTO(dto)
        } catch {
            // 404 returns "null"
            if let s = String(data: data, encoding: .utf8),
               s.trimmingCharacters(in: .whitespacesAndNewlines) == "null" {
                result = nil
                return
            }

            resultError = error
        }
    }

    task.resume()
    sem.wait()

    if let e = resultError {
        throw e
    }

    return result
}

func removePackage(bashketHome: URL, packageName: String) throws {
    let pkg = try readPakfile(
        bashketHome: bashketHome,
        packageName: packageName
    )

    let fm = FileManager.default

    // 1. remove alias FIRST
    try removeAlias(name: packageName)

    // 2. remove binary
    if fm.fileExists(atPath: pkg.binaryPath.path) {
        try fm.removeItem(at: pkg.binaryPath)
    }

    // 3. remove pakfile LAST
    let pakURL = pakfileURL(
        bashketHome: bashketHome,
        packageName: packageName
    )

    if fm.fileExists(atPath: pakURL.path) {
        try fm.removeItem(at: pakURL)
    }
}

func installPackage(bashketHome: URL, package: Package) throws {
    if let deps = package.dependencies {
        for dep in deps {
            let pakURL = pakfileURL(bashketHome: bashketHome, packageName: dep.name)
            if !FileManager.default.fileExists(atPath: pakURL.path) {
                try installPackage(bashketHome: bashketHome, package: dep)
            }
        }
    }

    let installedBinary = try installBinary(bashketHome: bashketHome, package: package)

    try installAlias(
        forBinary: installedBinary,
        name: package.name
    )

    let installedPackage = Package(
        name: package.name,
        id: package.id,
        binaryPath: installedBinary,
        dependencies: package.dependencies
    )

    try writePakfile(bashketHome: bashketHome, package: installedPackage)
}

func runPkg(_ pkgName: String, bashketHome: URL) -> Never {
    let pkg: Package
    do {
        pkg = try readPakfile(
            bashketHome: bashketHome,
            packageName: pkgName
        )
    } catch {
        print("Package '\(pkgName)' is not installed.".termStyled(TermStylePresets.error))
        exit(1)
    }

    let binPath = pkg.binaryPath.path

    guard FileManager.default.isExecutableFile(atPath: binPath) else {
        print("Binary is not executable: \(binPath)".termStyled(TermStylePresets.error))
        exit(1)
    }

    let forwarded = Array(CommandLine.arguments.dropFirst(3))

    let argv = [binPath] + forwarded

    let cArgs = argv.map { strdup($0) } + [nil]

    execv(binPath, cArgs)

    perror(pkgName)
    exit(1)
}

func publishPackage(
    pakFile: URL,
    endpoint: URL,
    password: String
) throws {

    let data = try Data(contentsOf: pakFile)

    let dto = try JSONDecoder().decode(PublishPackageDTO.self, from: data)

    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.setValue(
        "application/x-www-form-urlencoded",
        forHTTPHeaderField: "Content-Type"
    )

    var items: [URLQueryItem] = [
        .init(name: "name", value: dto.name),
        .init(name: "binary_url", value: dto.binaryPath),
        .init(name: "password", value: password)
    ]

    if let deps = dto.dependencies {
        for d in deps {
            items.append(
                URLQueryItem(name: "dependencies[]", value: d)
            )
        }
    }

    var comps = URLComponents()
    comps.queryItems = items
    request.httpBody = comps.percentEncodedQuery?
        .data(using: .utf8)

    let sem = DispatchSemaphore(value: 0)
    var resultError: Error?

    let task = URLSession.shared.dataTask(with: request) { data, _, error in
        defer { sem.signal() }

        if let error = error {
            resultError = error
            return
        }

        guard let data = data else {
            resultError = NSError(domain: "bashket", code: 1)
            return
        }

        if let json = try? JSONSerialization.jsonObject(with: data),
           let dict = json as? [String: Any],
           let ok = dict["ok"] as? Bool,
           ok == true {
            return
        }

        let text = String(decoding: data, as: UTF8.self)
        resultError = NSError(
            domain: "bashket.publish",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: text]
        )
    }

    task.resume()
    sem.wait()

    if let e = resultError {
        throw e
    }
}

func teardownPackage(
    name: String,
    password: String,
    endpoint: URL
) throws {

    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.setValue(
        "application/x-www-form-urlencoded",
        forHTTPHeaderField: "Content-Type"
    )

    let items: [URLQueryItem] = [
        .init(name: "name", value: name),
        .init(name: "password", value: password)
    ]

    var comps = URLComponents()
    comps.queryItems = items

    request.httpBody =
        comps.percentEncodedQuery?
        .data(using: .utf8)

    let sem = DispatchSemaphore(value: 0)
    var resultError: Error?

    let task = URLSession.shared.dataTask(with: request) { data, _, error in
        defer { sem.signal() }

        if let error = error {
            resultError = error
            return
        }

        guard let data = data else {
            resultError = NSError(domain: "bashket", code: 1)
            return
        }

        if let json = try? JSONSerialization.jsonObject(with: data),
           let dict = json as? [String: Any],
           let ok = dict["ok"] as? Bool,
           ok == true {
            return
        }

        let text = String(decoding: data, as: UTF8.self)

        resultError = NSError(
            domain: "bashket.teardown",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: text]
        )
    }

    task.resume()
    sem.wait()

    if let e = resultError {
        throw e
    }
}
