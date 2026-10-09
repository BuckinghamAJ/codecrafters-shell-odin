#+feature dynamic-literals
package main

import "core:fmt"
import "core:os"

execute_command :: proc(command: string, params: []string) -> (should_exit: bool) {
	switch command {
	case "exit":
		return true
	case "echo":
		for p, idx in params {
			fmt.printf(p)
			if len(params) - 1 != idx do fmt.print(" ")
		}
		fmt.println()
	case "pwd":
		cwd, err := os.get_working_directory(context.temp_allocator)
		if err != nil {
			display_error(Exception{err, fmt.tprintf("Error getting working directory: %v", err)})
			break
		}
		fmt.println(cwd)
	case "cd":
		if len(params) == 0 {
			break
		}

		param := params[0]

		err := cd(param)
		if err != Shell_Error.None{
			display_error(Exception{err, fmt.tprintf("cd: %s: No such file or directory", param)})
			break
		}
	case "type":
		if len(params) == 0 {
			break
		}
		param := params[0]

		if _, exists := builtins[param]; exists {
			fmt.println(fmt.tprintf("%s is a shell builtin", param))
			break
		}

		if cmd_path, ok := path_search(param); ok {
			fmt.println(fmt.tprintf("%s is %s", param, cmd_path))
			break
		}

		fmt.println(fmt.tprintf("%s: not found", param))
	case:
		if cmd_path, ok := path_search(command); ok {
			execute(command, params)
			break
		}

		display_error(Exception {
			Shell_Error.Invalid_Command,
			fmt.tprintf("%s: command not found", command),
		})
	}
	return false
}


execute :: proc(command: string, params: []string) {

	process_cmd := [dynamic]string{command}
	defer delete(process_cmd)
	append(&process_cmd, ..params)

	process_desc := os.Process_Desc{
		working_dir = "",
		command = process_cmd[:],
		env = nil,
		stdin = nil,
		stdout = nil,
		stderr = nil,
	}

	s, stdout, stderr , err :=  os.process_exec(process_desc, context.temp_allocator)
	if err != nil {
		display_error(Exception{err, fmt.tprintf("Error executing command %s: %v", command, err)})
		return
	}

	for !s.exited {}

	if s.success do fmt.printf(string(stdout))
	else do fmt.printf(string(stderr))

	return
}

cd :: proc(path: string) -> Error {
	switch path {
	case "":
		os.change_directory("/") or_return
	case "~":
		hom_dir := os.get_env("HOME", context.temp_allocator)
		os.change_directory(hom_dir) or_return
	case:
		if !os.is_dir(path) do return Shell_Error.Invalid_Command

		os.change_directory(path) or_return
		return Shell_Error.None
	}

	return Shell_Error.None
}
