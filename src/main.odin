#+feature dynamic-literals
package main

import "core:slice"
import "base:runtime"
import "core:bufio"
import "core:fmt"
import "core:os"
import "core:strings"

Shell_Error :: enum byte {
	None,
	Invalid_Command,
}

Error :: union {
	Shell_Error,
	runtime.Allocator_Error,
	os.Error
}

Exception :: struct {
	error:   Error,
	message: string,
}


builtins : map[string]bool

read_stdin :: proc() {
	scanner: bufio.Scanner

	stdin := os.to_stream(os.stdin)
	bufio.scanner_init(&scanner, stdin, context.temp_allocator)

	for {
		fmt.printf("$ ")
		if !bufio.scanner_scan(&scanner) do break

		line := bufio.scanner_text(&scanner)
		input, err := strings.split_n(line, " ", 2)
		if err != nil {
			display_error(Exception{err, fmt.tprintf("Error with string splitting: %v", err)})
		}

		command := input[0]
		params := clean_params(input[1]) if len(input) > 1 else []string{}

		if execute_command(command, params) do return
	}
}

previous_char :: proc(b : ^strings.Builder) -> (prev: rune, has_previous: bool) {
	if len(b.buf) == 0 do return
	else do return rune(b.buf[len(b.buf)-1]), true
}

clean_params :: proc(p: string) -> (res: []string) {
	// TODO need to parse through the characters of the string this and make a struct
	r : [dynamic]string
	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	in_quote := false

	for c, idx in p {
		switch {
		case c == '\'':
			in_quote = !in_quote
		case c == ' ' && !in_quote:
			if strings.builder_len(sb) == 0 do continue
			append(&r, strings.clone(strings.to_string(sb)))
			strings.builder_reset(&sb)
		case:
			strings.write_rune(&sb, c)
		}
	}

	if strings.builder_len(sb) > 0 {
		append(&r, strings.clone(strings.to_string(sb)))
	}

	return slice.clone(r[:])
}

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

display_error :: proc(err: Exception) {
	switch value in err.error {
	case Shell_Error, runtime.Allocator_Error, os.Error:
		switch value {
		case Shell_Error.None, runtime.Allocator_Error.None:
			break
		}
		fmt.println(err.message)
	}
}

main :: proc() {
	builtins = {
		"exit" = true,
		"echo" = true,
		"type" = true,
		"pwd" = true,
		"cd" = true,
	}
	defer delete(builtins)

	read_stdin()

}
