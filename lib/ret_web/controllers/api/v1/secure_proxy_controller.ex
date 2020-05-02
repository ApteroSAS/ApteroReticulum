defmodule RetWeb.Api.V1.SecureProxy do
  use RetWeb, :controller
  use Retry

  def handle(conn, params) do
    paramCopy = params
    account = conn
              |> Guardian.Plug.current_resource()

    proxy_url = paramCopy["proxy_url"]

    paramCopy = if (account && account.account_id) do
      #inject user account
      IO.inspect(paramCopy)
      #params =Map.put(params, :user, account.account_id)
      Map.merge(paramCopy, %{"user" => account.account_id})
    else
      conn |> send_resp(403, "unauthorized")
      paramCopy
    end

    IO.inspect(paramCopy)
    paramCopy = Map.put(paramCopy, "server_secret", module_config(:secret) || "secretsecret");

    payload = paramCopy |> Poison.encode!()
    case HTTPoison.post(proxy_url, payload, [{"Content-Type", "application/json"}]) do
      {:ok, %HTTPoison.Response{status_code: 200} = resp} ->
        json(conn, Poison.decode!(resp.body))
      _ ->
        conn
        |> send_resp(404, "")
    end
  end

  defp module_config(key), do: Application.get_env(:ret, RetWeb.Endpoint)[key]

end
