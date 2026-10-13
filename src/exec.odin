#+feature dynamic-literals
package main

import "core:fmt"
import "core:os"

contains_pipe :: proc(params: []string) -> bool {
	for p in params {
		if p == ">" do return true
		if p == "1>" do return true
	}
	return false
}

execute_command :: proc(command: string, params: []string) -> (should_exit: bool) {
	args : []string
	file : ^os.File

	if contains_pipe(params){
		args = params[:len(params)-2]
		file_name := params[len(params)-1]
		err: os.Error
		file, err = os.create(file_name)
		if err != nil {
			display_error(
				Exception{err,
				fmt.tprintf("Error creating file %s working directory: %v", file_name, err)})
		}
	}
	else do args = params

	if file == nil do file = os.stdout
	defer {
		if file != os.stdout do os.close(file)
	}

	switch command {
	case "exit":
		return true
	case "echo":
		for p, idx in args {
			fmt.fprintf(file, p)
			if len(args) - 1 != idx do fmt.fprint(file, " ")
		}
		fmt.fprintln(file)
	case "pwd":
		cwd, err := os.get_working_directory(context.temp_allocator)
		if err != nil {
			display_error(Exception{err, fmt.tprintf("Error getting working directory: %v", err)})
			break
		}
		fmt.fprintln(file, cwd)
	case "cd":
		if len(args) == 0 {
			break
		}

		param := args[0]

		err := cd(param)
		if err != Shell_Error.None{
			display_error(Exception{err, fmt.tprintf("cd: %s: No such file or directory", param)})
			break
		}
	case "type":
		if len(args) == 0 {
			break
		}
		param := args[0]

		if _, exists := builtins[param]; exists {
			fmt.fprintln(file, fmt.tprintf("%s is a shell builtin", param))
			break
		}

		if cmd_path, ok := path_search(param); ok {
			fmt.fprintln(file, fmt.tprintf("%s is %s", param, cmd_path))
			break
		}

		fmt.println(fmt.tprintf("%s: not found", param))
	case:
		if cmd_path, ok := path_search(command); ok {
			execute(command, args, file)
			break
		}

		display_error(Exception {
			Shell_Error.Invalid_Command,
			fmt.tprintf("%s: command not found", command),
		})
	}

	return false
}


execute :: proc(command: string, params: []string, out: ^os.File = os.stdout) {

	process_cmd := [dynamic]string{command}
	defer delete(process_cmd)
	append(&process_cmd, ..params)

	process_desc := os.Process_Desc{
		working_dir = "",
		command = process_cmd[:],
		env = nil,
		stdin = os.stdin,
		stdout = out,
		stderr = os.stderr,
	}

	p, err :=  os.process_start(process_desc)
	if err != nil {
		display_error(Exception{err, fmt.tprintf("Error executing command %s: %v", command, err)})
		return
	}

	_, err = os.process_wait(p)
	if err != nil {
		display_error(Exception{err, fmt.tprintf("Error waiting for command %s: %v", command, err)})
	}

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
