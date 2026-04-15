class CareersController < ApplicationController
  def index
    @jobs = Job.published.order(published_at: :desc, created_at: :desc)
  end

  def show
    @job = Job.published.find_by!(slug: params[:id])
    @application = Application.new
  end
end
