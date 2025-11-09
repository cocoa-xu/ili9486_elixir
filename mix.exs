defmodule Ili9486Elixir.MixProject do
  use Mix.Project

  def project do
    [
      app: :ili9486_elixir,
      version: "0.1.5",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      description: description(),
      package: package(),
      deps: deps(),
      docs: docs(),
      source_url: "https://github.com/cocoa-xu/ili9486_elixir"
    ]
  end

  def application do
    []
  end

  defp deps do
    [
      {:cvt_color, "~> 0.1.3"},
      {:circuits_gpio, "~> 2.0 or ~> 1.0"},
      {:circuits_spi, "~> 2.0 or ~> 1.0"},
      {:ex_doc, "~> 0.27", only: [:dev, :docs], runtime: false}
    ]
  end

  defp description() do
    "ILI9486 Elixir driver"
  end

  defp elixirc_paths(_), do: ~w(lib)

  defp docs() do
    [
      groups_for_functions: [
        Constants: &(&1[:functions] == :constants)
      ]
    ]
  end

  defp package() do
    [
      name: "ili9486_elixir",
      files: ~w(lib .formatter.exs mix.exs README* LICENSE*),
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/cocoa-xu/ili9486_elixir"}
    ]
  end
end
