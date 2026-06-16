extends Node

var failures: Array[String] = []
var current_test_name: String = ""

func before_each() -> void:
	pass

func after_each() -> void:
	var sb = get_node_or_null("/root/SignalBus")
	if sb:
		for sig_info in sb.get_signal_list():
			var signal_name = sig_info.name
			var signal_obj = sb.get(signal_name)
			if signal_obj is Signal:
				for conn in signal_obj.get_connections():
					signal_obj.disconnect(conn.callable)

func assert_true(val: bool, msg: String = "") -> void:
	if not val:
		_fail(msg if msg != "" else "Expected true, got false")

func assert_false(val: bool, msg: String = "") -> void:
	if val:
		_fail(msg if msg != "" else "Expected false, got true")

func assert_eq(actual, expected, msg: String = "") -> void:
	var act_val = actual
	var exp_val = expected
	if typeof(actual) == TYPE_STRING_NAME:
		act_val = String(actual)
	if typeof(expected) == TYPE_STRING_NAME:
		exp_val = String(expected)
	if typeof(act_val) != typeof(exp_val) or act_val != exp_val:
		var err_msg = "Expected: %s (%s), Actual: %s (%s)" % [str(expected), type_string(typeof(expected)), str(actual), type_string(typeof(actual))]
		_fail(msg if msg != "" else err_msg)

func assert_almost_eq(actual: float, expected: float, margin: float, msg: String = "") -> void:
	if abs(actual - expected) > margin:
		var err_msg = "Expected: %f within %f margin of %f, Actual: %f" % [expected, margin, expected, actual]
		_fail(msg if msg != "" else err_msg)

func assert_null(val, msg: String = "") -> void:
	if val != null:
		_fail(msg if msg != "" else "Expected null, got: " + str(val))

func assert_not_null(val, msg: String = "") -> void:
	if val == null:
		_fail(msg if msg != "" else "Expected non-null value")

func assert_gt(actual, expected, msg: String = "") -> void:
	if not (actual > expected):
		_fail(msg if msg != "" else "Expected %s > %s" % [str(actual), str(expected)])

func assert_lt(actual, expected, msg: String = "") -> void:
	if not (actual < expected):
		_fail(msg if msg != "" else "Expected %s < %s" % [str(actual), str(expected)])

func _fail(msg: String) -> void:
	var prefix = ""
	if current_test_name != "":
		prefix = "[%s] " % current_test_name
	failures.append(prefix + msg)
