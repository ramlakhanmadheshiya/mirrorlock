class_name PlayState
extends RefCounted
## A level being played: which pieces are left, moves, bumps, hearts, hints,
## undo history and stars. Pure logic (no nodes), saved after every tap so a
## half-played level resumes where it was left.

const HEARTS: int = 3

var level: MirrorLevel
var rules: MirrorRules
var present: int = 0
var moves: int = 0
var bounces: int = 0
var hints_used: int = 0
## Hearts bought back after running out (coins or a video).
var extra_hearts: int = 0
## Masks of the groups taken, newest last (for Undo).
var history: Array[int] = []


func _init(l: MirrorLevel) -> void:
	level = l
	rules = MirrorRules.new(l)
	present = rules.full_mask


## The result of tapping piece i:
##   {"ok": bool, "group": Array[int] (the pieces that moved or bumped),
##    "travel", "obstacles", "reason" (for a bump), "complete", "failed"}.
## A tap on a piece that has already gone, or once the level is over, does nothing.
func tap(i: int) -> Dictionary:
	if i < 0 or i >= rules.count or not (present & (1 << i)) or is_complete() or is_failed():
		return {"ok": false, "group": [] as Array[int], "ignored": true}
	var g: int = rules.group(i, present, moves)
	var members: Array[int] = MirrorRules.bits(g)
	if rules.group_free(g, present, moves):
		present &= ~g
		moves += 1
		history.append(g)
		return {"ok": true, "group": members, "complete": is_complete(), "failed": false}
	var why: Dictionary = rules.explain(g, present, moves)
	bounces += 1
	return {"ok": false, "group": members, "travel": why["travel"], "obstacles": why["obstacles"],
		"reason": why["reason"], "complete": false, "failed": is_failed()}


## Puts the last group back. Bumps and hints are not refunded.
func undo() -> int:
	if history.is_empty() or is_complete():
		return 0
	var g: int = history.pop_back()
	present |= g
	moves -= 1
	return g


func can_undo() -> bool:
	return not history.is_empty() and not is_complete() and not is_failed()


func hearts_left() -> int:
	return maxi(0, HEARTS + extra_hearts - bounces)


func is_complete() -> bool:
	return present == 0


func is_failed() -> bool:
	return present != 0 and hearts_left() <= 0


func add_heart() -> void:
	extra_hearts += 1


func pieces_left() -> int:
	return MirrorRules.popcount(present)


## ★★★ with no bumps, ★★ with one, ★ with more. Using a hint caps it at ★★.
func stars() -> int:
	var s: int = Economy.stars_for(bounces)
	if hints_used > 0:
		s = mini(s, 2)
	return s


## The next safe tap (-1 if the position is stuck, e.g. after a bad order on
## the turning mirror; Undo or Restart then).
func hint_piece() -> int:
	return MirrorSolver.hint(rules, present, moves)


func use_hint() -> int:
	var i: int = hint_piece()
	if i >= 0:
		hints_used += 1
	return i


func is_present(i: int) -> bool:
	return i >= 0 and i < rules.count and (present & (1 << i)) != 0


## Which mirror is drawn now ("v", "h", "d" or "k").
func axis_now() -> String:
	return level.axis_at(moves)


func to_dict() -> Dictionary:
	return {"present": present, "moves": moves, "bounces": bounces, "hints": hints_used,
		"extra": extra_hearts, "history": history.duplicate()}


## Restores a saved position (ignored if it doesn't fit this level).
func restore(d: Dictionary) -> void:
	if d.is_empty():
		return
	var p: int = int(d.get("present", rules.full_mask))
	if p & ~rules.full_mask:
		return
	var hist: Array[int] = []
	var seen: int = 0
	for v: Variant in d.get("history", []):
		var g: int = int(v)
		if g & ~rules.full_mask or g & seen or g & p:
			return
		seen |= g
		hist.append(g)
	if (seen | p) != rules.full_mask or hist.size() != int(d.get("moves", -1)):
		return
	present = p
	moves = hist.size()
	history = hist
	bounces = maxi(0, int(d.get("bounces", 0)))
	hints_used = maxi(0, int(d.get("hints", 0)))
	extra_hearts = maxi(0, int(d.get("extra", 0)))
