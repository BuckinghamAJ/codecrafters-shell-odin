package main

import "core:log"
import "core:slice"
import "core:fmt"
import "core:strings"

@(require_results)
build_exec_completions :: proc(allocator := context.allocator) -> []string {
	builtin_keys, _ := slice.map_keys(builtins, context.temp_allocator)
	all, _ := slice.concatenate([][]string{builtin_keys, get_all_path_cmd_names(allocator)}, allocator)

	slice.sort(all)
	return slice.unique(all)
}

@(require_results)
build_file_completions :: proc(allocator := context.allocator) ->  []string {
	res, err := get_files_in_cwd(allocator)
	if err != nil {
		panic(fmt.tprint("Should not fail getting files in cwd, %v", err))
	}
	slice.sort(res)

	return res
}

tab :: proc(current_input: string, cmds: []string, rang_before: bool = false) -> (res: string, ring:bool) {
	log.debug(cmds)

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

	if common[0] == current_input {
		if !rang_before do return "", true
		else do return tab_print(current_input, r), false
	}

	return tab_print(current_input, common, true), false
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
