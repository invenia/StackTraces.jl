# StackTraces.jl

[![Build Status](https://travis-ci.org/invenia/StackTraces.jl.svg?branch=master)](https://travis-ci.org/invenia/StackTraces.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/24lp146n8bk848e6?svg=true)](https://ci.appveyor.com/project/spurll/stacktraces-jl)
[![codecov.io](https://codecov.io/github/invenia/StackTraces.jl/coverage.svg?branch=master)](https://codecov.io/github/invenia/StackTraces.jl?branch=master)

`StackTraces.jl` provides simple stack traces that are both human readable and easy to use programmatically.

## Quick Start

```julia
Pkg.add("StackTraces")
```

### Viewing a Stack Trace

The primary function used to obtain a stack trace is `stacktrace`:

```julia
julia> using StackTraces

julia> stacktrace()
2-element Array{StackTraces.StackFrame,1}:
 StackTraces.StackFrame(:eval_user_input,symbol("REPL.jl"),62,symbol(""),-1,false,13041465684)
 StackTraces.StackFrame(:anonymous,symbol("REPL.jl"),92,symbol("task.jl"),63,false,1304140086)
```

Calling `stacktrace` returns a vector of `StackFrame`s. For ease of use, the alias `StackTrace` can be used in place of `Vector{StackFrame}`.

```julia
julia> example() = stacktrace()
example (generic function with 1 method)

julia> example()
3-element Array{StackTraces.StackFrame,1}:
 StackTraces.StackFrame(:example,:none,1,symbol(""),-1,false,13041535346)
 StackTraces.StackFrame(:eval_user_input,symbol("REPL.jl"),62,symbol(""),-1,false,13041465684)
 StackTraces.StackFrame(:anonymous,symbol("REPL.jl"),92,symbol("task.jl"),63,false,13041400866)
```

If you'd like the output to be a little more human-readable, replace calls to `stacktrace` (which returns a vector of `StackFrame`s) with `show_stacktrace` (which prints the stacktrace to an IO stream).

```julia
julia> example() = show_stacktrace()
example (generic function with 1 method)

julia> example()
StackTrace with 3 StackFrames:
  example at none:1
  eval_user_input at REPL.jl:62
  [inlined code from REPL.jl:92] anonymous at task.jl:63
```

Note that when calling `stacktrace` from the REPL you'll always have those last two frames in the stack from `REPL.jl` (including the anonymous function from `task.jl`).

```julia
julia> @noinline child() = show_stacktrace()
child (generic function with 1 method)

julia> @noinline parent() = child()
parent (generic function with 1 method)

julia> grandparent() = parent()
grandparent (generic function with 1 method)

julia> grandparent()
StackTrace with 5 StackFrames:
  child at none:1
  parent at none:1
  grandparent at none:1
  eval_user_input at REPL.jl:62
  [inlined code from REPL.jl:92] anonymous at task.jl:63
```

### Extracting Useful Information

Each `StackFrame` contains the function name, file name, line number, file and line information for inlined functions, a flag indicating whether it is a C function (by default C functions do not appear in the stack trace), and an integer representation of the pointer returned by `backtrace`:

```julia
julia> top_frame = stacktrace()[1]
StackTraces.StackFrame(:eval_user_input,symbol("REPL.jl"),62,symbol(""),-1,false, 13203085684)

julia> top_frame.func
:eval_user_input

julia> top_frame.file
symbol("REPL.jl")

julia> top_frame.line
62

julia> top_frame.inlined_file
symbol("")

julia> top_frame.inlined_line
-1

julia> top_frame.from_c
false

julia> top_frame.pointer
13203085684
```

This makes stack trace information available programmatically without having to capture and parse the output from something like `Base.show_backtrace(io, backtrace())`.

### Error Handling

While having easy access to information about the current state of the callstack can be helpful in many places, the most obvious application is in error handling and debugging.

``` julia
julia> example() = try
           error("Oh no!")
       catch
           show_stacktrace()
       end
example (generic function with 1 method)

julia> example()
StackTrace with 3 StackFrames:
  example at none:4
  eval_user_input at REPL.jl:62
  [inlined code from REPL.jl:92] anonymous at task.jl:63
```

You may notice that in the example above the first stack frame points points at line 4, where `stacktrace` is called, rather than line 2, where the error occurred. While in this example it's trivial to track down the actual source of the error, things can get misleading pretty quickly if the stack trace doesn't even point to the right function.

This can be remedied by calling `catch_stacktrace` instead of `stacktrace`. Instead of returning callstack information for the current context, `catch_stacktrace` returns stack information for the context of the most recent error:

``` julia
julia> example() = try
           error("Oh no!")
       catch
           show_stacktrace(catch_stacktrace())
       end
example (generic function with 1 method)

julia> example()
StackTrace with 3 StackFrames:
  example at none:2
  eval_user_input at REPL.jl:62
  [inlined code from REPL.jl:92] anonymous at task.jl:63
```

Notice that the stack trace now indicates the appropriate line number.

```julia
julia> @noinline child() = error("Whoops!")
child (generic function with 1 method)

julia> @noinline parent() = child()
parent (generic function with 1 method)

julia> function grandparent()
           try
               parent()
           catch err
               println("ERROR: ", err.msg)
               show_stacktrace(catch_stacktrace())
           end
       end
grandparent (generic function with 1 method)

julia> grandparent()
ERROR: Whoops!
StackTrace with 5 StackFrames:
  child at none:1
  parent at none:1
  grandparent at none:3
  eval_user_input at REPL.jl:62
  [inlined code from REPL.jl:92] anonymous at task.jl:63
```

## Architecture and API

### Types

`StackFrame` is an immutable type with the following fields:

* `func::Symbol`: the name of the function containing the execution context
* `file::Symbol`: the path to the file containing the execution context
* `line::Integer`: the line number in the file containing the execution context
* `inlined_file::Symbol`: the path to the file containing the context for inlined code
* `inlined_line::Integer`: the line number in the file containing the context for inlined code
* `from_c::Bool`: true if the function is from C
* `pointer::Int64`: a representation of the pointer to the stack context as returned by `backtrace`

`StackTrace` is an alias for `Vector{StackFrame}` (or `Array{StackFrame, 1}`), provided for convenience. Calls to `stacktrace` return `StackTrace`s.

Neither `StackTrace` nor `StackFrame` are exported.

### Functions

#### stacktrace

```julia
stacktrace(trace::Vector{Ptr{Void}}, c_funcs::Bool)
```

Returns a `StackTrace` (vector of `StackFrame`s) representing either the current context or a context provided by output from a previous call to `backtrace`.

* `trace` (optional): output from a call to `backtrace` to be turned into a vector of `StackFrame`s
* `c_funcs` (optional): true to include C calls in the resulting vector of `StackFrame`s (by default, C calls are removed)

#### catch\_stacktrace

```julia
catch_stacktrace(c_funcs::Bool)
```

Returns a `StackTrace` representing context of the current (most recent) exception.

#### show\_stacktrace

```julia
show_stacktrace(io::IO, stack::StackTrace; full_path::Bool)
```

For those accustomed to calling `Base.show_backtrace`, `StackTraces.jl` also includes a `show_stacktrace` function that provides handy formatted output.

* `io` (optional): the I/O stream to use for output (defaults to `STDOUT`)
* `stack` (optional): the stack trace to output (defaults to `stacktrace()`)
* `full_path` (optional kwarg): true to include full path information for files in the trace (defaults to `false`)

```julia
julia> show_stacktrace()
StackTrace with 2 StackFrames:
  eval_user_input at REPL.jl:62
  [inlined code from REPL.jl:92] anonymous at task.jl:63
```

#### format\_stacktrace

```julia
format_stacktrace(stack::StackTrace, separator::AbstractString, start::AbstractString, finish::AbstractString; full_path::Bool)
```

Returns a human-readable string representing a formatted `StackTrace`.

* `stack`: the stack trace to format
* `separator`: a string to use to separate each stack frame
* `start` (optional): a string with which to prepend the formatted stack trace
* `finish` (optional): a string to append to the formatted stack trace
* `full_path` (optional kwarg): true to include full path information for files in the trace (defaults to `false`)

```julia
julia> format_stacktrace(stacktrace(), ", ", "{", "}")
"{eval_user_input at REPL.jl:62, [inlined code from REPL.jl:92] anonymous at task.jl:63}"
```

You can, of course, format `StackTrace`s yourself by looping through (or `map`ing) the elements.

#### format\_stackframe

```julia
format_stackframe(frame::StackFrame; full_path::Bool)
```

Returns a human-readable string representing a formatted `StackFrame`.

* `frame`: the stack frame to format
* `full_path` (optional kwarg): true to include full path information for files in the frame (defaults to `false`)

```julia
julia> format_stackframe(stacktrace()[1])
"eval_user_input at REPL.jl:62"
```

## Comparison with `backtrace`

Developers familiar with Julia's `backtrace` function, which returns a vector of `Ptr{Void}`, may be interested to know that you can pass that vector into `stacktrace`:

```julia
julia> stack = backtrace()
15-element Array{Ptr{Void},1}:
 Ptr{Void} @0x000000010e9562ed
 Ptr{Void} @0x0000000312f95f20
 Ptr{Void} @0x0000000312f95ea0
 Ptr{Void} @0x000000010e8e5776
 Ptr{Void} @0x000000010e950c04
 Ptr{Void} @0x000000010e94f2a8
 Ptr{Void} @0x000000010e94f137
 Ptr{Void} @0x000000010e95070d
 Ptr{Void} @0x000000010e95053f
 Ptr{Void} @0x000000010e963348
 Ptr{Void} @0x000000010e8edd67
 Ptr{Void} @0x0000000312f71974
 Ptr{Void} @0x0000000312f715c7
 Ptr{Void} @0x0000000312f65c22
 Ptr{Void} @0x000000010e95708f

julia> stacktrace(stack)
3-element Array{StackTraces.StackFrame,1}:
 StackTraces.StackFrame(:backtrace,symbol("error.jl"),26,symbol(""),-1,false,13203234592)
 StackTraces.StackFrame(:eval_user_input,symbol("REPL.jl"),62,symbol(""),-1,false,13203085684)
 StackTraces.StackFrame(:anonymous,symbol("REPL.jl"),92,symbol("task.jl"),63,false,13203037218)
```

You may notice that the vector returned by `backtrace` had 15 pointers, but the vector returned by `stacktrace` only had 3. This is because, by default, `stacktrace` removes any lower-level C functions from the stack. If you want to include stack frames from C calls, you can do it like this:

```julia
julia> stacktrace(stack, true)
15-element Array{StackTraces.StackFrame,1}:
 StackTraces.StackFrame(:rec_backtrace,symbol("/private/tmp/julia20151107-44794-o1d6wy/src/task.c"),644,symbol("/private/tmp/julia20151107-44794-o1d6wy/src/task.c"),703,true,4539638509)
 StackTraces.StackFrame(:backtrace,symbol("error.jl"),26,symbol(""),-1,false,13203234592)
 StackTraces.StackFrame(:jlcall_backtrace_21483,symbol(""),-1,symbol(""),-1,true,13203234464)
 StackTraces.StackFrame(:jl_apply,symbol("/private/tmp/julia20151107-44794-o1d6wy/src/gf.c"),1691,symbol("/private/tmp/julia20151107-44794-o1d6wy/src/gf.c"),1708,true,4539176822)
 StackTraces.StackFrame(:jl_apply,symbol("/private/tmp/julia20151107-44794-o1d6wy/src/interpreter.c"),55,symbol("/private/tmp/julia20151107-44794-o1d6wy/src/interpreter.c"),65,true,4539616260
 StackTraces.StackFrame(:eval,symbol("/private/tmp/julia20151107-44794-o1d6wy/src/interpreter.c"),213,symbol(""),-1,true,4539609768)
 StackTraces.StackFrame(:eval,symbol("/private/tmp/julia20151107-44794-o1d6wy/src/interpreter.c"),219,symbol(""),-1,true,4539609399)
 StackTraces.StackFrame(:eval_body,symbol("/private/tmp/julia20151107-44794-o1d6wy/src/interpreter.c"),592,symbol(""),-1,true,4539614989)
 StackTraces.StackFrame(:jl_toplevel_eval_body,symbol("/private/tmp/julia20151107-44794-o1d6wy/src/interpreter.c"),527,symbol(""),-1,true,4539614527)
 StackTraces.StackFrame(:jl_toplevel_eval_flex,symbol("/private/tmp/julia20151107-44794-o1d6wy/src/toplevel.c"),521,symbol(""),-1,true,4539691848)
 StackTraces.StackFrame(:jl_toplevel_eval_in,symbol("/private/tmp/julia20151107-44794-o1d6wy/src/builtins.c"),579,symbol(""),-1,true,4539211111)
 StackTraces.StackFrame(:eval_user_input,symbol("REPL.jl"),62,symbol(""),-1,false,13203085684)
 StackTraces.StackFrame(:jlcall_eval_user_input_21232,symbol(""),-1,symbol(""),-1,true,13203084743)
 StackTraces.StackFrame(:anonymous,symbol("REPL.jl"),92,symbol("task.jl"),63,false,13203037218)
 StackTraces.StackFrame(:jl_apply,symbol("/private/tmp/julia20151107-44794-o1d6wy/src/task.c"),241,symbol("/private/tmp/julia20151107-44794-o1d6wy/src/task.c"),240,true,4539641999)
```

## License

StackTraces.jl is provided under the MIT "Expat" License. See `LICENSE.md` for details.
