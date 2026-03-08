# Bashket

**Bashket** is a lightweight package manager for installing command-line tools.

---

# Install Bashket

Run:
```bash
curl -fsSL https://raw.githubusercontent.com/milestones14/bashket/main/install.sh | bash
```

---

# Installing Packages

Install a package with:

```
bashket install <package>
```

Example:

```
bashket install mytool
```

After installing, you can run the tool directly:

```
mytool
```

---

# Listing Installed Packages

To see everything you have installed:

```
bashket list
```

---

# Removing Packages

To uninstall a package:

```
bashket rm <package>
```

Example:

```
bashket rm mytool
```

---

# Running Packages Through Bashket

Normally packages can be run directly.

You can also run them through Bashket if needed:

```
bashket run <package> [arguments]
```

Example:

```
bashket run mytool --help
```

---

# For Developers

Packages are published to the Bashket registry using `.bpk` (Bashket Pakfile) files.

## Publishing

```bash
bashket publish <file.bpk>
```
You will be prompted for a password, this allows you to manage your package later on.

The `.bpk` file contains JSON describing the package.

### Example BPK file

```json
{
  "name": "myPak",
  "binaryPath": "https://example.com/myPak",
  "dependencies": null
}
```

### Fields

| Field          | Description                                |
| -------------- | ------------------------------------------ |
| `name`         | Package name and resulting executable name |
| `binaryPath`   | Direct URL to the package binary           |
| `dependencies` | Optional dependencies                      |

> [!IMPORTANT]
> **Bashket does NOT host binaries.**
>
> `binaryPath` must point to a binary hosted elsewhere.
>
> If you do not have your own domain, hosting the binary on **GitHub** and linking to the raw file is recommended.
>
> **Zipped archives are not currently supported.**

### Removing packages from Bashket (teardown)

To remove a package from Bashket, use the **teardown** command:

```bash
bashket teardown <package>
```

Note: You must provide the password set when publishing the package.

### Executable Name

The executable name comes from **`name`**, not `binaryPath`.

Example:

```
name: "abc"
binaryPath: "https://example.com/def"
```

Users run:

```bash
abc
```

Not:

```bash
def
```
