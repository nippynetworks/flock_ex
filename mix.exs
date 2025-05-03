defmodule FlockEx.MixProject do
  use Mix.Project

  @source_url "https://github.com/nippynetworks/flock_ex"
  @version "0.1.0"

  def project do
    [
      app: :flock_ex,
      description: description(),
      package: package(),
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      compilers: [:elixir_make] ++ Mix.compilers(),
      make_clean: ["clean"],
      deps: deps(),
      docs: [
        extras: ["README.md"],
        main: "readme",
        source_url: @source_url,
        source_ref: "v#{@version}"
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:elixir_make, "~> 0.6", runtime: false}
    ]
  end

  defp description do
    """
    An Elixir wrapper aroumd the Linux `flock()` system call for advisory file locking.
    """
  end

  defp package do
    %{
      maintainers: ["Ed Wildgoose"],
      files: ~w(
        .formatter.exs
        c_src/flock_ex.c
        lib/flock_ex.ex
        LICENSE
        Makefile
        README.md
        mix.exs
      ),
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url}
    }
  end
end
