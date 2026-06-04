## TASK-019 / DD-004 Electricity-chain showcase: the PURE, scene-free link graph a
## SwarmGroup's members are connected by. Members are identified by an opaque key
## (any int — typically a node's instance_id); the graph stores undirected adjacency.
##
## It is deliberately free of any node/scene refs so the link math — building a ring
## or chain, removing a member WITHOUT leaving dangling links, and a bounded,
## repeat-free traversal — is trivially unit-testable and can never silently drift
## (the same discipline as DroneAi / ProjectileChain / ElementMatchup).
##
## The SwarmGroup uses this to (a) decide which living members an arc connects, and
## (b) drop a dead member + all its links on death so no arc is ever drawn to a freed
## node. (The LIVE projectile chain redirects by proximity via ProjectileChain; this
## graph is the tested "link relationship" the ticket asks for.)
class_name SwarmLinks extends RefCounted

## member key -> Dictionary used as a set of neighbor keys ({neighbor: true}).
## Undirected: an edge a-b is stored on BOTH a's and b's neighbor sets, so removing
## a member can drop the back-references and never leave a dangling half-edge.
var _adjacency: Dictionary = {}


## Register `members` and link them in a RING (each member to its two neighbors,
## wrapping the last back to the first). A 0/1-member ring has no links; a 2-member
## ring shares exactly one link. Clears any previous graph.
func build_ring(members: Array) -> void:
	_reset(members)
	var n := members.size()
	if n < 2:
		return
	if n == 2:
		add_link(members[0], members[1])
		return
	for i in range(n):
		add_link(members[i], members[(i + 1) % n])


## Register `members` and link them in an open CHAIN (each consecutive pair; does
## NOT wrap). Clears any previous graph.
func build_chain(members: Array) -> void:
	_reset(members)
	for i in range(members.size() - 1):
		add_link(members[i], members[i + 1])


func _reset(members: Array) -> void:
	_adjacency.clear()
	for m in members:
		if not _adjacency.has(m):
			_adjacency[m] = {}


## Add an undirected link between two registered members (idempotent; a self-link
## or a link to an unknown member is ignored so the graph stays well-formed).
func add_link(a, b) -> void:
	if a == b:
		return
	if not _adjacency.has(a) or not _adjacency.has(b):
		return
	(_adjacency[a] as Dictionary)[b] = true
	(_adjacency[b] as Dictionary)[a] = true


## True if `a` and `b` are directly linked.
func are_linked(a, b) -> bool:
	return _adjacency.has(a) and (_adjacency[a] as Dictionary).has(b)


## The (copied) list of a member's neighbor keys, or [] if it is not a member.
func neighbors(member) -> Array:
	if not _adjacency.has(member):
		return []
	return (_adjacency[member] as Dictionary).keys()


## All registered member keys.
func members() -> Array:
	return _adjacency.keys()


func has_member(member) -> bool:
	return _adjacency.has(member)


## Number of undirected links (each edge counted once).
func link_count() -> int:
	var half := 0
	for m in _adjacency:
		half += (_adjacency[m] as Dictionary).size()
	return half / 2


## Remove `member` AND every link referencing it: delete its own adjacency entry and
## erase the back-reference from each of its former neighbors. Guarantees NO dangling
## links (no surviving member still points at the removed one). Unknown member -> no-op.
func remove(member) -> void:
	if not _adjacency.has(member):
		return
	for neighbor in (_adjacency[member] as Dictionary).keys():
		if _adjacency.has(neighbor):
			(_adjacency[neighbor] as Dictionary).erase(member)
	_adjacency.erase(member)


## Bounded, repeat-free traversal of the links starting at `start`, returning the
## visited member keys (start first), at most `max_targets` of them. A breadth-first
## walk along links: it visits the start, then its neighbors, then theirs, never
## repeating a member and never crossing a removed member (its links are gone). An
## unknown start or max_targets <= 0 yields []. This is the link-driven analogue of
## ProjectileChain's proximity walk — bounded, distinct, no loops.
func chain_order(start, max_targets: int) -> Array:
	var order: Array = []
	if max_targets <= 0 or not _adjacency.has(start):
		return order
	var visited := {start: true}
	var queue: Array = [start]
	while not queue.is_empty() and order.size() < max_targets:
		var current = queue.pop_front()
		order.append(current)
		for neighbor in (_adjacency[current] as Dictionary).keys():
			if not visited.has(neighbor):
				visited[neighbor] = true
				queue.append(neighbor)
	return order
