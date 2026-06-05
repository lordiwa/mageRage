## TASK-037 (M2.1 combat-feel): a tiny object pool that kills the per-shot
## allocation hitch in the shooting path. Instead of instantiate()/queue_free() on
## every cast (which also re-allocated a Line2D + Curve trail per shot — see
## Projectile._ensure_trail), the MagicManager acquires a reusable instance from
## this pool, sets it up, and the instance RETURNS to the pool on expiry/spend
## (hidden + processing off + state reset) for the next shot.
##
## Visuals/behavior are byte-for-byte identical: pooling only changes the lifetime
## of the node, never how it looks or what it does. A pooled Projectile builds its
## trail ONCE (on first _ready) and just clears the trail points on reuse.
##
## Generic by design (not Projectile-specific) so the same pool serves the muzzle
## flash. Pooled instances may implement two optional hooks the pool calls on
## reuse/return:
##   _pool_activate()    — re-enable (show, processing on) when acquired;
##   _pool_deactivate()  — disable (hide, processing off, reset) when released.
## Both are optional; the pool degrades gracefully (visible/process_mode) without.
class_name ProjectilePool extends Node

## The PackedScene this pool instances. Set before acquire() (in code or editor).
@export var scene: PackedScene

## Every instance this pool owns (free + in-flight). Bounded by concurrent demand:
## the pool grows only when no free instance exists, never per shot.
var _all: Array[Node] = []
## The subset of _all currently idle and available for reuse.
var _free: Array[Node] = []


## Acquire a ready-to-use instance: reuse a free one when available, otherwise
## grow the pool by instancing one. The returned node is parented under this pool,
## activated (shown + processing on), and handed back for setup()/positioning.
## Null-safe: a missing scene returns null.
func acquire() -> Node:
	if scene == null:
		return null
	var node: Node
	if _free.is_empty():
		node = scene.instantiate()
		_all.append(node)
		add_child(node)
		_bind_release(node)
	else:
		node = _free.pop_back()
	_activate(node)
	return node


## Return an instance to the pool: deactivate it (hide + processing off + reset)
## and mark it free for the next acquire. Idempotent — releasing an already-free
## or foreign node is a safe no-op (it never double-lists or crashes).
func release(node: Node) -> void:
	if node == null or not _all.has(node):
		return
	if _free.has(node):
		return
	_deactivate(node)
	_free.append(node)


## Total instances owned (free + in-flight) — the pool's high-water size.
func size() -> int:
	return _all.size()


## How many instances are idle and available for reuse right now.
func free_count() -> int:
	return _free.size()


## Tell a pooled node how to return itself to THIS pool when it expires/spends,
## via an optional set_pool(Callable) hook. A node without the hook is still
## poolable — the caller (or the node's own _despawn) must call release().
func _bind_release(node: Node) -> void:
	if node.has_method("set_pool"):
		node.set_pool(release)


## Activate an acquired instance: prefer the node's own _pool_activate() hook,
## else fall back to the generic show + re-enable processing.
func _activate(node: Node) -> void:
	if node.has_method("_pool_activate"):
		node._pool_activate()
		return
	if node is CanvasItem:
		(node as CanvasItem).visible = true
	node.process_mode = Node.PROCESS_MODE_INHERIT


## Deactivate a released instance: prefer the node's own _pool_deactivate() hook
## (which also resets per-shot state), else fall back to hide + disable processing.
func _deactivate(node: Node) -> void:
	if node.has_method("_pool_deactivate"):
		node._pool_deactivate()
		return
	if node is CanvasItem:
		(node as CanvasItem).visible = false
	node.process_mode = Node.PROCESS_MODE_DISABLED
