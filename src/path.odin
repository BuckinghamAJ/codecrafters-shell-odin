package main

import "core:log"
import "core:fmt"
import "core:strings"
import "core:os"

@(require_results)
path_search :: proc(command: string) -> (path: string, found: bool) {
	path_env := os.get_env("PATH", context.temp_allocator)
	paths := strings.split(path_env, ":")

	for _path in paths {
		info, err := os.read_all_directory_by_path(_path, context.temp_allocator)
		if err != nil {
			// TODO: Handle error properly instead of panicking
			log.error(fmt.tprintf("Error reading directory %s: %v", _path, err))
		}

		for fi in info {
			if fi.name == command && (fi.type == .Regular || fi.type == .Symlink) {
				if (fi.mode & os.Permissions_Execute_All) == {} do break

				path, err = os.join_path({_path, command}, context.temp_allocator)
				if err != nil {
					panic(fmt.tprintf("Error joining path %s and command %s: %v", _path, command, err))
				}

				return path, true
			}
		}

	}

	return "", false
}
