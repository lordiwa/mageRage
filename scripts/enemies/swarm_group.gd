## TASK-019 SwarmGroup (Enjambre vinculado) — a cluster of N linked Swarmlings that
## makes the ELECTRICITY identity LEGIBLE (DD-004 anti-dominance): the members are
## visually LINKED by electricity-tinted arcs, and an Electricity CHAIN bolt arcs
## between them to clear the group efficiently, while Fire/Ice hit one at a time.
##
## Responsibilities:
##   - spawn `member_count` Swarmlings at offsets around its position (a loose cluster);
##   - build a link graph over them (SwarmLinks — a ring) and draw a Line2D arc for
##     each LIVING link;
##   - when a member dies, drop it from the graph and REFRESH the arcs so there is
##     never a dangling link or an arc to a freed member (no crash, no ghost arc).
##
## The arcs are placeholder visuals (electricity-tinted Line2Ds). The actual chain
## damage is the existing TASK-022 Projectile CHAIN behavior (proximity arc via
## ProjectileChain over the `enemies` group), which already reaches the clustered
## members; SwarmLinks is the tested link relationship that drives the arcs +
## the link-update-on-death guarantee.
class_name SwarmGroup extends Node2D

## Placeholder member scene. Optional: if unassigned (bare-node tests), the group
## builds plain Swarmlings with a Health + ColorRect child in code instead.
@export var swarmling_scene: PackedScene

## How many members the cluster spawns.
@export var member_count: int = 3

## Radius (px) of the ring the members are placed on around the group origin.
@export var spawn_radius: float = 40.0

## Per-member HP (low — the swarm's threat is numbers, not single-shot power).
@export var member_health: float = 20.0

## Member armor element. FIRE by default so Electricity is BOTH the 1.5x weak point
## AND the chaining element (the showcase). @export so an encounter can vary it.
@export var member_armor: SpellData.Element = SpellData.Element.FIRE

## Electricity-tinted arc color (arc yellow, matching the element color language).
const ARC_COLOR := Color(0.95, 0.85, 0.25, 0.7)
const ARC_WIDTH := 2.0

## The link graph over the living members, keyed by each member's instance_id.
var _links := SwarmLinks.new()

## instance_id -> Swarmling node, for the living members.
var _members: Dictionary = {}

## Container for the arc Line2Ds (drawn under the members). Lazily created.
var _arcs_root: Node2D


func _ready() -> void:
	_arcs_root = Node2D.new()
	_arcs_root.name = "Arcs"
	add_child(_arcs_root)
	_spawn_members()
	_build_links()
	_refresh_arcs()


## Spawn `member_count` Swarmlings on a ring around the group origin. Each member is
## wired to report its death so the group can drop it from the link graph.
func _spawn_members() -> void:
	for i in range(member_count):
		var member := _make_member()
		var angle := TAU * float(i) / float(maxi(member_count, 1))
		member.position = Vector2(cos(angle), sin(angle)) * spawn_radius
		member.armor_type = member_armor
		add_child(member)
		var id := member.get_instance_id()
		_members[id] = member
		# Drop the member from the graph + refresh arcs the moment it dies. Bind the
		# id so the handler doesn't have to touch the (possibly freeing) node.
		var health := member.get_node_or_null("Health") as Health
		if health != null:
			health.max_health = member_health
			health.died.connect(_on_member_died.bind(id))
		# Belt-and-suspenders: also drop it if it leaves the tree by any other path.
		member.tree_exited.connect(_on_member_exited.bind(id))


## Build a plain Swarmling node with a Health + ColorRect child (no .tscn) when no
## scene is assigned; otherwise instantiate the assigned scene. Keeps bare-node tests
## working and the encounter authorable from a scene.
func _make_member() -> Swarmling:
	if swarmling_scene != null:
		return swarmling_scene.instantiate() as Swarmling
	var s := Swarmling.new()
	var health := Health.new()
	health.name = "Health"
	health.max_health = member_health
	s.add_child(health)
	var sprite := ColorRect.new()
	sprite.name = "Sprite"
	sprite.offset_left = -10.0
	sprite.offset_top = -10.0
	sprite.offset_right = 10.0
	sprite.offset_bottom = 10.0
	s.add_child(sprite)
	return s


## Link the living members in a RING (each to its two neighbors). A ring keeps every
## member reachable from any hit member along the links (good chain showcase) while
## staying a small, legible adjacency.
func _build_links() -> void:
	_links.build_ring(_members.keys())


## Redraw one Line2D arc per LIVING link. Clears the old arcs first so a refresh after
## a death never leaves an arc to a freed member. Each undirected link is drawn once.
func _refresh_arcs() -> void:
	if _arcs_root == null:
		return
	for child in _arcs_root.get_children():
		child.queue_free()
	var drawn := {}
	for id in _members.keys():
		var a := _members[id] as Swarmling
		if a == null or not is_instance_valid(a):
			continue
		for nid in _links.neighbors(id):
			# Draw each undirected edge once (skip the mirror).
			var key := _edge_key(id, nid)
			if drawn.has(key):
				continue
			var b := _members.get(nid) as Swarmling
			if b == null or not is_instance_valid(b):
				continue
			drawn[key] = true
			var line := Line2D.new()
			line.width = ARC_WIDTH
			line.default_color = ARC_COLOR
			line.add_point(a.position)
			line.add_point(b.position)
			_arcs_root.add_child(line)


func _edge_key(a: int, b: int) -> String:
	return "%d-%d" % [mini(a, b), maxi(a, b)]


## A member died: drop it from the graph + members map and refresh the arcs so no
## dangling link / arc to a freed member survives. Idempotent (a re-emitted died or a
## following tree_exited for the same id is a no-op).
func _on_member_died(id: int) -> void:
	if not _members.has(id):
		return
	_links.remove(id)
	_members.erase(id)
	_refresh_arcs()


## Same drop path for a member that leaves the tree without dying (defensive).
func _on_member_exited(id: int) -> void:
	_on_member_died(id)


# --- Query seams (used by tests / an encounter coordinator) -------------------

## The living member nodes.
func living_members() -> Array:
	var out: Array = []
	for id in _members.keys():
		var m: Variant = _members[id]
		if m != null and is_instance_valid(m):
			out.append(m)
	return out

## Number of links in the current (living) graph.
func link_count() -> int:
	return _links.link_count()

## Number of arc Line2Ds currently drawn.
func arc_count() -> int:
	if _arcs_root == null:
		return 0
	var n := 0
	for child in _arcs_root.get_children():
		if child is Line2D and not child.is_queued_for_deletion():
			n += 1
	return n

## True while the link graph still references `id`.
func graph_has_member(id: int) -> bool:
	return _links.has_member(id)
