defmodule Condiment.MixProject do
  use Mix.Project

  def project do
    [
      app: :condiment,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Condiment",
      description: description(),
      package: package(),
      source_url: "https://github.com/edisonywh/condiment"
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
      {:ex_doc, "~> 0.14", only: :dev, runtime: false}
    ]
  end

  defp description do
    "🍡 Add flavors to your context function without the hassles."
  end

  defp package do
    [
      maintainers: ["Edison Yap"],
      licenses: ["MIT"],
      links: %{GitHub: "https://github.com/edisonywh/condiment"}
    ]
  end
end
