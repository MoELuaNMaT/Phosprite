extends RefCounted

## Base class for Phosprite P0 regression suites.
##
## Subclasses implement `test_*` methods and record problems through the
## `check_*` helpers. tests/runner.gd injects the shared `failures` array and
## reports a suite as failed when it is non-empty.
##
## Unit suites run without Main.tscn and use plain data objects. Integration
## suites load the editor scene and therefore need frame awaits and the tree.

## Injected by tests/runner.gd; collects assertion messages for the active test.
var failures: Array[String] = []

## Counts the checks recorded for the active test. tests/runner.gd reads it to
## tell an executed test from a method body that was aborted by a runtime error:
## both return the same value to the caller, so the count is the only difference.
var assertions := 0
## Injected by tests/runner.gd. Suites are RefCounted, so this is how an
## integration test reaches `process_frame` and the scene root.
var tree: SceneTree = null


## Removes any previously recorded failures. Called by the runner before each test.
func reset() -> void:
	failures.clear()
	assertions = 0


## Records [param message] as a failure of the currently running test.
func fail(message: String) -> void:
	failures.append(message)


## Records that a check ran, for the counter read by tests/runner.gd.
func _record_check() -> void:
	assertions += 1


## Fails unless [param condition] is truthy.
func check_true(condition: bool, message: String) -> void:
	_record_check()
	if not condition:
		fail(message)


## Fails unless [param actual] equals [param expected].
func check_eq(actual: Variant, expected: Variant, message: String) -> void:
	_record_check()
	if actual != expected:
		fail("%s (expected %s, got %s)" % [message, var_to_str(expected), var_to_str(actual)])


## Fails unless [param actual] differs from [param unexpected].
func check_ne(actual: Variant, unexpected: Variant, message: String) -> void:
	_record_check()
	if actual == unexpected:
		fail("%s (value should not be %s)" % [message, var_to_str(unexpected)])


## Fails unless [param haystack] contains [param needle].
func check_has(haystack: Variant, needle: Variant, message: String) -> void:
	_record_check()
	if not (needle in haystack):
		fail("%s (missing %s)" % [message, var_to_str(needle)])


## Fails unless [param path] points at an existing file.
func check_file_exists(path: String, message: String) -> void:
	_record_check()
	if not FileAccess.file_exists(path):
		fail("%s (missing file %s)" % [message, path])


## Fails unless both values are within [param epsilon] of each other.
func check_almost_eq(actual: float, expected: float, epsilon: float, message: String) -> void:
	_record_check()
	if absf(actual - expected) > epsilon:
		fail("%s (expected %f ± %f, got %f)" % [message, expected, epsilon, actual])
