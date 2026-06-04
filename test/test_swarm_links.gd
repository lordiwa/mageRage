## TASK-019 unit tests for the PURE link-graph helper (no scene).
##
## DD-004 Electricity-chain showcase: a SwarmGroup's members are connected in a
## small adjacency graph. SwarmLinks is the scene-free model of that graph:
##   - build links for N members (a ring or a chain);
##   - `remove(member)` deletes a node AND every link referencing it (NO dangling
##     links / no link to a removed member);
##   - `chain_order(start, max_targets)` walks the links from a starting member,
##     returning DISTINCT members only, bounded by max_targets, never repeating.
##
## This is the tested "link graph" the ticket asks for and it drives the visual
## arcs + the link-update-on-death guarantee. (The live projectile chain uses
## proximity nearest_index, already covered in test_projectile_chain.gd.)
extends GutTest


func test_build_ring_links_each_member_to_two_neighbors() -> void:
	var links := SwarmLinks.new()
	links.build_ring([1, 2, 3, 4])
	assert_eq(links.members().size(), 4, "all members are registered")
	# In a ring each member has exactly two neighbors.
	assert_eq(links.neighbors(1).size(), 2, "ring member has two neighbors")
	assert_true(links.are_linked(1, 2), "1-2 linked")
	assert_true(links.are_linked(4, 1), "ring wraps: 4-1 linked")
	assert_false(links.are_linked(1, 3), "non-adjacent ring members are not linked")


func test_build_ring_of_two_links_them_once() -> void:
	var links := SwarmLinks.new()
	links.build_ring([1, 2])
	assert_true(links.are_linked(1, 2), "a 2-member ring links the pair")
	assert_eq(links.link_count(), 1, "two members share exactly one link (no double)")


func test_build_chain_links_consecutive_members_only() -> void:
	var links := SwarmLinks.new()
	links.build_chain([1, 2, 3])
	assert_true(links.are_linked(1, 2), "consecutive 1-2 linked")
	assert_true(links.are_linked(2, 3), "consecutive 2-3 linked")
	assert_false(links.are_linked(1, 3), "a chain does NOT wrap (1-3 not linked)")
	assert_eq(links.link_count(), 2, "a 3-member chain has 2 links")


func test_single_member_graph_has_no_links() -> void:
	var links := SwarmLinks.new()
	links.build_ring([7])
	assert_eq(links.members().size(), 1, "the lone member is registered")
	assert_eq(links.link_count(), 0, "a single member has no links")
	assert_eq(links.neighbors(7).size(), 0, "a lone member has no neighbors")


func test_empty_graph_is_safe() -> void:
	var links := SwarmLinks.new()
	links.build_ring([])
	assert_eq(links.members().size(), 0, "empty build -> no members")
	assert_eq(links.link_count(), 0, "empty build -> no links")
	assert_eq(links.chain_order(123, 3), [], "chain_order on an empty graph is empty")


# --- remove(): drops the node AND every link referencing it (no dangling) -----

func test_remove_deletes_member_and_all_its_links() -> void:
	var links := SwarmLinks.new()
	links.build_ring([1, 2, 3, 4])
	var before := links.link_count()
	links.remove(2)
	assert_false(links.has_member(2), "the removed member is gone from the graph")
	assert_false(links.are_linked(1, 2), "no dangling link from a former neighbor (1)")
	assert_false(links.are_linked(2, 3), "no dangling link to the removed member (3)")
	assert_false(links.neighbors(1).has(2),
		"a surviving neighbor no longer references the removed member")
	assert_lt(links.link_count(), before,
		"removing a member drops its links (link count decreases)")


func test_remove_unknown_member_is_safe() -> void:
	var links := SwarmLinks.new()
	links.build_ring([1, 2, 3])
	var before := links.link_count()
	links.remove(999)   # not in the graph
	assert_eq(links.link_count(), before, "removing an unknown member changes nothing")
	assert_eq(links.members().size(), 3, "members unchanged")


func test_remove_last_member_empties_graph() -> void:
	var links := SwarmLinks.new()
	links.build_chain([1, 2])
	links.remove(1)
	links.remove(2)
	assert_eq(links.members().size(), 0, "removing all members empties the graph")
	assert_eq(links.link_count(), 0, "no links remain")


# --- chain_order(): bounded, distinct traversal along the links ---------------

func test_chain_order_walks_links_distinct_and_bounded() -> void:
	# Chain 1-2-3-4; from 1 with max 3 -> visits 1,2,3 (bounded), no 4.
	var links := SwarmLinks.new()
	links.build_chain([1, 2, 3, 4])
	var order := links.chain_order(1, 3)
	assert_eq(order.size(), 3, "bounded by max_targets (3)")
	assert_eq(order[0], 1, "the traversal starts at the hit member")
	# No repeats.
	var seen := {}
	for m in order:
		assert_false(seen.has(m), "each member appears at most once")
		seen[m] = true
	# Every visited member is reachable along links from the start.
	assert_true(order.has(2) and order.has(3), "walks to linked neighbors")
	assert_false(order.has(4), "stops at the max_targets bound (4 not reached)")


func test_chain_order_does_not_exceed_living_members() -> void:
	var links := SwarmLinks.new()
	links.build_ring([1, 2, 3])
	# max_targets larger than the graph: visits every member once, no repeats.
	var order := links.chain_order(1, 10)
	assert_eq(order.size(), 3, "never visits more members than exist")
	var seen := {}
	for m in order:
		seen[m] = true
	assert_eq(seen.size(), 3, "all three distinct members visited, none twice")


func test_chain_order_from_unknown_start_is_empty() -> void:
	var links := SwarmLinks.new()
	links.build_ring([1, 2, 3])
	assert_eq(links.chain_order(999, 3), [],
		"a start that is not a member yields an empty traversal")


func test_chain_order_after_removal_skips_dead_member() -> void:
	# Chain 1-2-3-4; remove 2 (the bridge). From 1 the only reachable member is 1
	# itself (its link to 2 was deleted), so the order can't cross the gap.
	var links := SwarmLinks.new()
	links.build_chain([1, 2, 3, 4])
	links.remove(2)
	var order := links.chain_order(1, 4)
	assert_false(order.has(2), "a removed member is never traversed (no chain to dead)")
	assert_eq(order, [1], "with the bridge gone, 1 reaches only itself")


func test_chain_order_zero_max_targets_is_empty() -> void:
	var links := SwarmLinks.new()
	links.build_ring([1, 2, 3])
	assert_eq(links.chain_order(1, 0), [], "max_targets 0 visits nobody")
