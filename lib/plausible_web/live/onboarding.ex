defmodule PlausibleWeb.Live.Onboarding do
  use PlausibleWeb, :live_view

  @onboarding_steps [
    %{component: PlausibleWeb.Live.Onboarding.Step1, state: :active, title: "First step"},
    %{component: PlausibleWeb.Live.Onboarding.Step2, state: :inactive, title: "Second step"},
    %{component: PlausibleWeb.Live.Onboarding.Step2, state: :inactive, title: "Third step"}
  ]

  def mount(_params, _, socket) do
    socket =
      assign(socket,
        current_step_idx: 1,
        total_steps_count: 4
      )

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto mt-6 text-center dark:text-gray-300">
      <.progress />

      <hr />

      <.current_component current_step_idx={@current_step_idx} />

      <hr />

      <a href="#" phx-click="next">Next</a>
    </div>
    """
  end

  def onboarding_steps do
    @onboarding_steps
  end

  def progress(assigns) do
    ~H"""
    <div class="flex items-center justify-between max-w-3xl mx-auto">
      <%= for {step, idx} <- Enum.with_index(onboarding_steps(), 1) do %>
        <div class="flex items-center">
          <div
            :if={step.state == :active}
            class="w-8 h-8 bg-indigo-600 text-white rounded-full flex items-center justify-center font-semibold"
          >
            <%= idx %>
          </div>
          <div
            :if={step.state == :inactive}
            class="w-8 h-8 bg-gray-300 text-white rounded-full flex items-center justify-center"
          >
            <%= idx %>
          </div>
          <span :if={step.state == :active} class="ml-2 font-semibold text-black">
            <%= step.title %>
          </span>
          <span :if={step.state == :inactive} class="ml-2 text-gray-400">
            <%= step.title %>
          </span>
        </div>

        <div :if={idx != length(onboarding_steps())} class="flex-1 h-px bg-gray-300 mx-4"></div>
      <% end %>
    </div>
    <span :for={step <- onboarding_steps()}>
      <%= step.title %>
    </span>
    """
  end

  def current_component(assigns) do
    step = Enum.at(@onboarding_steps, assigns.current_step_idx - 1)
    assigns = assign(assigns, :step, step)

    ~H"""
    <.live_component
      module={@step.component}
      state={@step.state}
      id={"step-#{@current_step_idx}-#{:erlang.phash2(@step)}"}
    />
    """
  end

  def handle_event("next", _, socket) do
    socket = assign(socket, current_step_idx: socket.assigns.current_step_idx + 1)
    {:noreply, socket}
  end
end
