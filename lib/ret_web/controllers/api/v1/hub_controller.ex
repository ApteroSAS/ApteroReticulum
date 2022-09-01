defmodule RetWeb.Api.V1.HubController do
  use RetWeb, :controller

  alias Ret.{Hub, Scene, Repo, OwnedFile}#Aptero

  import Canada, only: [can?: 2]

  # Limit to 1 TPS
  #Aptero remove rate limite since it will be used by a micro service
  #plug(RetWeb.Plugs.RateLimit)

  # Only allow access to remove hubs with secret header
  plug(RetWeb.Plugs.HeaderAuthorization when action in [:delete])

  def create(conn, %{"hub" => _hub_params} = params) do
    #IO.inspect(params)
    if _hub_params["hub_sid"] != nil do
      exec_get(conn,params["hub"])#APTERO
    else
      Hub.create_new_room(params["hub"], false)
      |> exec_create(conn)
    end
  end

  #APTERO API to get hub info
  defp hub_to_entry(%Hub{} = hub) when hub != nil do
    scene_or_scene_listing = hub.scene || hub.scene_listing

    images =
      if scene_or_scene_listing do
        %{preview: %{url: scene_or_scene_listing.screenshot_owned_file |> OwnedFile.uri_for() |> URI.to_string()}}
      else
        %{preview: %{url: "#{RetWeb.Endpoint.url()}/data/app-thumbnail.png"}}
      end

    scene_id =
      if scene_or_scene_listing do
        Scene.to_sid(scene_or_scene_listing)
      else
        nil
      end

    %{
      id: hub.hub_sid,
      url: hub |> Hub.url_for(),
      type: :room,
      room_size: hub |> Hub.room_size_for(),
      member_count: hub |> Hub.member_count_for(),
      lobby_count: hub |> Hub.lobby_count_for(),
      name: hub.name,
      description: hub.description,
      scene_id: scene_id,
      user_data: hub.user_data,
      images: images
    }
  end

  defp exec_get(conn, %{"hub_sid" => _hub_sid} = params) do
    #IO.inspect("exec_get")
    #IO.inspect(params)
    #IO.inspect(_hub_sid) Note this is impossible to display Oo
    hub = Hub |> Repo.get_by(hub_sid: _hub_sid)
          |> Repo.preload(scene: [:screenshot_owned_file], scene_listing: [:scene, :screenshot_owned_file])
    #IO.inspect(hub)
    entry = hub_to_entry(hub)
    #IO.inspect(entry)
    render(conn, "entry.json", %{entry: entry})
  end
  # END APTERO
  defp exec_create(hub_changeset, conn) do
    account = Guardian.Plug.current_resource(conn)

    if account |> can?(create_hub(nil)) do
      {result, hub} =
        hub_changeset
        |> Hub.add_account_to_changeset(account)
        |> Repo.insert()

      case result do
        :ok -> render(conn, "create.json", hub: hub)
        :error -> conn |> send_resp(422, "invalid hub")
      end
    else
      conn |> send_resp(401, "unauthorized")
    end
  end

  def update(conn, %{"id" => hub_sid, "hub" => hub_params}) do
    account = Guardian.Plug.current_resource(conn)

    case Hub
         |> Repo.get_by(hub_sid: hub_sid)
         |> Repo.preload([:created_by_account, :hub_bindings, :hub_role_memberships]) do
      %Hub{} = hub ->
        if account |> can?(update_hub(hub)) do
          update_with_hub(conn, account, hub, hub_params)
        else
          conn |> send_resp(401, "You cannot update this hub")
        end

      _ ->
        conn |> send_resp(404, "not found")
    end
  end

  defp update_with_hub(conn, account, hub, hub_params) do
    if is_nil(hub_params["scene_id"]) do
      update_with_hub_and_scene(conn, account, hub, nil, hub_params)
    else
      case Scene.scene_or_scene_listing_by_sid(hub_params["scene_id"]) do
        nil -> conn |> send_resp(422, "scene not found")
        scene -> update_with_hub_and_scene(conn, account, hub, scene, hub_params)
      end
    end
  end

  defp update_with_hub_and_scene(conn, account, hub, scene, hub_params) do
    changeset =
      hub
      |> Hub.add_attrs_to_changeset(hub_params)
      |> maybe_add_new_scene(scene)
      |> Hub.maybe_add_member_permissions(hub, hub_params)
      |> Hub.maybe_add_promotion(account, hub, hub_params)

    hub = changeset |> Repo.update!() |> Repo.preload(Hub.hub_preloads())

    conn |> render("show.json", %{hub: hub, embeddable: account |> can?(embed_hub(hub))})
  end

  defp maybe_add_new_scene(changeset, nil), do: changeset

  defp maybe_add_new_scene(changeset, scene), do: changeset |> Hub.add_new_scene_to_changeset(scene)

  def delete(conn, %{"id" => hub_sid}) do
    Hub
    |> Repo.get_by(hub_sid: hub_sid)
    |> Hub.changeset_for_entry_mode(:deny)
    |> Repo.update!()

    conn |> send_resp(200, "OK")
  end
end
