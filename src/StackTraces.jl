module StackTraces


export StackFrame, StackTrace
export stacktrace, catch_stacktrace, format_stacktrace, format_stackframe, show_stacktrace


immutable StackFrame
    name::Symbol
    file::Symbol
    line::Int
    inline_file::Symbol
    inline_line::Int
    from_c::Bool
end

typealias StackTrace Vector{StackFrame}


"""
Returns a stack trace in the form of a vector of StackFrames. Each StackFrame contains a
function name, a file name, a line number, and a flag indicating whether it's a C function.
(By default `stacktrace` doesn't return C functions, but this can be enabled.)
"""
function stacktrace(trace::Vector{Ptr{Void}}, c_funcs::Bool=false)
    stack = [
        ccall(:jl_lookup_code_address, Any, (Ptr{Void}, Cint), frame, 0)
        for frame in trace
    ]

    # Convert the vector of tuples into a vector of StackFrames.
    stack = StackFrame[
        StackFrame(frame[1:6]...) for frame in filter(f -> f !== nothing, stack)
    ]

    # Remove frames that come from C calls.
    if !c_funcs
        filter!(frame -> !frame.from_c, stack)
    end

    # Remove frame for this function (and any functions called by this function).
    remove_frames!(stack, :stacktrace)
end

stacktrace(c_funcs::Bool=false) = stacktrace(backtrace(), c_funcs)

"""
Returns the stack trace for the most recent error thrown, rather than the current context.
"""
catch_stacktrace(c_funcs::Bool=false) = stacktrace(catch_backtrace(), c_funcs)

"""
Takes a StackTrace (a vector of StackFrames) and a function name (a Symbol) and removes the
StackFrame specified by the function name from the StackTrace (also removing all functions
above the specified function). Primarily used to remove StackTraces functions from the Stack
prior to returning it.
"""
function remove_frames!(stack::StackTrace, name::Symbol)
    splice!(stack, 1:findlast(frame -> frame.name == name, stack))
    return stack
end

function remove_frames!(stack::StackTrace, names::Vector{Symbol})
    splice!(stack, 1:findlast(frame -> in(frame.name, names), stack))
    return stack
end

function format_stackframe(frame::StackFrame)
    string(frame.name != "" ? frame.name : "?", " at ", frame.file, ":", frame.line)
end

function format_stacktrace(
    stack::StackTrace, separator::AbstractString, start::AbstractString="",
    finish::AbstractString=""
)
    if isempty(stack)
        return ""
    end

    string(start, join(map(format_stackframe, stack), separator), finish)
end

# Convenient analogue of Base.show_backtrace.
function show_stacktrace(io::IO, stack::StackTrace)
    println(
        io, "StackTrace with $(length(stack)) StackFrames$(isempty(stack) ? "" : ":")",
        format_stacktrace(stack, "\n  ", "\n  ")
    )
end

show_stacktrace() = show_stacktrace(STDOUT)

function show_stacktrace(io::IO)
    show_stacktrace(io, remove_frames!(stacktrace(), :show_stacktrace))
end

show_stacktrace(stack::StackTrace) = show_stacktrace(STDOUT, stack)


end
