import Foundation

func pakfileURL(bashketHome: URL, packageName: String) -> URL {
    bashketHome
        .appendingPathComponent("pakfiles", isDirectory: true)
        .appendingPathComponent(packageName + ".bpkc")
}

func writePakfile(bashketHome: URL, package: Package) throws {
    let dto = package.toDTO()
    let json = try JSONEncoder().encode(dto)
    let encrypted = xor(json)
    let url = pakfileURL(bashketHome: bashketHome, packageName: package.name)
    try encrypted.write(to: url, options: .atomic)
}

func readPakfile(bashketHome: URL, packageName: String) throws -> Package {
    let url = pakfileURL(bashketHome: bashketHome, packageName: packageName)
    let encrypted = try Data(contentsOf: url)
    let json = xor(encrypted)
    let dto = try JSONDecoder().decode(PackageDTO.self, from: json)
    return Package.fromDTO(dto)
}
