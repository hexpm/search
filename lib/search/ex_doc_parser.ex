defmodule Search.ExDocParser do
  @moduledoc """
  Contains functionality for extracting the raw documentation with metadata from a tarball of an
  ExDoc-generated documentation page
  """

  def get_documentation(file_or_binary \\ []) do
    %{file: file, binary: binary} =
      file_or_binary
      |> Keyword.validate!(file: nil, binary: nil)
      |> Map.new()

    tarball =
      case {file, binary} do
        {f, nil} when not is_nil(f) -> {:file, f}
        {nil, b} when not is_nil(b) -> {:binary, b}
        _ -> raise ArgumentError, message: "Exactly one of :file or :binary must be given"
      end

    case :erl_tar.extract(tarball, [:memory]) do
      {:error, _} = err ->
        err

      {:ok, search_data} ->
        search_data =
          Enum.find(search_data, fn {maybe_search_data, _} ->
            List.starts_with?(maybe_search_data, ~c"dist/search_data")
          end)

        if is_nil(search_data) do
          {:error, "Search data not found, package documentation is not in a supported format."}
        else
          {_, search_data} = search_data

          parse_search_data(search_data)
        end
    end
  end

  @search_data_prefix "searchData="
  defp parse_search_data(search_data) when is_binary(search_data) do
    if !String.starts_with?(search_data, @search_data_prefix) do
      {:error, "Search data content does not start with \"#{@search_data_prefix}\"."}
    else
      case search_data
           |> String.slice(String.length(@search_data_prefix)..-1//1)
           |> JSON.decode() do
        {:ok, %{"items" => doc_items}} -> {:ok, doc_items}
        {:ok, _} -> {:error, "Search data content does not contain the key \"items\""}
        _ -> {:error, "Search data content is not proper JSON"}
      end
    end
  end
end
