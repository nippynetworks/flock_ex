defmodule FlockExTest do
  use ExUnit.Case, async: true
  doctest FlockEx

  @tag :tmp_dir
  test "can call flock and unflock", %{tmp_dir: tmp_dir} do
    lock_file = "#{tmp_dir}/lockme"
    {:ok, lock} = FlockEx.flock(lock_file, exclusive: true)
    FlockEx.unflock(lock)
  end

  @tag :tmp_dir
  test "can take multiple shared flocks", %{tmp_dir: tmp_dir} do
    lock_file = "#{tmp_dir}/lockme"
    self = self()

    {:ok, _lock} = FlockEx.flock(lock_file, exclusive: false)

    Task.async(fn ->
      FlockEx.flock(lock_file, exclusive: false)
      send(self, "locked")
    end)

    assert_receive "locked", 50
  end

  @tag :tmp_dir
  test "cannot take exclusive lock when shared flock in place", %{tmp_dir: tmp_dir} do
    lock_file = "#{tmp_dir}/lockme"
    self = self()

    {:ok, _lock} = FlockEx.flock(lock_file, exclusive: false)

    Task.async(fn ->
      FlockEx.flock(lock_file, exclusive: true)
      send(self, "locked")
    end)

    refute_receive "locked", 50
  end

  @tag :tmp_dir
  test "cannot take shared lock when exclusive flock in place", %{tmp_dir: tmp_dir} do
    lock_file = "#{tmp_dir}/lockme"
    self = self()

    {:ok, _lock} = FlockEx.flock(lock_file, exclusive: true)

    Task.async(fn ->
      FlockEx.flock(lock_file, exclusive: false)
      send(self, "locked")
    end)

    refute_receive "locked", 50
  end

  @tag :tmp_dir
  test "cannot take exclusive lock when exclusive flock in place", %{tmp_dir: tmp_dir} do
    lock_file = "#{tmp_dir}/lockme"
    self = self()

    {:ok, _lock} = FlockEx.flock(lock_file, exclusive: true)

    Task.async(fn ->
      FlockEx.flock(lock_file, exclusive: true)
      send(self, "locked")
    end)

    refute_receive "locked", 50
  end

  @tag :tmp_dir
  test "can abort if lock cannot be acquired", %{tmp_dir: tmp_dir} do
    lock_file = "#{tmp_dir}/lockme"
    self = self()

    {:ok, _lock} = FlockEx.flock(lock_file, exclusive: false)

    Task.async(fn ->
      {:error, :eagain} = FlockEx.flock(lock_file, exclusive: true, wait: false)
      send(self, "lock-failed")
    end)

    assert_receive "lock-failed", 50
  end

  @tag :tmp_dir
  test "can take either lock after first unlocking", %{tmp_dir: tmp_dir} do
    lock_file = "#{tmp_dir}/lockme"
    self = self()

    {:ok, lock} = FlockEx.flock(lock_file, exclusive: true)
    FlockEx.unflock(lock)

    Task.async(fn ->
      {:ok, lock} = FlockEx.flock(lock_file, exclusive: true)
      send(self, "locked excl")
      FlockEx.unflock(lock)
    end)

    assert_receive "locked excl", 50

    Task.async(fn ->
      {:ok, lock} = FlockEx.flock(lock_file, exclusive: false)
      send(self, "locked shared")
      FlockEx.unflock(lock)
    end)

    assert_receive "locked shared", 50
  end

  @tag :tmp_dir
  test "lock released when parent process dies", %{tmp_dir: tmp_dir} do
    lock_file = "#{tmp_dir}/lockme"
    self = self()

    lock_pid = Task.async(fn ->
      FlockEx.flock(lock_file, exclusive: true)
      send(self, "locked")
      Process.sleep(2_000)
    end)

    assert_receive "locked", 50

    # Forcibly kill the task
    Task.shutdown(lock_pid, 50)

    Task.async(fn ->
      FlockEx.flock(lock_file, exclusive: true)
      send(self, "locked again")
    end)

    assert_receive "locked again", 500
  end

end
