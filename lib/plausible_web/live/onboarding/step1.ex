defmodule PlausibleWeb.Live.Onboarding.Step1 do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
    <div>
      Step 1 contents <%= live_render(@socket, PlausibleWeb.Live.RegisterForm,
        id: "register_form_embedded",
        session: %{},
        params: %{}
      ) %>
    </div>
    """
  end
end
