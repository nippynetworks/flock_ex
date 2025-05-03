defmodule FlockEx do
  @moduledoc """
  Simple advisory file locking interface using Linux `flock()` via NIF.
  Automatically releases lock on process crash.
  """

  @on_load :load_nif

  def load_nif do
    path = :filename.join(:code.priv_dir(:flock_ex), ~c"flock_ex")
    :erlang.load_nif(path, 0)
  end

  @doc """
  Acquire a lock on `path`.
  Returns `{:ok, handle}` or `{:error, reason}`.

  Options:
  * `:exclusive` - if true, obtain an exclusive (`LOCK_EX`) lock (default: true),
                    else obtain shared/read-only ('LOCK_SH') lock
  * `:wait` - if true, return immediately with `{:error, :eagain}`
              if lock cannot be immediately acquired (default: true)
              else, wait for lock to become free

  """
  def flock(path, opts \\ []) when is_binary(path) and is_list(opts) do
    do_flock(path, opts)
  end

  defp do_flock(_path, _opts), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Release a previously acquired lock.
  """
  def unflock(_handle), do: :erlang.nif_error(:nif_not_loaded)
end
