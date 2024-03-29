defmodule Search.ExDocParser do
  @moduledoc """
  Contains functionality for extracting the raw documentation with metadata from a tarball of an
  ExDoc-generated documentation page
  """

  def extract_search_data(untarred_docs) when is_list(untarred_docs) do
    search_data =
      Enum.find_value(untarred_docs, fn {path, contents} ->
        if match?(~c"dist/search_data-" ++ _, path) do
          contents
        end
      end)

    if search_data do
      parse_search_data(search_data)
    else
      {:error, "Search data not found, package documentation is not in a supported format."}
    end
  end

  @search_data_prefix "searchData="
  defp parse_search_data(search_data) when is_binary(search_data) do
    case search_data do
      @search_data_prefix <> json ->
        case Jason.decode(json) do
          {:ok, %{"items" => items}} ->
            {:ok, items}

          _ ->
            {:error, "Search data content is invalid JSON"}
        end

      _ ->
        {:error, "Search data content does not start with \"#{@search_data_prefix}\"."}
    end
  end
end
