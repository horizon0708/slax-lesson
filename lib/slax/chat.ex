defmodule Slax.Chat do
  alias Slax.Accounts.User
  alias Slax.Chat.{Message, Room}
  alias Slax.Repo

  import Ecto.Query

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
    %Message{room: room, user: user}
    |> Message.changeset(attrs)
    |> Repo.insert()
  end

  def delete_message_by_id(id, %User{id: user_id}) do
    message = %Message{user_id: ^user_id} = Repo.get(Message, id)
    Repo.delete(message)
  end
end
