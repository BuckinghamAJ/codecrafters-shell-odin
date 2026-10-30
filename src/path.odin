package main

import "core:log"
import "core:fmt"
import "core:strings"
import "core:os"

@(require_results)
path_search :: proc(command: string) -> (path: string, found: bool) {
	path_env := os.get_env("PATH", context.temp_allocator)

	for dir in strings.split_iterator(&path_env, ":") {
		full, _ := os.join_path({dir, command}, context.temp_allocator)
		fi, err := os.stat(full, context.temp_allocator)
		if err != nil do continue
		if fi.type == .Regular && (fi.mode & os.Permissions_Execute_All) != {} {
			return full, true
		}
	}

	return "", false
}

get_files_in_cwd :: proc(allocator := context.allocator) -> (files: []string, err: Error) {
	f := make([dynamic]string, allocator)
	cwd := os.get_working_directory(allocator) or_return
	all := os.read_all_directory_by_path(cwd, allocator) or_return

	for fi in all {
		if fi.type == .Regular do append(&f, strings.clone(fi.name, allocator))
	}

	return f[:], nil
}

get_all_path_cmd_names :: proc(allocator := context.allocator) -> (names: []string) {
	res := make([dynamic]string, allocator)
	path_env := os.get_env("PATH", allocator)

	for dir in strings.split_iterator(&path_env, ":")  {
		info, err := os.read_all_directory_by_path(dir, allocator)
		if err != nil {
			log.error(fmt.tprintf("Error reading directory %s: %v", dir, err))
			continue
		}

		for fi in info {
			if fi.type == .Regular || fi.type == .Symlink do append(&res, strings.clone(fi.name, allocator ))
		}

	}

	return res[:]
}
