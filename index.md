---
title: "Language Study: Odin"
---

**Author:** Nathan Tebbs  

---

## Sources

- [Odin official website](https://odin-lang.org/)
- [Odin FAQ](https://odin-lang.org/docs/faq/) (origin, influences, Pascal-clone prototype)
- [Odin language overview](https://odin-lang.org/docs/overview/) (syntax, control flow, types)
- [Odin on GitHub](https://github.com/odin-lang/Odin)
- [`core:mem` package docs](https://pkg.odin-lang.org/core/mem/) (tracking allocator, arena allocator)
- Ginger Bill, [*The Video That Inspired Me To Create Odin*](https://www.gingerbill.org/article/2024/04/04/video-that-inspired-odin/) (3-month 70% quote, early C preprocessor attempt)
- Ginger Bill, [*On the Aesthetics of the Syntax of Declarations*](https://www.gingerbill.org/article/2018/03/12/on-the-aesthetics-of-the-syntax-of-declarations/) (reasoning behind `::` and `:=`)
- Sean Barrett, [the video Ginger Bill credits as inspiration](https://www.youtube.com/watch?v=eAhWIO1Ra6M)
- [JangaFX](https://jangafx.com/) and [EmberGen showcase on the Odin site](https://odin-lang.org/showcase/embergen/) (production usage)

## (a) History and Current Status

Odin was created by [Ginger Bill](https://www.gingerbill.org/). The [official FAQ](https://odin-lang.org/docs/faq/) puts the start date at "late July 2016" and says the project began "when Ginger Bill was annoyed with programming in C++." His first attempt was not a new language at all. In his own words from [*The Video That Inspired Me To Create Odin*](https://www.gingerbill.org/article/2024/04/04/video-that-inspired-odin/), he "began experimenting with just making an 'augmented' C compiler so that I could add constructs to C which I found to be some of the most annoying things C lacked." The two features he wanted most were slices and `defer`. That C-augmenting experiment became a dead end, so he started fresh.

The first real prototype of Odin was not the language it is today. The FAQ says plainly: "The language began as a Pascal clone (with `begin` and `end` and more) but changed quite quickly to become something else." Progress after that was uneven. Ginger Bill wrote that "about 3 months later, I had implemented ~70% of Odin; the other ~30% took 7 years."

The talk that pushed Ginger Bill to start the project was [this video by Sean Barrett](https://www.youtube.com/watch?v=eAhWIO1Ra6M), which he embeds at the top of [his blog post on Odin's origins](https://www.gingerbill.org/article/2024/04/04/video-that-inspired-odin/).

Odin's influences are listed explicitly in the FAQ: "The language borrows heavily from (in order of philosophy and impact): Pascal, C, Go, Oberon-2, Newsqueak, GLSL." The FAQ also names two specific design idols: "Niklaus Wirth and Rob Pike have been the programming language design idols throughout this project." (Wirth created Pascal and Oberon-2. Pike co-created Newsqueak and Go.) The FAQ does not attribute the `::` declaration syntax to any particular prior language. Ginger Bill has his own blog post, [*On the Aesthetics of the Syntax of Declarations*](https://www.gingerbill.org/article/2018/03/12/on-the-aesthetics-of-the-syntax-of-declarations/), that explains the reasoning behind it.

Odin is used in production today. Ginger Bill works at [JangaFX](https://jangafx.com/), and [their showcase page on the Odin site](https://odin-lang.org/showcase/embergen/) lists their products EmberGen, GeoGen, and LiquiGen as all written in Odin. Through EmberGen, Odin ships into studios including Bethesda, CAPCOM, Weta Digital, and Warner Bros.

**Current version.** Odin does not cut traditional semantic-version releases. Instead, the project publishes periodic snapshot tags named `dev-YYYY-MM` (see the [releases page on GitHub](https://github.com/odin-lang/Odin/releases)). I am building against `dev-2026-04:a896fb2b4`, installed via Homebrew (`brew install odin`). The official binaries, source tree, and installation notes all live at <https://odin-lang.org/>, and the source repository is at <https://github.com/odin-lang/Odin>.

What I find most interesting about Odin is that it is a deliberately *small* language. There is no implicit allocator. There is no runtime garbage collector. There is no class hierarchy. There are no exceptions. All of that is intentionally absent. The goal is that a programmer reading a piece of Odin code can see what it actually does. That minimalism makes Odin unusually readable for a systems language.

## (b) Paradigm

Odin is primarily an **imperative and procedural** language with strong **data-oriented** leanings. Here is how you can tell:

- The unit of code is the **procedure** (`proc`), not a method on an object. There are no classes, no inheritance, and no `this` or `self`.
- State lives in **structs** and **arrays of structs (or SOA)**. Behavior lives in free procedures that take those structs as arguments.
- **Array programming** is built in. You can do element-wise arithmetic on fixed-size arrays (for example `c := a + b`). SIMD-friendly `matrix` types are first-class. This design pushes you toward batch-over-items thinking rather than item-at-a-time method calls.
- The explicit `context` and allocator system makes the layout and lifetime of data a visible part of the program. They are not a hidden runtime concern.

Odin borrows some conveniences that are common in functional languages. Procedures are first-class values. You can write anonymous procedure literals. The `or_return` and `or_else` operators thread error values through expressions. That said, Odin's anonymous procedures are **not true closures**. They cannot capture local variables at runtime, only compile-time constants. And you would not write an Odin program the way you would write a Haskell one. There is no lazy evaluation, no pervasive immutability, no typeclasses, and no pattern matching beyond `switch` on union variants.

## (c) Typing System

Odin is **strongly and statically typed**.

- **Declarations are required**, but they are almost always inferred at the use site. For example, `x := 42` infers `int`. The line `pi :: 3.14159` declares an untyped float constant. The explicit form is `x: f32 = 42`.
- **The programmer can create new types** using a rich palette. The options include `struct`, `enum`, `union` (discriminated), `bit_set`, fixed arrays `[N]T`, dynamic arrays `[dynamic]T`, maps `map[K]V`, and `distinct`. The `distinct` keyword brands a new type from an existing one so the compiler refuses to mix them. The [official overview](https://odin-lang.org/docs/overview/) gives `My_Int :: distinct int` as the canonical example. Type aliases use the form `T :: U`.
- **Procedures are first-class objects.** You can declare a procedure type such as `Callback :: proc(x: int) -> int`, store procedure values in variables, pass them as arguments, return them from other procedures, and put them in arrays or structs. Odin also supports **procedure overload groups** written as `proc{a, b, c}` (example from the overview: `to_string :: proc{bool_to_string, int_to_string}`). It also supports **parametric polymorphism** using the `$T: typeid` form for compile-time type parameters.
- The `any` type exists and carries runtime type info. Idiomatic Odin reaches for generics long before it reaches for `any`.

Because the type system is static and strong, almost every bug that would be a runtime type error in a dynamic language surfaces at compile time in Odin.

## (d) Control Structures

**Selection:**

- `if` / `else if` / `else`: no parentheses around the condition. Braces are required, or the one-liner form `if cond do stmt`. It supports an init clause, for example `if v, ok := lookup(k); ok { ... }`.
- `switch`: no implicit fallthrough. There is an explicit `fallthrough` keyword when you want it. You can put multiple values per case, use range cases like `case 0..=9:`, and run **type switches** on unions using `switch v in value { case int: ... }`.
- `when`: a **compile-time** `if`. The arms that fail the condition are never type-checked or emitted. This is how Odin does conditional compilation without a preprocessor.

**Repetition:**

- C-style: `for i := 0; i < n; i += 1 { ... }`.
- Range-based: `for i in 0..<n` is a half-open range, `for i in 0..=n` is a closed range.
- Iterator-based: `for v, i in slice { ... }` or `for k, v in some_map { ... }`.
- Infinite: a bare `for { ... }`.

**Other flow tools:**

- `defer stmt`: runs `stmt` at scope exit in LIFO order. This is the standard idiom for `delete`, `close`, `builder_destroy`, and similar cleanup calls. Odin's `defer` is at scope exit, not at function return like Go's.
- `break` and `continue`, optionally with **labels** to target an outer loop.
- Error-flow operators: `or_return`, `or_else`, `or_break`, `or_continue`. Together they give multi-value error handling a terse style that feels similar to Rust's `?` operator, but without a `Result` type.

## (e) Semantics

- **Scoping is lexical (static)**, with block scope. Every `{ ... }` opens a new scope. The `using` keyword can promote a struct's fields or an imported package's names into the current scope explicitly.
- **Constants** use the `::` operator and are fully compile-time evaluated. Examples are `PI :: 3.14159`, `MAX_ITER :: 100`, and `Color :: enum { Red, Green, Blue }`. Constants can be untyped (polymorphic over numeric types) or given an explicit type. Because they exist at compile time, they are usable in `when` branches, array-length positions, and other constant contexts.
- **Storage allocation** is explicit and split across three regions:
  - *Static*: package-level variables and constants.
  - *Stack-dynamic*: local variables, fixed-size arrays `[N]T`, and any `struct` value whose size is known at compile time.
  - *Heap-dynamic*: anything allocated through `make` (dynamic arrays, maps, slices) or `new`. Allocation routes through an implicit `context.allocator`. The programmer can swap this allocator per-scope.
- **Garbage collection: none.** Odin has no runtime GC. Memory is freed explicitly with `delete` or `free`. The idiom is to pair the allocation with a `defer` at the allocation site so the cleanup is impossible to forget:

  ```odin
  xs := make([dynamic]int, 0, 16)
  defer delete(xs)
  ```

  The [`core:mem` package](https://pkg.odin-lang.org/core/mem/) ships a tracking allocator (`mem.Tracking_Allocator`) that reports leaks in debug builds, and an arena allocator (`mem.Arena`) for bulk deallocation.

## (f) Desirable Language Characteristic: Efficiency

Topic 2 covered four categories of desirable characteristics: Efficiency, Regularity, Security and Reliability, and Extensibility. Of those four, **Efficiency** is the one Odin leans hardest into. It is the characteristic that every other design decision seems to serve.

**Features that support efficiency:**

- **No garbage collector, no hidden runtime.** There are no stop-the-world pauses. There are no write barriers. There are no background threads scanning the heap. A procedure's runtime cost is visible on the page.
- **Explicit allocators via `context.allocator`.** Swapping to an arena or scratch allocator is a one-line change. It eliminates per-object `malloc` and `free` costs for an entire subsystem. Cache locality becomes something the programmer designs for, not something they pray about.
- **SOA (struct-of-arrays) as a language feature.** `v: #soa[N]Particle` transposes a struct array so that each field is stored contiguously. That layout is ideal for SIMD and cache line efficiency. Doing the same thing by hand in C would be a lot of bookkeeping.
- **Built-in `matrix` and fixed-array arithmetic.** Expressions like `c := a + b` on fixed-size arrays compile to vector-friendly code without intrinsics.
- **Zero-cost abstractions.** Generics are monomorphized at compile time. `when` arms that fail are omitted entirely. Procedure calls can be forced inline with `#force_inline`.
- **Calling conventions under programmer control.** Odin supports the `"contextless"` calling convention, which omits the hidden context pointer, and direct `"c"` ABI interop, so you can drop to the metal where it matters.
- **Compile times are a design constraint.** Odin compiles whole-program. There are no header files and no template instantiation explosion. Iteration is fast. That matters for development efficiency as well as runtime efficiency.

**Where efficiency comes at a cost.** The programmer owns memory lifetime. Beginners hit use-after-free and leak bugs that a garbage-collected language would never allow. The tracking allocator catches leaks in debug builds, but dangling pointers are on you. In short, Odin hands you a sharp knife and trusts you to hold it by the handle. That tradeoff is the one Odin is most willing to make: efficient by default, safe only if you write it safely.

---

## About the Common Program (Part 2)

The Part 2 submission is a global-thresholding image segmenter written in Odin. It reads an ASCII PGM (P2) file from the command line. It then converges on a threshold using the two-means algorithm from the assignment. The algorithm starts from the mean of 10 randomly chosen pixels. It repeatedly sets the threshold to the mean of the below-threshold and above-threshold partition means. It stops when the change is under 0.001 or 100 iterations have elapsed. Finally, it writes a PBM (P1) file with the same basename.

The program exercises several parts of Odin's core library. It uses file I/O from [`core:os`](https://pkg.odin-lang.org/core/os/). It uses string tokenization from [`core:strings`](https://pkg.odin-lang.org/core/strings/) and [`core:strconv`](https://pkg.odin-lang.org/core/strconv/). It uses random-number generation from [`core:math/rand`](https://pkg.odin-lang.org/core/math/rand/), seeded from the monotonic clock in [`core:time`](https://pkg.odin-lang.org/core/time/). It also uses the `defer`-based cleanup idiom that stands in for a garbage collector.

**Source:** [`threshold.odin`](https://raw.githubusercontent.com/vetr0s/odin-language-study/refs/heads/main/threshold.odin). The source is a single file of about 180 lines. You can build it with `odin build threshold.odin -file -out:threshold`.
