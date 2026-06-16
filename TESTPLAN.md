# Saint Manick Test Plan

This document outlines the testing architecture, runner instructions, and manual playtest regression procedures for **Saint Manick**.

---

## 1. Automated Headless Test Suite

Saint Manick features a self-contained, custom GDScript test framework designed to run headless and validate core Phase 0-3 gameplay and persistence logic.

### 1.1 Running Instructions

To execute the test suite from the command line, run the following command (adjusting the path to your Godot binary as necessary):

```powershell
& "C:\Users\MARCO\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\MARCO\Documents\GitHub\SAINT MANICK" -s res://tests/run_tests.gd
```

On success, the suite outputs `Result: SUCCESS` and exits with process code `0`. If any assertions fail, it prints detailed error messages and exits with code `1`.

---

## 2. Test Coverage Table

The automated suite consists of **32 test cases** across **9 test suites**, covering all core Phase 0-3 systems:

| Test Suite File | Test Cases | Objective / Verification |
| :--- | :---: | :--- |
| [`test_health_component.gd`](file:///C:/Users/MARCO/Documents/GitHub/SAINT%20MANICK/tests/cases/test_health_component.gd) | 6 | <ul><li>Verify shield absorbs damage first, leaving health unaffected.</li><li>Verify spillover damage to health when shield is depleted.</li><li>Verify `is_shield_breaker` completely bypasses shield.</li><li>Verify health bounds clamping at `0.0` and `died` signal.</li><li>Verify shield regeneration processes only after the configured delay.</li><li>Verify signal routing to SignalBus and GameManager when `is_player` is true.</li></ul> |
| [`test_damage_flow.gd`](file:///C:/Users/MARCO/Documents/GitHub/SAINT%20MANICK/tests/cases/test_damage_flow.gd) | 4 | <ul><li>Verify active `Hitbox3D` overlapping `Hurtbox3D` inflicts damage.</li><li>Verify inactive `Hitbox3D` ignores overlaps.</li><li>Verify `damage_info.source` is automatically populated with the hitbox owner if unset.</li><li>Verify custom `source` remains intact if already populated.</li></ul> |
| [`test_conductor.gd`](file:///C:/Users/MARCO/Documents/GitHub/SAINT%20MANICK/tests/cases/test_conductor.gd) | 3 | <ul><li>Verify `beat_index` progression and downbeat wrapping (1 to 4).</li><li>Verify `downbeat` emissions and `measure_index` incrementing.</li><li>Verify tempo transitions and smooth BPM ramping towards target BPM.</li></ul> |
| [`test_game_manager.gd`](file:///C:/Users/MARCO/Documents/GitHub/SAINT%20MANICK/tests/cases/test_game_manager.gd) | 3 | <ul><li>Verify `start_new_run()` resets volatile state and loads max upgrades correctly.</li><li>Verify volatile run scrap vs persistent profile scrap modification/spending.</li><li>Verify `respawn_or_game_over()` decrements lives, resets HP/Shield, and respects the permadeath shop transition boundary.</li></ul> |
| [`test_save_manager.gd`](file:///C:/Users/MARCO/Documents/GitHub/SAINT%20MANICK/tests/cases/test_save_manager.gd) | 2 | <ul><li>Verify profile serialization/deserialization with `user://test_save_data.tres`.</li><li>Ensure missing save files fall back to clean default profiles.</li><li>Confirm cleanup of test files after suite execution.</li></ul> |
| [`test_enemy_stats.gd`](file:///C:/Users/MARCO/Documents/GitHub/SAINT%20MANICK/tests/cases/test_enemy_stats.gd) | 5 | <ul><li>Assert values of Bruiser `.tres` stats (90HP / 20DMG).</li><li>Assert values of Runner `.tres` stats (30HP / 8DMG).</li><li>Assert values of Sniper `.tres` stats (24HP / 18DMG).</li><li>Assert values of Enforcer `.tres` stats (600HP / 22DMG).</li><li>Assert values of Headliner `.tres` stats (1500HP / 25DMG).</li></ul> |
| [`test_wave_encounter.gd`](file:///C:/Users/MARCO/Documents/GitHub/SAINT%20MANICK/tests/cases/test_wave_encounter.gd) | 2 | <ul><li>Verify WaveSpawner emits `wave_cleared` when spawned enemies are defeated.</li><li>Verify ZoneEncounter wave progression, initial gate locking, and gate unlocking upon completion.</li></ul> |
| [`test_collision_layers.gd`](file:///C:/Users/MARCO/Documents/GitHub/SAINT%20MANICK/tests/cases/test_collision_layers.gd) | 4 | <ul><li>Verify 3D physics collision layer constants (e.g. player_hitbox=512, player_hurtbox=1024, enemy_hitbox=2048, enemy_hurtbox=4096, hazard_hitbox=8192).</li><li>Verify layer and mask assignments on player, enemy, and hazard scenes.</li></ul> |
| [`test_camera_fsm.gd`](file:///C:/Users/MARCO/Documents/GitHub/SAINT%20MANICK/tests/cases/test_camera_fsm.gd) | 3 | <ul><li>Verify camera transitions via `SignalBus.camera_shift_requested` (Sidescroll -> Transitioning -> TopDown).</li><li>Confirm target tracking and camera offset updates.</li><li>Confirm target `is_jump_enabled` and `current_path` properties update accordingly.</li></ul> |

---

## 3. Manual Playtest Regression Checklist

For features and visual/game-feel parameters that cannot be fully validated programmatically, use the following checklist during manual playtests:

### 3.1 Movement & Physics
- [ ] **Basic Movement**: Check that the player moves left/right smoothly on the current Path3D.
- [ ] **Double Jump**: Verify double jump works in sidescroll mode.
- [ ] **Dash & Roll**: Verify Dash (Shift) and Roll (Ctrl) trigger the correct states and move the player correctly.
- [ ] **Jump Constraints**: Check that jumping is fully disabled in Top-Down mode (e.g., during top-down encounters).

### 3.2 Visual & Camera
- [ ] **Camera Shifts**: Request top-down transitions (e.g., entering an encounter) and check that the camera smoothly shifts to the top-down perspective within `1.5` seconds.
- [ ] **Camera Tracking**: Ensure the camera tracks the player smoothly without jittering.
- [ ] **Transition Boundaries**: Check that the screen borders block player movement or keep them in frame during combat encounters.

### 3.3 Combat Flow & UI
- [ ] **Attack Input**: Verify light attack (J) and heavy attack (K) trigger animations and damage enemies.
- [ ] **Health & Shield UI**: Verify that taking damage updates the health/shield UI bars immediately.
- [ ] **Combo Counter**: Check that the combo counter increases upon consecutive hits and drops after a delay of no combat.
- [ ] **Shop Transition**: Confirm that losing all lives triggers a screen fade and transitions the player to Karen's Shop.
