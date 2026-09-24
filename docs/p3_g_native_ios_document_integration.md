# P3-G — Native iOS Document Integration

P3-G connects the P3-F import business layer to real iOS system entry points.
It is intentionally a thin platform bridge: native code acquires user-selected
inputs and hands sandbox-safe temporary paths to the existing P3-F
`handoff_import_path()` API.

P3-G does not reimplement project parsing, image policy or managed persistence.

## 1. Native plugin

P3-G adds `PhospriteNativeDocuments`, an Objective-C++ Godot iOS plugin built
against the pinned Godot 4.6.3 headers in the existing unsigned-iOS workflow.

The plugin exposes:

- native Document Picker presentation;
- native Photo Picker presentation;
- pending native-event queue;
- Files reveal capability;
- temporary-import cleanup.

The singleton is iOS-only. Desktop/headless runs remain independent of it.

## 2. Files / Document Picker

Gallery → Import → 文件 routes to a real
`UIDocumentPickerViewController`.

The picker:

- opens existing documents instead of treating external URLs as save targets;
- supports native multi-selection;
- filters for PXO, ASE/ASEPRITE and P3-F-supported image extensions;
- returns selected external URLs to the native bridge.

Each returned file URL is handled under an explicit security-scoped access
window:

1. call `startAccessingSecurityScopedResource()`;
2. coordinate read access through `NSFileCoordinator`;
3. copy the source into a unique Phosprite temporary import folder;
4. call `stopAccessingSecurityScopedResource()`;
5. enqueue only the sandbox-local temporary path.

The external source remains untouched.

## 3. Photos Picker

Gallery → Import → 照片 routes to a real `PHPickerViewController`.

P3-G uses PHPicker rather than broad Photo Library permission.

The picker supports multiple selected photos.

Selected `UIImage` values are rendered into normalized temporary PNG files in
the Phosprite import cache. P3-F therefore receives one deterministic ordinary
image format regardless of the original Photos asset representation such as
HEIC.

The source Photos asset is never used as a project save location.

## 4. Multi-selection queue

`IOSDocumentBridge` owns a serial path queue.

For a native multi-selection batch:

1. every native result is queued in selection order;
2. only one path enters P3-F at a time;
3. PXO/ASE flows can complete synchronously;
4. image flows wait for the user's 作为图层 / 作为参考图 decision;
5. cancel/failure completes that item and advances to the next item;
6. non-final successful imports stay in Gallery;
7. only the final successful path enters Editor.

After a path's P3-F flow completes, the native temporary copy is deleted.

P3-F remains the only importer.

## 5. Files “Open in Phosprite”

P3-G registers iOS document types for:

- Phosprite PXO;
- Aseprite ASE/ASEPRITE;
- public images.

The native bridge captures external file URLs delivered by iOS.

Godot 4.6.3 uses the scene lifecycle on iOS, so P3-G covers both:

- warm `scene:openURLContexts:`;
- cold `scene:willConnectToSession:options:`.

A UIApplicationDelegate `application:openURL:options:` service is also retained
for compatible handoff paths.

Open-In files go through the same security-scoped coordinated temporary copy and
then the same P3-F path queue. There is no separate parser path for Files Open In.

Cold-open temporary URLs are buffered by native code until the Godot singleton is
ready. Main starts consuming them only after AppShell startup finishes, avoiding
startup routing from overwriting the imported-project destination.

## 6. iOS document types

The iOS export declares:

### Owned type

`com.phosprite.project`

- description: Phosprite Project;
- extension: `.pxo`;
- MIME: `application/x-phosprite-project`;
- conforms to `public.data`;
- handler rank Owner.

### Imported Aseprite type

`com.phosprite.import.aseprite`

- extensions: `.ase`, `.aseprite`;
- conforms to `public.data`;
- handler rank Alternate.

### Images

`public.image` is registered with editor role / Alternate rank.

This allows Files/share/open-in surfaces to offer Phosprite for supported input
documents without claiming ownership of standard images or Aseprite files.

## 7. Files app visibility

The existing managed-storage boundary remains:

- `UIFileSharingEnabled = true`;
- `LSSupportsOpeningDocumentsInPlace = true`;
- Godot `user_data/accessible_from_files_app = true`.

Managed `Projects/*.pxo` therefore remain within the Files-visible app
Documents area.

P3-G does not change P3-B's authority: opening an external document still causes
copy-in/conversion to the managed Project Library.

## 8. Reveal in Files capability

The native singleton exposes `reveal_in_files(path)`, and
`IOSDocumentBridge.reveal_in_files()` globalizes a managed path before handing
it to iOS.

The native bridge opens the Files app's shared-document URL for that managed
file. Failure is surfaced through the native event/error queue.

P3-G owns this native capability. P3-H owns the project-card/project-action UI
that will invoke it.

## 9. Failure and cancellation

Native picker cancellation creates no project and no managed file.

If native copying fails, the bridge emits an error and never calls P3-F with an
invalid external URL.

If P3-F import later fails or the user cancels an image mode/size decision:

- AppShell emits `import_flow_finished(false)`;
- the queue releases the current temporary copy;
- the next selected item may continue;
- no external source is modified.

## 10. Build verification

The unsigned iOS CI now builds two local Phosprite plugins against the same pinned
Godot 4.6.3 checkout:

- PhospritePointerIdentity;
- PhospriteNativeDocuments.

The export verification gate must prove the generated Xcode project contains
PhospriteNativeDocuments and that the generated Info.plist contains:

- Phosprite PXO type declaration;
- Aseprite imported type declaration;
- CFBundleDocumentTypes;
- UIFileSharingEnabled;
- LSSupportsOpeningDocumentsInPlace.

The .xcarchive and unsigned IPA must still build successfully.

## 11. Acceptance

P3-G is complete when:

1. 文件 is wired to UIDocumentPicker;
2. 照片 is wired to PHPicker;
3. both pickers support multiple selections;
4. external Files URLs use balanced security-scoped access;
5. external reads use NSFileCoordinator before sandbox copy;
6. Photos assets become sandbox-local PNG inputs;
7. native paths reuse P3-F `handoff_import_path`;
8. multi-selection serializes image decisions safely;
9. non-final batch items do not prematurely enter Editor;
10. temporary native copies are cleaned after flow completion;
11. PXO / Aseprite / images are declared to iOS;
12. Files Open In reaches the same P3-F path on warm launch;
13. Files Open In reaches the same path on cold scene launch;
14. managed Projects stay Files-visible;
15. Reveal in Files native capability is available;
16. desktop/headless behavior does not require the iOS singleton;
17. existing P0/P1/P2/P3-0…P3-F regressions remain green;
18. iOS plugin compile, Xcode export, plugin verification, archive and unsigned IPA
    all remain green.

## 12. Deferred

P3-G does not implement:

- P3-H project-card gestures or project action menus;
- rename / duplicate / delete interaction UI;
- wiring Reveal in Files into the P3-H action menu;
- P3-I export/share redesign;
- P3-J transition/motion/polish;
- P3-K real-device final acceptance matrix.

The P3-K device gate must exercise the actual iPad Files picker, Photos picker,
Files Open In, Files visibility and managed-project handoff end to end.
