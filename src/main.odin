package main

import "core:fmt"
import "core:os"
import "core:bufio"

read_stdin :: proc() {
	scanner: bufio.Scanner

	buf : [1024]byte

	stdin := os.to_stream(os.stdin)
	bufio.scanner_init(&scanner, stdin, context.temp_allocator)

	for {
		fmt.printf("$ ")
		if !bufio.scanner_scan(&scanner) do break

		line := bufio.scanner_text(&scanner)
		fmt.printf("%s: command not found\n", line)
	}

}

main :: proc() {
	read_stdin()
}
