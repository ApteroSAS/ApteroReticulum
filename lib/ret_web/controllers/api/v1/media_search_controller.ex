defmodule RetWeb.Api.V1.MediaSearchController do
  use RetWeb, :controller
  use Retry

  def index(conn, %{"source" => "rooms"} = params) do
    {:commit, results} =
      %Ret.MediaSearchQuery{
        source: "rooms",
        cursor: params["cursor"] || "1",
        filter: params["filter"],
        q: params["q"]
      }
      |> Ret.MediaSearch.search()

    conn |> render("index.json", results: results)
  end

  def index(conn, %{"source" => "sketchfab", "user" => user}) do
    {:commit, results} =
      %Ret.MediaSearchQuery{source: "sketchfab", user: user} |> Ret.MediaSearch.search()

    conn |> render("index.json", results: results)
  end

  def index(conn, %{"source" => "scene_listings"} = params) do
    {:commit, results} =
      %Ret.MediaSearchQuery{
        source: "scene_listings",
        q: params["q"],
        filter: params["filter"],
        cursor: params["cursor"] || "1"
      }
      |> Ret.MediaSearch.search()

    conn |> render("index.json", results: results)
  end

  def index(conn, %{"source" => "avatar_listings"} = params) do
    {:commit, results} =
      %Ret.MediaSearchQuery{
        source: "avatar_listings",
        q: params["q"],
        filter: params["filter"],
        similar_to: params["similar_to"],
        cursor: params["cursor"] || "1"
      }
      |> Ret.MediaSearch.search()

    conn |> render("index.json", results: results)
  end

  def index(conn, %{"source" => source, "user" => user} = params)
      when source in ["scenes", "avatars", "favorites", "assets", "objects"] do #APTERO
    account = conn |> Guardian.Plug.current_resource()

    if account && account.account_id == String.to_integer(user) do
      {:commit, results} =
        %Ret.MediaSearchQuery{
          source: source,
          cursor: params["cursor"] || "1",
          user: account.account_id,
          filter: params["filter"],#APTERO
          type: params["type"],
          q: params["q"]
        }
        |> Ret.MediaSearch.search()

      conn |> render("index.json", results: results)
    else
      conn |> send_resp(401, "You can only search #{source} by user for your own account.")
    end
  end

  def index(conn, %{"source" => source}) when source in ["favorites"] do
    conn |> send_resp(401, "Missing account id for favorites search.")
  end

  def index(conn, %{"source" => source} = params)
      when source in [
             "sketchfab",
             "tenor",
             "youtube_videos",
             "bing_videos",
             "bing_images",
             "twitch"
           ] do
    query = %Ret.MediaSearchQuery{
      source: source,
      cursor: params["cursor"],
      q: params["q"],
      filter: params["filter"],
      collection: params["collection"],
      locale: params["locale"]
    }

    case Cachex.fetch(cache_for_query(query), query) do
      {_status, nil} ->
        conn |> send_resp(404, "")

      {_status, %Ret.MediaSearchResult{} = results} ->
        conn |> render("index.json", results: results)

      _ ->
        conn |> send_resp(404, "")
    end
  end

  #APTERO
  def index(conn, %{"source" => source, "user" => user, "filter" => filter} = params)
      when source in ["videos360", "videos"] and filter in ["my-videos-live", "my-videos-360-live"] do
    #Just forward the data
    # For local dev, allow insecure SSL because of webpack server
    url = module_config(:video360URL)
    account = conn
              |> Guardian.Plug.current_resource()

    params = if(account && account.account_id)do
      Map.put(params, "user", account.account_id)
    else
        params
    end

    params = if(filter=="my-videos-live") do
      Map.put(params, "filter", "live-2d")
    else
      params
    end

    params = if(filter=="my-videos-360-live") do
      Map.put(params, "filter", "live-360")
    else
      params
    end

    payload = params |> Poison.encode!()
    IO.inspect(params)
    case HTTPoison.post(url, payload, [{"Content-Type", "application/json"}]) do
      {:ok, %HTTPoison.Response{status_code: 200} = resp} ->
        conn
        |> render("index.json", results: Poison.decode!(resp.body))
      _ ->
        conn
        |> send_resp(404, "")
    end
  end

  # For Google services, increase cache duration for landing pages by using long-lived cache, due to quotas.
  defp cache_for_query(%Ret.MediaSearchQuery{source: source, q: nil})
       when source == "youtube_videos",
       do: :media_search_results_long

  defp cache_for_query(_query), do: :media_search_results

  def index(conn) do
    conn |> send_resp(422, "")
  end
  #APTERO
  defp module_config(key), do: Application.get_env(:ret, RetWeb.Endpoint)[key]
end
