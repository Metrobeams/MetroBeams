defmodule Plataforma.Media.ImageProcessor.ImageMagick do
  @moduledoc """
  ImageMagick-based image processor implementation.
  """

  @behaviour Plataforma.Media.ImageProcessor

  @max_size 5 * 1024 * 1024
  @supported_formats ~w(JPEG PNG WEBP)

  @impl true
  def process(source_path) do
    with {:ok, stat} <- File.stat(source_path),
         :ok <- validate_size(stat.size),
         {:ok, _format} <- identify_format(source_path),
         output_path <- output_path(),
         :ok <- transform(source_path, output_path),
         {:ok, output_stat} <- File.stat(output_path) do
      {:ok, %{path: output_path, content_type: "image/webp", size: output_stat.size}}
    else
      {:error, :enoent} -> {:error, :unsupported_image}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_size(size) when size > @max_size, do: {:error, :file_too_large}
  defp validate_size(_size), do: :ok

  defp identify_format(path) do
    case command(["identify", "-format", "%m", path]) do
      {format, 0} when format in @supported_formats -> {:ok, format}
      _ -> {:error, :unsupported_image}
    end
  end

  defp transform(source_path, output_path) do
    arguments = [
      source_path,
      "-auto-orient",
      "-strip",
      "-thumbnail",
      "256x256^",
      "-gravity",
      "center",
      "-extent",
      "256x256",
      "-quality",
      "85",
      "webp:#{output_path}"
    ]

    case command(arguments) do
      {_output, 0} ->
        :ok

      _ ->
        File.rm(output_path)
        {:error, :processing_failed}
    end
  end

  defp command(arguments) do
    executable = Application.get_env(:plataforma, :imagemagick_executable, "magick")
    System.cmd(executable, arguments, stderr_to_stdout: true)
  rescue
    ErlangError -> {"", 1}
  end

  defp output_path do
    Path.join(System.tmp_dir!(), "avatar-#{Ecto.UUID.generate()}.webp")
  end
end
