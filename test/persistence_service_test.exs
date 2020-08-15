defmodule PersistenceServiceTest do
  use ExUnit.Case
  doctest PersistenceService

  test "insert record" do
    init()
    data = {"test", 1}
    PersistenceService.insert_record(:counter, data)
    assert :ets.lookup_element(:counter, "test", 2) == 1
  end

  test "update counter" do
    init()
    data = {"test", 1}
    PersistenceService.insert_record(:counter, data)
    PersistenceService.update_counter("test", 2)
    assert :ets.lookup_element(:counter, "test", 2) == 3
  end

  test "find user" do
    init()
    PersistenceService.insert_record(
        :users,
        {"test", :online, MapSet.new(), :queue.new(), "client"}
      )
    record = PersistenceService.find_user("test")
    assert elem(record,0) == "test"
  end


  def init() do
    PersistenceService.start()
  end
end
