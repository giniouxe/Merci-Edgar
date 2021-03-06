class Network < ActiveRecord::Base
  default_scope { where(:account_id => Account.current_id) }
  validates :network, presence: true
  validates_uniqueness_of :network, scope: :account_id  
  
  def self.add_network(network_name)
    n = Network.new()
    n.network = network_name
    n.save
  end
  
  def self.add_networks(networks)
    networks.each { |n| add_network(n) }
  end
  
end