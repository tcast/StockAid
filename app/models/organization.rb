class Organization < ActiveRecord::Base
  has_many :organization_users
  has_many :users, through: :organization_users
  has_many :orders
  has_many :addresses
  accepts_nested_attributes_for :addresses, allow_destroy: true
  validates :name, uniqueness: true

  before_save :add_county

  def add_county
    return unless county.nil? && primary_address
    if changed_attributes.keys.include?("addresses_attributes")
      fetch_geocoding_data do |result|
        self.county = result.address_components.find { |component|
          component["types"].include?("administrative_area_level_2")
        }["short_name"]
      end
    end
  end

  def reportable_orders
    orders.where("status >= 1").order(order_date: :desc) # Approved
  end

  def reportable_orders_value
    reportable_orders.map(&:value).inject(0) { |a, e| a + e }
  end

  def reportable_orders_item_count
    reportable_orders.map(&:item_count).inject(0) { |a, e| a + e }
  end

  def self.counties
    Organization.select(:county).map(&:county).uniq
  end

  def primary_address
    addresses.first.present? ? addresses.first.address : "No Adress Found"
  end

  private

  def fetch_geocoding_data
    begin
      result = Geocoder.search(primary_address).first
    rescue Geocoder::Error => e
      Rails.logger.error("Error fetching geocoding info for #{primary_address}:\n #{e.backtrace}")
    end
    yield result if result
  end
end
