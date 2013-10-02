# == Schema Information
#
# Table name: contacts
#
#  id               :integer          not null, primary key
#  phone            :string(255)
#  email            :string(255)
#  website          :string(255)
#  street           :string(255)
#  postal_code      :string(255)
#  state            :string(255)
#  city             :string(255)
#  country          :string(255)
#  contactable_id   :integer
#  contactable_type :string(255)
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#

class Contact < ActiveRecord::Base
  default_scope { where(:account_id => Account.current_id).order(:name) }

  attr_accessible :emails_attributes, :phones_attributes, :addresses_attributes, :websites_attributes, :avatar, :style_list, :network_list, :custom_list
  has_many :emails, :dependent => :destroy
  has_many :phones, :dependent => :destroy
  has_many :addresses, :dependent => :destroy
  has_many :websites, :dependent => :destroy

  has_many :taggings, as: :asset
  has_many :tags, through: :taggings
  has_many :styles, through: :taggings, source: :tag, class_name: "Style"
  has_many :networks, through: :taggings, source: :tag, class_name: "Network"
  has_many :customs, through: :taggings, source: :tag, class_name: "CustomTag"

  has_many :tasks, :as => :asset

  has_many :reportings, :as => :asset, :order => 'created_at DESC'
  has_many :reports, through: :reportings, source: :report, source_type: :report

  has_many :favorite_contacts

  belongs_to :main_contact, class_name: "Contact"


  accepts_nested_attributes_for :emails, :reject_if => proc { |attributes| attributes[:address].blank? }, :allow_destroy => true
  accepts_nested_attributes_for :phones, :reject_if => proc { |attributes| attributes[:national_number].blank? }, :allow_destroy => true
  accepts_nested_attributes_for :addresses, :reject_if => proc { |attributes| attributes[:street].blank? && attributes[:city].blank? && attributes[:postal_code].blank? }, :allow_destroy => true
  accepts_nested_attributes_for :websites, :reject_if => :all_blank, :allow_destroy => true

  mount_uploader :avatar, AvatarUploader

  scope :tagged_with, lambda { |tag_name| joins(:tags).where('tags.name = ?', tag_name) }
  scope :with_name_like, lambda { |pattern| where('name LIKE ? OR first_name LIKE ?', "%#{pattern}%", "%#{pattern}%")}
  scope :with_first_name_and_last_name, lambda { |pattern,fn,ln| where('first_name LIKE ? AND name LIKE ? OR name LIKE ?', "%#{fn}%", "%#{ln}%","%#{pattern}%")}
  scope :with_reportings, joins: :reportings
  scope :by_department, lambda { |code_dept| joins(:addresses).where('addresses.postal_code LIKE ?', "#{code_dept}%")}


  def phone_number
    @phone_number ||= phones.first.try(:formatted_phone)
  end

  def email_address
    @email_address ||= emails.first.try(:address)
  end

  def address
    @address ||= addresses.first
  end

  def postal_code
    @postal_code ||= address.try(:postal_code)
  end

  def city
    @city ||= address.try(:city)
  end

  def country
    @country ||= address.try(:country)
  end

  def website_url
    @website_url ||= websites.first.try(:url)
  end

  def contacted?
    self.reportings.any?
  end


  def reject_if_all_blank_except_country
    attributes[:street].blank? && attributes[:city].blank? && attributes[:postal_code].blank?
  end

  def tag_list
    tags.map(&:name).join(", ")
  end

  def tag_list=(names)
    self.tags = names.split(",").map do |n|
      Tag.where(name: n.strip).first_or_create!
    end
  end


  def self.advanced_search(params)
    if params[:capacity_lt].present? || params[:capacity_gt].present? || params[:venue_kind].present?
      @contacts = Venue.order(:name)
      @contacts = @contacts.capacities_less_than(params[:capacity_lt]) if params[:capacity_lt].present?
      @contacts = @contacts.capacities_more_than(params[:capacity_gt]) if params[:capacity_gt].present?
      @contacts = @contacts.by_type(params[:venue_kind]) if params[:venue_kind].present?
    else
      @contacts = Contact.order(:name)
    end

    @contacts = @contacts.by_department(params[:dept]) if params[:dept].present?
    if params[:style_list].present? || params[:contract_list].present? || params[:custom_list].present?
      fields = []
      values = []
      params[:style_list].split(',').each do |t|
        fields << "tags.name = ? AND tags.type = 'Style'"
        values << t.strip
      end
      style_fields = fields.join(" OR ")

      fields = []
      params[:contract_list].split(',').each do |t|
        fields << "tags.name = ? AND tags.type = 'Contract'"
        values << t.strip
      end
      contract_fields = fields.join(" OR ")

      fields = []
      params[:custom_list].split(',').each do |t|
        fields << "tags.name = ? AND tags.type = 'CustomTag'"
        values << t.strip
      end
      custom_fields = fields.join(" OR ")

      fields = [style_fields, contract_fields, custom_fields].reject(&:empty?).join(" AND ")
      debugger
      @contacts = @contacts.joins(:tags).where([fields] + values)

    end
    @contacts
  end

  def self.search(search)
    if search.present?
      a = search.split
      if a.size > 1
        Contact.with_first_name_and_last_name(search,a.shift,a.join(' '))
      else
        Contact.with_name_like(search)
      end
    else
      Contact.order(:name)
    end
  end

  def favorite?(user)
    @favorite ||= self.favorite_contacts.where(user_id: user.id).any?
  end

  def style_list
    styles.map(&:name).join(", ")
  end

  def style_list=(names)
    self.styles = names.split(",").map do |n|
      Style.where(name: n.strip).first_or_create!
    end
  end

  def network_list
    networks.map(&:name).join(", ")
  end

  def network_list=(names)
    self.networks = names.split(",").map do |n|
      Network.where(name: n.strip).first_or_create!
    end
  end

  def custom_list
    customs.map(&:name).join(", ")
  end

  def custom_list=(names)
    self.customs = names.split(",").map do |n|
      CustomTag.where(name: n.strip, account_id: Account.current_id).first_or_create!
    end
  end

end
