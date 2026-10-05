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
status: closed
priority: medium
kind: feature
labels: area:parsing, effort:l
created: 2026-10-05T13:57:24Z
updated: 2026-10-05T15:10:00Z
closed: 2026-10-05T15:10:00Z
+++

Animation is an empty stub. Decode the glTF animation model into renderer-agnostic types on Document: animations -> channels (target node + path: translation/rotation/scale/weights) and samplers (input/output accessors, interpolation LINEAR/STEP/CUBICSPLINE). Provide a way to sample a channel at time t. No SceneKit/RealityKit here.

Acceptance: AnimatedCube/BoxAnimated decode into typed channels/samplers; a unit test samples a known keyframe value at a given time. Rendering is tracked separately (depends-on).

- `2026-10-05T15:10:01Z`: Animation is now fully decoded (channels with target node/path, samplers with input/output/interpolation, extensions/extras); Path is an open type. AnimationKeyframes + Container.keyframes(for:) / sample(_:of:at:) evaluate LINEAR (slerp for rotation), STEP and CUBICSPLINE (Hermite, glTF tangent layout) with clamping. Renderer-agnostic; playback is #28. Tests: AnimationTests (exact values on inline data + BoxAnimated sample).

---

## 12: Decode skin data (joints, inverseBindMatrices, weights)

+++
status: closed
priority: low
kind: feature
labels: effort:m, area:parsing
created: 2026-10-05T13:57:24Z
updated: 2026-10-05T15:11:15Z
closed: 2026-10-05T15:11:15Z
+++

Skin is a stub; Node.skin and Node.weights are commented out. Decode the skinning model: Skin (joints, inverseBindMatrices accessor, optional skeleton), Node.skin, and expose JOINTS_0/WEIGHTS_0 vertex data via the accessor layer. Renderer-agnostic.

Acceptance: RiggedSimple/RiggedFigure decode joints + inverse bind matrices + joint/weight attributes; unit test checks counts and a sample bind matrix. Rendering tracked separately (depends-on).

- `2026-10-05T15:11:15Z`: Skin decoded (inverseBindMatrices, skeleton, joints, extensions/extras) and made a Resolver; Document.skins non-optional. Node.skin and Node.weights decoded (were commented out). Container.inverseBindMatrices(for:) returns column-major simd matrices (identity when absent). JOINTS_n/WEIGHTS_n readable via floatComponents. Validator now checks skin/animation references. Rendering is #29. Tests: SkinTests (RiggedSimple) + validation case.

---

## 13: Decode morph target data (targets + weights)

+++
status: closed
priority: low
kind: feature
labels: effort:m, area:parsing
created: 2026-10-05T13:57:24Z
updated: 2026-10-05T15:12:05Z
closed: 2026-10-05T15:12:05Z
+++

Mesh primitive 'targets' and node 'weights' are ignored. Decode morph targets into the model: per-primitive target attribute sets (POSITION/NORMAL/TANGENT deltas) and node/mesh default weights. Renderer-agnostic.

Acceptance: AnimatedMorphCube/MorphPrimitivesTest decode their targets + weights; unit test reads a target delta accessor. Rendering tracked separately (depends-on).

- `2026-10-05T15:12:05Z`: Primitive.targets is now typed [[Semantic: Index<Accessor>]] (was [[String: Int]]). Node.morphWeights(in:) resolves effective weights (node > mesh > zeros). Container.morphed(_:of:weights:) applies weighted deltas on the CPU as a renderer-agnostic reference. Validator checks target indices, target/base count match, and weights/targets count. Added GLTFError.invalidDocument. Rendering is #30. Tests: MorphTargetTests (exact values inline + AnimatedMorphCube).

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
status: closed
priority: low
kind: enhancement
labels: effort:xs, area:rendering
depends: 14
created: 2026-10-05T13:58:08Z
updated: 2026-10-05T14:53:20Z
closed: 2026-10-05T14:53:20Z
+++

Decode KHR_materials_emissive_strength and scale emissive output accordingly.

Acceptance: emissive strength multiplies emissive factor/texture in render output.

- `2026-10-05T14:53:20Z`: Added KHRMaterialsEmissiveStrength decoding (Material.emissiveStrength, default 1). SceneKit sets emission.intensity; RealityKit sets emissiveIntensity (was hardcoded 1). Test: EmissiveStrengthTests on EmissiveStrengthTest.glb. Note: visible brightening needs an HDR/bloom-capable render path (CLI SceneKit sets camera.wantsHDR).

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
status: closed
priority: low
kind: enhancement
labels: effort:s, area:rendering
created: 2026-10-05T13:58:21Z
updated: 2026-10-05T14:45:21Z
closed: 2026-10-05T14:45:21Z
+++

COLOR_0 is mapped in SceneKit sources but not used by RealityKit; TEXCOORD_1 is dropped in both. Wire vertex colors into materials and support the second UV set where referenced by texCoord.

Acceptance: a vertex-colored model shows colors; a model using texCoord=1 samples the right UVs.

- `2026-10-05T14:45:21Z`: SceneKit: TEXCOORD_1 now builds a second .texcoord source and material properties route via mappingChannel = textureInfo.texCoord. COLOR_0 vertex colors already render (float path; normalized reading available via floatComponents from #23). RealityKit: COLOR_0 and TEXCOORD_1 are unsupported (warned) - MeshDescriptor has no vertex-color/2nd-UV channel. Tests: VertexColorUVTests (BoxVertexColors color source; MultiUVTest two texcoord sources).

---

## 23: normalized accessor flag is ignored

+++
status: closed
priority: low
kind: bug
labels: effort:s, area:parsing
created: 2026-10-05T13:58:21Z
updated: 2026-10-05T14:43:23Z
closed: 2026-10-05T14:43:23Z
+++

Accessor.normalized is parsed but never applied; normalized integer attributes are read as raw integers instead of being scaled to [0,1]/[-1,1]. Apply normalization during data conversion.

Acceptance: a model with normalized integer attributes (e.g. normalized vertex colors) loads correct values.

- `2026-10-05T14:43:23Z`: Added Container.floatComponents(for:) which reads accessor components as Float and applies the normalized flag per spec (ubyte/255, ushort/65535, byte/127, short/32767, clamped). Also made Container.data(for:) compute elementSize generically (componentSize * componentCount) instead of a hardcoded whitelist, so combos like (UNSIGNED_BYTE, VEC4) work. Test: NormalizedAccessorTests on RecursiveSkeletons (normalized ubyte colors scale to [0,1]).

---

## 24: Generate tangents when TANGENT attribute is absent

+++
status: closed
priority: low
kind: enhancement
labels: effort:m, area:rendering
created: 2026-10-05T13:58:21Z
updated: 2026-10-05T15:05:29Z
closed: 2026-10-05T15:05:29Z
+++

Normal mapping requires tangents; when a primitive has a normal map but no TANGENT attribute, tangents must be generated (MikkTSpace or equivalent). Currently absent tangents mean broken normal mapping.

Acceptance: a normal-mapped model without TANGENT renders correct normal mapping.

- `2026-10-05T14:40:28Z`: Implementation note: a ready-to-vendor MikkTSpace C library lives at ~/Shared/Projects/Current/SwiftMesh/Sources/MikkTSpace (mikktspace.c + mikktspace.h; declared there as a C target with publicHeadersPath: "."). Plan: copy it into SwiftGLTF as a C target (e.g. Sources/MikkTSpace), add a small Swift wrapper that implements SMikkTSpaceInterface over a primitive's POSITION/NORMAL/TEXCOORD_0/indices, and compute TANGENT when a material has a normal map but the primitive lacks TANGENT. This sits in the parse/model layer (renderer-agnostic) so both generators benefit. Belongs under area:parsing conceptually even though labelled area:rendering.
- `2026-10-05T15:05:29Z`: Won't do here (by design): tangent generation is mesh processing and belongs ABOVE SwiftGLTF (e.g. SwiftMesh, which already owns MikkTSpace). The opt-in SwiftGLTFTangents module was reverted. Consumers should generate tangents from the decoded model (Container.floatComponents) in a higher-level library.

---

## 25: glTF/GLB writer: Encodable model + container writing (25b)

+++
status: closed
priority: low
kind: feature
labels: area:api, effort:m
depends: 33, 32
created: 2026-10-05T13:58:21Z
updated: 2026-10-05T15:19:40Z
closed: 2026-10-05T15:19:40Z
+++

Write a Document back to .gltf (external .bin or data URIs) and .glb (JSON + BIN chunks, 4-byte padding, header).

- Add Encodable to all model types (matching the custom init(from:) defaults).
- Container writing for both formats.
- Round-trip tests: load -> save -> load and compare models, plus a pass over the sample corpus.

Output will be equivalent, not byte-identical (decoded defaults are indistinguishable from explicit values).

Depends on the model-completeness issue so export doesn't silently drop data. Full fidelity for animations/skins/morphs follows #11-#13.

- `2026-10-05T15:19:40Z`: Writer done. Model is Codable (mechanical Decodable->Codable on declarations; hand-written encoders where synthesis would be invalid glTF: Index/URI as scalars, no empty arrays, no byteOffset without bufferView, no identity matrix alongside TRS, Semantic-keyed attributes/targets). Container.write(to:embedResources:) writes .glb (all buffers repacked into one 4-byte-aligned BIN chunk, bufferViews rebased) or .gltf (embedded data URIs, or keep URIs + copy relative files + BIN sidecar). Moved Container.data(for: Image) into core. Tests: WriterTests - every sample GLB <5MB round-trips GLB->GLB and GLB->glTF with identical model and identical accessor/image bytes; FlightHelmet external-file glTF; JSON shape; GLB framing. Output is equivalent, not byte-identical. Not covered: unmodeled fields noted in #33 (normalTexture.scale, occlusionTexture.strength).

---

## 26: glTF validation mode

+++
status: closed
priority: low
kind: feature
labels: effort:m, area:api
created: 2026-10-05T13:58:21Z
updated: 2026-10-05T15:04:35Z
closed: 2026-10-05T15:04:35Z
+++

Add a validation pass that surfaces spec violations with clear messages (index bounds, required fields, accessor/bufferView consistency, unsupported required extensions) instead of failing deep in parsing/rendering.

Acceptance: invalid models report actionable diagnostics; a validate() API or test exists.

- `2026-10-05T15:04:35Z`: Added Document.validate() -> [ValidationIssue] (severity, JSON-pointer path, message): index bounds everywhere, bufferView-in-buffer and accessor-in-bufferView ranges, byteStride rules, sparse bounds, POSITION presence, matching attribute counts, unsupported required/used extensions, multiple parents and cycles in the node graph. Index.resolve now throws on out-of-range instead of crashing. gltf-render --validate prints issues and exits non-zero on errors. Tests: ValidationTests (one defect per case + whole sample corpus has no false-positive errors).

---

## 27: RealityKit render path needs image-based lighting (IBL)

+++
status: closed
priority: medium
kind: enhancement
labels: effort:m, area:rendering
created: 2026-10-05T14:38:29Z
updated: 2026-10-05T14:59:04Z
closed: 2026-10-05T14:59:04Z
+++

The gltf-render RealityKit backend (and RealityRenderer-based tests) render highly-metallic models (e.g. DamagedHelmet) as washed-out uniform gray. RealityRenderer has no lighting environment set, so metallic/rough surfaces have nothing to reflect except the directional key/fill lights -> they read as flat bright gray instead of showing base color + reflections. SceneKit already looks correct because it uses lightingEnvironment.

Set RealityRenderer.lighting.resource to an EnvironmentResource (IBL):
- Generate one from an equirectangular image (a simple gradient or a bundled studio HDR), or load a bundled .exr/.hdr.
- Expose it in gltf-render (and reuse in the RealityKit render tests for nicer, more representative goldens).

Acceptance: DamagedHelmet via 'gltf-render -b realitykit' shows its base-color texture and plausible metallic reflections instead of a uniform white/gray blob.

- `2026-10-05T14:59:04Z`: Done, but the original diagnosis was incomplete. IBL alone did NOT fix the washed-out look. Root cause (found by disabling emissive): RealityKit's EmissiveColor(color:texture:) doesn't compute factor*texture, so DamagedHelmet's white emissiveFactor made the whole surface glow. Fixed in makeMaterial: pass the emissive texture alone and bake a non-white factor into it. Also: RealityRenderer writes linear color, so the CLI now renders into rgba8Unorm_srgb (was too dark). Added gltf-render --environment <equirect HDR/EXR> (RealityKit IBL via EnvironmentResource + SceneKit lightingEnvironment) and --exposure. Regenerated the DamagedHelmet-realitykit golden (old one encoded the emissive bug).

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

## 31: SceneKit generator applies glTF quaternion rotation as axis-angle

+++
status: closed
priority: high
kind: bug
labels: effort:xs, area:rendering
created: 2026-10-05T15:00:06Z
updated: 2026-10-05T15:03:24Z
closed: 2026-10-05T15:03:24Z
+++

glTF node.rotation is a unit quaternion [x, y, z, w]. SceneKitGenerator.generateSCNNode assigns it to scnNode.simdRotation, which SceneKit interprets as axis-angle (axis xyz, angle w). Any rotated node gets the wrong orientation. RealityKit is correct (simd_quatf(vector:)).

Evidence: DamagedHelmet (root node rotation [0.7071, 0, 0, 0.7071]) faces different directions in gltf-render SceneKit vs RealityKit with identical camera setup.

Fix: use scnNode.simdOrientation = simd_quatf(vector: rotation). Add a test asserting a rotated node's orientation matches the quaternion, and regenerate any SceneKit goldens that change (DamagedHelmet-scenekit).

Acceptance: SceneKit and RealityKit render DamagedHelmet in the same orientation.

- `2026-10-05T15:03:24Z`: SceneKit now uses simdOrientation = simd_quatf(vector: rotation). Test: NodeRotationTests (fails before fix, passes after). Regenerated DamagedHelmet-scenekit golden; SceneKit now matches RealityKit orientation.

---

## 32: Crash on unknown primitive attribute names (closed Semantic enum)

+++
status: closed
priority: high
kind: bug
labels: effort:s, area:parsing
created: 2026-10-05T15:07:22Z
updated: 2026-10-05T15:08:23Z
closed: 2026-10-05T15:08:23Z
+++

Mesh.Primitive decodes attributes with Semantic(rawValue: $0)!, and Semantic is a closed enum (POSITION, NORMAL, TANGENT, TEXCOORD_0-2, COLOR_0, JOINTS_0, WEIGHTS_0). Any other valid attribute name crashes on load: TEXCOORD_3+, COLOR_1, JOINTS_1/WEIGHTS_1, or application-specific attributes (leading underscore, e.g. _CUSTOM), which the spec allows.

Fix: make Semantic an open type (e.g. a RawRepresentable struct with static known values), or keep unknown names as raw strings; never force-unwrap.

Acceptance: a primitive with TEXCOORD_3 and a _CUSTOM attribute loads without crashing and both attributes are accessible.

- `2026-10-05T15:08:23Z`: Mesh.Primitive.Semantic is now an open RawRepresentable struct (ExpressibleByStringLiteral) with static known values, so any attribute name decodes; removed the force-unwrap. Existing .POSITION etc. call sites unchanged. Test: AttributeSemanticTests (TEXCOORD_3, COLOR_1, _CUSTOM); previously a crash.

---

## 33: Make the model lossless: extensions/extras on all types (25a)

+++
status: closed
priority: low
kind: enhancement
labels: effort:m, area:parsing
created: 2026-10-05T15:07:23Z
updated: 2026-10-05T15:16:08Z
closed: 2026-10-05T15:16:08Z
+++

Prerequisite for the writer (#25). Today extensions/extras are preserved only on Document, Node, Scene, Material, PBRMetallicRoughness, Mesh.Primitive and TextureInfo. They are silently dropped on Accessor, Buffer, BufferView, Image, Texture, Sampler, Camera, Asset, and Mesh.

Add extensions: Extensions? and extras: JSONValue? (and Extensible conformance) to the remaining types.

Acceptance: an unknown extension and extras on each of these types survive decode (test per type). Unknown attribute names are covered by the Semantic crash bug.

- `2026-10-05T15:16:08Z`: extensions/extras now decoded + Extensible on Accessor, Asset, Buffer, BufferView, Camera, Image, Mesh, Sampler, Texture. Also fixed two spec typos: Accessor CodingKeys used 'extension' (singular), and Image.mimetype never decoded (spec key mimeType). Test: LosslessModelTests (one doc, every type). Remaining lossy spots (not in scope): normalTexture.scale / occlusionTexture.strength are unmodeled; sub-objects (sparse, perspective/orthographic) don't keep extensions.

---

## 34: Writer: preserve explicit vs default values (closer to byte-identical output)

+++
status: open
priority: low
kind: enhancement
labels: effort:m, area:api
created: 2026-10-05T15:47:27Z
+++

The writer (#25) produces output that is equivalent to the input, not byte-identical. Two causes:
1. Decoding collapses defaults: absent and explicit-default values become the same (e.g. byteOffset 0, mode TRIANGLES, normalized false, texCoord 0, wrapS/T REPEAT, baseColorFactor [1,1,1,1], node matrix identity). On write we cannot tell whether the original file spelled them out.
2. JSON key order and number formatting differ (sortedKeys; Float printed in shortest form).

Options: track presence for defaulted fields (e.g. store Optionals and expose computed defaults), and/or preserve the original key order. Exact byte identity is probably not a goal; aim for 'only re-emits what was in the source'.

Acceptance: for the sample corpus, a load -> save round trip re-emits a field only if it was present in the source (test compares JSON key sets per object).

---

## 35: Model normalTexture.scale and occlusionTexture.strength

+++
status: closed
priority: medium
kind: bug
labels: effort:s, area:parsing
created: 2026-10-05T15:47:27Z
updated: 2026-10-05T15:50:42Z
closed: 2026-10-05T15:50:42Z
+++

Material.normalTexture and occlusionTexture are decoded as TextureInfo, which only has index/texCoord. The spec's normalTextureInfo.scale (default 1) and occlusionTextureInfo.strength (default 1) are dropped on load and therefore lost on write (#25).

Add NormalTextureInfo (scale) and OcclusionTextureInfo (strength) types (or optional fields), decode/encode them, and apply them in the generators where possible (SceneKit normal intensity / ambientOcclusion intensity; RealityKit normal/AO scale).

Acceptance: a material with scale 0.5 / strength 0.3 decodes those values and round-trips through the writer.

- `2026-10-05T15:50:42Z`: TextureInfo gains optional scale/strength (written back only if present) with normalScale/occlusionStrength defaults of 1. SceneKit: normal.intensity = scale, ambientOcclusion.intensity = strength (and AO now reads the R channel per spec). RealityKit has no such parameters, so they are baked into the texture with a non-color-managed CIColorMatrix (normal: n' = s*n + (1-s)/2 on RG; AO: ao' = 1 + s*(ao-1)). Tests: TextureInfoScaleTests (decode, defaults, encoder round-trip, both bakes).

---

## 36: CI: validate writer output with Khronos glTF-Validator

+++
status: open
priority: low
kind: task
labels: effort:s, area:api
created: 2026-10-05T15:47:27Z
+++

The writer is only checked by our own validator and round-trip tests. Add a CI step that writes the sample corpus (GLB and embedded glTF) and runs the official Khronos glTF-Validator (npx gltf-validator) on the output, failing on errors.

Acceptance: CI job runs the validator over writer output for the sample assets; zero errors.

---

## 37: Demo app fails to build: deployment target below package minimum

+++
status: closed
priority: high
kind: bug
labels: effort:xs, area:api
created: 2026-10-05T15:54:49Z
updated: 2026-10-05T15:55:49Z
closed: 2026-10-05T15:55:49Z
+++

Demo/SwiftGLTFDemo targets macOS 14 (and likely iOS 17), but the SwiftGLTF package was raised to macOS 15 / iOS 18 for the GoldenImage test dependency. Every Demo file fails with: 'compiling for macOS 14, but module SwiftGLTF has a minimum deployment target of macOS 15.0'. The xcode.yml CI workflow builds the Demo, so CI is red.

Regression from the platform bump; an earlier 'Demo builds fine' check was wrong (likely stale build).

Fix: raise the Demo project's deployment targets to macOS 15 / iOS 18.

Acceptance: xcb build --target SwiftGLTFDemo succeeds for macOS and generic iOS.

- `2026-10-05T15:55:49Z`: Raised Demo deployment targets to macOS 15.0 / iOS 18.0 (Debug + Release), matching the package minimum. Verified with a clean macOS build and an iOS build with CODE_SIGNING_ALLOWED=NO (as CI does). No test: project-settings change, verified by building.

---

## 38: SceneKit ignores emissiveFactor when an emissive texture is present

+++
status: open
priority: medium
kind: bug
labels: effort:s, area:rendering
created: 2026-10-05T15:54:49Z
+++

glTF emissive = emissiveFactor * emissiveTexture. SceneKitGenerator sets emission.contents to the texture and only logs a warning about the factor, so a non-white factor is dropped. Same class of bug fixed for RealityKit in #27.

Fix: multiply the factor into the texture (CIColorMatrix, as RealityKit does) or otherwise apply it.

Acceptance: a material with emissiveFactor [1, 0, 0] and an emissive texture renders red-tinted emission in SceneKit.

---

## 39: RealityKit golden test reads back with wrong gamma

+++
status: open
priority: low
kind: task
labels: effort:xs, area:rendering
created: 2026-10-05T15:54:49Z
+++

RealityKitRenderingTests renders into rgba8Unorm and reads the bytes as sRGB. RealityRenderer writes linear color, so the goldens are darker than the real output (fixed in gltf-render via rgba8Unorm_srgb in #27).

Fix: use .rgba8Unorm_srgb in the test helper and regenerate the RealityKit goldens.

Acceptance: test render background 0.12 gray reads back as ~31/255, matching the CLI.

---

## 40: Preserve extensions on sub-objects (sparse, perspective, orthographic)

+++
status: open
priority: low
kind: enhancement
labels: effort:s, area:parsing
created: 2026-10-05T15:54:49Z
+++

#33 made every top-level object keep extensions/extras, but some nested objects still drop them: Accessor.Sparse (and its indices/values), Camera.Perspective, Camera.Orthographic. They are therefore lost on write (#25). Related to #34 (lossless round trip).

Acceptance: extensions/extras on each of these sub-objects survive decode and the writer round trip.

---

## 41: CLI: expose writer (convert) and standalone validate

+++
status: open
priority: low
kind: enhancement
labels: effort:s, area:api
created: 2026-10-05T15:54:49Z
+++

The writer (#25) and validator (#26) are library-only, except validate as a gltf-render flag. Add CLI support, e.g. a convert mode (gltf-render in.gltf --convert out.glb [--embed]) or a separate gltf-tool with convert/validate/render subcommands.

Acceptance: a GLB can be converted to self-contained glTF and back from the command line; validate works without rendering flags.

---

## 42: Validator gaps: min/max, index range, texture-info fields

+++
status: open
priority: low
kind: enhancement
labels: effort:s, area:api
created: 2026-10-05T15:54:49Z
+++

Document.validate() (#26) does not yet check:
- accessor min/max match the actual data;
- index values are < the vertex count of their primitive;
- scale on non-normal textures / strength on non-occlusion textures (TextureInfo models both as optional fields since #35).

Acceptance: each case has a test with one targeted defect; sample corpus still has no false-positive errors.

---

## 43: Document known RealityKit generator limitations

+++
status: open
priority: low
kind: documentation
labels: effort:xs, area:rendering
created: 2026-10-05T15:54:49Z
+++

Several features are unsupported by the RealityKit generator and only surface as runtime warnings: KHR_texture_transform, COLOR_0 vertex colors, TEXCOORD_1, orthographic cameras. Add a 'Known limitations' section to the README (per backend), and note that tangent generation is expected above this library (#24).

Acceptance: README lists per-backend limitations.

---

## 44: TextureInfo does not expose normal scale or occlusion strength

+++
status: new
priority: medium
kind: bug
labels: materials
created: 2026-10-05T16:00:33Z
+++

glTF `normalTexture` has an optional `scale` and `occlusionTexture` an optional `strength` (both default 1). Material.normalTexture and Material.occlusionTexture are decoded as plain TextureInfo, so these values are dropped and renderers cannot read them.

---

## 45: Relative URIs with percent-escapes are not decoded

+++
status: new
priority: low
kind: bug
labels: loading
created: 2026-10-05T16:00:33Z
+++

`Container.data(for: URI)` resolves relative URIs with `appendingPathComponent(uri.string)` without percent-decoding. glTF URIs are RFC 3986 encoded, so a file reference like `my%20texture.png` points at a file literally named `my%20texture.png` and fails to load.

---
