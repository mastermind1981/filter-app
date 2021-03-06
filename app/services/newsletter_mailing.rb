class NewsletterMailing
  attr_reader :subscription

  def self.cronjob
    MailSubscription.confirmed.each do |s|
      ms = new(s)
      if ms.sendable?
        ms.send!
      end
    end
  end

  def initialize(subscription)
    @subscription = subscription
  end

  def sendable?
    news_items.count > 0 && subscription.due?
  end

  def send!
    mail.deliver_now!
  rescue StandardError => e
    puts "[NewsletterMailing] #{e.inspect}"
  ensure
    subscription.update_column :last_send_date, Date.today
  end

  def mail
    NewsletterMailer.newsletter(self)
  end

  def email
    @subscription.email
  end

  def news_items
    @news_items ||=
      begin
        all = categories.map { |category|
          top_news_items_for(category).to_a
        }.flatten
        all.uniq(&:id).sort_by { |i| -(i.absolute_score || 0) }
      end
  end

  def count
    @count ||= news_items.count
  end

  def total_count
    sql = NewsItem.
          where('published_at > ?', subscription.interval_from.ago)

    categorized = sql.
                  joins(:categories).
                  where(categories: { id: categories }).
                  group('news_items.id').length

    if has_uncatorized?
      categorized + sql.uncategorized.length
    else
      categorized
    end
  end

  def categories
    ids = @subscription.categories.reject(&:blank?)
    base = Category.where(id: ids).to_a
    if has_uncatorized?
      base + [Uncategorized.new]
    else
      base
    end
  end

  def has_uncatorized?
    @subscription.categories.include? 0
  end

  private

  def filter_doubles(categories_with_counts)
    filtered = []
    categories_with_counts.map do |cat, nis, total_count|
      ids = nis.pluck(:id)
      if filtered.present?
        filtered_nis = nis.where("news_items.id not in (?)", filtered)
      else
        filtered_nis = nis
      end
      filtered += ids
      [cat, filtered_nis, total_count]
    end
  end

  def top_news_items_for(category)
    if category.is_a?(Uncategorized)
      all = NewsItem.uncategorized
    else
      all = NewsItem.
            joins(:categories).
            where(categories: { id: category })
    end
    all = all.
          group('news_items.id').
          where('published_at > ?', subscription.interval_from.ago).
          order('absolute_score desc')

    count = all.length
    limit = limit_fn(count)
    all.limit(limit)
  end

  def limit_fn(count)
    case count
    when 0..5 then count
    when 5..10_000 then 5 + ((count - 5)**0.50).to_i
    end
  end
end
