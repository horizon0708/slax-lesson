defmodule Slax.Chat do
  alias Slax.Chat.Room
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
end
