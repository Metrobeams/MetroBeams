defmodule Plataforma.Media.ImageProcessorTest do
  use ExUnit.Case, async: true

  alias Plataforma.Media.ImageProcessor.ImageMagick

  setup do
    directory = Path.join(System.tmp_dir!(), "avatar-test-#{System.unique_integer([:positive])}")
    File.mkdir_p!(directory)

    on_exit(fn -> File.rm_rf!(directory) end)

    %{directory: directory}
  end

  test "converts a real supported image to a stripped square WebP", %{directory: directory} do
    source = Path.join(directory, "source.jpg")
    create_image!(source, "640x320", "jpeg")

    assert {:ok, processed} = ImageMagick.process(source)
    assert processed.content_type == "image/webp"
    assert processed.size == File.stat!(processed.path).size
    assert processed.size > 0
    assert image_property(processed.path, "%m") == "WEBP"
    assert image_property(processed.path, "%wx%h") == "256x256"
    assert image_property(processed.path, "%[EXIF:*]") == ""
  end

  test "rejects unsupported content even when its extension is allowed", %{directory: directory} do
    source = Path.join(directory, "disguised.png")
    File.write!(source, :crypto.strong_rand_bytes(128))

    assert {:error, :unsupported_image} = ImageMagick.process(source)
  end

  test "rejects a source larger than the configured limit", %{directory: directory} do
    source = Path.join(directory, "large.jpg")
    limit = 5 * 1024 * 1024
    File.write!(source, :binary.copy(<<0>>, limit + 1))

    assert {:error, :file_too_large} = ImageMagick.process(source)
  end

  defp create_image!(path, dimensions, format) do
    {_output, 0} =
      System.cmd("magick", ["-size", dimensions, "gradient:", "#{format}:#{path}"],
        stderr_to_stdout: true
      )
  end

  defp image_property(path, property) do
    {output, 0} = System.cmd("magick", ["identify", "-format", property, path])
    output
  end
end
