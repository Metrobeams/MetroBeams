defmodule Plataforma.Media.ImageProcessor do
  @moduledoc """
  Behaviour for image processing backends.
  """

  @callback process(Path.t()) ::
              {:ok, %{path: Path.t(), content_type: String.t(), size: non_neg_integer()}}
              | {:error, atom()}
end
