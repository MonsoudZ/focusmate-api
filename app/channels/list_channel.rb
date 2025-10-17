class ListChannel < ApplicationCable::Channel
  def subscribed
    @list = List.find(params[:list_id])
    reject if @list.blank?
    reject unless current_user.memberships.exists?(list_id: @list.id)
    stream_for @list
  end
end
