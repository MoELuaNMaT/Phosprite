# P3-K — Final Integration Gate

P3-K is the final validation stage for the P3 Project Library program. It does not add product behavior unless validation exposes a blocking defect.

## Scope

The final gate combines:

- the complete recursive unit/integration regression suite, including all retained P0/P1/P2/P3 tests;
- Project Library stress and external-rescan coverage;
- deterministic transaction-interruption and recovery coverage;
- final static checks;
- final unsigned iOS export, native-plugin verification, archive and IPA packaging;
- a real-device Chinese manual acceptance matrix for iPad.

## Automated final-gate additions

### Project Library stress

tests/unit/test_p3_k_final_gate_stress.gd creates 120 managed PXO projects and verifies that:

- ProjectLibrary.scan(false) discovers all physical PXOs;
- the fast path does not instantiate or deserialize full Project objects;
- preview PNGs remain undecoded during metadata-only scan;
- external delete is reflected by the next scan;
- external add is reflected by the next scan;
- external metadata replacement is reflected by the next scan;
- an externally corrupted PXO remains visible and is classified as CORRUPTED.

A separate duplicate-identity stress fixture creates 12 physical PXOs sharing one UUID and verifies:

- every physical copy survives;
- exactly one canonical file retains the original UUID;
- every other copy receives a unique valid replacement;
- the repaired identities remain stable on the following scan.

### Transaction interruption and recovery

The final gate models two process-death boundaries using only on-disk state:

1. death after staging serialization but before recovery installation:
   - formal PXO remains valid and unchanged;
   - staging alone is not advertised as pending recovery;
2. death after validated recovery installation but before formal commit:
   - formal PXO still remains valid and unchanged;
   - the newer recovery candidate remains on disk;
   - a fresh ProjectLibrary instance reconstructs has_pending_recovery;
   - explicit restore promotes the recovery into the formal PXO and consumes the slot.

The runtime gate additionally models loss of transient AppShell state while the per-project recovery prompt is visible. After the transient UUID/path selection is cleared and Gallery is rescanned, opening the project must ask again. Cancel remains non-destructive.

## Existing gates reused

P3-K deliberately reuses the existing single regression runner instead of creating a competing test path.

Because tests/runner.gd recursively discovers every .gd suite under tests/unit and tests/integration, the P3-K regression automatically includes the retained P2 workspace/input tests and every earlier P3 stage test.

The final candidate must also pass the existing GitHub Actions gates:

- Static Checks: gdformat, gdlint, codespell;
- Regression Tests: complete recursive suite;
- iOS build (unsigned):
  - Pointer Identity native plugin;
  - Phosprite Native Documents plugin;
  - pinned Godot Share plugin;
  - Godot resource import;
  - Xcode project export;
  - iOS plugin / Info.plist verification;
  - unsigned .xcarchive;
  - unsigned .ipa;
  - artifact upload.

## Real-device boundary

CI cannot substitute for UIKit, Files, Photos, Share Sheet, Apple Pencil, physical orientation, process termination or actual installation on the user's iPad.

Therefore P3-K has two explicit statuses:

- AUTOMATION PASS: repository, regression and unsigned iOS packaging gates are green;
- REAL-DEVICE PASS: the Chinese manual acceptance matrix in docs/p3_k_manual_acceptance_zh.md has been executed on the final IPA and every required case passes.

The stage is fully closed only after both statuses are PASS.

## Exit criteria

P3-K is complete when:

1. final Static Checks pass;
2. the complete recursive regression suite passes with zero failures;
3. Project Library stress / external rescan / duplicate UUID tests pass;
4. deterministic interruption and recovery tests pass;
5. final unsigned iOS archive and IPA packaging pass;
6. final IPA artifact is retained and delivered;
7. the complete Chinese real-device manual cases are delivered;
8. required real-device cases pass on the final build.

If real-device execution has not yet been performed, the repository gate may be closed as AUTOMATION PASS, but P3-K must remain REAL-DEVICE PENDING rather than claiming device behavior was verified.
