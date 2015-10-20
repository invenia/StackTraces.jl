# StackTraces.jl

[![Build Status](https://travis-ci.org/invenia/StackTraces.jl.svg?branch=master)](https://travis-ci.org/spurll/StackTraces.jl)

`StackTraces.jl` provides simple stack traces that are both human readable and easy to use programmatically.

## Quick Start

```julia
Pkg.add("StackTraces")
```

### View a Stack Trace

The primary function used to obtain a stack trace is `stacktrace`:

```julia
julia> using StackTraces

julia> stacktrace()
2-element Array{StackTraces.StackFrame,1}:
   eval_user_input at REPL.jl:62
   anonymous at task.jl:91
```

`stacktrace` returns a vector of `StackFrame`s (for ease of use the alias `StackTrace` is used in place of `Vector{StackFrame}`).

```julia
julia> function example()
           return stacktrace()
       end
example (generic function with 1 method)

julia> stack = example()
3-element Array{StackTraces.StackFrame,1}:
   example at none:3            
   eval_user_input at REPL.jl:62
   anonymous at task.jl:91
```

Note that when calling `stacktrace` from the REPL, you'll always have those last two frames in the stack (`eval_user_input` from `REPL.jl` and `anonymous` from `task.jl`).

### Extracting Useful Information

Each `StackFrame` contains the function name, file name, line number, and a flag indicating whether it is a C function (by default C functions do not appear in the stack trace):

```julia
julia> top_frame = stacktrace()[1];

julia> top_frame.name
:eval_user_input

julia> top_frame.file
symbol("REPL.jl")

julia> top_frame.line
62

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
           print(stacktrace())
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
           print(catch_stacktrace())
       end
example (generic function with 1 method)

julia> example()
StackTrace with 3 StackFrames:
  example at none:2
  eval_user_input at REPL.jl:62
  anonymous at task.jl:91
```

Notice that the stack trace now indicates the appropriate line number.


### Limitations

One of the limitations of the way Julia handles stack traces is the limited information provided 

```julia
julia> function child()
           error("Can't find me!")
       end
child (generic function with 1 method)

julia> function parent()
           child()
       end
parent (generic function with 1 method)

julia> function grandparent()
           parent()
       end
grandparent (generic function with 1 method)

julia> child()
ERROR: Can't find me!
 in child at none:2

julia> parent()
ERROR: Can't find me!
 in parent at none:2

julia> grandparent()
ERROR: Can't find me!
 in grandparent at none:2
```

In a better world (and in this specific instance, sadly, Matlab qualifies), these last two calls would look like this:

```julia
julia> parent()
ERROR: Can't find me!
 in child at none:2
 in parent at none:2

julia> grandparent()
ERROR: Can't find me!
 in child at none:2
 in parent at none:2
 in grandparent at none:2
```

Because `StackTraces.jl` relies on base Julia's `backtrace` function, the current implementation is also unable to provide more detail for exceptions that "bubble up" from deeper stack levels in this way:

``` julia
julia> function grandparent()
           try
               parent()
	       catch err
               println("ERROR: ", err.msg)
               print(catch_stacktrace())
           end
       end
grandparent (generic function with 1 method)

julia> grandparent()
ERROR: Can't find me!
StackTrace with 3 StackFrames:
  grandparent at none:4
  eval_user_input at REPL.jl:62
  anonymous at task.jl:91
```

For this reason (and several others), the best solution is to wrap unsafe operations in their own try-catch blocks.

### Comparison with `backtrace`

Developers familiar with Julia's `backtrace` function, which returns a vector of `{Ptr{Void}`, may be interested to know that you can pass that vector into `stacktrace`:

```julia
julia> stack = backtrace()
15-element Array{Ptr{Void},1}:
 Ptr{Void} @0x00000001096732ad
 Ptr{Void} @0x000000030c862550
 Ptr{Void} @0x000000030c8624d0
 Ptr{Void} @0x0000000109605ad6
 Ptr{Void} @0x000000010966dc74
 Ptr{Void} @0x000000010966c066
 Ptr{Void} @0x000000010966bfd8
 Ptr{Void} @0x000000010966d5dd
 Ptr{Void} @0x000000010966d3ff
 Ptr{Void} @0x000000010967e58b
 Ptr{Void} @0x000000010960d1c6
 Ptr{Void} @0x000000030c844acd
 Ptr{Void} @0x000000030c844707
 Ptr{Void} @0x000000030c83a8ce
 Ptr{Void} @0x0000000109673f87

julia> stacktrace(stack)
3-element Array{StackTraces.StackFrame,1}:
   backtrace at error.jl:26     
   eval_user_input at REPL.jl:62
   anonymous at task.jl:91      
```

You may notice that the vector returned by `backtrace` had 15 pointers, but the vector returned by `stacktrace` only had 3. This is because, by default, `stacktrace` removes any lower-level C functions from the stack. If you want to include stack frames from C calls, you can do it like this:

```julia
julia> stacktrace(stack, true)
15-element Array{StackTraces.StackFrame,1}:
   rec_backtrace at /private/tmp/julia20150617-44010-dgl3rk/src/task.c:647               
   backtrace at error.jl:26                                                              
   jlcall_backtrace_21678 at :-1                                                         
   jl_apply at /private/tmp/julia20150617-44010-dgl3rk/src/gf.c:1632                     
   jl_apply at /private/tmp/julia20150617-44010-dgl3rk/src/interpreter.c:55              
   eval at /private/tmp/julia20150617-44010-dgl3rk/src/interpreter.c:212                 
   eval at /private/tmp/julia20150617-44010-dgl3rk/src/interpreter.c:218                 
   eval_body at /private/tmp/julia20150617-44010-dgl3rk/src/interpreter.c:592            
   jl_toplevel_eval_body at /private/tmp/julia20150617-44010-dgl3rk/src/interpreter.c:527
   jl_toplevel_eval_flex at /private/tmp/julia20150617-44010-dgl3rk/src/toplevel.c:480   
   jl_toplevel_eval_in at /private/tmp/julia20150617-44010-dgl3rk/src/builtins.c:539     
   eval_user_input at REPL.jl:62                                                         
   jlcall_eval_user_input_21465 at :-1                                                   
   anonymous at task.jl:91                                                               
   jl_apply at /private/tmp/julia20150617-44010-dgl3rk/src/task.c:234
```

For those accustomed to calling `Base.show_backtrace`, `StackTraces.jl` also includes a `show_stacktrace` function:

```julia
julia> show_stacktrace()
StackTrace with 2 StackFrames:
  eval_user_input at REPL.jl:62
  anonymous at task.jl:91
```
