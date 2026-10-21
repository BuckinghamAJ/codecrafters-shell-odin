package main

import "core:slice"
import "core:fmt"
import "core:strings"

tab :: proc(sb: ^strings.Builder, searchable_cmds: []string, rang_before: bool = false) -> (res: string, ring:bool) {
	current_input := strings.to_string(sb^)

	slice.sort(searchable_cmds)
	cmds := slice.unique(searchable_cmds)

	r := cmd_filter(cmds, current_input, proc(s: string, prefix: string) -> bool {
		return strings.starts_with(s, prefix)
	}, context.temp_allocator)

	switch len(r) {
	case 0:
		return "", true
	case 1:
		return tab_print(current_input, r), false
	}

	if !rang_before do return "", true
	else do return tab_print(current_input, r), false

}

tab_print :: proc(input: string, tab_cmds : []string) -> string{
	if tab_cmds == nil do return ""
	if len(tab_cmds) == 1 do return autocomplete(input, tab_cmds[0])

	return fmt.tprintf("\n%s\n", strings.join(tab_cmds, " ", context.temp_allocator))
}

@(private="file")
autocomplete :: proc(input, cmd: string) -> string {
	start_idx := len(cmd) - (len(cmd) - len(input))
	remaining, _ := strings.substring_from(cmd, start_idx)

	return fmt.tprintf("%s ", remaining)
}

cmd_filter :: proc(s: []$T, prefix: string, f: proc(T, string) -> bool, allocator := context.allocator) -> []T {
	res := make([dynamic]T, allocator)
	for v in s do if f(v, prefix) do append(&res, v)
	return res[:]
}
