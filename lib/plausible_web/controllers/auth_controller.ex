defmodule PlausibleWeb.AuthController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  alias Plausible.Auth
  require Logger

  plug(
    PlausibleWeb.RequireLoggedOutPlug
    when action in [
           :register_form,
           :register,
           :register_from_invitation,
           :login_form,
           :login
         ]
  )

  plug(
    PlausibleWeb.RequireAccountPlug
    when action in [
           :user_settings,
           :save_settings,
           :update_email,
           :cancel_update_email,
           :new_api_key,
           :create_api_key,
           :delete_api_key,
           :delete_me,
           :activate_form,
           :activate,
           :request_activation_code
         ]
  )

  plug(:assign_is_selfhost)

  defp assign_is_selfhost(conn, _opts) do
    assign(conn, :is_selfhost, Plausible.Release.selfhost?())
  end

  def register(conn, %{"user" => %{"email" => email, "password" => password}}) do
    with {:ok, user} <- login_user(conn, email, password) do
      conn = set_user_session(conn, user)

      if user.email_verified do
        redirect(conn, to: Routes.site_path(conn, :new))
      else
        send_email_verification(user)
        redirect(conn, to: Routes.auth_path(conn, :activate_form))
      end
    end
  end

  def register_from_invitation(conn, %{"user" => %{"email" => email, "password" => password}}) do
    with {:ok, user} <- login_user(conn, email, password) do
      conn = set_user_session(conn, user)

      if user.email_verified do
        redirect(conn, to: Routes.site_path(conn, :index))
      else
        send_email_verification(user)
        redirect(conn, to: Routes.auth_path(conn, :activate_form))
      end
    end
  end

  defp send_email_verification(user) do
    code = Auth.issue_email_verification(user)
    email_template = PlausibleWeb.Email.activation_email(user, code)
    result = Plausible.Mailer.send(email_template)

    Logger.debug(
      "E-mail verification e-mail sent. In dev environment GET /sent-emails for details."
    )

    result
  end

  def activate_form(conn, _params) do
    user = conn.assigns[:current_user]

    render(conn, "activate.html",
      has_email_code?: Plausible.Users.has_email_code?(user.id),
      has_any_invitations?: Plausible.Site.Memberships.has_any_invitations?(user.email),
      has_any_memberships?: Plausible.Site.Memberships.any?(user.id),
      layout: {PlausibleWeb.LayoutView, "focus.html"}
    )
  end

  def activate(conn, %{"code" => code}) do
    user = conn.assigns[:current_user]

    has_any_invitations? = Plausible.Site.Memberships.has_any_invitations?(user.email)
    has_any_memberships? = Plausible.Site.Memberships.any?(user.id)

    {code, ""} = Integer.parse(code)

    case Auth.verify_email(user, code) do
      :ok ->
        cond do
          has_any_memberships? ->
            conn
            |> put_flash(:success, "Email updated successfully")
            |> redirect(to: Routes.auth_path(conn, :user_settings) <> "#change-email-address")

          has_any_invitations? ->
            redirect(conn, to: Routes.site_path(conn, :index))

          true ->
            redirect(conn, to: Routes.site_path(conn, :new))
        end

      {:error, :incorrect} ->
        render(conn, "activate.html",
          error: "Incorrect activation code",
          has_email_code?: true,
          has_any_invitations?: has_any_invitations?,
          has_any_memberships?: has_any_memberships?,
          layout: {PlausibleWeb.LayoutView, "focus.html"}
        )

      {:error, :expired} ->
        render(conn, "activate.html",
          error: "Code is expired, please request another one",
          has_email_code?: false,
          has_any_invitations?: has_any_invitations?,
          has_any_memberships?: has_any_memberships?,
          layout: {PlausibleWeb.LayoutView, "focus.html"}
        )
    end
  end

  def request_activation_code(conn, _params) do
    user = conn.assigns[:current_user]
    code = Auth.issue_email_verification(user)

    email_template = PlausibleWeb.Email.activation_email(user, code)
    Plausible.Mailer.send(email_template)

    conn
    |> put_flash(:success, "Activation code was sent to #{user.email}")
    |> redirect(to: Routes.auth_path(conn, :activate_form))
  end

  def password_reset_request_form(conn, _) do
    render(conn, "password_reset_request_form.html",
      layout: {PlausibleWeb.LayoutView, "focus.html"}
    )
  end

  def password_reset_request(conn, %{"email" => ""}) do
    render(conn, "password_reset_request_form.html",
      error: "Please enter an email address",
      layout: {PlausibleWeb.LayoutView, "focus.html"}
    )
  end

  def password_reset_request(conn, %{"email" => email} = params) do
    if PlausibleWeb.Captcha.verify(params["h-captcha-response"]) do
      user = Repo.get_by(Plausible.Auth.User, email: email)

      if user do
        token = Auth.Token.sign_password_reset(email)
        url = PlausibleWeb.Endpoint.url() <> "/password/reset?token=#{token}"
        email_template = PlausibleWeb.Email.password_reset_email(email, url)
        Plausible.Mailer.deliver_later(email_template)

        Logger.debug(
          "Password reset e-mail sent. In dev environment GET /sent-emails for details."
        )

        render(conn, "password_reset_request_success.html",
          email: email,
          layout: {PlausibleWeb.LayoutView, "focus.html"}
        )
      else
        render(conn, "password_reset_request_success.html",
          email: email,
          layout: {PlausibleWeb.LayoutView, "focus.html"}
        )
      end
    else
      render(conn, "password_reset_request_form.html",
        error: "Please complete the captcha to reset your password",
        layout: {PlausibleWeb.LayoutView, "focus.html"}
      )
    end
  end

  def password_reset_form(conn, params) do
    case Auth.Token.verify_password_reset(params["token"]) do
      {:ok, %{email: email}} ->
        render(conn, "password_reset_form.html",
          connect_live_socket: true,
          email: email,
          layout: {PlausibleWeb.LayoutView, "focus.html"}
        )

      {:error, :expired} ->
        render_error(
          conn,
          401,
          "Your token has expired. Please request another password reset link."
        )

      {:error, _} ->
        render_error(
          conn,
          401,
          "Your token is invalid. Please request another password reset link."
        )
    end
  end

  def password_reset(conn, _params) do
    conn
    |> put_flash(:login_title, "Password updated successfully")
    |> put_flash(:login_instructions, "Please log in with your new credentials")
    |> put_session(:current_user_id, nil)
    |> delete_resp_cookie("logged_in")
    |> redirect(to: Routes.auth_path(conn, :login_form))
  end

  def login(conn, %{"email" => email, "password" => password}) do
    with {:ok, user} <- login_user(conn, email, password) do
      login_dest = get_session(conn, :login_dest) || Routes.site_path(conn, :index)

      conn
      |> set_user_session(user)
      |> put_session(:login_dest, nil)
      |> redirect(to: login_dest)
    end
  end

  defp login_user(conn, email, password) do
    with :ok <- check_ip_rate_limit(conn),
         {:ok, user} <- find_user(email),
         :ok <- check_user_rate_limit(user),
         :ok <- check_password(user, password) do
      {:ok, user}
    else
      :wrong_password ->
        maybe_log_failed_login_attempts("wrong password for #{email}")

        render(conn, "login_form.html",
          error: "Wrong email or password. Please try again.",
          layout: {PlausibleWeb.LayoutView, "focus.html"}
        )

      :user_not_found ->
        maybe_log_failed_login_attempts("user not found for #{email}")
        Plausible.Auth.Password.dummy_calculation()

        render(conn, "login_form.html",
          error: "Wrong email or password. Please try again.",
          layout: {PlausibleWeb.LayoutView, "focus.html"}
        )

      {:rate_limit, _} ->
        maybe_log_failed_login_attempts("too many logging attempts for #{email}")

        render_error(
          conn,
          429,
          "Too many login attempts. Wait a minute before trying again."
        )
    end
  end

  defp set_user_session(conn, user) do
    conn
    |> put_session(:current_user_id, user.id)
    |> put_resp_cookie("logged_in", "true",
      http_only: false,
      max_age: 60 * 60 * 24 * 365 * 5000
    )
  end

  defp maybe_log_failed_login_attempts(message) do
    if Application.get_env(:plausible, :log_failed_login_attempts) do
      Logger.warning("[login] #{message}")
    end
  end

  @login_interval 60_000
  @login_limit 5
  defp check_ip_rate_limit(conn) do
    ip_address = PlausibleWeb.RemoteIp.get(conn)

    case Hammer.check_rate("login:ip:#{ip_address}", @login_interval, @login_limit) do
      {:allow, _} -> :ok
      {:deny, _} -> {:rate_limit, :ip_address}
    end
  end

  defp find_user(email) do
    user =
      Repo.one(
        from(u in Plausible.Auth.User,
          where: u.email == ^email
        )
      )

    if user, do: {:ok, user}, else: :user_not_found
  end

  defp check_user_rate_limit(user) do
    case Hammer.check_rate("login:user:#{user.id}", @login_interval, @login_limit) do
      {:allow, _} -> :ok
      {:deny, _} -> {:rate_limit, :user}
    end
  end

  defp check_password(user, password) do
    if Plausible.Auth.Password.match?(password, user.password_hash || "") do
      :ok
    else
      :wrong_password
    end
  end

  def login_form(conn, _params) do
    render(conn, "login_form.html", layout: {PlausibleWeb.LayoutView, "focus.html"})
  end

  def user_settings(conn, _params) do
    settings_changeset = Auth.User.settings_changeset(conn.assigns[:current_user])
    email_changeset = Auth.User.settings_changeset(conn.assigns[:current_user])

    render_settings(conn, settings_changeset: settings_changeset, email_changeset: email_changeset)
  end

  def save_settings(conn, %{"user" => user_params}) do
    changes = Auth.User.settings_changeset(conn.assigns[:current_user], user_params)

    case Repo.update(changes) do
      {:ok, _user} ->
        conn
        |> put_flash(:success, "Account settings saved successfully")
        |> redirect(to: Routes.auth_path(conn, :user_settings))

      {:error, changeset} ->
        email_changeset = Auth.User.settings_changeset(conn.assigns[:current_user])

        render_settings(conn, settings_changeset: changeset, email_changeset: email_changeset)
    end
  end

  def update_email(conn, %{"user" => user_params}) do
    changes = Auth.User.email_changeset(conn.assigns[:current_user], user_params)

    case Repo.update(changes) do
      {:ok, user} ->
        send_email_verification(user)

        redirect(conn, to: Routes.auth_path(conn, :activate_form))

      {:error, changeset} ->
        settings_changeset = Auth.User.settings_changeset(conn.assigns[:current_user])

        render_settings(conn, settings_changeset: settings_changeset, email_changeset: changeset)
    end
  end

  def cancel_update_email(conn, _params) do
    changeset = Auth.User.cancel_email_changeset(conn.assigns.current_user)

    case Repo.update(changeset) do
      {:ok, user} ->
        conn
        |> put_flash(:success, "Email changed back to #{user.email}")
        |> redirect(to: Routes.auth_path(conn, :user_settings) <> "#change-email-address")

      {:error, _} ->
        conn
        |> put_flash(
          :error,
          "Could not cancel email update because previous email has already been taken"
        )
        |> redirect(to: Routes.auth_path(conn, :activate_form))
    end
  end

  defp render_settings(conn, opts) do
    settings_changeset = Keyword.fetch!(opts, :settings_changeset)
    email_changeset = Keyword.fetch!(opts, :email_changeset)

    user = Plausible.Users.with_subscription(conn.assigns[:current_user])
    {pageview_usage, custom_event_usage} = Plausible.Billing.usage_breakdown(user)

    render(conn, "user_settings.html",
      user: user |> Repo.preload(:api_keys),
      settings_changeset: settings_changeset,
      email_changeset: email_changeset,
      subscription: user.subscription,
      invoices: Plausible.Billing.paddle_api().get_invoices(user.subscription),
      theme: user.theme || "system",
      team_member_limit: Plausible.Billing.Quota.team_member_limit(user),
      team_member_usage: Plausible.Billing.Quota.team_member_usage(user),
      site_limit: Plausible.Billing.Quota.site_limit(user),
      site_usage: Plausible.Billing.Quota.site_usage(user),
      total_pageview_limit: Plausible.Billing.Quota.monthly_pageview_limit(user.subscription),
      total_pageview_usage: pageview_usage + custom_event_usage,
      custom_event_usage: custom_event_usage,
      pageview_usage: pageview_usage
    )
  end

  def new_api_key(conn, _params) do
    key = :crypto.strong_rand_bytes(64) |> Base.url_encode64() |> binary_part(0, 64)
    changeset = Auth.ApiKey.changeset(%Auth.ApiKey{}, %{key: key})

    render(conn, "new_api_key.html",
      changeset: changeset,
      layout: {PlausibleWeb.LayoutView, "focus.html"}
    )
  end

  def create_api_key(conn, %{"api_key" => key_params}) do
    api_key = %Auth.ApiKey{user_id: conn.assigns[:current_user].id}
    key_params = Map.delete(key_params, "user_id")
    changeset = Auth.ApiKey.changeset(api_key, key_params)

    case Repo.insert(changeset) do
      {:ok, _api_key} ->
        conn
        |> put_flash(:success, "API key created successfully")
        |> redirect(to: "/settings#api-keys")

      {:error, changeset} ->
        render(conn, "new_api_key.html",
          changeset: changeset,
          layout: {PlausibleWeb.LayoutView, "focus.html"}
        )
    end
  end

  def delete_api_key(conn, %{"id" => id}) do
    query =
      from(k in Auth.ApiKey,
        where: k.id == ^id and k.user_id == ^conn.assigns[:current_user].id
      )

    query
    |> Repo.one!()
    |> Repo.delete!()

    conn
    |> put_flash(:success, "API key revoked successfully")
    |> redirect(to: "/settings#api-keys")
  end

  def delete_me(conn, params) do
    Plausible.Auth.delete_user(conn.assigns[:current_user])

    logout(conn, params)
  end

  def logout(conn, params) do
    redirect_to = Map.get(params, "redirect", "/")

    conn
    |> configure_session(drop: true)
    |> delete_resp_cookie("logged_in")
    |> redirect(to: redirect_to)
  end

  def google_auth_callback(conn, %{"error" => error, "state" => state} = params) do
    [site_id, _redirect_to] = Jason.decode!(state)
    site = Repo.get(Plausible.Site, site_id)

    case error do
      "access_denied" ->
        conn
        |> put_flash(
          :error,
          "We were unable to authenticate your Google Analytics account. Please check that you have granted us permission to 'See and download your Google Analytics data' and try again."
        )
        |> redirect(to: Routes.site_path(conn, :settings_general, site.domain))

      message when message in ["server_error", "temporarily_unavailable"] ->
        conn
        |> put_flash(
          :error,
          "We are unable to authenticate your Google Analytics account because Google's authentication service is temporarily unavailable. Please try again in a few moments."
        )
        |> redirect(to: Routes.site_path(conn, :settings_general, site.domain))

      _any ->
        Sentry.capture_message("Google OAuth callback failed. Reason: #{inspect(params)}")

        conn
        |> put_flash(
          :error,
          "We were unable to authenticate your Google Analytics account. If the problem persists, please contact support for assistance."
        )
        |> redirect(to: Routes.site_path(conn, :settings_general, site.domain))
    end
  end

  def google_auth_callback(conn, %{"code" => code, "state" => state}) do
    res = Plausible.Google.HTTP.fetch_access_token(code)
    [site_id, redirect_to] = Jason.decode!(state)
    site = Repo.get(Plausible.Site, site_id)
    expires_at = NaiveDateTime.add(NaiveDateTime.utc_now(), res["expires_in"])

    case redirect_to do
      "import" ->
        redirect(conn,
          to:
            Routes.site_path(conn, :import_from_google_view_id_form, site.domain,
              access_token: res["access_token"],
              refresh_token: res["refresh_token"],
              expires_at: NaiveDateTime.to_iso8601(expires_at)
            )
        )

      _ ->
        id_token = res["id_token"]
        [_, body, _] = String.split(id_token, ".")
        id = body |> Base.decode64!(padding: false) |> Jason.decode!()

        Plausible.Site.GoogleAuth.changeset(%Plausible.Site.GoogleAuth{}, %{
          email: id["email"],
          refresh_token: res["refresh_token"],
          access_token: res["access_token"],
          expires: expires_at,
          user_id: conn.assigns[:current_user].id,
          site_id: site_id
        })
        |> Repo.insert!()

        site = Repo.get(Plausible.Site, site_id)

        redirect(conn, to: "/#{URI.encode_www_form(site.domain)}/settings/#{redirect_to}")
    end
  end
end