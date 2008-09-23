class Feed < ActiveRecord::Base
  
  class_inheritable_accessor :entry_type
  
  has_many :posts
  
  validates_presence_of :uri
  validates_format_of :uri, :with => %r{^(http|file)://}i, :on => :create
  
  after_create :learn_attributes!
  
  class << self
    def refresh_all!
      find(:all).each(&:refresh!)
    end
    
    def entries_become(post_type, &block)
      self.entry_type = post_type
      has_many post_type, :foreign_key => :feed_id, :dependent => :destroy
      define_method(:refresh!) do
        logger.debug "=> creating #{post_type} from #{uri}"
        entries.each(&block.bind(self))
        self.updated_at = Time.now
        self.save
      end
    end
  end
  
  def fetch_feed
    with_indifferent_io do |io|
      FeedNormalizer::FeedNormalizer.parse(io)
    end
  end
  
  def refresh=(res)
    refresh! if res.to_boolean
    return true
  end
  
  def learn_attributes!
    self.title  = fetched_feed.title
    self.description = fetched_feed.description
    self.url = fetched_feed.urls.first
    self.update_timestamp
    self.save
  end
  
  def type
    attributes['type']
  end
  
  def update_timestamp
    self.last_updated_at = fetched_feed.last_updated || fetched_feed.entries.sort_by(&:date_published).last.date_published
  end
  
  def entries
    @entries ||= fetch_feed.entries
  end
  
  def fetched_feed
    @fetched_feed ||= fetch_feed
  end
  
end
