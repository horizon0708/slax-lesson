defmodule Slax.Chat do
  alias Slax.Accounts.User
  alias Slax.Chat.{Message, Room, RoomMembership}
  alias Slax.Repo

  import Ecto.Changeset
  import Ecto.Query

  @pubsub Slax.PubSub

  def get_first_room! do
    Room
    |> order_by(asc: :name)
    |> limit(1)
    |> Repo.one!()
  end

  def get_room!(id) do
    Room |> Repo.get!(id)
  end

  def list_rooms do
    # lets try declarative style
    Repo.all(from r in Room, order_by: [asc: r.name])
  end

  def list_joined_rooms_with_unread_counts(%User{} = user) do
    from(
      # From all rooms:
      room in Room,
      # Select only those rooms for which the user has a membership:
      join: membership in assoc(room, :memberships),
      where: membership.user_id == ^user.id,

      # Additionally select the unread messages in those rooms. Use 'left_join'
      # so that we don't remove rooms which have no unread messages.
      left_join: message in assoc(room, :messages),
      on: message.id > membership.last_read_id,

      # Select the room, plus each room's unread message count:
      group_by: room.id,
      select: {room, count(message.id)},

      # Order the results by room name:
      order_by: [asc: room.name]
    )
    |> Repo.all()
  end

  def list_rooms_with_joined(%User{} = user) do
    query =
      from r in Room,
        left_join: m in RoomMembership,
        on: r.id == m.room_id and m.user_id == ^user.id,
        select: {r, not is_nil(m.id)},
        order_by: [asc: :name]

    Repo.all(query)
  end

  def change_room(%Room{} = room, attrs \\ %{}) do
    Room.changeset(room, attrs)
  end

  def create_room(attrs) do
    %Room{} |> Room.changeset(attrs) |> Repo.insert()
  end

  def update_room(%Room{} = room, attrs) do
    room |> Room.changeset(attrs) |> Repo.update()
  end

  # Messages

  def list_messages_in_room(%Room{id: room_id}) do
    Message
    |> where([m], m.room_id == ^room_id)
    |> order_by([m], asc: :inserted_at, asc: :id)
    |> preload(:user)
    |> Repo.all()
  end

  def change_message(message, attrs \\ %{}) do
    Message.changeset(message, attrs)
  end

  def create_message(room, attrs, user) do
    with {:ok, message} <-
           %Message{room: room, user: user}
           |> Message.changeset(attrs)
           |> Repo.insert() do
      Phoenix.PubSub.broadcast!(@pubsub, topic(room.id), {:new_message, message})
      {:ok, message}
    end
  end

  def delete_message_by_id(id, %User{id: user_id}) do
    message = %Message{user_id: ^user_id} = Repo.get(Message, id)
    Repo.delete(message)

    Phoenix.PubSub.broadcast!(@pubsub, topic(message.room_id), {:message_deleted, message})
  end

  def subscribe_to_room(room) do
    Phoenix.PubSub.subscribe(@pubsub, topic(room.id))
  end

  def unsubscribe_from_room(room) do
    Phoenix.PubSub.unsubscribe(@pubsub, topic(room.id))
  end

  def join_room!(room, user) do
    Repo.insert!(%RoomMembership{room: room, user: user})
  end

  def toggle_room_membership(room, user) do
    case get_membership(room, user) do
      %RoomMembership{} = membership ->
        Repo.delete(membership)
        {room, false}

      nil ->
        join_room!(room, user)
        {room, true}
    end
  end

  def update_last_read_id(room, user) do
    case get_membership(room, user) do
      %RoomMembership{} = membership ->
        id =
          from(m in Message, where: m.room_id == ^room.id, select: max(m.id))
          |> Repo.one()

        membership
        |> change(%{last_read_id: id})
        |> Repo.update()

      nil ->
        nil
    end
  end

  defp get_membership(room, user) do
    Repo.get_by(RoomMembership, room_id: room.id, user_id: user.id)
  end

  def joined?(%Room{} = room, %User{} = user) do
    Repo.exists?(
      from rm in RoomMembership, where: rm.room_id == ^room.id and rm.user_id == ^user.id
    )
  end

  defp topic(room_id), do: "chat_room:#{room_id}"

  def get_last_read_id(%Room{} = room, user) do
    case get_membership(room, user) do
      %RoomMembership{} = membership ->
        membership.last_read_id

      nil ->
        nil
    end
  end
end
