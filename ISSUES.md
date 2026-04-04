## 1: Crash parsing BarramundiFish.glb - fatalError in scanChunk()
status: new
priority: medium
kind: bug
created: 2026-04-02T23:25:38Z

Loading /Users/schwa/Shared/Organised/3D Models/glTF-Sample-Models/1.0/BarramundiFish/glTF-Binary/BarramundiFish.glb (2.7MB) crashes in Scanner.scanChunk() with a fatalError. The crash is in the force-unwrap of ChunkType(rawValue:) — likely an unrecognized chunk type in the binary container.

Crash site:
```swift
mutating func scanChunk() -> Chunk? {
    ...
    return Chunk(chunkLength: chunkLength, chunkType: .init(rawValue: chunkType)!, content: Data(content))
}
```

The force-unwrap on ChunkType init should be replaced with proper error handling.

---

## 2: Add unit tests for loading all Khronos glTF-Sample-Assets models
status: new
priority: medium
kind: enhancement
created: 2026-04-02T23:35:06Z

SwiftGLTF crashes on some valid glTF files (e.g. BarramundiFish.glb — see #1). We should have a test suite that attempts to load every model from https://github.com/KhronosGroup/glTF-Sample-Assets and verifies no crashes or parse failures. The test data can be downloaded to a local cache directory. At minimum, test that Container(url:) and document parsing succeed without throwing or crashing.

---

## 3: Errors when using as dependency
status: closed
priority: medium
kind: bug
created: 2026-04-04T02:59:03Z
updated: 2026-04-04T02:59:06Z
closed: 2026-04-04T02:59:06Z

GH#1 (originally CLOSED). User gets errors when using SwiftGLTF as a dependency to their own Swift library, even though the xcode project from this repo works fine.

- `2026-04-04T02:59:06Z`: Was closed on GitHub

---

## 4: Models fail to import when byteStride is non-zero
status: new
priority: medium
kind: bug
created: 2026-04-04T02:59:03Z

GH#2. The model's bufferView contains a byteStride of 12 and fails to import. Tracked to gltf.swift L133-135.

---

## 5: Type SRT does not conform to protocol Hashable
status: closed
priority: medium
kind: bug
created: 2026-04-04T02:59:03Z
updated: 2026-04-04T02:59:06Z
closed: 2026-04-04T02:59:06Z

GH#4 (originally CLOSED). Build error in Demo: Type SRT does not conform to protocol Hashable.

- `2026-04-04T02:59:06Z`: Was closed on GitHub

---

## 6: Animation support in RealityKit Entity
status: closed
priority: medium
kind: enhancement
created: 2026-04-04T02:59:03Z
updated: 2026-04-04T02:59:06Z
closed: 2026-04-04T02:59:06Z

GH#5 (originally CLOSED). Animations embedded in glb/gltf are not implemented for the RealityKit entity version.

- `2026-04-04T02:59:06Z`: Was closed on GitHub

---

## 7: Rendering of Khronos group model doesnt work
status: new
priority: medium
kind: bug
created: 2026-04-04T02:59:03Z

GH#11. DamagedHelmet model fails to render. Various debug log errors about material resolution and file status. macOS 14.1.1, Xcode 15.0.1, iOS 17.0.2.

---

