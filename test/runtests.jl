using StackTraces
using FactCheck


@noinline child() = stacktrace()
@noinline parent() = child()
grandparent() = parent()

@noinline bad_function() = nonexistent_var
function good_function()
    try
        bad_function()
    catch
        return catch_stacktrace()
    end
end

format_stack = [
    StackFrame(:frame1, "path/file.1", 10, Symbol(""), -1, false),
    StackFrame(:frame2, "path/file.2", 20, Symbol(""), -1, false)
]

facts() do
    context("basic") do
        stack = grandparent()
        @fact stack[1:3] --> [
            StackFrame(:child, @__FILE__, 5, Symbol(""), -1, false),
            StackFrame(:parent, @__FILE__, 6, Symbol(""), -1, false),
            StackFrame(:grandparent, @__FILE__, 7, Symbol(""), -1, false)
        ]
    end

    context("try...catch") do
        stack = good_function()
        @fact stack[1:2] --> [
            StackFrame(:bad_function, @__FILE__, 9, Symbol(""), -1, false),
            StackFrame(:good_function, @__FILE__, 12, Symbol(""), -1, false)
        ]
    end

    context("formatting") do
        @fact format_stackframe(format_stack[1]) --> "frame1 at path/file.1:10"
        @fact format_stacktrace(format_stack, ", ", "{", "}") -->
            "{frame1 at path/file.1:10, frame2 at path/file.2:20}"
    end

    context("output") do
        io = IOBuffer()
        show_stacktrace(io, format_stack)
        @fact takebuf_string(io) -->
            """
            StackTrace with 2 StackFrames:
              frame1 at path/file.1:10
              frame2 at path/file.2:20
            """
    end
end

FactCheck.exitstatus()
