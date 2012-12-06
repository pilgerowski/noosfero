class Kalibro::Processing < Kalibro::Model

  attr_accessor :id, :date, :state, :error, :process_time, :results_root_id

  def self.processing_of(repository_id)
    if has_ready_processing(repository_id)
      last_ready_processing_of(repository_id)
    else
      last_processing_of(repository_id)
    end
  end

  def self.processing_with_date_of(repository_id, date)
    if has_processing_after(repository_id, date)
      first_processing_after(repository_id, date)
    elsif has_processing_before(repository_id, date)
      last_processing_before(repository_id, date)
    else
      last_processing_of(repository_id)        
    end
  end

  def date=(value)
    @date = value.is_a?(String) ? DateTime.parse(value) : value
  end

  def process_times=(value)
    process_time=value
  end

  def process_time=(value)
    @process_time = Kalibro::ProcessTime.to_objects_array value
  end

  def process_times
    process_time
  end

  private

  def self.has_processing(repository_id)
    request(:has_processing, {:repository_id => repository_id})[:exists]
  end
  
  def self.has_ready_processing(repository_id)
    request(:has_ready_processing, {:repository_id => repository_id})[:exists]
  end
  
  def self.has_processing_after(repository_id, date)
    request(:has_processing_after, {:repository_id => repository_id, :date => date})[:exists]
  end

  def self.has_processing_before(repository_id, date)
    request(:has_processing_before, {:repository_id => repository_id, :date => date})[:exists]
  end

  def self.last_processing_state_of(repository_id)
    request(:last_processing_state, {:repository_id => repository_id})[:process_state]
  end
  
  def self.last_ready_processing_of(repository_id)
    new request(:last_ready_processing, {:repository_id => repository_id})[:processing]
  end

  def self.first_processing_of(repository_id)
    new request(:first_processing, {:repository_id => repository_id})[:processing]
  end

  def self.last_processing_of(repository_id)
    new request(:last_processing, {:repository_id => repository_id})[:processing]
  end

  def self.first_processing_after(repository_id, date)
    new request(:first_processing_after, {:repository_id => repository_id, :date => date})[:processing]
  end

  def self.last_processing_before(repository_id, date)
    new request(:last_processing_before, {:repository_id => repository_id, :date => date})[:processing]
  end

end
