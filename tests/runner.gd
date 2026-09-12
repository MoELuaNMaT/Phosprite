extends SceneTree

## Phosprite P0 headless regression runner.
##
## Usage:
##   godot --headless --path . --script res://tests/runner.gd -- --phosprite-test-runner
##
## The trailing `-- --phosprite-test-runner` flag tells Global._ready() that it is
## running under the regression runner and must not initialize the UI project.
##
## Discovers test scripts under tests/unit and tests/integration, runs every
## method whose name starts with "test_", and exits with a non-zero code when
## any assertion fails.
##
## Unit suites run with only autoloads present. Integration suites run after the
## runner instantiates Main.tscn, because Project/OpenSave reach into UI nodes.

const UNIT_DIR := "res://tests/unit"
const INTEGRATION_DIR := "res://tests/integration"
const EDITOR_SCENE := "res://src/Main.tscn"

# Collected assertion failures for the currently running test file.
var _failures: Array[String] = []
# Name of the test script currently executing, used in failure messages.
var _current_file := ""
# Running totals reported at the end of the run.
var _total_tests := 0
var _total_failures := 0
var _failed_files: Array[String] = []


## Entry point. Autoload singletons are not registered yet while SceneTree._init()
## runs, so suites that transitively reference `Global` would fail to compile.
## Defer the actual run to the first process frame, when autoloads exist.
func _init() -> void:
	_run_all.call_deferred()


## Runs every discovered suite and quits with the aggregate result.
##
## Unit suites run first, with no Main.tscn loaded. Integration suites then run
## against a live editor scene, because Project and OpenSave reach into UI nodes
## (Global.tabs, Global.canvas, Themes) and cannot function without one.
func _run_all() -> void:
	print("=== Phosprite P0 regression runner ===")
	var suites := _discover_suites()
	if suites.is_empty():
		print("No test suites found.")
		quit(1)
		return

	var unit_suites := suites.filter(func(p: String): return p.begins_with(UNIT_DIR))
	var integration_suites := suites.filter(func(p: String): return p.begins_with(INTEGRATION_DIR))

	for script_path: String in unit_suites:
		await _run_suite(script_path)

	if not integration_suites.is_empty():
		var scene := await _load_editor_scene()
		for script_path: String in integration_suites:
			await _run_suite(script_path)
		if scene != null:
			scene.queue_free()
			await process_frame

	print("")
	print("=== Summary ===")
	print("Tests: %d, Failures: %d" % [_total_tests, _total_failures])
	if _total_failures > 0:
		print("FAILED suites:")
		for f: String in _failed_files:
			print("  - ", f)
		print("RESULT: FAIL")
		quit(1)
	else:
		print("RESULT: PASS")
		quit(0)


## Instantiates Main.tscn so integration suites have real editor nodes.
## Returns the added scene, or null when it could not be created.
func _load_editor_scene() -> Node:
	var packed: PackedScene = load(EDITOR_SCENE)
	if packed == null:
		print("WARNING: could not load %s; integration suites will fail." % EDITOR_SCENE)
		return null
	var scene: Node = packed.instantiate()

	var global: Node = root.get_node_or_null("Global")
	if global == null:
		print("WARNING: Global autoload missing; integration suites will fail.")
		root.add_child(scene)
		current_scene = scene
		return scene

	# The editor's UI scripts and Main._ready() read Global.current_project, so the
	# project must exist before the scene's _ready cascade runs. Bind the UI and
	# create the project while the scene is still detached, then hand the scene to
	# the engine through change_scene_to_node(): it installs the scene as
	# current_scene before the node enters the tree, which is what Tabs.gd resolves
	# against, and its _ready cascade then appends the first layer and frame.
	global.call("bind_ui_nodes", scene)
	global.call("bootstrap_first_project")
	change_scene_to_node(scene)

	# Let the editor settle: the scene's own _ready cascade plus any deferred
	# autoload callbacks that react to the freshly created project.
	await process_frame
	await process_frame
	return scene


## Returns sorted paths of every .gd test script under the unit and integration dirs.
func _discover_suites() -> Array[String]:
	var suites: Array[String] = []
	for dir: String in [UNIT_DIR, INTEGRATION_DIR]:
		_collect_scripts(dir, suites)
	suites.sort()
	return suites


## Recursively appends .gd files under [param dir] to [param out].
func _collect_scripts(dir: String, out: Array[String]) -> void:
	var da := DirAccess.open(dir)
	if da == null:
		return
	da.list_dir_begin()
	var name := da.get_next()
	while name != "":
		if name.begins_with("."):
			name = da.get_next()
			continue
		var path := dir.path_join(name)
		if da.current_is_dir():
			_collect_scripts(path, out)
		elif name.ends_with(".gd"):
			out.append(path)
		name = da.get_next()
	da.list_dir_end()


## Instantiates [param script_path], invokes every test_ method on it, and reports.
## Tests may be coroutines (they `await get_tree().process_frame`); the returned
## state is awaited so assertions made after an await still count.
func _run_suite(script_path: String) -> void:
	var script: GDScript = load(script_path)
	if script == null:
		push_error("Failed to load test script: %s" % script_path)
		_total_failures += 1
		_failed_files.append(script_path)
		return

	var suite: Object = script.new()
	if suite == null:
		push_error("Failed to instantiate test script: %s" % script_path)
		_total_failures += 1
		_failed_files.append(script_path)
		return

	# Suites are RefCounted, so they cannot call get_tree(); hand them the tree
	# they need for scene loading and frame awaits.
	suite.set("tree", self)
	_current_file = script_path
	_failures.clear()
	var suite_failures := 0
	var method_names: Array[String] = []
	for m: Dictionary in suite.get_method_list():
		var method_name: String = m["name"]
		if method_name.begins_with("test_") and not method_names.has(method_name):
			method_names.append(method_name)
	method_names.sort()

	for method_name: String in method_names:
		_total_tests += 1
		# Reset per-test scratch space; suites expose it as `failures`.
		if suite.has_method("reset"):
			suite.call("reset")
		suite.set("failures", _failures)
		var result: Variant = suite.call(method_name)
		# The call hands back a GDScriptFunctionState for a test that suspends, not a
		# Signal, so testing for a Signal here cut every coroutine test off at its
		# first await and silently discarded the assertions that followed. Awaiting
		# a plain value returns it unchanged, so every result is awaited.
		await result
		# A method body aborted by a runtime error returns the same value as a
		# passing one, so a test that dies before its first check would be
		# reported as ok while nothing was ever verified.
		if int(suite.get("assertions")) == 0:
			_failures.append("the test body reached no check, so nothing was verified")
		if _failures.is_empty():
			print("  ok   %s::%s" % [script_path.get_file(), method_name])
		else:
			suite_failures += _failures.size()
			_total_failures += _failures.size()
			print("  FAIL %s::%s" % [script_path.get_file(), method_name])
			for f: String in _failures:
				print("       ", f)
			_failures.clear()

	if suite_failures > 0:
		_failed_files.append(script_path)

	# Suites may hold Node/Resource references that need explicit cleanup.
	if suite.has_method("teardown"):
		suite.call("teardown")
	suite = null
