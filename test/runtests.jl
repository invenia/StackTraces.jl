using StackTraces
using FactCheck


@noinline child() = stacktrace()
@noinline parent() = child()
@noinline grandparent() = parent()

@noinline bad_function() = nonexistent_var
@noinline function good_function()
    try
        bad_function()
    catch
        return catch_stacktrace()
    end
end

format_stack = [
    StackFrame(:frame1, "path/file.1", 10, "path/file.inline", 0, false, 0),
    StackFrame(:frame2, "path/file.2", 20, Symbol(""), -1, false, 0)
]

facts() do
    context("basic") do
        stack = grandparent()
        @fact [:child, :parent, :grandparent] --> [f.func for f in stack[1:3]]
        for (line, frame) in zip(5:7, stack[1:3])
            @fact [Symbol(@__FILE__), line] -->
                anyof([frame.file, frame.line], [frame.inlined_file, frame.inlined_line])
        end
        @fact [false, false, false] --> [f.from_c for f in stack[1:3]]
    end

    context("from_c") do
        default, with_c, without_c = stacktrace(), stacktrace(true), stacktrace(false)
        @fact default --> without_c
        @fact length(with_c) --> greater_than(length(without_c))
        @fact filter(frame -> frame.from_c, with_c) --> not(isempty)
        @fact filter(frame -> frame.from_c, without_c) --> isempty
    end

    context("remove_frames!") do
        stack = StackTraces.remove_frames!(grandparent(), :parent)
        @fact stack[1] --> StackFrame(:grandparent, @__FILE__, 7, Symbol(""), -1, false, 0)

        stack = StackTraces.remove_frames!(grandparent(), [:child, :something_nonexistent])
        @fact stack[1:2] --> [
            StackFrame(:parent, @__FILE__, 6, Symbol(""), -1, false, 0),
            StackFrame(:grandparent, @__FILE__, 7, Symbol(""), -1, false, 0)
        ]
    end

    context("try...catch") do
        stack = good_function()
        @fact stack[1:2] --> [
            StackFrame(:bad_function, @__FILE__, 9, Symbol(""), -1, false, 0),
            StackFrame(:good_function, @__FILE__, 12, Symbol(""), -1, false, 0)
        ]
    end

    context("formatting") do
        context("frame") do
            @fact format_stackframe(format_stack[1]) -->
                "[inlined code from file.1:10] frame1 at file.inline:0"
            @fact format_stackframe(format_stack[1]; full_path=true) -->
                "[inlined code from path/file.1:10] frame1 at path/file.inline:0"

            @fact format_stackframe(format_stack[2]) --> "frame2 at file.2:20"
            @fact format_stackframe(format_stack[2]; full_path=true) -->
                "frame2 at path/file.2:20"
        end

        context("stack") do
            @fact format_stacktrace(format_stack, ", ") -->
                "[inlined code from file.1:10] frame1 at file.inline:0, frame2 at file.2:20"
            @fact format_stacktrace(format_stack, ", "; full_path=true) -->
                string(
                    "[inlined code from path/file.1:10] ",
                    "frame1 at path/file.inline:0, frame2 at path/file.2:20"
                )

            @fact format_stacktrace(format_stack, ", ", "Stack: ") -->
                string(
                    "Stack: [inlined code from file.1:10] ",
                    "frame1 at file.inline:0, frame2 at file.2:20"
                )
            @fact format_stacktrace(format_stack, ", ", "Stack: "; full_path=true) -->
                string(
                    "Stack: [inlined code from path/file.1:10] ",
                    "frame1 at path/file.inline:0, frame2 at path/file.2:20"
                )

            @fact format_stacktrace(format_stack, ", ", "{", "}") -->
                string(
                    "{[inlined code from file.1:10] ",
                    "frame1 at file.inline:0, frame2 at file.2:20}"
                )
            @fact format_stacktrace(format_stack, ", ", "{", "}", full_path=true) -->
                string(
                    "{[inlined code from path/file.1:10] ",
                    "frame1 at path/file.inline:0, frame2 at path/file.2:20}"
                )
        end

        context("empty") do
            @fact format_stacktrace(StackTrace(), ", ") --> ""
            @fact format_stacktrace(StackTrace(), ", ", "Stack: ") --> ""
            @fact format_stacktrace(StackTrace(), ", ", "{", "}") --> ""
        end
    end

    context("output") do
        io = IOBuffer()
        show_stacktrace(io, format_stack)
        @fact takebuf_string(io) -->
            """
            StackTrace with 2 StackFrames:
              [inlined code from file.1:10] frame1 at file.inline:0
              frame2 at file.2:20
            """
        show_stacktrace()   # Improves code coverage.
    end
end

FactCheck.exitstatus()
