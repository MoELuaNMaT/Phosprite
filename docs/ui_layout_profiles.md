# UI layout profiles

Phosprite exposes four top-level UI profile slots from the `UI` menu in the editor title bar.

## User contract

- Slots `1`, `2`, `3`, and `4` are mutually exclusive.
- Slot `1` is the default and inherits the existing Workspace layout from installs created before this feature.
- Every slot persists its own Workspace placement state.
- The first time an unused slot is selected, it starts as a copy of the profile the user switched from. Further edits are isolated to that slot.
- The selected slot is persisted and restored on the next launch.

## Architecture

A UI profile is intentionally broader than a Workspace layout preset.

`WorkspaceLayoutStore` owns the four independent persisted Workspace snapshots. The active slot is stored in the existing application config. The legacy `workspace/layout_state` key remains mirrored to slot 1 for backward compatibility.

`WorkspaceUIProfileController` owns switching and the top-bar radio menu. Switching is transactional: pending autosave is flushed, the target implementation hook is activated, and the target slot is restored. A never-used slot is seeded from the previous profile.

`WorkspaceEditorMigration.activate_ui_profile()` is the implementation boundary for future profile-specific UI. All four profiles currently use the same Workspace implementation. A later profile can replace a floating module with a fixed toolbar, use different module composition, or route to profile-specific controls without changing the slot persistence contract.

The existing `Window > Layouts` presets remain layout presets inside the currently active UI profile. They do not replace or select UI profiles.
