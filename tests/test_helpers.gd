extends RefCounted
## Test accumulator + shared utilities for the headless harness (tests/run_tests.gd).
## NEVER use assert() in tests: it aborts the whole process and is stripped from release
## builds. Record every check through expect()/expect_eq()/expect_near() instead.

var passed: int = 0
var failed: int = 0
var failures: Array[String] = []
var _ctx: String = ""

func ctx(name: String) -> void:
	_ctx = name

func expect(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		failures.append("[%s] %s" % [_ctx, msg])

func expect_eq(a, b, msg: String) -> void:
	expect(a == b, "%s (got %s, want %s)" % [msg, str(a), str(b)])

func expect_near(a: float, b: float, msg: String, eps: float = 0.001) -> void:
	expect(absf(a - b) <= eps, "%s (got %f, want %f +/- %f)" % [msg, a, b, eps])

## Pin the survival meters high so a long test run does not die of an unrelated cause.
func keep_alive(g) -> void:
	g.meters["Calories"] = 80.0
	g.meters["Hydration"] = 80.0
	g.meters["Blood"] = 100.0
	g.meters["Warmth"] = 80.0
	g.meters["Energy"] = 80.0
	g.meters["Sleep"] = 80.0
	g.meters["Immune"] = 80.0
	g.meters["Mental"] = 80.0

## Advance the sim by whole days. Death does not stop the day roll or the event director,
## so alive=false is fine for schedule/director assertions; pass alive=true when the run
## must keep the character alive (e.g. research accrual).
func advance_days(g, n: int, alive: bool = true) -> void:
	for i in range(n):
		if alive:
			keep_alive(g)
		g.advance_time(1440)
