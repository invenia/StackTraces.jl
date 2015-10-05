module StackTraces


export StackFrame, stacktrace, format_stacktrace, show_stacktrace


type StackFrame
    name::Symbol
    file::Symbol
    line::Integer
    from_c::Bool
end

typealias Stack Array{StackFrame, 1}


function stacktrace(c_funcs::Bool=false)
    stack = [
        ccall(:jl_lookup_code_address, Any, (Ptr{Void}, Cint), frame, 0)
        for frame in backtrace()
    ]

    # Convert the vector of tuples into a vector of StackFrames.
    stack = StackFrame[
        StackFrame(frame[1:4]...) for frame in filter(f -> f !== nothing, stack)
    ]

    # Remove frames that come from C calls.
    if !c_funcs
        filter!(frame -> !frame.from_c, stack)
    end

    # Remove frame for this function (and any functions called by this function).
    remove_frames!(stack, :stacktrace)
end

function remove_frames!(stack::Stack, name::Symbol)
    # Remove the frame for a given function (and all functions called by that function).
    splice!(stack, 1:findlast(map(frame -> frame.name == name, stack)))
    return stack
end

function format_frame(frame::StackFrame)
    string(frame.name != "" ? frame.name : "?", " at ", frame.file, ":", frame.line)
end

function format_stacktrace(stack::Stack, separator::String, finish::String="")
    if isempty(stack)
        return ""
    end

    string(join(map(format_frame, stack), separator), finish)
end

function show_stacktrace(io::IO, stack::Stack)
    print(io, "  ", format_stacktrace(stack, "\n  ", "\n"))
end

show_stacktrace() = show_stacktrace(STDOUT, remove_frames!(stacktrace(), :show_stacktrace))
show_stacktrace(io::IO) = show_stacktrace(io, remove_frames!(stacktrace(), :show_stacktrace))
show_stacktrace(stack::Stack) = show_stacktrace(STDOUT, stack)


end
