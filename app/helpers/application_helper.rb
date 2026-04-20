module ApplicationHelper
  def profile_or_new_path
    if current_user&.profile.present?
      profile_path
    else
      new_profile_path
    end
  end
end
