# ZhareHubSDK

A Swift package for processing, extracting, and parsing **iOS / macCatalyst application packages** (`.ipa`, `.app`, `.zip`) and **Android application packages** (`.apk`), with built-in async networking for uploading and downloading.

ZhareHubSDK turns a raw app archive into a strongly-typed, ready-to-upload payload:

- **iOS / macCatalyst** — extracts the app binary, app icon, `Info.plist`, and embedded provisioning profile, parses bundle metadata, and generates the OTA installation manifest.
- **Android** (macCatalyst-only at runtime) — runs `aapt2 dump badging` via a host-supplied shell, parses package metadata, extracts the app icon (raster or vector / adaptive-icon rendered to PNG), and recovers the v1 / v2 / v3 signing certificate.

Everything is shipped over the network with progress reporting and cancellation.

---

## Requirements

| Platform | Minimum Version |
|----------|----------------|
| iOS | 26.0 |
| Mac Catalyst | 26.0 |
| Swift tools | 6.2 |

## Installation

### Swift Package Manager

In your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/<owner>/ZhareHubSDK.git", branch: "main")
]
```

Or in Xcode: **File → Add Package Dependencies…** and enter the repository URL.

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| [Alamofire](https://github.com/Alamofire/Alamofire) | 5.10.0+ | HTTP networking |
| [Zip](https://github.com/marmelroy/Zip) | 2.1.2+ | Archive extraction / compression (internal, iOS path) |
| [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) | 0.9.19+ | Single-entry archive reads (internal, APK path) |
| [SUICore](https://github.com/hariharan-rs-19343/SUICore) | main | File management, logging, connectivity, default avatar |

---

## Architecture

```
ZhareHubSDK
├── iOSPackageHandler/
│   ├── ExtractionHandler/        # PackageExtractionHandler + per-format strategies
│   ├── AppPackageProcessor/      # Lower-level archive/conversion utilities
│   └── PackageParsingHandler/    # Plist / mobile-provision parsing & models
├── androidPackageHandler/
│   ├── ExtractionHandler/        # APKExtractionHandler + APKExtractionStrategy + Resolver
│   ├── PackageParsingHandler/    # DefaultAPKBadgingParser + APK models
│   ├── SignatureHandler/         # DefaultAPKSignatureExtractor (v1 / v2 / v3)
│   ├── IconHandler/              # DefaultAPKIconExtractor + APKVectorIconParser
│   └── ArchiveSupport/           # APKZipReader (single-entry ZIPFoundation reader)
├── Networking/
│   ├── builder/                  # RequestBuilder (fluent API)
│   ├── protocols/                # NetworkRequest / NetworkRequestProtocol / NetworkServiceProtocol
│   └── service/                  # ZhareHubNetworkService (Alamofire-backed)
├── Utilities/
│   ├── Extensions/               # Bundle+, UTType+
│   └── Shell/                    # ShellExecutorProtocol (consumer-injected)
└── Errors/                       # FileConversionError, NetworkError, ErrorProtocol
```

### Design Patterns

- **Strategy Pattern** — Each supported file format (`.ipa`, `.zip`, `.app`) implements [PackageExtractionProtocol](Sources/ZhareHubSDK/iOSPackageHandler/ExtractionHandler/Protocol/PackageExtractionProtocol.swift). [PackageExtractionStrategyResolver](Sources/ZhareHubSDK/iOSPackageHandler/ExtractionHandler/PackageExtractionStrategyResolver.swift) selects the correct strategy by inspecting the URL.
- **Builder Pattern** — [RequestBuilder](Sources/ZhareHubSDK/Networking/builder/RequestBuilder.swift) provides a chainable API for constructing `NetworkRequest`s.
- **Protocol-Oriented Design** — Core behaviors are defined as protocols (`PackageProcessorProtocol`, `NetworkServiceProtocol`, `PackageParserProtocol`, `ArchiveOperationsProtocol`, `PackageConversionProtocol`, `PropertyListHandlerProtocol`) for easy testing and DI.
- **Default protocol implementations** — Common extraction logic (`extractInfoPlistData`, `extractMobileProvision`, `readAppIconName`, default-icon fallback) lives in a `PackageExtractionProtocol` extension and is overridden per strategy when needed.

---

## Usage

### 1. Package Extraction (high-level API)

[PackageExtractionHandler](Sources/ZhareHubSDK/iOSPackageHandler/ExtractionHandler/PackageExtractionHandler.swift) is the main entry point. It resolves a strategy, extracts the payload, locates the `.app` bundle, and returns a [PackageExtractionModel](Sources/ZhareHubSDK/iOSPackageHandler/PackageParsingHandler/Models/PackageExtractionModel.swift).

```swift
import ZhareHubSDK

let handler = PackageExtractionHandler()
let result = handler.initiateAppExtraction(from: fileURL, fileName: "MyApp.ipa")

switch result {
case .success(let model):
    // model.fileName         — original file name
    // model.appIcon          — Data (PNG; falls back to a generated letter avatar)
    // model.app              — Raw binary Data ready for upload
    // model.mobileProvision  — Provisioning-profile Data (nil for unsigned builds)
    // model.infoPropertyList — Info.plist Data
    print("Extracted: \(model.fileName ?? "")")

case .failure(let error):
    print("Extraction failed: \(error.localizedDescription)")
}
```

`initiateAppExtraction` automatically calls `startAccessingSecurityScopedResource()` for security-scoped URLs (e.g., `UIDocumentPicker` / drag-and-drop) and stops access on exit.

#### Supported File Types

| Format | Strategy | Behavior |
|--------|----------|----------|
| `.ipa` | [IPAExtractionStrategy](Sources/ZhareHubSDK/iOSPackageHandler/ExtractionHandler/IPAExtractionStrategy.swift) | Copies to `.zip`, unzips to cache, returns `Payload/` |
| `.zip` | [ZipExtractionStrategy](Sources/ZhareHubSDK/iOSPackageHandler/ExtractionHandler/ZipExtractionStrategy.swift) | Unzips directly, walks tree to find the `.app` bundle |
| `.app` | [APPExtractionStrategy](Sources/ZhareHubSDK/iOSPackageHandler/ExtractionHandler/APPExtractionStrategy.swift) | Reads bundle in place; on macCatalyst dives into `Contents/`; zips before upload |

The `.app` strategy additionally:
- Reads `embedded.provisionprofile` (instead of `.mobileprovision`).
- Falls back to `Resources/*.icns` for the icon when no `CFBundleIcons` entry is present.

### 1b. Android Package Extraction

Android extraction lives under [androidPackageHandler/](Sources/ZhareHubSDK/androidPackageHandler/) and is fully parallel to the iOS family — it does **not** share `PackageExtractionProtocol`. The entry point is [APKExtractionHandler](Sources/ZhareHubSDK/androidPackageHandler/ExtractionHandler/APKExtractionHandler.swift).

#### Runtime contract

The SDK does **not** ship `aapt2` and does **not** ship a process-execution helper. The host application is responsible for:

1. Bundling an **`aapt2`** binary inside its app bundle (any modern Android build-tools version works).
2. Providing a concrete [ShellExecutorProtocol](Sources/ZhareHubSDK/Utilities/Shell/ShellExecutorProtocol.swift) that can spawn `aapt2`. On Mac Catalyst this typically means loading a small **macOS helper bundle** (`Bundle.main.builtInPlugInsURL` → `ShellHelper.bundle`) and calling its principal class, since `Foundation.Process` is unavailable on iOS / macCatalyst directly.
3. Calling APK APIs only on Mac Catalyst — they throw [`FileConversionError.unsupportedPlatform`](Sources/ZhareHubSDK/Errors/FileConversionError.swift) at runtime when [`ShellExecutorProtocol.isAvailable`](Sources/ZhareHubSDK/Utilities/Shell/ShellExecutorProtocol.swift) is `false`.

#### Usage

```swift
import ZhareHubSDK

// 1. Consumer-injected shell (loads ShellHelper.bundle on macCatalyst)
let shell: ShellExecutorProtocol = MyAppShellExecutor()

// 2. Path to bundled aapt2
guard let aapt2Path = Bundle.main.path(forResource: "aapt2", ofType: nil) else { return }

let handler = APKExtractionHandler(shell: shell, aapt2Path: aapt2Path)

let result = await handler.initiateAPKExtraction(from: apkURL, fileName: "MyApp.apk")

switch result {
case .success(let model):
    // model.fileName        — original file name
    // model.appIcon         — PNG Data (raster, or rendered vector / adaptive icon)
    // model.app             — Raw .apk bytes ready for upload
    // model.iconSourcePath  — Source path inside the APK (e.g. "res/mipmap-xxxhdpi/ic_launcher.png")
    // model.properties      — APKBundleProperties (package, versions, SDKs, permissions, features…)
    // model.signature       — APKSignatureInfo (signer DN, signing schemes — "v1, v2, v3")
    print(model.properties?.appName ?? "")
    print(model.properties?.packageName ?? "")
    print(model.signature?.signingSchemes ?? "")

case .failure(FileConversionError.unsupportedPlatform):
    // Running on iOS device — APK extraction is macCatalyst-only.
    break

case .failure(let error):
    print(error.localizedDescription)
}
```

#### Pipeline

[APKExtractionStrategy](Sources/ZhareHubSDK/androidPackageHandler/ExtractionHandler/APKExtractionStrategy.swift) runs:

1. `aapt2 dump badging <apk>` (via injected shell).
2. [DefaultAPKBadgingParser](Sources/ZhareHubSDK/androidPackageHandler/PackageParsingHandler/DefaultAPKBadgingParser.swift) → [APKBundleProperties](Sources/ZhareHubSDK/androidPackageHandler/PackageParsingHandler/Models/APKBundleProperties.swift).
3. **In parallel:**
   - [DefaultAPKIconExtractor](Sources/ZhareHubSDK/androidPackageHandler/IconHandler/DefaultAPKIconExtractor.swift) — 4 strategies: direct raster path → vector / adaptive-icon rendered via [APKVectorIconParser](Sources/ZhareHubSDK/androidPackageHandler/IconHandler/APKVectorIconParser.swift) → adaptive-icon foreground PNG resolution → density scan → best-square-PNG fallback for obfuscated APKs.
   - [DefaultAPKSignatureExtractor](Sources/ZhareHubSDK/androidPackageHandler/SignatureHandler/DefaultAPKSignatureExtractor.swift) — native Swift parsing of the APK Signing Block (no shell calls): v1 (`META-INF/MANIFEST.MF` + `.RSA`/`.DSA`/`.EC`), v2 (block ID `0x7109871a`), v3 (block ID `0xf05368c0`); DER-decodes the signer certificate, picks Organization > Common Name > OU.
4. Reads raw APK bytes for upload.
5. Aggregates into [APKExtractionModel](Sources/ZhareHubSDK/androidPackageHandler/PackageParsingHandler/Models/APKExtractionModel.swift).

#### Vector / adaptive icon rendering

[APKVectorIconParser](Sources/ZhareHubSDK/androidPackageHandler/IconHandler/APKVectorIconParser.swift) parses `aapt2 dump xmltree` output, decodes Android `pathData` (M / L / H / V / C / S / Q / T / A / Z, including arc-to-bezier conversion), composites adaptive-icon foreground + background through a superellipse (squircle) mask, and renders to a `UIImage` via `UIGraphicsImageRenderer`. Drawable references and color resources are resolved through `aapt2 dump resources`.

#### Customizing the pipeline

All dependencies are constructor-injected — pass alternate implementations to override default behavior:

```swift
let handler = APKExtractionHandler(
    resolver: APKExtractionStrategyResolver(strategies: [MyAPKStrategy()]),
    parser: MyBadgingParser(),
    signatureExtractor: MySignatureExtractor(),
    iconExtractor: MyIconExtractor(),
    shell: shell,
    aapt2Path: aapt2Path
)
```

### 2. Lower-level Package Processing

[AppPackageProcessor](Sources/ZhareHubSDK/iOSPackageHandler/AppPackageProcessor/AppPackageProcessor.swift) exposes the conversion + extraction step on its own:

```swift
let processor = AppPackageProcessor()
let payloadURL = try processor.processPackage(of: sourceURL)
```

It uses [DefaultPackageConversion](Sources/ZhareHubSDK/iOSPackageHandler/AppPackageProcessor/DefaultPackageConversion.swift) (rename `.ipa` → `.zip` in the cache) and [DefaultArchiveOperations](Sources/ZhareHubSDK/iOSPackageHandler/AppPackageProcessor/DefaultArchiveOperations.swift) (Zip-backed unzip).

### 3. Parsing Bundle Metadata

[DefaultPackageParser](Sources/ZhareHubSDK/iOSPackageHandler/PackageParsingHandler/DefaultPackageParser.swift) deserializes `Info.plist` and provisioning profiles into typed models.

```swift
let parser = DefaultPackageParser()

// Info.plist → BundleProperties
if case .success(let dict?) = parser.deserializePlist(plistData) {
    let bundle = parser.loadBundleProperties(with: dict)
    print(bundle?.bundleName)        // "MyApp"
    print(bundle?.bundleIdentifier)  // "com.example.myapp"
    print(bundle?.minimumOSVersion)  // "17.0"
    print(bundle?.appCategory.friendlyName) // "Productivity"
}

// .mobileprovision → MobileProvision
if case .success(let xml) = parser.extractXMLFromProvision(provisionData),
   case .success(let dict?) = parser.deserializePlist(xml) {
    let provision = parser.loadMobileProvision(with: dict)
    print(provision?.teamName)
    print(provision?.expirationDate)
}

// Generate OTA installation manifest plist
let manifest = parser.generatePropertyList(
    fileURL: "https://cdn.example.com/MyApp.ipa",
    bundleId: "com.example.myapp",
    bundleVersion: "1.0.0",
    fileName: "MyApp"
)
```

#### Key Models

- [BundleProperties](Sources/ZhareHubSDK/iOSPackageHandler/PackageParsingHandler/Models/BundleProperties.swift) — `Decodable` + `Hashable`. Maps `CFBundleName`, `CFBundleShortVersionString`, `CFBundleVersion`, `CFBundleIdentifier`, `MinimumOSVersion`, `UIRequiredDeviceCapabilities`, `CFBundleSupportedPlatforms`, primary `CFBundleIcons` file, first `CFBundleURLTypes` redirect URL, and `LSApplicationCategoryType` → `Bundle.ApplicationCategory`.
- [MobileProvision](Sources/ZhareHubSDK/iOSPackageHandler/PackageParsingHandler/Models/MobileProvision.swift) — Name, team identifiers, team name, creation/expiration dates, `isExpired`. Includes a separate `Entitlements` struct.
- [PackageExtractionModel](Sources/ZhareHubSDK/iOSPackageHandler/PackageParsingHandler/Models/PackageExtractionModel.swift) — Aggregated extraction output: `fileName`, `appIcon`, `app`, `mobileProvision`, `infoPropertyList`, optional `installationPList`. Provides `isContentAvailable()`.
- [Bundle.ApplicationCategory](Sources/ZhareHubSDK/Utilities/Extensions/Bundle+.swift) — Full enumeration of Apple's `LSApplicationCategoryType` values with `friendlyName`.

### 4. Networking

Build requests fluently and execute them with async/await.

```swift
import Alamofire
import ZhareHubSDK

let service = ZhareHubNetworkService()

let request = RequestBuilder(path: "https://api.example.com/upload")
    .set(method: .post)
    .set(headers: HTTPHeaders(["Authorization": "Bearer \(token)"]))
    .set(binary: appData)
    .set(timeoutInterval: 120)
    .build()

// Upload (typed response)
let response: UploadResponse = try await service.upload(request: request) { fraction in
    print("Upload: \(Int(fraction * 100))%")
}

// Download to a file URL
let fileURL: URL = try await service.download(request: request) { fraction in
    print("Download: \(Int(fraction * 100))%")
}

// Download as Data
let data: Data = try await service.download(request: request) { _ in }

// Standard request
let result: MyDecodable = try await service.execute(request: request)
```

#### Behaviors

- Pre-flight check via `ConnectionStatus.shared.isNetworkAvailable` (from SUICore) — throws `NetworkError.noNetworkAvailable` when offline.
- `validateHTTPResponse` maps status codes (400, 401, 403, 404, 408, 500) to typed `NetworkError` cases.
- All in-flight uploads/downloads are tracked by UUID and can be cancelled via `cancelUploads()`, `cancelDownloads()`, or `cancelAllRequests()`. Cancellation is also invoked on `deinit`.

---

## Errors

- [FileConversionError](Sources/ZhareHubSDK/Errors/FileConversionError.swift) — `invalidFilePath`, `packageToZipConversionError`, `fileToDataConversionError`, `fileReadFailed`, `unsupportedFile`, `infoPlistNotFoundInPayload`, `appIconNotFoundInPayload`, `provisioningProfileNotFoundInPayload`, `deserialiizationError`, `unsupportedPlatform`, `custom(String)`.
- [NetworkError](Sources/ZhareHubSDK/Errors/NetworkError.swift) — Full HTTP-mapped set plus `noNetworkAvailable`, `isExplicitlyCancelled`, `serializationFailed`, `custom(String, String?)`.
- [PropertyListError](Sources/ZhareHubSDK/iOSPackageHandler/PackageParsingHandler/DefaultPropertyListHandler.swift) — `missingRequiredData`, `failedToCreateFile`.

All conform to a shared [ErrorProtocol](Sources/ZhareHubSDK/Errors/Protocols/ErrorProtocol.swift).

---

## Constants

[ZHConstants](Sources/ZhareHubSDK/ZHConstants.swift):

| Name | Value |
|------|-------|
| `PAYLOAD` | `Payload` |
| `EMBEDDED_MOBILE_PROVISION` | `embedded.mobileprovision` |
| `EMBEDDED_PROVISION_PROFILE` | `embedded.provisionprofile` |
| `INFO_PLIST` | `Info.plist` |
| `INSTALLATION_PREFIX` | `itms-services://?action=download-manifest&url=` |
| `AAPT2_TOOL_NAME` | `aapt2` |
| `APK_FILE_EXTENSION` | `apk` |
| `ANDROID_MANIFEST` | `AndroidManifest.xml` |

---

## Testing

```bash
swift test
```

Tests live under [Tests/ZhareHubSDKTests/ZhareHubSDKTests.swift](Tests/ZhareHubSDKTests/ZhareHubSDKTests.swift).

---

## License

This project is proprietary. All rights reserved.
