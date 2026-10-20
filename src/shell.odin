package main

import "core:fmt"
import "core:strings"

tab :: proc(sb: ^strings.Builder, searchable_cmds: map[string]bool) -> string {
	current_input := strings.to_string(sb^)

	for builtin_cmd in searchable_cmds {
		// TODO: Not work with multiple matches
		if strings.starts_with(builtin_cmd, current_input) {
			start_idx := len(builtin_cmd) - (len(builtin_cmd) - len(current_input))

			if remaining, ok := strings.substring_from(builtin_cmd, start_idx); ok {
				return fmt.tprintf("%s ", remaining)
			}
			else do return ""
		}
	}

	return ""
}
