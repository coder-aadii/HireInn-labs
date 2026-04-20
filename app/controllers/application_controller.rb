class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  stale_when_importmap_changes

  def after_sign_in_path_for(_resource)
    dashboard_path
  end

  def after_sign_out_path_for(_resource_or_scope)
    root_path
  end
end
