#+feature dynamic-literals
package main

import "core:sys/posix"
import "core:mem"
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

read_line :: proc(sb: ^strings.Builder) -> (line: string, ok: bool) {
	orig : posix.termios
	posix.tcgetattr(posix.STDIN_FILENO, &orig)
	raw := orig
	raw.c_lflag -= {.ICANON, .ECHO}
	raw.c_cc[.VMIN] = 1
	raw.c_cc[.VTIME] = 0
	posix.tcsetattr(posix.STDIN_FILENO, .TCSANOW, &raw)
	defer posix.tcsetattr(posix.STDIN_FILENO, .TCSANOW, &orig)

	strings.builder_reset(sb)
	buf: [1]byte

	for {
		n, err := os.read(os.stdin, buf[:])
		if n == 0 || err != nil do return "", false
		switch buf[0] {
		case '\t':
		 	auto_complete, ring := tab(sb, builtins)
			if ring do os.write_byte(os.stdout, '\x07')
			else {
				strings.write_string(sb, auto_complete)
				os.write_string(os.stdout, auto_complete)
			}
		case '\n', '\r':
			os.write_string(os.stdout, "\n")
			return strings.to_string(sb^), true
		case 8, 127: //Backspace
			if strings.builder_len(sb^) > 0 {
				strings.pop_byte(sb)
				os.write_string(os.stdout, "\b \b")
			}
		case:
			strings.write_byte(sb, buf[0])
			os.write(os.stdout, buf[:]) // manual echo
		}

	}

}

read_stdin :: proc() {
	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)

	for {
		fmt.printf("$ ")

		line, ok := read_line(&sb)
		if !ok do break

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
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			for _, entry in track.allocation_map {
				fmt.eprintfln("%v leaked %v bytes", entry.location, entry.size)
			}
			for entry in track.bad_free_array {
				fmt.eprintfln("%v bad free at %v", entry.location, entry.memory)
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

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
