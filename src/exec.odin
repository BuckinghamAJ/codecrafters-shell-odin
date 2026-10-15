#+feature dynamic-literals
package main

import "core:fmt"
import "core:os"

Shell_Operation :: enum {
	Redirect_Stdout,
	Redirect_Stderr,
	Append_Stdout,
	Append_Stderr
}

contains_operation :: proc(params: []string) -> (op: Shell_Operation, contains: bool) {
	for p in params {
		switch p {
		case ">>", "1>>": return .Append_Stdout, true
		case "2>>": return .Append_Stderr, true
		case ">", "1>": return .Redirect_Stdout, true
		case "2>": return .Redirect_Stderr, true
		}
	}
	return nil, false
}

@(rodata)
FILE_OP_FLAGS := [Shell_Operation]os.File_Flags{
	.Redirect_Stdout = {.Write, .Create, .Trunc},
	.Redirect_Stderr = {.Write, .Create, .Trunc},
	.Append_Stdout   = {.Write, .Create, .Append},
	.Append_Stderr   = {.Write, .Create, .Append},
}

execute_command :: proc(command: string, params: []string) -> (should_exit: bool) {
	args : []string
	stdout := os.stdout
	stderr := os.stderr

	if op, ok := contains_operation(params); ok{
		args = params[:len(params)-2]
		file_name := params[len(params)-1]
		file, err := os.open(file_name, FILE_OP_FLAGS[op])
		if err != nil {
			display_error(
				Exception{err,
				fmt.tprintf("Error creating file %s working directory: %v", file_name, err)})
		}

		switch op {
		case .Redirect_Stdout, .Append_Stdout:
			stdout = file
		case .Redirect_Stderr, .Append_Stderr:
			stderr = file
		}

	}
	else do args = params

	defer {
		if stdout != os.stdout do os.close(stdout)
		if stderr != os.stderr do os.close(stderr)
	}

	switch command {
	case "exit":
		return true
	case "echo":
		for p, idx in args {
			fmt.fprintf(stdout, p)
			if len(args) - 1 != idx do fmt.fprint(stdout, " ")
		}
		fmt.fprintln(stdout)
	case "pwd":
		cwd, err := os.get_working_directory(context.temp_allocator)
		if err != nil {
			display_error(Exception{err, fmt.tprintf("Error getting working directory: %v", err)})
			break
		}
		fmt.fprintln(stdout, cwd)
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
			fmt.fprintln(stdout, fmt.tprintf("%s is a shell builtin", param))
			break
		}

		if cmd_path, ok := path_search(param); ok {
			fmt.fprintln(stdout, fmt.tprintf("%s is %s", param, cmd_path))
			break
		}

		fmt.println(fmt.tprintf("%s: not found", param))
	case:
		if cmd_path, ok := path_search(command); ok {
			execute(command, args, stdout, stderr)
			break
		}

		display_error(Exception {
			Shell_Error.Invalid_Command,
			fmt.tprintf("%s: command not found", command),
		})
	}

	return false
}


execute :: proc(command: string, params: []string, stdout: ^os.File = os.stdout, stderr: ^os.File = os.stderr) {

	process_cmd := [dynamic]string{command}
	defer delete(process_cmd)
	append(&process_cmd, ..params)

	process_desc := os.Process_Desc{
		working_dir = "",
		command = process_cmd[:],
		env = nil,
		stdin = os.stdin,
		stdout = stdout,
		stderr = stderr,
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
