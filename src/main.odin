#+feature dynamic-literals
package main

import "core:log"
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

Shell_Action :: enum {
	Exit,
	ReLoop,
	Execute
}

Cli_Parts :: enum {
	Command,
	Parameter,
}

read_line :: proc(sb: ^strings.Builder) -> (line: string, action: Shell_Action) {
	orig : posix.termios
	posix.tcgetattr(posix.STDIN_FILENO, &orig)
	raw := orig
	raw.c_lflag -= {.ICANON, .ECHO}
	raw.c_cc[.VMIN] = 1
	raw.c_cc[.VTIME] = 0
	posix.tcsetattr(posix.STDIN_FILENO, .TCSANOW, &raw)
	defer posix.tcsetattr(posix.STDIN_FILENO, .TCSANOW, &orig)

	buf: [1]byte
	prev: byte
	completions: []string = nil
	file_completions : []string = nil
	cli_part := Cli_Parts.Command


	for {
		n, err := os.read(os.stdin, buf[:])
		if n == 0 || err != nil do return "", .Exit
		switch buf[0] {
		case '\t':
			line := strings.to_string(sb^)
			space_idx  := strings.last_index_byte(line, ' ') // -1 if none
			prefix := line[space_idx+1:]


			if space_idx < 0 do cli_part = .Command
			else do cli_part = .Parameter


			options: []string

			switch cli_part {
			case .Command:
				if completions == nil && cli_part == .Command do completions = build_exec_completions(context.temp_allocator)
				options = completions
			case .Parameter:
				if file_completions == nil && cli_part == .Parameter do file_completions = build_file_completions(context.temp_allocator)
				options = file_completions
			}

			auto_complete, ring := tab(prefix, options, rang_before = prev == '\t')

			if ring do os.write_byte(os.stdout, '\x07')
			else {
				if prev == '\t' {
					os.write_string(os.stdout, auto_complete)
					return line, .ReLoop
				}
				else {
					strings.write_string(sb, auto_complete)
					os.write_string(os.stdout, auto_complete)
				}
			}
		case '\n', '\r':
			os.write_string(os.stdout, "\n")
			return strings.to_string(sb^), .Execute
		case 8, 127: //Backspace
			if strings.builder_len(sb^) > 0 {
				strings.pop_byte(sb)
				os.write_string(os.stdout, "\b \b")
			}
		case:
			strings.write_byte(sb, buf[0])
			os.write(os.stdout, buf[:]) // manual echo
		}
		 prev = buf[0]

	}

}

read_stdin :: proc() {
	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)

	for {
		defer free_all(context.temp_allocator)
		fmt.printf("$ %s", strings.to_string(sb))

		line, action := read_line(&sb)
	 	#partial switch action {
		case .Exit:
			return
		case .ReLoop:
			continue
		}
		defer strings.builder_reset(&sb)
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

 	f, _ := os.open("/tmp/shell.log", os.O_WRONLY | os.O_CREATE | os.O_TRUNC)
    context.logger = log.create_file_logger(f)
    defer log.destroy_file_logger(context.logger)

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
