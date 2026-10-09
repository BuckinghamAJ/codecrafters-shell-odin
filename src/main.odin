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
		input := clean_input(line)
		defer {
			for i in input do delete(i)
			delete(input)
		}

		command := input[0]
		params := input[1:] if len(input) > 1 else []string{}

		if execute_command(command, params) do return
	}
}

previous_char :: proc(b : ^strings.Builder) -> (prev: rune, has_previous: bool) {
	if len(b.buf) == 0 do return
	else do return rune(b.buf[len(b.buf)-1]), true
}

clean_input :: proc(p: string) -> (res: []string) {
	r : [dynamic]string
	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	in_single := false
	in_double := false
	prev_backslash := false

	for c, idx in p {
		switch {
		case c == '\\' && !prev_backslash && !in_single:
			prev_backslash = true
		case c == '\'' && !in_double && !prev_backslash:
			in_single = !in_single
		case c == '"' && !in_single && !prev_backslash:
			in_double = !in_double
		case c == ' ' && !in_single && !in_double && !prev_backslash:
			if strings.builder_len(sb) == 0 do continue
			append(&r, strings.clone(strings.to_string(sb)))
			strings.builder_reset(&sb)
		case:
			prev_backslash = false
			strings.write_rune(&sb, c)
		}
	}

	if strings.builder_len(sb) > 0 {
		append(&r, strings.clone(strings.to_string(sb)))
	}

	return r[:]
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
