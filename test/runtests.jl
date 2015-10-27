using StackTraces
using FactCheck


@noinline child() = stacktrace()
@noinline parent() = child()
grandparent() = parent()

@noinline bad_function() = error("Whoops!")
function good_function()
    try
        bad_function()
    catch
        return catch_stacktrace()
    end
end

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
        @fact stack[1].name --> :error
        @fact stack[2:3] --> [
            StackFrame(:bad_function, @__FILE__, 9, Symbol(""), -1, false),
            StackFrame(:good_function, @__FILE__, 12, Symbol(""), -1, false)
        ]
    end
end

FactCheck.exitstatus()
