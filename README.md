# ZhareHubSDK

A Swift package for processing, extracting, and parsing iOS application packages (`.ipa`, `.app`, `.zip`) with built-in networking capabilities for uploading and downloading.

## Requirements

| Platform | Minimum Version |
|----------|----------------|
| iOS | 17.0 |
| Mac Catalyst | 17.0 |
| Swift | 6.2 |

## Installation

### Swift Package Manager

Add ZhareHubSDK to your project via SPM. In your `Package.swift`:

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
| [Zip](https://github.com/marmelroy/Zip) | 2.1.2+ | Archive extraction |
| [SUICore](https://github.com/hariharan-rs-19343/SUICore) | main | Core utilities & file management |

## Architecture

ZhareHubSDK is organized into three main modules:

```
ZhareHubSDK
├── iOSPackageHandler    # Package processing, extraction & parsing
├── Networking           # HTTP request builder & network service
├── Utilities            # Extensions (UTType, Bundle)
└── Errors               # Typed error handling
```

### Design Patterns

- **Strategy Pattern** — Each supported file type (`.ipa`, `.zip`, `.app`) has its own extraction strategy conforming to `PackageExtractionProtocol`.
- **Builder Pattern** — `RequestBuilder` provides a fluent API for constructing network requests.
- **Protocol-Oriented Design** — Core behaviors are defined through protocols (`PackageProcessorProtocol`, `NetworkServiceProtocol`, `PackageParserProtocol`, etc.) enabling easy testing and dependency injection.

## Usage

### Package Extraction

Extract metadata, app icons, provisioning profiles, and `Info.plist` data from iOS packages:

```swift
import ZhareHubSDK

let handler = PackageExtractionHandler()

let result = handler.initiateAppExtraction(from: fileURL, fileName: "MyApp.ipa")

switch result {
case .success(let model):
    // model.appIcon       — App icon as Data
    // model.app           — Raw app binary as Data
    // model.mobileProvision — Provisioning profile as Data
    // model.infoPropertyList — Info.plist as Data
    // model.fileName      — Original file name
    print("Extracted: \(model.fileName ?? "")")

case .failure(let error):
    print("Extraction failed: \(error.localizedDescription)")
}
```

#### Supported File Types

| Format | Strategy | Behavior |
|--------|----------|----------|
| `.ipa` | `IPAExtractionStrategy` | Converts to `.zip`, extracts Payload, reads app bundle contents |
| `.zip` | `ZipExtractionStrategy` | Extracts directly and locates the `.app` bundle inside |
| `.app` | `APPExtractionStrategy` | Reads the bundle directly; zips it for upload preparation |

### Package Processing

Lower-level API for converting and extracting package archives:

```swift
let processor = AppPackageProcessor()
let payloadURL = try processor.processPackage(of: sourceURL)
```

### Parsing Bundle Metadata

Parse `Info.plist` and provisioning profiles into strongly-typed models:

```swift
let parser = DefaultPackageParser()

// Deserialize Info.plist
let plistResult = parser.deserializePlist(plistData)
if case .success(let dict) = plistResult, let dict {
    let bundle = parser.loadBundleProperties(with: dict)
    print(bundle?.bundleName)       // e.g. "MyApp"
    print(bundle?.bundleIdentifier) // e.g. "com.example.myapp"
    print(bundle?.minimumOSVersion) // e.g. "17.0"
}

// Parse provisioning profile
let xmlResult = parser.extractXMLFromProvision(provisionData)
if case .success(let xmlData) = xmlResult,
   case .success(let provDict) = parser.deserializePlist(xmlData),
   let provDict {
    let provision = parser.loadMobileProvision(with: provDict)
    print(provision?.teamName)       // e.g. "My Team"
    print(provision?.expirationDate) // Expiration date
}
```

#### Key Models

- **`BundleProperties`** — Bundle name, version, identifier, minimum OS version, supported platforms, app icon name, redirect URL, and app category.
- **`MobileProvision`** — Provisioning profile name, team identifier, team name, creation/expiration dates, and expiry check.
- **`PackageExtractionModel`** — Aggregated extraction output containing file name, app icon, app binary, provisioning profile, and property list data.

### Networking

Build and execute HTTP requests with progress tracking:

```swift
let service = ZhareHubNetworkService()

// Build a request
let request = RequestBuilder(path: "https://api.example.com/upload")
    .set(method: .post)
    .set(headers: HTTPHeaders(["Authorization": "Bearer token"]))
    .set(binary: appData)
    .set(timeoutInterval: 120)
    .build()

// Upload with progress
let response: MyResponse = try await service.upload(request: request) { progress in
    print("Upload progress: \(progress * 100)%")
}

// Download to file
let fileURL: URL = try await service.download(request: downloadRequest) { progress in
    print("Download progress: \(progress * 100)%")
}

// Download as Data
let data: Data = try await service.download(request: downloadRequest) { progress in
    print("Download progress: \(progress * 100)%")
}

// Execute a standard request
let result: MyDecodable = try await service.execute(request: request)
```

The network service automatically validates HTTP responses and maps status codes to typed `NetworkError` cases. All active uploads and downloads can be cancelled via `cancelUploads()`, `cancelDownloads()`, or `cancelAllRequests()`.

## Error Handling

### `FileConversionError`

Covers file processing issues:

| Case | Description |
|------|-------------|
| `invalidFilePath` | File path is invalid or doesn't exist |
| `unsupportedFile` | File format is not supported |
| `packageToZipConversionError` | Failed to convert package to zip |
| `fileToDataConversionError` | Failed to convert file to Data |
| `infoPlistNotFoundInPayload` | Info.plist missing from payload |
| `appIconNotFoundInPayload` | App icon missing from payload |
| `provisioningProfileNotFoundInPayload` | Provisioning profile missing |
| `deserialiizationError` | Property list deserialization failed |
| `custom(String)` | Custom error message |

### `NetworkError`

Covers networking issues including `badRequest`, `userAuthenticationRequired`, `noNetworkAvailable`, `timeout`, `badServerResponse`, `fileDoesNotExist`, `isExplicitlyCancelled`, and more. All errors conform to `ErrorProtocol` (extending `LocalizedError`) for descriptive messages.

## Project Structure

```
Sources/ZhareHubSDK/
├── ZhareHubSDK.swift                          # Package entry point
├── ZHConstants.swift                          # Shared constants
├── Errors/
│   ├── FileConversionError.swift              # File processing errors
│   ├── NetworkError.swift                     # Network errors
│   └── Protocols/
│       └── ErrorProtocol.swift                # Base error protocol
├── iOSPackageHandler/
│   ├── AppPackageProcessor/
│   │   ├── AppPackageProcessor.swift          # Package processing coordinator
│   │   ├── DefaultArchiveOperations.swift     # Archive extraction operations
│   │   ├── DefaultPackageConversion.swift     # IPA → ZIP conversion
│   │   └── Protocols/                         # Processor protocols
│   ├── ExtractionHandler/
│   │   ├── PackageExtractionHandler.swift     # Main extraction orchestrator
│   │   ├── PackageExtractionStrategyResolver.swift  # Strategy resolver
│   │   ├── IPAExtractionStrategy.swift        # .ipa extraction
│   │   ├── ZipExtractionStrategy.swift        # .zip extraction
│   │   ├── APPExtractionStrategy.swift        # .app extraction
│   │   └── Protocol/
│   │       └── PackageExtractionProtocol.swift
│   └── PackageParsingHandler/
│       ├── DefaultPackageParser.swift         # Plist & provision parser
│       ├── DefaultPropertyListHandler.swift   # Low-level plist operations
│       ├── DownloadType.swift                 # Download type enum
│       ├── SupportedFileTypes.swift           # Supported file type enum
│       ├── Models/
│       │   ├── BundleProperties.swift         # Info.plist model
│       │   ├── MobileProvision.swift          # Provisioning profile model
│       │   └── PackageExtractionModel.swift   # Extraction result model
│       └── Protocols/                         # Parser protocols
├── Networking/
│   ├── builder/
│   │   └── RequestBuilder.swift               # Fluent request builder
│   ├── protocols/
│   │   ├── NetworkRequest.swift               # Request model
│   │   ├── NetworkRequestProtocol.swift       # Request protocol
│   │   └── NetworkServiceProtocol.swift       # Service protocol
│   └── service/
│       └── ZhareHubNetworkService.swift       # Alamofire-based network service
└── Utilities/
    └── Extensions/
        ├── Bundle+.swift                      # App version & ApplicationCategory enum
        └── UTType+.swift                      # .ipa and .app UTType definitions
```

## License

This project is proprietary. All rights reserved.
