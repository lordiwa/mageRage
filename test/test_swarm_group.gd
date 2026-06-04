## TASK-019 unit tests for the SwarmGroup node + the Electricity-chain showcase.
##
## A SwarmGroup spawns N Swarmlings at offsets around its position, builds a link
## graph (SwarmLinks), and draws Line2D arcs between LIVING linked members. When a
## member dies the group drops it from the graph and refreshes the arcs (no dangling
## links / no arc to a freed member).
##
## Showcase integration (the legible DD-004 identity):
##   - a CHAIN projectile (lightning-like) hitting ONE clustered Swarmling arcs to
##     MULTIPLE members (bounded by max_targets, each once) -> Electricity clears
##     the group efficiently;
##   - a SINGLE (Fire) hit affects ONLY the struck member -> Fire hits one at a time.
extends GutTest

const FIRE := SpellData.Element.FIRE
const ELEC := SpellData.Element.ELECTRICITY
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")


func _make_group(count := 3) -> SwarmGroup:
	var g := SwarmGroup.new()
	g.member_count = count
	g.spawn_radius = 40.0
	add_child_autofree(g)   # _ready spawns members + builds links + arcs
	return g


func _make_spell(element: int, shot_type: int, max_targets := 1,
		chain_radius := 200.0) -> SpellData:
	var s := SpellData.new()
	s.element = element
	s.damage = 100.0          # ensure a lethal/clearly-readable hit
	s.speed = 400.0
	s.shot_type = shot_type
	s.max_targets = max_targets
	s.chain_radius = chain_radius
	return s


func _make_projectile() -> Projectile:
	var p := PROJECTILE_SCENE.instantiate()
	add_child_autofree(p)
	return p


# --- Spawning + linking + arcs ------------------------------------------------

func test_group_spawns_member_count_swarmlings() -> void:
	var g := _make_group(3)
	assert_eq(g.living_members().size(), 3, "the group spawns member_count Swarmlings")


func test_members_are_swarmlings_in_the_enemies_group() -> void:
	var g := _make_group(3)
	for m in g.living_members():
		assert_true(m is Swarmling, "every member is a Swarmling")
		assert_true(m.is_in_group("enemies"),
			"members are in `enemies` so the chain can arc between them")


func test_group_draws_an_arc_for_each_living_link() -> void:
	var g := _make_group(3)
	# A 3-member ring has 3 links -> 3 arcs (Line2D) between living members.
	assert_eq(g.arc_count(), g.link_count(),
		"one arc is drawn per living link")
	assert_gt(g.arc_count(), 0, "a multi-member group is visibly linked (arcs > 0)")


func test_members_spread_around_the_group_position() -> void:
	var g := _make_group(3)
	# Members sit at offsets (not all stacked on the group origin).
	var members := g.living_members()
	var distinct := {}
	for m in members:
		distinct[m.position] = true
	assert_gt(distinct.size(), 1, "members are spread at offsets, not stacked")


# --- Link graph updates when a member dies (no dangling links / no dead arcs) --

func test_member_death_drops_it_from_the_link_graph() -> void:
	var g := _make_group(3)
	var members := g.living_members()
	var victim := members[0] as Swarmling
	var victim_id := victim.get_instance_id()
	var links_before := g.link_count()
	# Kill the victim via its Health.died signal (the real on-death path).
	(victim.get_node("Health") as Health).take_damage(100000.0)
	# Let any queued frees / signal handlers settle.
	await get_tree().process_frame
	assert_false(g.graph_has_member(victim_id),
		"the dead member is removed from the link graph (no reference to it)")
	assert_lt(g.link_count(), links_before,
		"its links are dropped (link count decreases) — no dangling links")


func test_arcs_refresh_to_match_links_after_a_death() -> void:
	var g := _make_group(3)
	var victim := g.living_members()[0] as Swarmling
	(victim.get_node("Health") as Health).take_damage(100000.0)
	await get_tree().process_frame
	assert_eq(g.arc_count(), g.link_count(),
		"arcs refresh after a death so there is never an arc to a freed member")


# --- Showcase: Electricity CHAIN clears the cluster; Fire hits one ------------

# Drive the chain walk the way the projectile does in-game: hit, then follow the
# redirected velocity to the targeted member and hit again, until the bolt is spent.
# This mirrors test_projectile_shot_type.gd's chain test (which steps the hops by
# hand because the redirect-then-fly happens over physics frames). `enemies` here is
# the `enemies` group (the clustered Swarmlings); the projectile's CHAIN logic picks
# the nearest not-yet-hit one each hop via ProjectileChain.
func _run_chain(p: Projectile, members: Array, start: Swarmling) -> int:
	p.global_position = start.global_position
	var hit_target: Node2D = start
	while hit_target != null and not p.is_queued_for_deletion():
		p.global_position = hit_target.global_position
		p._try_hit(hit_target)
		if p.is_queued_for_deletion():
			break
		# After the hit, the bolt redirected toward the nearest unhit member; find it
		# (the member whose direction matches the new velocity / is closest ahead).
		hit_target = _nearest_unhit(p, members)
	# Count members that took a hit (HP dropped or death started).
	var struck := 0
	for m in members:
		var h := m.get_node("Health") as Health
		if h.current_health < h.max_health or m.is_dying():
			struck += 1
	return struck


func _nearest_unhit(p: Projectile, members: Array) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for m in members:
		var node := m as Node2D
		if p._hit.has(node.get_instance_id()):
			continue
		var d := p.global_position.distance_to(node.global_position)
		if d <= p.chain_radius and d < best_d:
			best_d = d
			best = node
	return best


func test_electricity_chain_hits_multiple_clustered_members() -> void:
	# 3 swarmlings clustered within chain_radius. A CHAIN bolt hitting one arcs to
	# the others (bounded by max_targets), so Electricity clears the group.
	var g := _make_group(3)
	var members := g.living_members()
	var p := _make_projectile()
	p.setup(_make_spell(ELEC, SpellData.ShotType.CHAIN, 3, 400.0), Vector2.RIGHT)
	var struck := _run_chain(p, members, members[0] as Swarmling)
	assert_gt(struck, 1,
		"an Electricity CHAIN hit on one clustered member arcs to MULTIPLE members")
	assert_lte(struck, 3, "bounded by the number of members / max_targets")


func test_fire_single_hit_affects_only_the_struck_member() -> void:
	var g := _make_group(3)
	var members := g.living_members()
	var p := _make_projectile()
	p.setup(_make_spell(FIRE, SpellData.ShotType.SINGLE, 1, 200.0), Vector2.RIGHT)
	var first := members[0] as Swarmling
	p.global_position = first.global_position
	p._try_hit(first)
	var struck := 0
	for m in members:
		var h := m.get_node("Health") as Health
		if h.current_health < h.max_health or m.is_dying():
			struck += 1
	assert_eq(struck, 1,
		"a SINGLE (Fire) hit affects ONLY the struck member (Fire hits one at a time)")
