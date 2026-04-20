class ProfilesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_profile, only: %i[show edit update]

  def new
    if current_user.profile.present?
      redirect_to profile_path, notice: "Your profile is already set up."
      return
    end

    @profile = current_user.build_profile
  end

  def create
    @profile = current_user.build_profile(profile_params)

    if @profile.save
      redirect_to profile_path, notice: "Profile created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    if @profile.blank?
      redirect_to new_profile_path, alert: "Complete your profile to personalize your workspace."
    end
  end

  def edit
    if @profile.blank?
      redirect_to new_profile_path, alert: "Complete your profile before editing it."
    end
  end

  def update
    if @profile.blank?
      redirect_to new_profile_path, alert: "Complete your profile before editing it."
      return
    end

    if @profile.update(profile_params)
      redirect_to profile_path, notice: "Profile updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_profile
    @profile = current_user.profile
  end

  def profile_params
    params.require(:profile).permit(:first_name, :last_name, :phone, :designation, :company_name, :company_location, :avatar, :bio)
  end
end
