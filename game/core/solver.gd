class_name MirrorSolver
extends RefCounted
## Solves levels, finds the next safe tap (hints) and measures difficulty.
##
## With a fixed mirror the game is monotone: taking pieces away only ever frees
## paths (stones crumble and locks open as moves are made), so a group that is
## free stays free and any safe tap keeps the level solvable. A greedy peel
## therefore decides solvability exactly. The turning mirror is not monotone
## (the pairs change after every move, so a careless order can strand a piece),
## so those levels are searched in full, with a memo over (pieces left, moves).

## Search limit for the turning mirror (the generator rejects bigger levels).
const MAX_STATES: int = 40000


## A solution as the list of pieces to tap, or [] if there is none.
static func solve(rules: MirrorRules) -> Array[int]:
	return solve_from(rules, rules.full_mask, 0)


static func solve_from(rules: MirrorRules, present: int, moves: int) -> Array[int]:
	var out: Array[int] = []
	if rules.level.axis != "t":
		var p: int = present
		var m: int = moves
		while p != 0:
			var pick: int = -1
			for gf: Array in rules.groups_now(p, m):
				if bool(gf[1]):
					pick = MirrorRules.bits(int(gf[0]))[0]
					p &= ~int(gf[0])
					break
			if pick < 0:
				return []
			out.append(pick)
			m += 1
		return out
	var memo: Dictionary = {}
	if not _search(rules, present, moves, memo, [0]):
		return []
	var p2: int = present
	var m2: int = moves
	while p2 != 0:
		var step: int = _good_move(rules, p2, m2, memo)
		if step < 0:
			return []
		out.append(step)
		p2 &= ~rules.group(step, p2, m2)
		m2 += 1
	return out


## The next safe tap from this position: a piece whose group can move and
## after which the level can still be cleared. -1 if there is none.
static func hint(rules: MirrorRules, present: int, moves: int) -> int:
	var s: Array[int] = solve_from(rules, present, moves)
	return s[0] if not s.is_empty() else -1


static func _key(present: int, moves: int) -> int:
	return present | (moves << 48)


## Depth-first search over the turning mirror's states. True if solvable.
## counter[0] counts states visited (stops at MAX_STATES).
static func _search(rules: MirrorRules, present: int, moves: int, memo: Dictionary, counter: Array) -> bool:
	if present == 0:
		return true
	var k: int = _key(present, moves)
	if memo.has(k):
		return memo[k]
	counter[0] = int(counter[0]) + 1
	if int(counter[0]) > MAX_STATES:
		memo[k] = false
		return false
	var ok: bool = false
	for gf: Array in rules.groups_now(present, moves):
		if bool(gf[1]) and _search(rules, present & ~int(gf[0]), moves + 1, memo, counter):
			ok = true
			break
	memo[k] = ok
	return ok


static func _good_move(rules: MirrorRules, present: int, moves: int, memo: Dictionary) -> int:
	for gf: Array in rules.groups_now(present, moves):
		if bool(gf[1]):
			var next: int = present & ~int(gf[0])
			if next == 0 or bool(memo.get(_key(next, moves + 1), false)) or _search(rules, next, moves + 1, memo, [0]):
				return MirrorRules.bits(int(gf[0]))[0]
	return -1


## Difficulty measures for a level (from the start position):
##   solvable, moves (taps in a solution), pieces, groups (distinct groups at the
##   start), depth (rounds when every free group is taken each round),
##   blocked (average share of groups that would bump, along a solution),
##   forced (steps where exactly one tap is safe), traps (average number of
##   safe-looking taps that lead to a dead end, turning mirror only),
##   dead_ends (reachable stuck positions, turning mirror only), states,
##   timing (turning mirror: pieces whose fate flips with the mirror, summed
##   along a solution).
static func analyse(rules: MirrorRules) -> Dictionary:
	var out: Dictionary = {"solvable": false, "moves": 0, "pieces": rules.count, "groups": 0, "depth": 0,
		"blocked": 0.0, "forced": 0, "traps": 0.0, "dead_ends": 0, "states": 0, "timing": 0}
	out["groups"] = rules.groups_now(rules.full_mask, 0).size()
	var memo: Dictionary = {}
	if rules.level.axis == "t":
		var counter: Array = [0]
		_explore(rules, rules.full_mask, 0, memo, counter)
		out["states"] = counter[0]
		if int(counter[0]) > MAX_STATES:
			return out
		var dead: int = 0
		for k: Variant in memo:
			if not bool(memo[k]):
				dead += 1
		out["dead_ends"] = dead
	var sol: Array[int] = solve(rules) if rules.level.axis != "t" else _solution_from_memo(rules, memo)
	if sol.is_empty() and rules.count > 0:
		return out
	out["solvable"] = true
	out["moves"] = sol.size()
	# Walk the solution, measuring each position.
	var p: int = rules.full_mask
	var m: int = 0
	var blocked_sum: float = 0.0
	var traps_sum: float = 0.0
	var forced: int = 0
	var timing: int = 0
	for step: int in sol:
		if rules.level.axis == "t":
			timing += _timing_at(rules, p, m)
		var gs: Array = rules.groups_now(p, m)
		var free: int = 0
		var good: int = 0
		for gf: Array in gs:
			if bool(gf[1]):
				free += 1
				var next: int = p & ~int(gf[0])
				if rules.level.axis != "t" or next == 0 or bool(memo.get(_key(next, m + 1), false)):
					good += 1
		blocked_sum += float(gs.size() - free) / float(maxi(1, gs.size()))
		traps_sum += float(free - good)
		if good == 1 and gs.size() > 1:
			forced += 1
		p &= ~rules.group(step, p, m)
		m += 1
	out["blocked"] = blocked_sum / float(maxi(1, sol.size()))
	out["traps"] = traps_sum / float(maxi(1, sol.size()))
	out["forced"] = forced
	out["timing"] = timing
	out["depth"] = _rounds(rules) if rules.level.axis != "t" else int(ceil(sol.size() / 2.0))
	return out


## Turning mirror: how many pieces would change between bumping and moving if
## the mirror were the other way round right now (so waiting a move matters).
static func _timing_at(rules: MirrorRules, present: int, moves: int) -> int:
	var other: Array[String] = rules.level.ops_at(moves + 1)
	var n: int = 0
	for i: int in rules.count:
		if not (present & (1 << i)):
			continue
		var now: bool = rules.group_free(rules.group(i, present, moves), present, moves)
		var then: bool = rules.group_free(rules.group_for(i, present, other), present, moves)
		if now != then:
			n += 1
	return n


## Full exploration of the turning mirror's reachable positions: memo[k] is
## true when the position can still be cleared.
static func _explore(rules: MirrorRules, present: int, moves: int, memo: Dictionary, counter: Array) -> bool:
	if present == 0:
		return true
	var k: int = _key(present, moves)
	if memo.has(k):
		return memo[k]
	counter[0] = int(counter[0]) + 1
	if int(counter[0]) > MAX_STATES:
		return false
	var ok: bool = false
	for gf: Array in rules.groups_now(present, moves):
		if bool(gf[1]):
			if _explore(rules, present & ~int(gf[0]), moves + 1, memo, counter):
				ok = true
	memo[k] = ok
	return ok


static func _solution_from_memo(rules: MirrorRules, memo: Dictionary) -> Array[int]:
	var out: Array[int] = []
	if not bool(memo.get(_key(rules.full_mask, 0), false)):
		return out
	var p: int = rules.full_mask
	var m: int = 0
	while p != 0:
		var step: int = _good_move(rules, p, m, memo)
		if step < 0:
			return []
		out.append(step)
		p &= ~rules.group(step, p, m)
		m += 1
	return out


## Rounds of play when every free group is taken at once: the longest chain of
## "this must go before that".
static func _rounds(rules: MirrorRules) -> int:
	var p: int = rules.full_mask
	var m: int = 0
	var rounds: int = 0
	while p != 0:
		var take: int = 0
		var n: int = 0
		for gf: Array in rules.groups_now(p, m):
			if bool(gf[1]):
				take |= int(gf[0])
				n += 1
		if take == 0:
			return 99
		p &= ~take
		m += n
		rounds += 1
	return rounds
