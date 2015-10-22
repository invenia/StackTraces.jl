using StackTraces
using FactCheck

# write your own tests here
# @test 1 == 1

PATH = Symbol(abspath("test/runtests.jl"))

# Calls are made by splatting an empty array because this (currently) prevents Julia from
# optimizing (collapsing) these simple functions (and such optimizations change the stack
# trace).
child() = stacktrace()
parent() = child([]...)
grandparent() = parent([]...)

bad_function() = error("Whoops!")
function good_function()
    try
        bad_function([]...)
    catch
        return catch_stacktrace()
    end
end

facts() do
    context("basic") do
        stack = grandparent()
        @fact stack[1:3] --> [
            StackFrame(:child, PATH, 12, false),
            StackFrame(:parent, PATH, 13, false),
            StackFrame(:grandparent, PATH, 14, false)
        ]
    end

    context("try...catch") do
        stack = good_function()
        @fact stack[1:2] --> [
            StackFrame(:bad_function, PATH, 16, false),
            StackFrame(:good_function, PATH, 19, false)
        ]
    end
end

FactCheck.exitstatus()
