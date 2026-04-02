## 1: Crash parsing BarramundiFish.glb - fatalError in scanChunk()
status: new
priority: medium
kind: bug
created: 2026-04-02T23:25:38.426872+00:00

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
created: 2026-04-02T23:35:06.536445+00:00

SwiftGLTF crashes on some valid glTF files (e.g. BarramundiFish.glb — see #1). We should have a test suite that attempts to load every model from https://github.com/KhronosGroup/glTF-Sample-Assets and verifies no crashes or parse failures. The test data can be downloaded to a local cache directory. At minimum, test that Container(url:) and document parsing succeed without throwing or crashing.

---

