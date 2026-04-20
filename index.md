---
title: "Language Study: Odin"
---

**Author:** Nathan Tebbs  

**Language chosen:** [Odin](https://odin-lang.org/)  

---

## (a) History and Current Status

Odin was created by Bill Hall, who goes by "Ginger Bill" online. He is a British ex-physicist. He started the project in late July 2016 because he was tired of programming in C++. The first prototype was Pascal-flavored and used `begin` and `end` keywords. He pivoted away from that design quickly. Ginger Bill has said that the first three months produced about 70% of the language as it exists today. The remaining 30% took several more years of steady evolution. A lot of that evolution came from writing real software in Odin. The flagship examples are the JangaFX tools and the EmberGen fluid simulator.

Odin's influences are openly stated. Pascal contributed block structure, distinct types, and the `::` constant syntax. C contributed the low-level memory model and C-ABI interop. Go contributed package structure and `defer`. Jonathan Blow's Jai contributed the explicit context and allocator idea, plus the data-oriented leanings. A talk by Sean Barrett called *"How I Program C"* was cited by Ginger Bill as a direct inspiration for starting the project.

Notable milestones over the years:

- **2016:** first public commits. The language is Pascal-shaped.
- **2017 to 2019:** shift away from Pascal syntax. `proc`, `::`, `:=`, and `defer` settle in. The explicit `context` and allocator system is added.
- **2020:** release numbering moves to rolling date-based snapshots (`dev-YYYY-MM`).
- **2021:** SOA (struct-of-arrays), `matrix` types, and `bit_set` land.
- **2022 to 2024:** parametric polymorphism matures. The vendor library grows and gains Raylib, GLFW, Vulkan, and WebGPU bindings.
- **2025 to 2026:** ongoing package-system and error-handling refinements.

**Current version.** Odin does not cut traditional semver releases. Instead, every month or so a tagged snapshot named `dev-YYYY-MM` is published. I am building against `dev-2026-04:a896fb2b4`, installed via Homebrew (`brew install odin`). The official binaries, source tree, and installation notes all live at <https://odin-lang.org/>. The source mirror lives on GitHub at <https://github.com/odin-lang/Odin>.

What I find most interesting about Odin is that it is unapologetically a *small* language. There is no implicit allocator. There is no runtime garbage collector. There is no class hierarchy. There are no exceptions. All of that is intentionally absent. The goal is that the programmer can always see what a piece of code actually does. That minimalism makes Odin unusually readable for a systems language.

## (b) Paradigm

Odin is primarily an **imperative and procedural** language with strong **data-oriented** leanings. Here is how you can tell:

- The unit of code is the **procedure** (`proc`), not a method on an object. There are no classes, no inheritance, and no `this` or `self`.
- State lives in **structs** and **arrays of structs (or SOA)**. Behavior lives in free procedures that take those structs as arguments.
- **Array programming** is built in. You can do element-wise arithmetic on fixed-size arrays (for example `c := a + b`). SIMD-accelerated `matrix` types are first-class. This design pushes you toward batch-over-items thinking rather than item-at-a-time method calls.
- The explicit `context` and allocator system makes the layout and lifetime of data a visible part of the program. They are not a hidden runtime concern.

Odin borrows some functional conveniences. Procedures are first-class values. Closures exist in a limited form via procedure literals. The `or_return` and `or_else` operators thread error values through expressions. Even so, you would not write an Odin program the way you would write a Haskell one. There is no lazy evaluation, no pervasive immutability, no typeclasses, and no pattern matching beyond `switch` on union variants.

## (c) Typing System

Odin is **strongly and statically typed**.

- **Declarations are required**, but they are almost always inferred at the use site. For example, `x := 42` infers `int`. The line `pi :: 3.14159` infers an untyped float constant. The explicit form is `x: f32 = 42`.
- **The programmer can create new types** using a rich palette. The options are `struct`, `enum`, `union` (discriminated), `bit_set`, fixed arrays `[N]T`, dynamic arrays `[dynamic]T`, maps `map[K]V`, and `distinct`. The `distinct` keyword brands a new type from an existing one so the compiler refuses to mix them (for example `Meters :: distinct f64`). Type aliases use `T :: U`.
- **Procedures are first-class objects.** You can declare a procedure type (for example `Callback :: proc(x: int) -> int`), store procedure values in variables, pass them as arguments, return them from other procedures, and put them in arrays or structs. Odin also supports procedure overload groups via `proc{a, b, c}` and parametric polymorphism via `proc($T: typeid, x: T) -> T`.
- The `any` type exists and carries runtime type info. Idiomatic Odin reaches for generics long before it reaches for `any`.

Because the type system is static and strong, almost every bug that would be a runtime type error in a dynamic language surfaces at compile time in Odin.

## (d) Control Structures

**Selection:**

- `if` / `else if` / `else`: no parentheses around the condition. Braces are required, or the one-liner `if cond do stmt`. It supports an init clause, for example `if v, ok := lookup(k); ok { ... }`.
- `switch`: no implicit fallthrough. There is an explicit `fallthrough` keyword. You can put multiple values per case, use range cases like `case 0..=9:`, and run **type switches** on unions via `switch v in value { case int: ... }`.
- `when`: a **compile-time** `if`. The arms that fail the condition are never type-checked or emitted. This is how Odin does conditional compilation without a preprocessor.

**Repetition:**

- C-style: `for i := 0; i < n; i += 1 { ... }`.
- Range-based: `for i in 0..<n` for a half-open range, or `for i in 0..=n` for a closed range.
- Iterator-based: `for v, i in slice { ... }` or `for k, v in map { ... }`.
- Infinite: a bare `for { ... }`.

**Other flow tools:**

- `defer stmt`: runs `stmt` at scope exit in LIFO order. This is the standard idiom for `delete`, `close`, `builder_destroy`, and similar cleanup calls.
- `break` and `continue` with **labels** to target an outer loop.
- Error-flow operators: `or_return`, `or_else`, `or_break`, `or_continue`. Together they give multi-value error handling the ergonomics of `?` in Rust without needing a `Result` type.

## (e) Semantics

- **Scoping is lexical (static)**, with block scope. Every `{ ... }` opens a new scope. The `using` keyword can promote a struct's fields or an imported package's names into the current scope explicitly.
- **Constants** use the `::` operator and are fully compile-time evaluated. Examples are `PI :: 3.14159`, `MAX_ITER :: 100`, and `Color :: enum { Red, Green, Blue }`. Constants can be untyped (polymorphic over numeric types) or given an explicit type. Because constants exist at compile time they are usable in `when` branches, array-length positions, and other constant contexts.
- **Storage allocation** is explicit and split across three regions:
  - *Static*: package-level variables and constants.
  - *Stack-dynamic*: local variables, fixed-size arrays `[N]T`, and any `struct` value whose size is known at compile time.
  - *Heap-dynamic*: anything allocated through `make` (dynamic arrays, maps, slices) or `new`. Allocation routes through an implicit `context.allocator`. The programmer can swap this allocator per-scope for an arena, temp, tracking, or custom allocator.
- **Garbage collection: none.** Odin has no runtime GC. Memory is freed explicitly by `delete` or `free`. The idiom is to pair the allocation with a `defer` at the allocation site so the cleanup is impossible to forget:

  ```odin
  xs := make([dynamic]int, 0, 16)
  defer delete(xs)
  ```

  Odin ships with a tracking allocator that reports leaks in debug builds, an arena allocator for bulk deallocation, and a temporary allocator (`context.temp_allocator`) that is cleared between frames or logical boundaries.

## (f) Desirable Language Characteristic: Efficiency

Topic 2 covered four categories of desirable characteristics: Efficiency, Regularity, Security and Reliability, and Extensibility. Of those four, **Efficiency** is the one Odin leans hardest into. It is the characteristic that every other design decision seems to serve.

**Features that support efficiency:**

- **No garbage collector, no hidden runtime.** There are no stop-the-world pauses. There are no write barriers. There are no background threads scanning the heap. A procedure's runtime cost is visible on the page.
- **Explicit allocators via `context.allocator`.** Swapping to an arena or temp allocator is a one-line change. It eliminates per-object `malloc` and `free` costs for an entire subsystem. Cache locality becomes something the programmer designs for, not something they pray about.
- **SOA (struct-of-arrays) as a language feature.** `v: #soa[N]Particle` transposes a struct array so that each field is stored contiguously. That layout is ideal for SIMD and cache line efficiency. Doing the same thing by hand in C would be a bookkeeping nightmare.
- **Built-in `matrix` and fixed-array arithmetic with SIMD lowering.** `c := a + b` on `[4]f32` emits vector instructions on x86-64 and ARM without any intrinsics.
- **Zero-cost abstractions.** Generics are monomorphized at compile time. `when` arms that fail are omitted entirely. Procedure calls can be forced inline.
- **Calling conventions under programmer control.** `#force_inline`, `"contextless"` (which omits the hidden context pointer), and direct `"c"` ABI interop let you drop to the metal where it matters.
- **Compile times are a design constraint.** Odin compiles whole-program. There are no header files and no template instantiation explosion. Iteration is fast. That matters for development efficiency as well as runtime efficiency.

**Where efficiency comes at a cost.** The programmer owns memory lifetime. Beginners hit use-after-free and leak bugs that a garbage-collected language would never allow. The tracking allocator catches leaks in debug builds, but dangling pointers are on you. In short, Odin hands you a sharp knife and trusts you to hold it by the handle. That tradeoff is the one Odin is most willing to make: efficient by default, safe only if you write it safely.

---

## Part 3: Creative Program

*(Placeholder. This will be filled in for the Part 3 submission.)*

---

## About the Common Program (Part 2)

The Part 2 submission is a global-thresholding image segmenter written in Odin. It reads an ASCII PGM (P2) file from the command line. It then converges on a threshold using the two-means algorithm from the assignment. The algorithm starts from the mean of 10 randomly chosen pixels. It repeatedly sets the threshold to the mean of the below-threshold and above-threshold partition means. It stops when the change is under 0.001 or 100 iterations have elapsed. Finally, it writes a PBM (P1) file with the same basename.

The program exercises several parts of Odin's core library. It uses file I/O from `core:os`. It uses string tokenisation from `core:strings` and `core:strconv`. It uses random-number generation from `core:math/rand`, seeded from the monotonic clock in `core:time`. It also uses the `defer`-based cleanup idiom that stands in for a garbage collector.

**Source:** [`threshold.odin`](https://github.com/nathantebbs/odin-language-study/blob/main/threshold.odin). The source is a single file of about 180 lines. You can build it with `odin build threshold.odin -file -out:threshold`.
