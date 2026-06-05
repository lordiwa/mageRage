# MAGE RAGE — CRUCIAL TEST CORE (push/PR gate)

> **Purpose:** the curated subset of GUT tests (< 66) that runs fast on every
> push/PR. The FULL suite (652) is KEPT and runs nightly via a GitHub Actions
> cron (+ `workflow_dispatch`). No tests are deleted — only the cadence changes.
> **Curated by:** independent reviewer pass for TASK-049 (2026-06-05).
> **Count:** 61 tests (4 headroom under the 66 cap).

## Mechanism (recommended)
A dedicated `.gutconfig.crucial.json` listing the crucial SCRIPTS, run with
`-gconfig`, so the 67 scattered test files are NOT edited/moved. Mirror
`should_exit`/exit-code settings from the existing `.gutconfig.json` (the full
run). If this GUT 9.4.0 build does not honor an explicit per-script `"tests"`
array, fall back to a thin `test/crucial/` dir of forwarder scripts
(`extends` the real test) referenced via `"dirs"`.

- **Crucial (push/PR):** `... -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.crucial.json -gexit`
- **Full (nightly cron):** `... -s res://addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit`
- **Flake caution:** the core concentrates the await-physics held-input surface
  (groups A + G). Keep each test's InputGate-clearing `after_each` teardown
  intact when relocating; run the crucial config 2–3x in CI (not 1x).

## The 61 crucial tests (file :: test)

### A. Flight-bypass gating — real-physics (M1's 3 regressions) [4]
- test_sector_boss_reachability.gd :: test_flying_hero_reaches_the_boss_room_and_starts_the_encounter
- test_anti_magic_zone_physics.gd :: test_high_entry_hero_cannot_pass_barrier_while_unpurged
- test_anti_magic_zone_physics.gd :: test_high_entry_hero_can_pass_barrier_after_purge
- test_sector_02.gd :: test_flying_hero_reaches_the_boss_room_and_starts_the_encounter

### B. Gate/zone blocker-span geometry (flight cannot bypass) [4]
- test_sector_01.gd :: test_placed_gate_blocker_spans_the_corridor_so_flight_cannot_bypass_it
- test_sector_01.gd :: test_anti_magic_route_requires_flight_and_cannot_be_walked_around
- test_sector_02.gd :: test_gate_blocker_spans_the_corridor_so_flight_cannot_bypass_it
- test_sector_02.gd :: test_zone_barrier_sits_above_jump_apex_so_route_requires_flight

### C. Corridor metrics + boss-gap (-288 / +328 / 98px) [3]
- test_sector_01.gd :: test_markers_lie_on_a_connected_left_to_right_path
- test_sector_02.gd :: test_corridor_uses_the_proven_flight_safe_metrics
- test_sector_02.gd :: test_spine_markers_are_monotone_left_to_right

### D. Gate/zone element logic (persistent open/purge, wrong-element no-op) [4]
- test_sector_01.gd :: test_elemental_gate_instance_resolves_and_blocks_a_required_route
- test_sector_01.gd :: test_anti_magic_zone_instance_resolves_and_suppresses_a_required_route
- test_sector_02.gd :: test_elemental_gate_wrong_element_is_a_noop_fire_opens_persistently
- test_sector_02.gd :: test_anti_magic_zone_wrong_element_noop_electricity_purges_persistently

### E. Camera per-level limits (TASK-045) [7]
- test_sector_02_visual_bounds.gd :: test_sector_02_camera_limits_match_the_level_bounds
- test_sector_02_visual_bounds.gd :: test_sector_01_camera_limits_match_its_own_narrower_bounds
- test_sector_02_visual_bounds.gd :: test_shared_player_scene_carries_no_baked_camera_limits
- test_sector_02_visual_bounds.gd :: test_encounter_level_camera_stays_unclamped
- test_sector_02_visual_bounds.gd :: test_arena_level_camera_stays_unclamped
- test_sector_02_visual_bounds.gd :: test_sector_02_backstop_covers_the_camera_reachable_view
- test_sector_02_visual_bounds.gd :: test_sector_01_backstop_covers_the_camera_reachable_view

### F. Floor/platform slab seating (TASK-046/048/051 — visible top == collision top) [2]
> The surfaces are solid slate SLABS (Sprite2D per collision footprint) after the
> slab rewrite replaced the finicky City TileMapLayer (transparent-cap + grid snap
> that kept the hero floating). These guard the floating-hero + floating-tower bugs.
- test_sector_02_visual_bounds.gd :: test_each_walkable_slab_top_sits_on_its_collision_top
- test_sector_02_visual_bounds.gd :: test_elevated_slabs_are_thin_not_towers

### G. Projectile-pool physics callback (TASK-044) [3]
- test_projectile_pool_physics.gd :: test_hit_parks_synchronously_but_defers_collision_disable
- test_projectile_pool_physics.gd :: test_no_double_hit_during_the_deferred_gap
- test_projectile_pool_physics.gd :: test_real_collision_callback_parks_without_error_and_hits_once

### H. Element-vs-armor RPS (DD-006) [4]
- test_element_matchup.gd :: test_fire_vs_fire_armor_resisted
- test_element_matchup.gd :: test_elec_vs_fire_armor_weak
- test_element_matchup.gd :: test_ice_vs_fire_armor_neutral
- test_element_matchup.gd :: test_damage_after_matchup_scales_base

### I. Combo armor RPS + anti-dominance (TASK-040 / DD-013) [5]
- test_combo_matchup.gd :: test_steam_multiplier_is_mean_of_fire_and_ice
- test_combo_matchup.gd :: test_no_combo_ever_exceeds_the_weak_bonus
- test_combo_matchup.gd :: test_each_combo_is_resisted_by_one_armor_and_bonused_by_another
- test_combo_anti_dominance.gd :: test_best_single_dpm_beats_best_combo_dpm_for_every_armor
- test_combo_anti_dominance.gd :: test_each_individual_combo_is_no_more_efficient_than_the_best_single

### J. Dual-cast combo cadence/cost/window (TASK-040) [7]
- test_combo_cadence.gd :: test_combo_fired_carries_the_blended_combo_spell
- test_combo_cadence.gd :: test_combo_spends_both_elements_mana
- test_combo_cadence.gd :: test_combo_does_not_fire_with_insufficient_combined_mana
- test_combo_cadence.gd :: test_combo_cadence_is_slower_than_either_single_interval
- test_combo_cadence.gd :: test_second_trigger_after_window_does_not_combo
- test_combo_cadence.gd :: test_same_element_both_slots_fires_exactly_one_empowered_shot
- test_combo_cadence.gd :: test_empowered_shot_is_scaled_by_the_empowered_multiplier

### K. Hold-to-fire per-element cadence (TASK-038) [4]
- test_fire_cadence.gd :: test_many_small_ticks_within_one_interval_fire_exactly_once
- test_fire_cadence.gd :: test_held_fire_out_rates_held_ice_over_same_window
- test_fire_cadence.gd :: test_mana_gates_a_cadence_ready_shot_then_regen_resumes
- test_fire_cadence.gd :: test_both_slots_fire_independently_primary_out_rates_secondary

### L. Aim-assist purity (DD-012) [5]
- test_aim_assist.gd :: test_enemy_outside_cone_not_assisted
- test_aim_assist.gd :: test_enemy_inside_inner_cone_full_snap
- test_aim_assist.gd :: test_enemy_between_cones_partial_pull
- test_aim_assist.gd :: test_nearest_of_several_chosen
- test_aim_assist.gd :: test_zero_length_raw_aim_returns_safe_unit_vector

### M. FSM / movement transitions [6]
- test_movement_transitions.gd :: test_move_buffered_jump_while_falling_fires_on_landing
- test_movement_transitions.gd :: test_jump_to_flight_on_second_jump_when_electricity_unlocked
- test_movement_transitions.gd :: test_jump_no_flight_on_second_jump_without_electricity
- test_movement_transitions.gd :: test_jump_first_air_jump_press_does_not_fly
- test_movement_transitions.gd :: test_flight_to_move_when_on_floor
- test_movement_transitions.gd :: test_jump_air_dash_is_one_shot_per_airtime

### N. FSM routing + projectile chain + slow [3]
- test_state_machine.gd :: test_stale_request_from_non_current_state_ignored
- test_projectile_chain.gd :: test_chain_walk_visits_each_once_bounded_by_max_targets
- test_slow_effect.gd :: test_decays_over_time_then_recovers_to_full

## Deliberately left to NIGHTLY (not crucial)
Component-unit gate/zone (FakePlayer) duplicates of the placed-instance guards;
`test_combo_table.gd` / `test_combo_projectile.gd` / `test_magic_manager.gd`
(duplicate combo coverage); the structural bulk of `test_sector_02.gd`
(node-exists / accessor / HUD-binding / tileset-paint); all `test_player_hud*`,
`test_*_style`, `test_*_visual`, `test_muzzle_flash`, `test_reticle`,
`test_parallax_background`. Good first promotions if the cap is ever raised:
`test_warden_phases.gd` (HP banding) and `test_shield_logic.gd` (arc math).
