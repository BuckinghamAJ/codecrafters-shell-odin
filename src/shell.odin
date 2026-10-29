package main

import "core:log"
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

	log.debug(r)

	common := []string{slice.reduce(r, "", proc(acc: string, s: string) -> string {
		if acc == "" do return s
		i := 0
		for i < len(acc) && i < len(s) && acc[i] == s[i] do i+= 1
		return s[:i]
	})}

	log.debug(common)

	if common[0] != "" do return tab_print(current_input, common, true), false

	if !rang_before do return "", true
	else do return tab_print(current_input, r), false

}

tab_print :: proc(input: string, tab_cmds : []string, prefix : bool = false) -> string{
	if tab_cmds == nil do return ""
	if len(tab_cmds) == 1 do return autocomplete(input, tab_cmds[0], !prefix)

	return fmt.tprintf("\n%s\n", strings.join(tab_cmds, " ", context.temp_allocator))
}

@(private="file")
autocomplete :: proc(input, cmd: string, add_space: bool = false) -> string {
	start_idx := len(cmd) - (len(cmd) - len(input))
	remaining, _ := strings.substring_from(cmd, start_idx)

	if !add_space do return fmt.tprintf("%s", remaining)

	return fmt.tprintf("%s ", remaining)
}

cmd_filter :: proc(s: []$T, prefix: string, f: proc(T, string) -> bool, allocator := context.allocator) -> []T {
	res := make([dynamic]T, allocator)
	for v in s do if f(v, prefix) do append(&res, v)
	return res[:]
}
