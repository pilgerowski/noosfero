class CustomFormsPlugin::Form < ApplicationRecord

  belongs_to :profile

  has_many :fields, -> { order 'position' },
    class_name: 'CustomFormsPlugin::Field', dependent: :destroy
  accepts_nested_attributes_for :fields, :allow_destroy => true

  has_many :submissions,
    :class_name => 'CustomFormsPlugin::Submission', :dependent => :destroy

  serialize :access

  validates_presence_of :profile, :name, :identifier
  validates_uniqueness_of :slug, :scope => :profile_id
  validates_uniqueness_of :identifier, :scope => :profile_id
  validate :period_range,
    :if => Proc.new { |f| f.begining.present? && f.ending.present? }
  validate :access_format

  attr_accessible :name, :profile, :for_admission, :access, :begining,
    :ending, :description, :fields_attributes, :profile_id,
    :on_membership, :identifier, :access_result_options

  before_validation do |form|
    form.slug = form.name.to_slug if form.name.present?
    form.access = nil if form.access.blank?
  end

  after_destroy do |form|
    tasks = CustomFormsPlugin::MembershipSurvey.opened.select { |t| t.form_id == form.id }
    tasks.each {|task| task.cancel}
  end

  scope :from_profile, -> profile { where profile_id: profile.id }
  scope :on_memberships, -> { where on_membership: true, for_admission: false }
  scope :for_admissions, -> { where for_admission: true }
  scope :public_results, -> { where access_result_options: "public" }
  scope :private_results, -> { where access_result_options: "private" }
  scope :public_after_ends, -> { where access_result_options: "public_after_ends" }

  def expired?
    (begining.present? && Time.now < begining) || (ending.present? && Time.now > ending)
  end

  def will_open?
    begining.present? && Time.now < begining
  end

  def accessible_to(target)
    return true if access.nil? || target == profile
    return false if target.nil?
    return true if access == 'logged'
    return true if access == 'associated' && ((profile.organization? && profile.members.include?(target)) || (profile.person? && profile.friends.include?(target)))
    return true if access.kind_of?(Integer) && target.id == access
    return true if access.kind_of?(Array) && access.include?(target.id)
  end

  def image
    self.article
  end

  def image=(uploaded_file)
    self.article = uploaded_file
  end

  private

  def access_format
    if access.present?
      if access.kind_of?(String)
        if access != 'logged' && access != 'associated'
          errors.add(:access, _('Invalid string format of access.'))
        end
      elsif access.kind_of?(Integer)
        if !Profile.exists?(access)
          errors.add(:access, _('There is no profile with the provided id.'))
        end
      elsif access.kind_of?(Array)
        access.each do |value|
          if !value.kind_of?(Integer) || !Profile.exists?(value)
            errors.add(:access, _('There is no profile with the provided id.'))
            break
          end
        end
      else
        errors.add(:access, _('Invalid type format of access.'))
      end
    end
  end

  def period_range
    errors.add(:base, _('The time range selected is invalid.')) if ending < begining
  end
end
