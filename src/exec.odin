#+feature dynamic-literals
package main

import "core:strings"
import "core:fmt"
import "core:os"

execute :: proc(command, params: string) {
	args := strings.split(params, " ")

	process_cmd := [dynamic]string{command}
	defer delete(process_cmd)
	append(&process_cmd, ..args[:])

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
