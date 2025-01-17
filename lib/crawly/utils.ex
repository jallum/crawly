defmodule Crawly.Utils do
  @moduledoc ~S"""
  Utility functions for Crawly
  """
  require Logger

  @doc """
  A helper function which returns a Request structure for the given URL
  """
  @spec request_from_url(binary()) :: Crawly.Request.t()
  def request_from_url(url), do: %Crawly.Request{url: url, headers: []}

  @doc """
  A helper function which converts a list of URLS into a requests list.
  """
  @spec requests_from_urls([binary()]) :: [Crawly.Request.t()]
  def requests_from_urls(urls), do: Enum.map(urls, &request_from_url/1)

  @doc """
  A helper function which joins relative url with a base URL
  """
  @spec build_absolute_url(binary(), binary()) :: binary()
  def build_absolute_url(url, base_url) do
    URI.merge(base_url, url) |> to_string()
  end

  @doc """
  A helper function which joins relative url with a base URL for a list
  """
  @spec build_absolute_urls([binary()], binary()) :: [binary()]
  def build_absolute_urls(urls, base_url) do
    Enum.map(urls, fn url -> URI.merge(base_url, url) |> to_string() end)
  end

  @doc """
  Pipeline/Middleware helper

  Executes a given list of pipelines on the given item, mimics filtermap
  behavior (but probably in a more complex way). Takes an item and state  and
  passes it through a list of modules which implements a pipeline behavior,
  executing the pipeline's run.

  The pipe function must return boolean (false) or updated item.
  In case if false is returned the item is not being processed by all descendant
  pipelines, and dropped.

  In case if a given pipeline crashes for the given item, it's result are being
  ignored, and the item is being processed by all other descendant pipelines.

  The state variable is used to persist the information accross multiple items.
  """
  @spec pipe(pipelines, item, state) :: result
        when pipelines: [Crawly.Pipeline.t()],
             item: map(),
             state: map(),
             result: {new_item | false, new_state},
             new_item: map(),
             new_state: map()
  def pipe([], item, state), do: {item, state}
  def pipe(_, false, state), do: {false, state}

  def pipe([pipeline | pipelines], item, state) do
    {new_item, new_state} =
      try do
        {new_item, new_state} = pipeline.run(item, state)
        {new_item, new_state}
      catch
        error, reason ->
          Logger.error(
            "Pipeline crash: #{pipeline}, error: #{inspect(error)}, reason: #{
              inspect(reason)
            }"
          )

          {item, state}
      end

    pipe(pipelines, new_item, new_state)
  end
end
