# The Techtonica study: findings

Mechanisms and numbers read from the local install (Steam build 20273707, Unity 2022.3.33f1, Mono) under the boundary of DESIGN.md, The Techtonica study. Each fact names the class (from `Assembly-CSharp.dll`, decompiled with `ilspycmd`) or the asset (from `sharedassets1.assets`, read with UnityPy and its type tree generator) it came from, so it can be checked again. The decompiled source and the exports live under `work/techtonica/`, outside git.

Dimensions are written x × y × z with y up. A footprint is x × z.

## Question 2: the machines (item 0039)

### The grid

One placement cell is one Unity unit, one metre: `GridInfo.BottomCenter` is the integer `minPos` plus half the dimensions with no scale factor, and the placement checks pass the same integer coordinates to `VoxelManager.CheckVoxel`, so a grid cell and a terrain voxel are the same cube. The grid is stored per chunk of 30 cells on each axis (`GridPos.CHUNK_SIZE`, `VoxelManager.CHUNK_SIZE`), a cell addressed by chunk id and a `ushort` index inside it (`GridPos`). Each chunk keeps hash maps from cell to machine, to clearance count, to obstruction and to inserter connections (`GridManager.ChunkGridData`).

A machine's placement state is `GridInfo`: `minPos` (the minimum corner cell), `dims` (from the definition), `yawRot` in degrees, `myGridClearance`, the strata (the layer of the world it sits in), and optional custom voxel footprint operations for shapes that are not boxes.

### Placement rules

| Rule | Mechanism | Source |
|---|---|---|
| Aim snap | The aimed point becomes the nearest bottom centre: x and z rounded so the footprint lands on whole cells (an odd footprint centres on a cell, an even one on a cell corner), y floored or rounded. | `FHG_Utils.GetNearestBottomCenter`, `SetBottomCenterOnCurStrata` |
| Ground align | With smart snap on and the definition's `alignToTerrain` set, a downward raycast from the aim point picks the ground the machine stands on. | `PlayerBuilder.AlignToGround` |
| Snap to machines | Aiming at a placed machine snaps the new one against it along the hit normal: a square machine of the same size always goes through `SnapToTarget`, others only when the aimed box is invalid, and with no machine hit an invalid box is moved out of the hit voxel along the normal. Definitions may carry a face snap profile and a custom snap box for structures. | `PlayerBuilder.SnapPlacement`, `SnapToTarget`, `SnapToVolume`, `BuilderInfo.faceSnapDataProfile` |
| Rotation | Yaw only, in steps of 90 degrees, one button each way. A footprint with x ≠ z swaps x and z at 90 and 270 and is re-placed about its bottom centre. Ports and anchors rotate through a fixed table per step. | `PlayerBuilder` (RotateLeft and RotateRight add 270 or 90), `GridInfo.Dimensions`, `FHG_Utils.SetYawRotation`, `PortInfo.GetOffset` |
| Occupied volume | Every cell of the box must be free of other machines, protected zones, obstructions, the player's cells, other machines' clearance (when this machine has clearance itself), terrain voxels and, for most machines, water. | `GridManager.CheckBuildableObstructionsAt`, `CoordIsValid`, `CheckOptions` |
| Support | The default builder also wants every cell directly under the footprint to be non empty (terrain or a machine), so machines stand on something. | `MachineInstanceDefaultBuilder.CheckBuildIsValid`, `GridManager.CheckBuildableSurfaceBelow` |
| Clearance | A definition's `gridClearance` (0 or 1 in the shipped data) adds a shell of that many cells around the footprint horizontally and one cell above and below. The shell only blocks against another machine that has clearance itself, so two clearance machines need a free cell between them, while belts and inserters (clearance 0) may sit in the shell. | `GridManager.CheckBuildableObstructionsAt` (the ring loop), `BuilderInfo.gridClearance` |
| Ports | Inserter, high voltage and axle ports are cells in that one cell ring around the body, at given heights: port coordinates run from 0 to dims + 1, shifted by one cell when placed. | `PortInfo.GetOffset`, `GridInfo.UpdatePortPositions`, `BuilderInfo.ports` |
| Terrain overlap | Structures may overlap terrain: `maxNumOverlappingVoxels` lets that many voxels stay inside the box (a 3 × 3 floor allows 8), and `sinkInTerrain` lets floors sink into the ground when the aim normal points up. | `MachineInstanceDefaultBuilder.BuildHelper`, `ProceduralBuilder.CanSinkIntoTerrain` |
| Neighbours | A machine's neighbours are the machines touching its faces (the one cell shell, edges and corners excluded). The power network is rebuilt from that list. | `GridManager.GetAdjacentObjectsFor`, `PowerInfo.RefreshPowerNetwork` |

### Footprints and heights

From the machine definitions (ScriptableObjects deriving from `BuilderInfo`, field `dimensions` in cells, field `gridClearance`) and the prefab each definition points to (`rawBuilderPrefab`), whose interaction box collider gives the body's size in metres.

| Machine | Footprint (cells) | Height (cells, m) | Clearance | Interaction box (m) | Definition asset |
|---|---|---|---|---|---|
| Smelter, all three tiers | 2 × 2 | 2 | 1 | 2 × 2 × 2 | `SmelterDefinition` Smelter, Smelter_2, Smelter_3 |
| Blast smelter | 2 × 2 | 2 | 1 | | `BlastSmelterDefinition` BlastSmelter |
| Assembler, both tiers | 2 × 4 | 4 | 1 | 2 × 4 × 4 | `AssemblerDefinition` Assembler_1, Assembler_2 |
| Mining drill, all tiers | 3 × 3 | 3 | 0 | 3 × 3 × 3 | `DrillDefinition` MiningDrill, MiningDrill_2, BlastDrill |
| Crusher | 4 × 4 | 6 | 1 | 4 × 6 × 4 base, 3 × 6 × 3 body | `CrusherDefinition` Crusher |
| Thresher | 3 × 4 | 4 | 1 | | `ThresherDefinition` Thresher_1, Thresher_2 |
| Conveyor belt, all tiers | 1 × 1 | 1 | 0 | | `ConveyorDefinition` ConveyorBelt, _2, _3 |
| Inserters, all kinds | 1 × 1 | 1 | 0 | | `InserterDefinition` (7 assets) |
| Accumulator | 2 × 2 | 4 | 1 | 2.1 × 4.1 × 2.1 | `AccumulatorDefinition` Accumulator |
| Power generator | 2 × 3 | 2 | 1 | 2.0 × 1.9 × 2.9 | `PowerGeneratorDefinition` PowerConverter, _2 |
| Voltage stepper | 2 × 2 | 3 | 0 | 2 × 3 × 2 | `VoltageStepperDefinition` VoltageStepper |
| High voltage cable end | 2 × 2 | 2 | 0 | | `HighVoltageCableDefinition` Highvoltage_cable |
| Transit pole | 1 × 1 | 4 | 0 | | `TransitPoleDefinition` TransitPole |
| Water wheel | 3 × 2 | 3 | 1 | | `WaterWheelDefinition` WaterWheel |
| Planter | 3 × 2 | 3 | 0 | | `PlanterDefinition` Planter, Planter_2 |
| Chest, small chest | 2 × 2, 1 × 1 | 2, 1 | 0 | | `ChestDefinition` Chest_1, Chest_2, Chest_Tiny |
| Production terminal | 3 × 3 | 4 | 0 | | `ProductionTerminalDefinition` (2 assets) |
| Transit depot | 3 × 4 | 4 | 0 | | `TransitDepotDefinition` TransitDepot_1 |
| Sand pump | 10 × 10 | 3 | 0 | | `SandPumpDefinition` SandPump (`alignToTerrain` off) |

There is no dedicated power pole: power flows through face contact between machines and through high voltage cables between port cells. The 64 building pieces (`StructureDefinition`, floors, walls, pillars, stairs, railings) run from 1 × 1 × 1 to 10 × 5 × 1 and are the only definitions with terrain overlap or sinking set.

Heights are whole cells everywhere, and the smaller production machines are compact: the smelter is a 2 m cube, the assembler 4 m tall on a 2 × 4 footprint.

### The smelter

Footprint 2 × 2 cells, height 2 cells, clearance 1 (so a 4 × 4 shell against other clearance machines), four inserter ports, two on each x side at floor level (`SmelterDefinition` Smelter, `ports`). The body mesh fills the cell box: `Smelter.001` has a bounding box of 2.00 × 2.00 × 2.00 m with its origin at the bottom centre (mesh local bounds centre (0, -0.01, 1.00) and extent (1.00, 1.00, 1.00) in its z up source frame, turned y up by its parent transform), and the interaction box is 2 × 2 × 2 centred 1 m up (prefab `RI_BI_Smelter`). The prefab's window light sits on the -z face at 1.27 m height, centred in x (`WindowLight`, point light, range 0.5, intensity 4), with the spout light lower on the same face at 0.52 m (intensity 8), the cauldron light at the top centre at 1.56 m (intensity 6), and two heating element lights at x ±0.80, 1.08 m. The emissive texels of the body's emission map (`Smelter_Emission`, 2048²) fall on faces within x ±0.67 m and between 0.17 and 1.93 m of height, recessed from the outer shell.

### How machine state is shown

Every placed machine is drawn instanced (`GPUInstancerPrefab` on each mesh part, with an impostor level of detail through `AmplifyImpostor`), and its state reaches the shader as one per instance vector (`StreamedMachineCommonData.materialPropState`, packed in `DefaultStreamedMachineInstance.UpdateMaterialProps`): x is on or off, y the status (`MachineStatus`: working, making, out of fuel, out of power, out of ingredients, no recipe, damaged, paused and others), w a per type value (the accumulator's charge fraction, a belt's speed). The machine shader (`Tech/Machine` on material `SmelterMat`) gates its emission map on that on state (`_UseDynamicEmission`, `_isOn`) with a flicker noise, and carries outline colours for working and error highlights (`_WorkingColor`, `_ErrorColor`).

What is on is chosen per channel through flags (`MachineIsOnState`: material, audio, animations, effects). Animation is data driven per prefab (`MachineAnimComponent`): lists of rotations, translations, shader float animations, shakers and light curves, each with a cycle time and a ramp up and wind down when the machine turns on or off (`BaseAnimData.UpdateCycles`). The smelter's has three stir rods turning at 0.06 revolutions per second with a 2 to 2.5 s spin up, four translations and one shader float (`_MeltingControl`) on a 5 s cycle. Particle systems sit under a proxy (`MachineParticleProxy`) and are switched with the on state (`StreamedMachineCommonData.ToggleAllParticles`): the smelter's are embers, smoke, steam, a fire disc over the cauldron and heat distortion at the elements and spout. Point lights are baked into the prefab with a light component of their own (`UL_FastGI`) and can be driven by light curves (`AnimLightsData`).
