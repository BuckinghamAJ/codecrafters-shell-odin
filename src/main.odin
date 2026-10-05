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
		params := input[1] if len(input) > 1 else ""

		if execute_command(command, params) do return
	}
}

execute_command :: proc(command, params: string) -> (should_exit: bool) {
	switch command {
	case "exit":
		return true
	case "echo":
		fmt.println(params)
	case "pwd":
		execute("pwd", "-L")
	case "type":
		if _, exists := builtins[params]; exists {
			fmt.println(fmt.tprintf("%s is a shell builtin", params))
			break
		}

		if cmd_path, ok := path_search(params); ok {
			fmt.println(fmt.tprintf("%s is %s", params, cmd_path))
			break
		}

		fmt.println(fmt.tprintf("%s: not found", params))
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
	}
	defer delete(builtins)

	read_stdin()

}
