/*
    threshold.odin
    --------------
    CSc 372 — Spring 2026 — Part 2 Common Program
    Author: Nathan Tebbs
    Language: Odin (dev-2026-04)
    Language study writeup: https://github.com/<user>/372-finalproject  (see README)

    Reads a PGM (P2, ASCII grayscale) image from the path given on the
    command line, computes a global threshold using the iterative two-means
    algorithm described in the assignment, and writes a segmented PBM (P1,
    ASCII black-and-white) image to the same basename with a .pbm extension.

    Build:  odin build threshold.odin -file -out:threshold
    Run:    ./threshold path/to/image.pgm
*/
package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:os"
import "core:path/filepath"
import "core:strconv"
import "core:strings"
import "core:time"

Image :: struct {
    width, height: int,
    max_val:       int,
    pixels:        []int,
}

MAX_ITERATIONS :: 100
CONVERGENCE    :: 0.001
SEED_SAMPLES   :: 10

die :: proc(msg: string, args: ..any) -> ! {
    fmt.eprintf("threshold: ")
    fmt.eprintfln(msg, ..args)
    os.exit(1)
}

// Strip PGM/PBM comment lines (anything from '#' to end of line) so the
// remaining text can be tokenised as whitespace-separated numbers and magic.
strip_comments :: proc(src: string, allocator := context.allocator) -> string {
    b := strings.builder_make(allocator)
    s := src
    for line in strings.split_lines_iterator(&s) {
        trimmed := strings.trim_left_space(line)
        if len(trimmed) > 0 && trimmed[0] == '#' {
            strings.write_byte(&b, '\n')
            continue
        }
        strings.write_string(&b, line)
        strings.write_byte(&b, '\n')
    }
    return strings.to_string(b)
}

read_pgm :: proc(path: string) -> (img: Image, ok: bool) {
    data, err := os.read_entire_file_from_path(path, context.allocator)
    if err != nil {
        fmt.eprintfln("threshold: cannot read %q: %v", path, err)
        return {}, false
    }
    defer delete(data)

    cleaned := strip_comments(string(data))
    defer delete(cleaned)

    tokens, terr := strings.fields(cleaned)
    if terr != nil {
        fmt.eprintfln("threshold: tokenising %q failed: %v", path, terr)
        return {}, false
    }
    defer delete(tokens)

    if len(tokens) < 4 {
        fmt.eprintfln("threshold: %q is too short to be a PGM", path)
        return {}, false
    }
    if tokens[0] != "P2" {
        fmt.eprintfln("threshold: %q is not a P2 (ASCII PGM) file; got magic %q", path, tokens[0])
        return {}, false
    }

    parse :: proc(tok: string, what: string) -> (int, bool) {
        v, pok := strconv.parse_int(tok)
        if !pok {
            fmt.eprintfln("threshold: cannot parse %s from %q", what, tok)
            return 0, false
        }
        return v, true
    }

    w, wok := parse(tokens[1], "width");    if !wok { return {}, false }
    h, hok := parse(tokens[2], "height");   if !hok { return {}, false }
    m, mok := parse(tokens[3], "max value"); if !mok { return {}, false }

    if w <= 0 || h <= 0 {
        fmt.eprintfln("threshold: image dimensions must be positive (got %d x %d)", w, h)
        return {}, false
    }

    expected := w * h
    pixel_tokens := tokens[4:]
    if len(pixel_tokens) < expected {
        fmt.eprintfln("threshold: expected %d pixels, found %d", expected, len(pixel_tokens))
        return {}, false
    }

    pixels := make([]int, expected)
    for i in 0..<expected {
        v, pok := parse(pixel_tokens[i], "pixel")
        if !pok {
            delete(pixels)
            return {}, false
        }
        pixels[i] = v
    }

    return Image{width = w, height = h, max_val = m, pixels = pixels}, true
}

// Iterative two-means threshold selection. Returns the converged threshold
// as a float so the caller can round once at comparison time.
compute_threshold :: proc(img: Image) -> f64 {
    rand.reset(u64(time.now()._nsec))

    n := len(img.pixels)
    sum := 0.0
    for _ in 0..<SEED_SAMPLES {
        sum += f64(img.pixels[rand.int_range(0, n)])
    }
    t := sum / f64(SEED_SAMPLES)

    prev := t
    for iter in 0..<MAX_ITERATIONS {
        below_sum, above_sum := 0.0, 0.0
        below_n, above_n := 0, 0
        for p in img.pixels {
            if f64(p) < t {
                below_sum += f64(p)
                below_n   += 1
            } else {
                above_sum += f64(p)
                above_n   += 1
            }
        }

        // If a partition is empty, fall back to t for that side so the
        // update is a no-op rather than a NaN from 0/0.
        mean_below := t if below_n == 0 else below_sum / f64(below_n)
        mean_above := t if above_n == 0 else above_sum / f64(above_n)

        prev = t
        t    = (mean_below + mean_above) / 2.0

        if math.abs(t - prev) < CONVERGENCE {
            fmt.printfln("converged after %d iteration(s) at threshold = %.4f", iter + 1, t)
            return t
        }
    }
    fmt.printfln("reached %d iterations without converging; using threshold = %.4f", MAX_ITERATIONS, t)
    return t
}

// Replace the file extension on `path` with ".pbm".
swap_extension :: proc(path: string) -> string {
    dir  := filepath.dir(path, context.allocator)
    defer delete(dir)
    stem := filepath.stem(path)
    if dir == "" || dir == "." {
        return fmt.aprintf("%s.pbm", stem)
    }
    return fmt.aprintf("%s/%s.pbm", dir, stem)
}

write_pbm :: proc(path: string, img: Image, threshold: f64) -> bool {
    b := strings.builder_make()
    defer strings.builder_destroy(&b)

    fmt.sbprintf(&b, "P1\n")
    fmt.sbprintf(&b, "# generated by threshold.odin (t = %.4f)\n", threshold)
    fmt.sbprintf(&b, "%d %d\n", img.width, img.height)

    // Per the assignment: pixels LESS than the threshold become black (1 in PBM),
    // the rest become white (0 in PBM). We emit width values per line so the
    // output is easy to eyeball alongside the input.
    for y in 0..<img.height {
        for x in 0..<img.width {
            p := img.pixels[y * img.width + x]
            bit := 1 if f64(p) < threshold else 0
            if x > 0 {
                strings.write_byte(&b, ' ')
            }
            fmt.sbprintf(&b, "%d", bit)
        }
        strings.write_byte(&b, '\n')
    }

    err := os.write_entire_file(path, strings.to_string(b))
    if err != nil {
        fmt.eprintfln("threshold: cannot write %q: %v", path, err)
        return false
    }
    return true
}

main :: proc() {
    if len(os.args) != 2 {
        die("usage: %s <image.pgm>", os.args[0] if len(os.args) > 0 else "threshold")
    }

    in_path := os.args[1]
    img, ok := read_pgm(in_path)
    if !ok {
        os.exit(1)
    }
    defer delete(img.pixels)

    t := compute_threshold(img)

    out_path := swap_extension(in_path)
    defer delete(out_path)

    if !write_pbm(out_path, img, t) {
        os.exit(1)
    }

    fmt.printfln("wrote %s (%d x %d)", out_path, img.width, img.height)
}
