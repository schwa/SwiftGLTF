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
status: closed
priority: high
kind: feature
labels: effort:s, area:rendering
created: 2026-10-05T13:57:24Z
updated: 2026-10-05T14:05:02Z
closed: 2026-10-05T14:05:02Z
+++

Camera is parsed but neither generator applies node cameras. Both render tests must hand-build a camera. Apply perspective/orthographic cameras from the glTF node graph.

Acceptance: a model with a camera renders from that camera; generators expose the active camera node/entity.

- `2026-10-05T14:05:02Z`: Implemented Camera decoding (perspective/orthographic) and applied node cameras in both generators (SCNCamera / PerspectiveCameraComponent). Also default-material fallback for material-less primitives (needed to generate the Cameras model). Tests: CameraTests (fail before fix: Camera was an empty stub). RealityKit orthographic cameras are unsupported (warned).

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
status: closed
priority: high
kind: feature
labels: effort:m, area:rendering
created: 2026-10-05T13:57:24Z
updated: 2026-10-05T14:12:21Z
closed: 2026-10-05T14:12:21Z
+++

makeMaterial only sets baseColor (tint + optional texture). Missing: normal, metallic, roughness, occlusion, emissive maps and factors, plus texCoord/texture transform.

Acceptance: a PBR model (DamagedHelmet) renders with normal/metallic-roughness/emissive maps via RealityKit; golden test.

- `2026-10-05T14:12:21Z`: makeMaterial now sets baseColor, metallic+roughness (from metallicRoughnessTexture B/G channels + factors), normal, ambient occlusion, and emissive (texture+factor). Test: RealityKitRenderingTests.rendersDamagedHelmetMatchingGolden (GLB, full PBR maps). Note: no IBL environment in the test, so metallic surfaces reflect the directional light; normal-mapped detail is visible and the pipeline is deterministic.

---

## 11: Decode animation data (channels, samplers, keyframes)

+++
status: open
priority: medium
kind: feature
labels: area:parsing, effort:l
created: 2026-10-05T13:57:24Z
updated: 2026-10-05T14:39:32Z
+++

Animation is an empty stub. Decode the glTF animation model into renderer-agnostic types on Document: animations -> channels (target node + path: translation/rotation/scale/weights) and samplers (input/output accessors, interpolation LINEAR/STEP/CUBICSPLINE). Provide a way to sample a channel at time t. No SceneKit/RealityKit here.

Acceptance: AnimatedCube/BoxAnimated decode into typed channels/samplers; a unit test samples a known keyframe value at a given time. Rendering is tracked separately (depends-on).

---

## 12: Decode skin data (joints, inverseBindMatrices, weights)

+++
status: open
priority: low
kind: feature
labels: effort:m, area:parsing
created: 2026-10-05T13:57:24Z
updated: 2026-10-05T14:39:53Z
+++

Skin is a stub; Node.skin and Node.weights are commented out. Decode the skinning model: Skin (joints, inverseBindMatrices accessor, optional skeleton), Node.skin, and expose JOINTS_0/WEIGHTS_0 vertex data via the accessor layer. Renderer-agnostic.

Acceptance: RiggedSimple/RiggedFigure decode joints + inverse bind matrices + joint/weight attributes; unit test checks counts and a sample bind matrix. Rendering tracked separately (depends-on).

---

## 13: Decode morph target data (targets + weights)

+++
status: open
priority: low
kind: feature
labels: effort:m, area:parsing
created: 2026-10-05T13:57:24Z
updated: 2026-10-05T14:39:53Z
+++

Mesh primitive 'targets' and node 'weights' are ignored. Decode morph targets into the model: per-primitive target attribute sets (POSITION/NORMAL/TANGENT deltas) and node/mesh default weights. Renderer-agnostic.

Acceptance: AnimatedMorphCube/MorphPrimitivesTest decode their targets + weights; unit test reads a target delta accessor. Rendering tracked separately (depends-on).

---

## 14: Decode and preserve glTF extensions/extras (infrastructure)

+++
status: closed
priority: high
kind: feature
labels: effort:l, area:parsing
created: 2026-10-05T13:57:45Z
updated: 2026-10-05T14:07:51Z
closed: 2026-10-05T14:07:51Z
+++

Today every 'extensions'/'extras' key is listed in CodingKeys but never decoded, so all extension and extras data is silently dropped on load (and would be lost on any future export).

Design:
- Add a typed-but-open extension mechanism on each extensible object (Document, Node, Material, Mesh.Primitive, TextureInfo, etc.): decode KNOWN extensions into typed structs via a registry, and PRESERVE UNKNOWN ones as raw JSON so nothing is lost.
- Represent 'extras' as a raw JSON value (Codable 'any JSON' type) rather than dropping it.
- Expose a typed accessor, e.g. material.extension(KHRMaterialsUnlit.self), returning nil when absent.
- Round-trip: unknown extensions survive decode (and re-encode once a writer exists).

This is the enabler for all concrete KHR_* extension issues.

Acceptance: loading a model that uses an unknown extension preserves its raw JSON; a registered extension decodes into its typed struct; extras is accessible.

- `2026-10-05T14:07:51Z`: Added JSONValue (raw JSON), Extensions map, GLTFExtension protocol, and Extensible on Document/Node/Scene/Material/PBRMetallicRoughness/Mesh.Primitive/TextureInfo. Unknown extensions and extras are preserved as raw JSON; registered extensions decode via extensionValue(_:). Tests: ExtensionsTests (registered decode, unknown-preserved, extras, absent-nil).

---

## 15: KHR_lights_punctual (punctual lights)

+++
status: closed
priority: high
kind: feature
labels: effort:m, area:rendering
depends: 14
created: 2026-10-05T13:58:08Z
updated: 2026-10-05T14:10:11Z
closed: 2026-10-05T14:10:11Z
+++

No light support at all: Document has no lights and KHR_lights_punctual is ignored. Add a Light type (directional/point/spot, color, intensity, range), decode the document-level and node-level extension, and emit SCNLight / RealityKit lights.

Acceptance: a model using KHR_lights_punctual lights renders with those lights instead of hand-added test lights.

- `2026-10-05T14:10:11Z`: Added Light type + KHR_lights_punctual decoding (document lights + node light ref) and emission of SCNLight (directional/omni/spot) and RealityKit Directional/Point/Spot light components. Tests: LightsPunctualTests. Photometric intensity units are passed through, not unit-converted (noted).

---

## 16: KHR_texture_transform (UV transform)

+++
status: closed
priority: medium
kind: feature
labels: effort:s, area:rendering
depends: 14
created: 2026-10-05T13:58:08Z
updated: 2026-10-05T14:22:37Z
closed: 2026-10-05T14:22:37Z
+++

Decode KHR_texture_transform (offset/rotation/scale, optional texCoord) on TextureInfo and apply it to material texture coordinates in both generators.

Acceptance: a model using KHR_texture_transform samples textures with the correct UV transform.

- `2026-10-05T14:22:37Z`: Added KHRTextureTransform decoding on TextureInfo (offset/rotation/scale/texCoord). SceneKit applies it via SCNMaterialProperty.contentsTransform per textured property. RealityKit's PhysicallyBasedMaterial has no public per-texture UV transform, so it warns (documented limitation). Test: TextureTransformTests (decode + SceneKit matrix).

---

## 17: KHR_materials_unlit

+++
status: closed
priority: medium
kind: feature
labels: effort:s, area:rendering
depends: 14
created: 2026-10-05T13:58:08Z
updated: 2026-10-05T14:24:26Z
closed: 2026-10-05T14:24:26Z
+++

Decode KHR_materials_unlit and render affected materials as constant/unlit (SceneKit .constant, RealityKit UnlitMaterial).

Acceptance: an unlit model renders without lighting response.

- `2026-10-05T14:24:26Z`: Added KHR_materials_unlit decoding (Material.isUnlit). SceneKit uses lightingModel .constant; RealityKit returns an UnlitMaterial with baseColor tint+texture. Test: MaterialsUnlitTests (decode + both generators).

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
status: closed
priority: medium
kind: bug
labels: effort:m, area:parsing
created: 2026-10-05T13:58:08Z
updated: 2026-10-05T14:19:21Z
closed: 2026-10-05T14:19:21Z
+++

Sparse accessors are not handled; Container.data(for:) ignores accessor.sparse, so sparse-encoded data is read wrong or throws. Parse accessor.sparse (count, indices, values) and apply the overrides when building data.

Acceptance: a model using sparse accessors (e.g. SimpleSparseAccessor) loads with correct values.

- `2026-10-05T14:19:21Z`: Added Accessor.Sparse decoding and applied sparse overrides in Container.data(for:) (base data, then replace count elements at given indices with given values). Also made data-URI decoding accept any ';base64' media type (was a hardcoded whitelist that rejected application/gltf-buffer). Test: SparseAccessorTests on SimpleSparseAccessor (overridden verts 8/10/12 differ from base).

---

## 20: RealityKit drops all but the first primitive per mesh

+++
status: closed
priority: medium
kind: bug
labels: effort:s, area:rendering
created: 2026-10-05T13:58:08Z
updated: 2026-10-05T14:14:56Z
closed: 2026-10-05T14:14:56Z
+++

generateMeshResource uses mesh.primitives.first! and silently ignores additional primitives (multi-material meshes). Build one MeshDescriptor per primitive and combine.

Acceptance: a multi-primitive mesh renders all primitives with their materials.

- `2026-10-05T14:14:56Z`: generateMeshResource now builds one MeshDescriptor per primitive (each with .allFaces(materialIndex)) and combines them into one MeshResource with a materials array. Test: multiPrimitiveMeshKeepsAllPrimitives (PointLightIntensityTest.glb, mesh with 2 primitives); before fix only the first primitive was kept (maxMaterials==1), after fix ==2.

---

## 21: Apply alphaMode/alphaCutoff/doubleSided (and make alphaMode an enum)

+++
status: closed
priority: medium
kind: enhancement
labels: effort:s, area:rendering
created: 2026-10-05T13:58:21Z
updated: 2026-10-05T14:21:00Z
closed: 2026-10-05T14:21:00Z
+++

Material.alphaMode is a raw String and none of alphaMode/alphaCutoff/doubleSided are applied in the generators (SceneKit only logs). Make alphaMode an enum (OPAQUE/MASK/BLEND) and apply blending, alpha masking (cutoff), and double-sided/cull mode.

Acceptance: AlphaBlendModeTest renders with correct opaque/mask/blend behavior.

- `2026-10-05T14:21:00Z`: alphaMode is now a Material.AlphaMode enum (OPAQUE/MASK/BLEND). Applied in both generators: SceneKit sets blendMode/writesToDepthBuffer, isDoubleSided, and a fragment discard shader modifier for MASK (SceneKit has no native alpha cutoff); RealityKit sets blending, opacityThreshold (MASK), and faceCulling (.none for doubleSided). Test: AlphaModeTests.

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
updated: 2026-10-05T14:40:28Z
+++

Normal mapping requires tangents; when a primitive has a normal map but no TANGENT attribute, tangents must be generated (MikkTSpace or equivalent). Currently absent tangents mean broken normal mapping.

Acceptance: a normal-mapped model without TANGENT renders correct normal mapping.

- `2026-10-05T14:40:28Z`: Implementation note: a ready-to-vendor MikkTSpace C library lives at ~/Shared/Projects/Current/SwiftMesh/Sources/MikkTSpace (mikktspace.c + mikktspace.h; declared there as a C target with publicHeadersPath: "."). Plan: copy it into SwiftGLTF as a C target (e.g. Sources/MikkTSpace), add a small Swift wrapper that implements SMikkTSpaceInterface over a primitive's POSITION/NORMAL/TEXCOORD_0/indices, and compute TANGENT when a material has a normal map but the primitive lacks TANGENT. This sits in the parse/model layer (renderer-agnostic) so both generators benefit. Belongs under area:parsing conceptually even though labelled area:rendering.

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

## 27: RealityKit render path needs image-based lighting (IBL)

+++
status: open
priority: medium
kind: enhancement
labels: effort:m, area:rendering
created: 2026-10-05T14:38:29Z
+++

The gltf-render RealityKit backend (and RealityRenderer-based tests) render highly-metallic models (e.g. DamagedHelmet) as washed-out uniform gray. RealityRenderer has no lighting environment set, so metallic/rough surfaces have nothing to reflect except the directional key/fill lights -> they read as flat bright gray instead of showing base color + reflections. SceneKit already looks correct because it uses lightingEnvironment.

Set RealityRenderer.lighting.resource to an EnvironmentResource (IBL):
- Generate one from an equirectangular image (a simple gradient or a bundled studio HDR), or load a bundled .exr/.hdr.
- Expose it in gltf-render (and reuse in the RealityKit render tests for nicer, more representative goldens).

Acceptance: DamagedHelmet via 'gltf-render -b realitykit' shows its base-color texture and plausible metallic reflections instead of a uniform white/gray blob.

---

## 28: Play glTF animations in SceneKit/RealityKit

+++
status: open
priority: medium
kind: feature
labels: effort:l, area:rendering
depends: 11
created: 2026-10-05T14:39:43Z
+++

Using the decoded animation model (#11), drive playback in the generators: build SCNAnimation / CAAnimationGroup keyed to nodes for SceneKit, and RealityKit AnimationResource / BlendTree for TRS (and morph weights once #13 lands). Map interpolation modes.

Acceptance: AnimatedCube/BoxAnimated plays in at least one backend; gltf-render could optionally render a frame at time t.

---

## 29: Render skinned meshes in SceneKit/RealityKit

+++
status: open
priority: low
kind: feature
labels: effort:l, area:rendering
depends: 12
created: 2026-10-05T14:39:43Z
+++

Using the decoded skin model (#12), build skinned geometry: SCNSkinner (bones, boneInverseBindTransforms, boneWeights/boneIndices) for SceneKit; RealityKit skinning via MeshResource joints/skeleton. Bind to the node hierarchy.

Acceptance: RiggedSimple/RiggedFigure deforms correctly in at least one backend.

---

## 30: Apply morph targets in SceneKit/RealityKit

+++
status: open
priority: low
kind: feature
labels: effort:m, area:rendering
depends: 13
created: 2026-10-05T14:39:43Z
+++

Using the decoded morph model (#13), apply targets: SCNMorpher (targets + weights) for SceneKit; RealityKit blend-shape equivalent. Respect default and animated weights.

Acceptance: AnimatedMorphCube morphs correctly (static weights minimum; animated once #11/the animation render issue lands).

---
