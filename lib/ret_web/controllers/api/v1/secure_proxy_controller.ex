defmodule RetWeb.Api.V1.SecureProxy do
  use RetWeb, :controller
  use Retry

  def handle(conn, params) do
    json(conn, %{body: params})
  end

  def handle(conn, %{"proxy_url" => proxy_url} = params) do
    account = conn
              |> Guardian.Plug.current_resource()

    case (account && account.account_id) do
      true ->
        #inject user account
        Map.put(params, :user, account.account_id)
      _ ->
        conn
        |> send_resp(403, "un authorized")
    end

    Map.put(params, :server_secret, module_config(:secret) || "secretsecret");

    payload = params
              |> Poison.encode!()
    case HTTPoison.post(proxy_url, payload, [{"Content-Type", "application/json"}]) do
      {:ok, %HTTPoison.Response{status_code: 200} = resp} ->
        conn
        |> render("create.json", results: Poison.decode!(resp.body))
      _ ->
        conn
        |> send_resp(404, "")
    end
  end

  defp module_config(key), do: Application.get_env(:ret, RetWeb.Endpoint)[key]

end
