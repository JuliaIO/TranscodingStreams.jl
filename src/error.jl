# Transcoding Error
# =================

"""
Container of transcoding error.

An object of this type is used to notify the caller of an exception that
happened inside a transcoding method.  The `error` field is undefined at first
but will be filled when data processing failed. The error should be set by
calling the `setindex!` method (e.g. `error[] = ErrorException("error!")`).
"""
mutable struct Error
    error::Exception

    function Error()
        return new()
    end
end

# Test if an exception is set.
function haserror(error::Error)
    return isdefined(error, :error)
end

function Base.setindex!(error::Error, ex::Exception)
    @assert !haserror(error) "an error is already set"
    error.error = ex
    return error
end

function Base.getindex(error::Error)
    @assert haserror(error) "no error is set"
    return error.error
end
