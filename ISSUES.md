# ISSUES.md

---

## 1: Crash parsing BarramundiFish.glb - fatalError in scanChunk()

+++
status: closed
priority: medium
kind: bug
labels: effort:s, area:parsing
created: 2026-04-02T23:25:38Z
updated: 2026-10-05T13:18:48Z
closed: 2026-10-05T13:18:48Z
+++

Loading /Users/schwa/Shared/Organised/3D Models/glTF-Sample-Models/1.0/BarramundiFish/glTF-Binary/BarramundiFish.glb (2.7MB) crashes in Scanner.scanChunk() with a fatalError. The crash is in the force-unwrap of ChunkType(rawValue:) — likely an unrecognized chunk type in the binary container.

Crash site:
```swift
mutating func scanChunk() -> Chunk? {
    ...
    return Chunk(chunkLength: chunkLength, chunkType: .init(rawValue: chunkType)!, content: Data(content))
}
```

The force-unwrap on ChunkType init should be replaced with proper error handling.

- `2026-10-05T12:47:50Z`: Related: #2 adds a test suite that would catch this crash.
- `2026-10-05T13:18:48Z`: Fixed: GLB scanner now throws GLTFError.malformedGLB instead of fatalError; removed ChunkType force-unwrap.

---

## 2: Add unit tests for loading all Khronos glTF-Sample-Assets models

+++
status: open
priority: medium
kind: enhancement
labels: effort:m, area:testing
created: 2026-04-02T23:35:06Z
updated: 2026-10-05T12:47:50Z
+++

SwiftGLTF crashes on some valid glTF files (e.g. BarramundiFish.glb — see #1). We should have a test suite that attempts to load every model from https://github.com/KhronosGroup/glTF-Sample-Assets and verifies no crashes or parse failures. The test data can be downloaded to a local cache directory. At minimum, test that Container(url:) and document parsing succeed without throwing or crashing.

- `2026-10-05T12:47:50Z`: Related: #1 is a concrete crash this suite should catch.

---

## 3: Errors when using as dependency

+++
status: closed
priority: medium
kind: bug
created: 2026-04-04T02:59:03Z
updated: 2026-04-04T02:59:06Z
closed: 2026-04-04T02:59:06Z
+++

GH#1 (originally CLOSED). User gets errors when using SwiftGLTF as a dependency to their own Swift library, even though the xcode project from this repo works fine.

- `2026-04-04T02:59:06Z`: Was closed on GitHub

---

## 4: Models fail to import when byteStride is non-zero

+++
status: closed
priority: medium
kind: bug
labels: effort:s, area:parsing
created: 2026-04-04T02:59:03Z
updated: 2026-10-05T13:18:48Z
closed: 2026-10-05T13:18:48Z
+++

GH#2. The model's bufferView contains a byteStride of 12 and fails to import. Tracked to gltf.swift L133-135.

- `2026-10-05T13:18:48Z`: Fixed: data(for accessor:) de-interleaves non-zero byteStride buffer views and bounds-checks.

---

## 5: Type SRT does not conform to protocol Hashable

+++
status: closed
priority: medium
kind: bug
created: 2026-04-04T02:59:03Z
updated: 2026-04-04T02:59:06Z
closed: 2026-04-04T02:59:06Z
+++

GH#4 (originally CLOSED). Build error in Demo: Type SRT does not conform to protocol Hashable.

- `2026-04-04T02:59:06Z`: Was closed on GitHub

---

## 6: Animation support in RealityKit Entity

+++
status: closed
priority: medium
kind: enhancement
created: 2026-04-04T02:59:03Z
updated: 2026-04-04T02:59:06Z
closed: 2026-04-04T02:59:06Z
+++

GH#5 (originally CLOSED). Animations embedded in glb/gltf are not implemented for the RealityKit entity version.

- `2026-04-04T02:59:06Z`: Was closed on GitHub

---

## 7: Rendering of Khronos group model doesnt work

+++
status: open
priority: high
kind: bug
labels: effort:m, area:rendering
created: 2026-04-04T02:59:03Z
updated: 2026-10-05T12:47:50Z
+++

GH#11. DamagedHelmet model fails to render. Various debug log errors about material resolution and file status. macOS 14.1.1, Xcode 15.0.1, iOS 17.0.2.

---
