defmodule MobAudioCapture.MixProject do
  use Mix.Project

  @source_url "https://github.com/GenericJam/mob_audio_capture"

  def project do
    [
      app: :mob_audio_capture,
      version: "0.1.0",
      elixir: "~> 1.17",
      deps: deps(),
      aliases: aliases(),
      description:
        "Global device-audio capture (Android MediaProjection/AudioPlaybackCapture) " <>
          "for Mob apps — a test-environment probe that meters audio other apps/native " <>
          "players produce, which the in-app Mob.Audio probes cannot reach",
      package: package(),
      docs: [main: "readme", extras: ["README.md", "PLAN.md"]],
      source_url: @source_url
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp aliases do
    # `mix setup` installs deps and activates the shared git hooks (.githooks):
    # format / Credo --strict / compile on every push, full suite when mix.exs changes.
    [setup: ["deps.get", "cmd git config core.hooksPath .githooks"]]
  end

  defp deps do
    [
      {:mob, "~> 0.7"},
      {:mob_dev, "~> 0.6", only: [:dev, :test], runtime: false},
      {:ex_ast, "~> 0.12", only: [:dev, :test], runtime: false},
      {:reach, "~> 2.7", only: [:dev, :test], runtime: false},
      {:recon, "~> 2.5", only: [:dev, :test]},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_slop, "~> 0.4.2", only: [:dev, :test], runtime: false},
      {:jump_credo_checks, "~> 0.1.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      # Native sources + manifest must ship — the host's native build compiles
      # them from deps/<plugin>/priv.
      files: ~w(lib src priv mix.exs README* CHANGELOG*)
    ]
  end
end
