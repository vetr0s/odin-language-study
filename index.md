---
title: "Language Study: Odin"
---

**Author:** Nathan Tebbs
**Language chosen:** [Odin](https://odin-lang.org/)

---

## (a) History and Current Status

Odin was created by **Bill Hall** (a.k.a. "Ginger Bill"), a British ex-physicist who started the project in late July 2016 after growing tired of C++. His first prototype was a Pascal-flavored toy — complete with `begin` and `end` — but the design pivoted quickly. Ginger Bill has said that the first three months produced roughly 70% of the language as it exists today; the remaining 30% took several more years of steady evolution, much of it shaped by writing real software in Odin (the JangaFX tools and the EmberGen fluid simulator are the flagship examples).

Odin's influences are openly stated: **Pascal** (for block structure, distinct types, and the `::` constant syntax), **C** (for the low-level memory model and C-ABI interop), **Go** (for package structure and `defer`), and **Jonathan Blow's Jai** (for the explicit-context/allocator idea and data-oriented leanings). A talk by Sean Barrett, *"How I Program C"*, was cited by Ginger Bill as a direct inspiration for starting the project.

Notable milestones over the years:

- **2016** — first public commits; language is Pascal-shaped.
- **2017–2019** — shift away from Pascal syntax; `proc` / `::` / `:=` / `defer` settle in; explicit `context` and allocator system added.
- **2020** — release numbering moves to rolling date-based snapshots (`dev-YYYY-MM`).
- **2021** — SOA (struct-of-arrays), `matrix` types, and `bit_set` land.
- **2022–2024** — parametric polymorphism matures; the vendor library grows (Raylib, GLFW, Vulkan, WebGPU bindings).
- **2025–2026** — ongoing package-system and error-handling refinements.

**Current version:** Odin does not cut traditional semver releases. Instead, every month or so a tagged snapshot named `dev-YYYY-MM` is published. I am building against `dev-2026-04:a896fb2b4`, installed via Homebrew (`brew install odin`). The official binaries, source tree, and installation notes all live at <https://odin-lang.org/>, with the source mirror on GitHub at <https://github.com/odin-lang/Odin>.

What I find most interesting about Odin is that it is unapologetically a *small* language. There is no implicit allocator, no runtime garbage collector, no class hierarchy, and no exceptions — all of that is intentionally absent so that the programmer can always see what a piece of code actually does. That minimalism makes Odin unusually readable for a systems language.

## (b) Paradigm

Odin is primarily an **imperative / procedural** language with strong **data-oriented** leanings. The giveaways:

- The unit of code is the **procedure** (`proc`), not the method on an object. There are no classes, no inheritance, and no `this`/`self`.
- State lives in **structs** and **arrays of structs (or SOA)**; behavior lives in free procedures that take those structs as arguments.
- **Array programming** is built in — element-wise arithmetic on fixed-size arrays (`c := a + b`) and SIMD-accelerated `matrix` types are first-class, which pushes you toward batch-over-items thinking rather than item-at-a-time method calls.
- The explicit `context` / allocator system makes the *layout and lifetime* of data a visible part of the program rather than a hidden runtime concern.

Odin borrows *some* functional conveniences (procedures are first-class values, closures exist in a limited form via procedure literals, and `or_return`/`or_else` thread error values through expressions), but you would not write an Odin program the way you'd write a Haskell one — there is no lazy evaluation, no pervasive immutability, no typeclasses, and no pattern matching beyond `switch` on union variants.

## (c) Typing System

Odin is **strongly and statically typed**.

- **Declarations are required**, but almost always inferred at the use site: `x := 42` infers `int`, `pi :: 3.14159` infers an untyped float constant. Explicit form is `x: f32 = 42`.
- **The programmer can create new types** using a rich palette: `struct`, `enum`, `union` (discriminated), `bit_set`, fixed arrays `[N]T`, dynamic arrays `[dynamic]T`, maps `map[K]V`, and `distinct` to brand a new type from an existing one so the compiler refuses to mix them (e.g. `Meters :: distinct f64`). Type aliases use `T :: U`.
- **Procedures are first-class objects**. You can declare a procedure type (`Callback :: proc(x: int) -> int`), store procedure values in variables, pass them as arguments, return them from other procedures, and put them in arrays or structs. Odin also supports **procedure overload groups** via `proc{a, b, c}` and **parametric polymorphism** (`proc($T: typeid, x: T) -> T`).
- The `any` type exists and carries runtime type info, but idiomatic Odin reaches for generics long before `any`.

Because the type system is static and strong, almost every bug that would be a runtime type error in a dynamic language surfaces at compile time in Odin.

## (d) Control Structures

**Selection:**

- `if` / `else if` / `else` — no parentheses around the condition; braces are required (or the one-liner `if cond do stmt`). Supports an init clause: `if v, ok := lookup(k); ok { ... }`.
- `switch` — no implicit fallthrough (an explicit `fallthrough` keyword exists), multiple values per case, range cases (`case 0..=9:`), and **type switches** on unions (`switch v in value { case int: ... }`).
- `when` — a **compile-time** `if`. The arms that fail the condition are never type-checked or emitted, which is how Odin does conditional compilation without a preprocessor.

**Repetition:**

- C-style: `for i := 0; i < n; i += 1 { ... }`
- Range-based: `for i in 0..<n` (half-open) or `for i in 0..=n` (closed).
- Iterator-based: `for v, i in slice { ... }` or `for k, v in map { ... }`.
- Infinite: a bare `for { ... }`.

**Other flow tools:**

- `defer stmt` — runs `stmt` at scope exit in LIFO order; the standard idiom for `delete`, `close`, `builder_destroy`, etc.
- `break` / `continue` with **labels** to target an outer loop.
- Error-flow operators: `or_return`, `or_else`, `or_break`, `or_continue` — together they give multi-value error handling the ergonomics of `?` in Rust without needing a `Result` type.

## (e) Semantics

- **Scoping is lexical (static)**, with block scope. Every `{ ... }` opens a new scope; the `using` keyword can promote a struct's fields or an imported package's names into the current scope explicitly.
- **Constants** use the `::` operator and are fully compile-time evaluated: `PI :: 3.14159`, `MAX_ITER :: 100`, `Color :: enum { Red, Green, Blue }`. They can be untyped (polymorphic over numeric types), or given an explicit type. Because constants exist at compile time they are usable in `when`, array-length positions, and other constant contexts.
- **Storage allocation** is explicit and split across three regions:
  - *Static* — package-level variables and constants.
  - *Stack-dynamic* — local variables, fixed-size arrays `[N]T`, and any `struct` value whose size is known at compile time.
  - *Heap-dynamic* — anything allocated through `make` (dynamic arrays, maps, slices) or `new`. Allocation routes through an implicit `context.allocator`, which the programmer can swap per-scope (arena, temp, tracking, etc.).
- **Garbage collection: none.** Odin has **no runtime GC**. Memory is freed explicitly by `delete` / `free`, usually paired with `defer` at the allocation site so the cleanup is impossible to forget:

  ```odin
  xs := make([dynamic]int, 0, 16)
  defer delete(xs)
  ```

  Odin ships with a tracking allocator that reports leaks in debug builds, an arena allocator for bulk deallocation, and a temporary allocator (`context.temp_allocator`) that's cleared between frames or logical boundaries.

## (f) Desirable Language Characteristic — Efficiency

Of the four characteristics we covered in Topic 2 (Efficiency, Regularity, Security/Reliability, Extensibility), **Efficiency** is the one Odin leans hardest into — it is the characteristic that every other design decision seems to serve.

**Features that support efficiency:**

- **No garbage collector, no hidden runtime.** There are no stop-the-world pauses, no write barriers, no background threads scanning the heap. A procedure's runtime cost is visible on the page.
- **Explicit allocators via `context.allocator`.** Swapping to an arena or temp allocator is a one-line change and eliminates per-object `malloc`/`free` costs for an entire subsystem. Cache locality becomes something the programmer designs for, not something they pray about.
- **SOA (struct-of-arrays) as a language feature.** `v: #soa[N]Particle` transposes a struct array so that each field is stored contiguously — ideal for SIMD and cache line efficiency. Doing the same thing by hand in C would be a bookkeeping nightmare.
- **Built-in `matrix` and fixed-array arithmetic with SIMD lowering.** `c := a + b` on `[4]f32` emits vector instructions on x86-64 and ARM without any intrinsics.
- **Zero-cost abstractions.** Generics are monomorphized at compile time, `when` arms that fail are omitted entirely, and procedure calls can be forced inline.
- **Calling conventions under programmer control.** `#force_inline`, `"contextless"` (omits the hidden context pointer), and direct `"c"` ABI interop let you drop to the metal where it matters.
- **Compile times are a design constraint.** Odin compiles whole-program (no header files, no template instantiation explosion), so iteration is fast — which matters for *development* efficiency as well as runtime.

**Where efficiency comes at a cost:**

Because the programmer owns memory lifetime, beginners hit use-after-free and leak bugs that a GC'd language would never allow. The tracking allocator catches leaks in debug builds, but dangling pointers are on you. In other words: Odin hands you a sharp knife and trusts you to hold it by the handle. That tradeoff — *efficient by default, safe-only-if-you-write-it-safely* — is the characteristic Odin is most willing to make.

---

## Part 3 — Creative Program

*(Placeholder — will be filled in for the Part 3 submission.)*

---

## About the Common Program (Part 2)

The Part 2 submission is a global-thresholding image segmenter in Odin. It reads an ASCII PGM (P2) file from the command line, iteratively converges on a threshold using the two-means algorithm from the assignment — start from the mean of 10 randomly chosen pixels, then repeatedly set the threshold to the mean of the below-threshold and above-threshold partition means until the change is under 0.001 or 100 iterations elapse — and writes a PBM (P1) file with the same basename. The program exercises Odin's file I/O (`core:os`), string tokenisation (`core:strings`, `core:strconv`), random-number generation seeded from the monotonic clock (`core:math/rand`, `core:time`), and the `defer`-based cleanup idiom that stands in for a garbage collector.

**Source:** [`threshold.odin`](https://github.com/nathantebbs/372-finalproject/blob/main/threshold.odin) — single file, ~180 lines, builds with `odin build threshold.odin -file -out:threshold`.
