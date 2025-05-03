# FlockEx

This library implements a simple wrapper around the C flock syscall for advisory locking

This gives you compatibility with linux command line utilities such as `flock`, or
other apps which use the flock syscall

Remember that flock is an advisory syscall and will not prevent an app reading or writing
to a given file, if it does not implement the flock checks. However, it's useful to be
compatible with such utilities

# Usage

  iex> {:ok, handle} = FlockEx.flock("#{System.tmp_dir}/lockme")
  {:ok, #Reference<0.2958773140.145358881.211403>}

  iex> FlockEx.unflock(handle)
  :ok

If the process holding the lock dies, then the flock will be automatically released.

If the flock lock goes out of scope, then the lock will be automatically released, but only
when a garbage collection is run, which could be some time later. Ideally release the flock correctly

By default flock will take out an exclusive lock and wait forever for the lock to become available,
this can be changed using params:

- exclusive: default true to take out an exclusive lock, false for a shared/read lock
- wait: default true to wait forever for a lock, false returns {:error, :eagain}
      if the lock cannot be obtained immediately

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `flock_ex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:flock_ex, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/flock_ex>.

