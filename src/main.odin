package main

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
}

Exception :: struct {
	error:   Error,
	message: string,
}


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

		execute_command(command, params)
	}
}

execute_command :: proc(command, params: string) {
	switch command {
	case "exit":
		os.exit(0)
	case "echo":
		fmt.println(params)
	case:
		display_error(Exception {
			Shell_Error.Invalid_Command,
			fmt.tprintf("%s: command not found", command),
		})
	}
}

// REFACTOR:
// shell_loop :: proc() {
// 	fmt.printf("$ ")
// 	if !bufio.scanner_scan(&scanner) do break
//
// 	line := bufio.scanner_text(&scanner)
// 	input, err := strings.split_n(line, " ", 1)
// 	if err != nil {
// 		return Exception{err, fmt.tprintf("Error with string splitting: %v", err)}
// 	}
//
// 	command := input[0]
// 	params := input[1] if len(input) > 1 else ""
//
// 	if command == "exit" {
// 		break
// 	}
//
// 	return Exception {
// 		Shell_Error.Invalid_Command,
// 		fmt.tprintf("%s: command not found", command),
// 	}
// }

display_error :: proc(err: Exception) {
	switch value in err.error {
	case Shell_Error, runtime.Allocator_Error:
		switch value {
		case Shell_Error.None, runtime.Allocator_Error.None:
			break
		}
		fmt.println(err.message)
	}
}

main :: proc() {
	read_stdin()

}
