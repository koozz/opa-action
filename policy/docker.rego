package docker

denylist = [
	# "apk", # I need this one :)
	"apt",
	"pip",
	# "curl", # I need this one :)
	"wget",
]

deny[msg] {
	input[i].Cmd == "run"
	val := input[i].Value
	contains(val[_], denylist[_])

	msg = sprintf("unallowed commands found %s", [val])
}
