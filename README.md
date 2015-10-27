# StackTraces.jl

[![Build Status](https://travis-ci.org/invenia/StackTraces.jl.svg?branch=master)](https://travis-ci.org/invenia/StackTraces.jl)

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
 StackTraces.StackFrame(:eval_user_input,symbol("REPL.jl"),62,symbol(""),-1,false) 
 StackTraces.StackFrame(:anonymous,symbol("REPL.jl"),92,symbol("task.jl"),90,false)
```

Calling `stacktrace` returns a vector of `StackFrame`s. For ease of use, the alias `StackTrace` can be used in place of `Vector{StackFrame}`.

```julia
julia> example() = stacktrace()
example (generic function with 1 method)

julia> example()
3-element Array{StackTraces.StackFrame,1}:
 StackTraces.StackFrame(:example,:none,1,symbol(""),-1,false)                      
 StackTraces.StackFrame(:eval_user_input,symbol("REPL.jl"),62,symbol(""),-1,false) 
 StackTraces.StackFrame(:anonymous,symbol("REPL.jl"),92,symbol("task.jl"),90,false)
```

If you'd like the output to be a little more human-readable, replace calls to `stacktrace` (which returns a vector of `StackFrame`s) with `show_stacktrace` (which prints the stacktrace to an IO stream).

```julia
julia> example() = show_stacktrace()
example (generic function with 1 method)

julia> example()
StackTrace with 3 StackFrames:
  example at none:1
  eval_user_input at REPL.jl:62
  anonymous at REPL.jl:92
```

Note that when calling `stacktrace` from the REPL you'll always have those last two frames in the stack (`eval_user_input` from `REPL.jl` and `anonymous` from `task.jl`).

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
  anonymous at task.jl:91
```

### Extracting Useful Information

Each `StackFrame` contains the function name, file name, line number, file and line information for inlined functions, and a flag indicating whether it is a C function (by default C functions do not appear in the stack trace):

```julia
julia> top_frame = stacktrace()[1]
StackTraces.StackFrame(:eval_user_input,symbol("REPL.jl"),62,symbol(""),-1,false)

julia> top_frame.name
:eval_user_input

julia> top_frame.file
symbol("REPL.jl")

julia> top_frame.line
62

julia> top_frame.inline_file
symbol("")

julia> top_frame.inline_line
-1

julia> top_frame.from_c
false
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
  anonymous at task.jl:91
```

You may notice that in the example above the first stack frame points points at line 4, where `stacktraces` is called, rather than line 2, where the error occurred. While in this example it's trivial to track down the actual source of the error, things can get misleading pretty quickly if the stack trace doesn't even point to the right function:

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
  anonymous at task.jl:91
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
  anonymous at task.jl:91
```

## Architecture and API

### Types

`StackFrame` is an immutable type with the following fields:

* `name::Symbol`: the name of the function being executed
* `file::Symbol`: the name of the file that contains the function
* `line::Integer`: the line number in the file
* `inline_file::Symbol`: the name of the file that contains the inlined function
* `inline_line::Integer`: the line number in the file containing the inlined function
* `from_c::Bool`: true if the function is from C (rather than Julia)

`StackTrace` is an alias for `Vector{StackFrame}` (or `Array{StackFrame, 1}`), provided for convenience. Calls to `stacktrace` return `StackTrace`s.

### Functions

#### stacktrace

```julia
stacktrace(trace::Vector{Ptr{Void}}, c_funcs::Bool)
```

Returns a `StackTrace` (vector of `StackFrame`s) representing either the current context or a context provided by output from a previous call to `Base.backtrace`.

* `trace` (optional): output from a call to `backtrace` to be turned into a vector of `StackFrame`s
* `c_funcs` (optional): true to include C calls in the resulting vector of `StackFrame`s (by default, C calls are removed)

#### catch\_stacktrace

```julia
catch_stacktrace(c_funcs::Bool)
```

Returns a `StackTrace` representing context of the current (most recent) exception.

#### show\_stacktrace

```julia
show_stacktrace(io::IO, stack::StackTrace)
```

For those accustomed to calling `Base.show_backtrace`, `StackTraces.jl` also includes a `show_stacktrace` function that provides handy formatted output.

* `io` (optional): the I/O stream to use for output (defaults to `STDOUT`)
* `stack` (optional): the stack trace to output (defaults to `stacktrace()`)

```julia
julia> show_stacktrace()
StackTrace with 2 StackFrames:
  eval_user_input at REPL.jl:62
  anonymous at task.jl:91
```

#### format\_stacktrace

```julia
format_stacktrace(stack::StackTrace, separator::AbstractString, start::AbstractString, finish::AbstractString)
```

Returns a human-readable string representing a formatted `StackTrace`.

* `stack`: the stack trace to format
* `separator`: a string to use to separate each stack frame
* `start` (optional): a string with which to prepend the formatted stack trace
* `finish` (optional): a string to append to the formatted stack trace

```julia
julia> format_stacktrace(stacktrace(), ", ", "{", "}")
"{eval_user_input at REPL.jl:62, anonymous at task.jl:91}"
```

You can, of course, format `StackTrace`s yourself by looping through (or `map`ing) the elements yourself.

#### format\_stackframe

```julia
format_stackframe(frame::StackFrame)
```

Returns a human-readable string representing a formatted `StackFrame`.

* `frame`: the stack frame to format

```julia
julia> format_stackframe(stacktrace()[1])
"eval_user_input at REPL.jl:62"
```

## Comparison with `Base.backtrace`

Developers familiar with Julia's `backtrace` function, which returns a vector of `{Ptr{Void}`, may be interested to know that you can pass that vector into `stacktrace`:

```julia
julia> stack = backtrace()
15-element Array{Ptr{Void},1}:
 Ptr{Void} @0x000000010face4ad
 Ptr{Void} @0x0000000314157630
 Ptr{Void} @0x00000003141575b0
 Ptr{Void} @0x000000010fa5e086
 Ptr{Void} @0x000000010fac8c65
 Ptr{Void} @0x000000010fac7301
 Ptr{Void} @0x000000010fac718c
 Ptr{Void} @0x000000010fac876d
 Ptr{Void} @0x000000010fac85a0
 Ptr{Void} @0x000000010fadb8cb
 Ptr{Void} @0x000000010fa666e7
 Ptr{Void} @0x0000000314138984
 Ptr{Void} @0x00000003141385d7
 Ptr{Void} @0x000000031412cc22
 Ptr{Void} @0x000000010facf28f

julia> stacktrace(stack)
3-element Array{StackTraces.StackFrame,1}:
 StackTraces.StackFrame(:backtrace,symbol("error.jl"),26,symbol(""),-1,false)      
 StackTraces.StackFrame(:eval_user_input,symbol("REPL.jl"),62,symbol(""),-1,false) 
 StackTraces.StackFrame(:anonymous,symbol("REPL.jl"),92,symbol("task.jl"),90,false)
```

You may notice that the vector returned by `Base.backtrace` had 15 pointers, but the vector returned by `stacktrace` only had 3. This is because, by default, `stacktrace` removes any lower-level C functions from the stack. If you want to include stack frames from C calls, you can do it like this:

```julia
julia> stacktrace(stack, true)
15-element Array{StackTraces.StackFrame,1}:
 StackTraces.StackFrame(:rec_backtrace,symbol("/private/tmp/julia20151023-27429-gjs30g/src/task.c"),644,symbol("/private/tmp/julia20151023-27429-gjs30g/src/task.c"),703,true)
 StackTraces.StackFrame(:backtrace,symbol("error.jl"),26,symbol(""),-1,false)
 StackTraces.StackFrame(:jlcall_backtrace_21562,symbol(""),-1,symbol(""),-1,true)
 StackTraces.StackFrame(:jl_apply,symbol("/private/tmp/julia20151023-27429-gjs30g/src/gf.c"),1691,symbol("/private/tmp/julia20151023-27429-gjs30g/src/gf.c"),1708,true)
 StackTraces.StackFrame(:jl_apply,symbol("/private/tmp/julia20151023-27429-gjs30g/src/interpreter.c"),55,symbol("/private/tmp/julia20151023-27429-gjs30g/src/interpreter.c"),65,true)
 StackTraces.StackFrame(:eval,symbol("/private/tmp/julia20151023-27429-gjs30g/src/interpreter.c"),213,symbol(""),-1,true)
 StackTraces.StackFrame(:eval,symbol("/private/tmp/julia20151023-27429-gjs30g/src/interpreter.c"),219,symbol(""),-1,true)
 StackTraces.StackFrame(:eval_body,symbol("/private/tmp/julia20151023-27429-gjs30g/src/interpreter.c"),592,symbol(""),-1,true)
 StackTraces.StackFrame(:jl_toplevel_eval_body,symbol("/private/tmp/julia20151023-27429-gjs30g/src/interpreter.c"),527,symbol(""),-1,true)
 StackTraces.StackFrame(:jl_toplevel_eval_flex,symbol("/private/tmp/julia20151023-27429-gjs30g/src/toplevel.c"),521,symbol(""),-1,true)
 StackTraces.StackFrame(:jl_toplevel_eval_in,symbol("/private/tmp/julia20151023-27429-gjs30g/src/builtins.c"),579,symbol(""),-1,true)
 StackTraces.StackFrame(:eval_user_input,symbol("REPL.jl"),62,symbol(""),-1,false)
 StackTraces.StackFrame(:jlcall_eval_user_input_21347,symbol(""),-1,symbol(""),-1,true)
 StackTraces.StackFrame(:anonymous,symbol("REPL.jl"),92,symbol("task.jl"),90,false)
 StackTraces.StackFrame(:jl_apply,symbol("/private/tmp/julia20151023-27429-gjs30g/src/task.c"),241,symbol("/private/tmp/julia20151023-27429-gjs30g/src/task.c"),240,true)
```
