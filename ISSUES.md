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
status: closed
priority: medium
kind: enhancement
labels: effort:m, area:testing
created: 2026-04-02T23:35:06Z
updated: 2026-10-05T13:55:47Z
closed: 2026-10-05T13:55:47Z
+++

SwiftGLTF crashes on some valid glTF files (e.g. BarramundiFish.glb — see #1). We should have a test suite that attempts to load every model from https://github.com/KhronosGroup/glTF-Sample-Assets and verifies no crashes or parse failures. The test data can be downloaded to a local cache directory. At minimum, test that Container(url:) and document parsing succeed without throwing or crashing.

- `2026-10-05T12:47:50Z`: Related: #1 is a concrete crash this suite should catch.
- `2026-10-05T13:55:47Z`: Delivered: SampleAssetsTests loads every glTF-Binary sample model (parse + accessor access, crash-safe); DamagedHelmet also rendered via SceneKit and RealityKit. Data from local .sample-assets (just download-sample-assets); CI clones it. Non-binary variant coverage can be a future enhancement.

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
status: closed
priority: high
kind: bug
labels: effort:m, area:rendering
created: 2026-04-04T02:59:03Z
updated: 2026-10-05T13:42:23Z
closed: 2026-10-05T13:42:23Z
+++

GH#11. DamagedHelmet model fails to render. Various debug log errors about material resolution and file status. macOS 14.1.1, Xcode 15.0.1, iOS 17.0.2.

- `2026-10-05T13:42:23Z`: Fixed by the SceneKit interleaved-accessor fix (accessor.byteOffset was ignored). DamagedHelmet.glb now builds a RealityKit entity successfully; covered by RealityKitRenderingTests.generatesDamagedHelmet.

---

## 8: Use glTF node cameras in SceneKit/RealityKit generators

+++
status: open
priority: high
kind: feature
labels: effort:s, area:rendering
created: 2026-10-05T13:57:24Z
updated: 2026-10-05T13:58:26Z
+++

Camera is parsed but neither generator applies node cameras. Both render tests must hand-build a camera. Apply perspective/orthographic cameras from the glTF node graph.

Acceptance: a model with a camera renders from that camera; generators expose the active camera node/entity.

---

## 9: SceneKit generator cannot load GLB buffers

+++
status: closed
priority: high
kind: enhancement
labels: effort:s, area:rendering
created: 2026-10-05T13:57:24Z
updated: 2026-10-05T14:03:14Z
closed: 2026-10-05T14:03:14Z
+++

SceneKitGenerator.data(for:) throws GLTFError.missingResource for GLB because buffers have no uri. RealityKit and Container already read the binary chunk. Make SceneKit resolve the GLB binary buffer the same way.

Acceptance: generateSCNScene() works on a .glb (e.g. DamagedHelmet.glb); add a render test.

- `2026-10-05T14:03:14Z`: SceneKitGenerator now resolves GLB binary buffers (new init(container:)) and loads bufferView-backed images; generateSCNScene() works on DamagedHelmet.glb. Test: generatesSCNSceneFromGLB (test fails before fix with missingResource, passes after).

---

## 10: RealityKit materials only set baseColor

+++
status: open
priority: high
kind: feature
labels: effort:m, area:rendering
created: 2026-10-05T13:57:24Z
updated: 2026-10-05T13:58:26Z
+++

makeMaterial only sets baseColor (tint + optional texture). Missing: normal, metallic, roughness, occlusion, emissive maps and factors, plus texCoord/texture transform.

Acceptance: a PBR model (DamagedHelmet) renders with normal/metallic-roughness/emissive maps via RealityKit; golden test.

---

## 11: Animation support (channels, samplers, playback)

+++
status: open
priority: medium
kind: feature
labels: effort:xl, area:rendering
created: 2026-10-05T13:57:24Z
updated: 2026-10-05T13:58:26Z
+++

Animation is an empty stub: no channels/samplers, no keyframe sampling. Parse animation channels/samplers (TRS + morph weights targets) and drive SCNAnimation / RealityKit animation.

Acceptance: an animated sample (e.g. AnimatedCube, BoxAnimated) plays in at least one backend.

---

## 12: Skinning support (joints, inverseBindMatrices)

+++
status: open
priority: low
kind: feature
labels: effort:xl, area:rendering
created: 2026-10-05T13:57:24Z
updated: 2026-10-05T13:58:26Z
+++

Skin is a stub; Node.skin and Node.weights are commented out. Implement skinned meshes: parse Skin (joints, inverseBindMatrices, skeleton), wire JOINTS_0/WEIGHTS_0.

Acceptance: a skinned sample (RiggedSimple/RiggedFigure) deforms correctly.

---

## 13: Morph target support

+++
status: open
priority: low
kind: feature
labels: effort:l, area:rendering
created: 2026-10-05T13:57:24Z
updated: 2026-10-05T13:58:26Z
+++

Mesh primitive 'targets' and node 'weights' are ignored. Parse morph targets and apply weights.

Acceptance: AnimatedMorphCube morphs correctly.

---

## 14: Decode and preserve glTF extensions/extras (infrastructure)

+++
status: open
priority: high
kind: feature
labels: effort:l, area:parsing
created: 2026-10-05T13:57:45Z
updated: 2026-10-05T13:58:26Z
+++

Today every 'extensions'/'extras' key is listed in CodingKeys but never decoded, so all extension and extras data is silently dropped on load (and would be lost on any future export).

Design:
- Add a typed-but-open extension mechanism on each extensible object (Document, Node, Material, Mesh.Primitive, TextureInfo, etc.): decode KNOWN extensions into typed structs via a registry, and PRESERVE UNKNOWN ones as raw JSON so nothing is lost.
- Represent 'extras' as a raw JSON value (Codable 'any JSON' type) rather than dropping it.
- Expose a typed accessor, e.g. material.extension(KHRMaterialsUnlit.self), returning nil when absent.
- Round-trip: unknown extensions survive decode (and re-encode once a writer exists).

This is the enabler for all concrete KHR_* extension issues.

Acceptance: loading a model that uses an unknown extension preserves its raw JSON; a registered extension decodes into its typed struct; extras is accessible.

---

## 15: KHR_lights_punctual (punctual lights)

+++
status: open
priority: high
kind: feature
labels: effort:m, area:rendering
depends: 14
created: 2026-10-05T13:58:08Z
updated: 2026-10-05T13:58:26Z
+++

No light support at all: Document has no lights and KHR_lights_punctual is ignored. Add a Light type (directional/point/spot, color, intensity, range), decode the document-level and node-level extension, and emit SCNLight / RealityKit lights.

Acceptance: a model using KHR_lights_punctual lights renders with those lights instead of hand-added test lights.

---

## 16: KHR_texture_transform (UV transform)

+++
status: open
priority: medium
kind: feature
labels: effort:s, area:rendering
depends: 14
created: 2026-10-05T13:58:08Z
updated: 2026-10-05T13:58:26Z
+++

Decode KHR_texture_transform (offset/rotation/scale, optional texCoord) on TextureInfo and apply it to material texture coordinates in both generators.

Acceptance: a model using KHR_texture_transform samples textures with the correct UV transform.

---

## 17: KHR_materials_unlit

+++
status: open
priority: medium
kind: feature
labels: effort:s, area:rendering
depends: 14
created: 2026-10-05T13:58:08Z
updated: 2026-10-05T13:58:26Z
+++

Decode KHR_materials_unlit and render affected materials as constant/unlit (SceneKit .constant, RealityKit UnlitMaterial).

Acceptance: an unlit model renders without lighting response.

---

## 18: KHR_materials_emissive_strength

+++
status: open
priority: low
kind: enhancement
labels: effort:xs, area:rendering
depends: 14
created: 2026-10-05T13:58:08Z
updated: 2026-10-05T13:58:26Z
+++

Decode KHR_materials_emissive_strength and scale emissive output accordingly.

Acceptance: emissive strength multiplies emissive factor/texture in render output.

---

## 19: Sparse accessor support

+++
status: open
priority: medium
kind: bug
labels: effort:m, area:parsing
created: 2026-10-05T13:58:08Z
updated: 2026-10-05T13:58:26Z
+++

Sparse accessors are not handled; Container.data(for:) ignores accessor.sparse, so sparse-encoded data is read wrong or throws. Parse accessor.sparse (count, indices, values) and apply the overrides when building data.

Acceptance: a model using sparse accessors (e.g. SimpleSparseAccessor) loads with correct values.

---

## 20: RealityKit drops all but the first primitive per mesh

+++
status: open
priority: medium
kind: bug
labels: effort:s, area:rendering
created: 2026-10-05T13:58:08Z
updated: 2026-10-05T13:58:26Z
+++

generateMeshResource uses mesh.primitives.first! and silently ignores additional primitives (multi-material meshes). Build one MeshDescriptor per primitive and combine.

Acceptance: a multi-primitive mesh renders all primitives with their materials.

---

## 21: Apply alphaMode/alphaCutoff/doubleSided (and make alphaMode an enum)

+++
status: open
priority: medium
kind: enhancement
labels: effort:s, area:rendering
created: 2026-10-05T13:58:21Z
updated: 2026-10-05T13:58:26Z
+++

Material.alphaMode is a raw String and none of alphaMode/alphaCutoff/doubleSided are applied in the generators (SceneKit only logs). Make alphaMode an enum (OPAQUE/MASK/BLEND) and apply blending, alpha masking (cutoff), and double-sided/cull mode.

Acceptance: AlphaBlendModeTest renders with correct opaque/mask/blend behavior.

---

## 22: Vertex colors (COLOR_0) and second UV set (TEXCOORD_1)

+++
status: open
priority: low
kind: enhancement
labels: effort:s, area:rendering
created: 2026-10-05T13:58:21Z
updated: 2026-10-05T13:58:26Z
+++

COLOR_0 is mapped in SceneKit sources but not used by RealityKit; TEXCOORD_1 is dropped in both. Wire vertex colors into materials and support the second UV set where referenced by texCoord.

Acceptance: a vertex-colored model shows colors; a model using texCoord=1 samples the right UVs.

---

## 23: normalized accessor flag is ignored

+++
status: open
priority: low
kind: bug
labels: effort:s, area:parsing
created: 2026-10-05T13:58:21Z
updated: 2026-10-05T13:58:26Z
+++

Accessor.normalized is parsed but never applied; normalized integer attributes are read as raw integers instead of being scaled to [0,1]/[-1,1]. Apply normalization during data conversion.

Acceptance: a model with normalized integer attributes (e.g. normalized vertex colors) loads correct values.

---

## 24: Generate tangents when TANGENT attribute is absent

+++
status: open
priority: low
kind: enhancement
labels: effort:m, area:rendering
created: 2026-10-05T13:58:21Z
updated: 2026-10-05T13:58:26Z
+++

Normal mapping requires tangents; when a primitive has a normal map but no TANGENT attribute, tangents must be generated (MikkTSpace or equivalent). Currently absent tangents mean broken normal mapping.

Acceptance: a normal-mapped model without TANGENT renders correct normal mapping.

---

## 25: glTF/GLB writer (export)

+++
status: open
priority: low
kind: feature
labels: effort:l, area:api
created: 2026-10-05T13:58:21Z
updated: 2026-10-05T13:58:26Z
+++

Library is read-only. Add encoding of Document back to .gltf and .glb (including buffers/chunks), round-tripping preserved extensions/extras (see #14).

Acceptance: load then save reproduces an equivalent file; round-trip test passes.

---

## 26: glTF validation mode

+++
status: open
priority: low
kind: feature
labels: effort:m, area:api
created: 2026-10-05T13:58:21Z
updated: 2026-10-05T13:58:26Z
+++

Add a validation pass that surfaces spec violations with clear messages (index bounds, required fields, accessor/bufferView consistency, unsupported required extensions) instead of failing deep in parsing/rendering.

Acceptance: invalid models report actionable diagnostics; a validate() API or test exists.

---
