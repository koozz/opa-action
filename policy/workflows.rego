package workflows

deny[msg] {
	not input.name
	msg = sprintf("Missing 'name' on: %s", [input])
}
