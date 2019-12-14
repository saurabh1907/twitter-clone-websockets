defmodule OperationService do
  use GenServer
  require Logger

  def start() do
    GenServer.start_link(__MODULE__, :ok, name: :operation_service)
  end

  def init(args) do
    state = args
    {:ok, state}
  end

  def handle_call({:hashtag, hashtag, username, client},_, state) do
    Logger.info("Sending tweets to user: #{username} with hashtag: #{hashtag}")
    spawn(fn -> send_hashtags(hashtag, client, username) end)
    {:reply, :ok, state}
  end

  def handle_call({:mention, mention, username, client},_, state) do
    Logger.info("sending tweets to user: #{username} with mention: #{mention}")
    spawn(fn -> send_mentions(mention, client, username) end)
    {:reply, :ok, state}
  end

  def handle_call({:tweet, username, tweet},_, state) do
    mentioned = None
    parts = SocialParser.extract(tweet, [:hashtags, :mentions])

    if Map.has_key?(parts, :hashtags) do
      hashTagValues = parts[:hashtags]

      for hashtag <- hashTagValues do
        Logger.info("adding hashtag :#{hashtag} for tweet: #{tweet} to table")
        add_hashtag_tweet(hashtag, tweet)
      end
    end

    if Map.has_key?(parts, :mentions) do
      mentioned = parts[:mentions]

      for user <- mentioned do
        Logger.info("adding mention: #{user} for tweet: #{tweet} to table")
        add_mention_tweet(user, tweet)
        mentioned_user = String.split(user, ["@", "+"], trim: true) |> List.first()

        if mentioned_user != username do
          send_tweet(mentioned_user, username, tweet)
        end
      end

      mentioned =
        mentioned
        |> Enum.reduce([], fn x, acc ->
          [List.first(String.split(x, ["@", "+"], trim: true)) | acc]
        end)
    end

    subscribers = find_user_subscribers(username)

    for subscriber <- subscribers do
      Logger.debug("subscribers: #{subscriber} mentioned_users: #{inspect(mentioned)}")

      if mentioned != None and Enum.member?(mentioned, subscriber) do
        Logger.debug("Avoiding to resend")
      else
        send_tweet(subscriber, username, tweet)
      end
    end

    {:reply, :ok, state}
  end

  defp add_mention_tweet(mention, tweet) do
    mentions = :ets.lookup(:mentions, mention)

    if mentions != [] do
      updated_mentions = mentions |> List.first() |> elem(1) |> MapSet.put(tweet)
      PersistenceService.insert_record(:mentions, {mention, updated_mentions})
    else
      tweets = MapSet.new() |> MapSet.put(tweet)
      PersistenceService.insert_record(:mentions, {mention, tweets})
    end
  end

  defp send_mentions(mention, client, username) do
    tweets_chunks = PersistenceService.get_mention_tweets(mention) |> MapSet.to_list() |> Enum.chunk_every(5)
    Logger.debug("sending mentions: #{inspect(tweets_chunks)}")

    for tweets <- tweets_chunks do
      data = %{"function" => "mention", "tweets" => tweets, "username" => username}
      send_response(client, data)
      :timer.sleep(20)
    end
  end

  defp member_of_hashtags(hashtag) do
    :ets.member(:hashtags, hashtag)
  end

  defp get_hashtag_tweets(hashtag) do
    if member_of_hashtags(hashtag) do
      :ets.lookup_element(:hashtags, hashtag, 2)
    else
      MapSet.new()
    end
  end

  defp add_hashtag_tweet(hashtag, tweet) do
    hashtags = :ets.lookup(:hashtags, hashtag)

    if hashtags != [] do
      updated_tweets = hashtags |> List.first() |> elem(1) |> MapSet.put(tweet)
      PersistenceService.insert_record(:hashtags, {hashtag, updated_tweets})
    else
      tweets = MapSet.new() |> MapSet.put(tweet)
      PersistenceService.insert_record(:hashtags, {hashtag, tweets})
    end
  end

  defp send_hashtags(hashtag, client, username) do
    tweets_chunks = get_hashtag_tweets(hashtag) |> MapSet.to_list() |> Enum.chunk_every(5)

    for tweets <- tweets_chunks do
      data = %{"function" => "hashtag", "tweets" => tweets, "username" => username}
      send_response(client, data)
      :timer.sleep(20)
    end
  end

  defp send_tweet(to, sender, tweet) do
    port = find_user_port(to)
    status = find_user_status(to)

    if status == :online do
      Logger.debug("Sending to: #{to} tweet: #{tweet} on socket: #{inspect(port)}")

      send_response(port, %{
        "function" => "tweet",
        "sender" => sender,
        "tweet" => tweet,
        "username" => to
      })
    else
      Logger.debug("Adding to user feed as #{to} is not online")
      add_user_feed(to, tweet)
    end

    StatsService.increment_counter("tweets")
  end

  defp find_user_status(username) do
    # User is stored with these parameters {status, subscribers, feed}
    find_user_field(username, 1)
  end

  defp find_user_port(username) do
    find_user_field(username, 4)
  end

  defp find_user_subscribers(username) do
    find_user_field(username, 2)
  end

  defp add_user_feed(username, tweet) do
    feed = find_user_feed(username)

    if feed do
      Logger.debug("#{username}'s feed: #{inspect(feed)}")
      feed = enqueue(feed, tweet)
      Logger.debug("#{username}'s updated feed: #{inspect(feed)}")
      PersistenceService.update_user_data(username, 4, feed)
    end
  end

  def send_response(client, data) do
    encoded_response = Poison.encode!(data)
    :gen_tcp.send(client, encoded_response)
  end

  defp find_user_field(username, position) do
    user = PersistenceService.find_user(username)

    if user != false do
      user |> elem(position)
    else
      false
    end
  end

  defp find_user_feed(username) do
    find_user_field(username, 3)
  end

  defp enqueue(queue, value) do
    if :queue.member(value, queue) do
      queue
    else
      :queue.in(value, queue)
    end
  end
end
