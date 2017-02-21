defmodule RestApiBuilder.Mixfile do
  use Mix.Project

  @version "0.5.1"

  def project do
    [app: :rest_api_builder,
     version: @version,
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     description: "Library for Elixir that uses a Provider to generate RESTful web interfaces.",
     name: "REST API Builder",
     package: %{
       licenses: ["Apache 2.0"],
       maintainers: ["Joseph Lindley"],
       links: %{"GitHub" => "https://github.com/cenurv/rest_api_builder"},
       files: ~w(mix.exs README.md CHANGELOG.md lib)
     },
     docs: [source_ref: "v#{@version}", main: "readme",
            canonical: "http://hexdocs.pm/rest_api_builder",
            source_url: "https://github.com/cenurv/rest_api_builder",
            extras: ["CHANGELOG.md", "README.md"]]]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [{:plug, "~> 1.3"},
     {:event_queues, "~> 1.1"},
     {:poison, "~> 2.2"},
     {:ex_doc, "~> 0.14", only: [:docs, :dev]}]
  end
end
