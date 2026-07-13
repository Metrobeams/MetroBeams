defmodule PlataformaWeb.Router do
  use PlataformaWeb, :router

  import PlataformaWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PlataformaWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
    plug PlataformaWeb.Plugs.FetchNotifications
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :authenticated_api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
    plug :require_authenticated_api_user
  end

  # Other scopes may use custom stacks.
  # scope "/api", PlataformaWeb do
  #   pipe_through :api
  # end

  scope "/api", PlataformaWeb do
    pipe_through :authenticated_api

    get "/account", AccountController, :show
    put "/account/avatar", AccountController, :update_avatar
    delete "/account/avatar", AccountController, :delete_avatar
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:plataforma, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PlataformaWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", PlataformaWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
  end

  scope "/", PlataformaWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/", PageController, :home
    get "/organizations/new", OrganizationController, :new
    post "/organizations", OrganizationController, :create
    get "/organizations/:id/edit", OrganizationController, :edit
    put "/organizations/:id", OrganizationController, :update
    get "/notifications", NotificationController, :index
    patch "/notifications/read-all", NotificationController, :read_all
    patch "/notifications/:id/read", NotificationController, :read
    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
    put "/users/settings/avatar", UserSettingsController, :update_avatar
    delete "/users/settings/avatar", UserSettingsController, :delete_avatar
    get "/users/settings/confirm-email/:token", UserSettingsController, :confirm_email

    resources "/asset-categories", AssetCategoryController
    resources "/manufacturers", ManufacturerController
  end

  scope "/", PlataformaWeb do
    pipe_through [:browser]

    get "/users/log-in", UserSessionController, :new
    get "/users/log-in/:token", UserSessionController, :confirm
    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
