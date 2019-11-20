defmodule RetWeb.Email do
  use Bamboo.Phoenix, view: RetWeb.EmailView

  def auth_email(to_address, signin_args) do
    new_email()
    |> to(to_address)
    |> from({"Aptero", from_address()})
    |> subject("Your Sign-In Link")
    |> text_body(
      "To sign-in to ApteroHub, please visit the link below. If you did not make this request, please ignore this e-mail.\n\n#{
        "https://hub.aptero.co"
      }/?#{URI.encode_query(signin_args)}"
    )
  end

  defp from_address do
    Application.get_env(:ret, __MODULE__)[:from]
  end
end
