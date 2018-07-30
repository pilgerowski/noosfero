class CustomFormsPlugin::Graph
  # @query_results have the format
  # [
  #   {
  #     "summary"=>{}, "data"=>{"foo"=>1, "bar"=>1, "teste"=>1},
  #     "show_as"=>"radio", "field"=>"some form field"
  #   }
  # ]
  # Each 'data' key on @query_results represents the data that will be used by
  # chartkick lib, to render a graph based on the show_as value.

  AVAILABLE_FIELDS = %w(check_box radio select multiple_select text)

  def initialize(form)
    @form = form
    self.compute_results
  end

  def compute_results
    @query_results = report()
  end


  def chart_to_show_data(show_as)
    return 'pizza' if ["radio", "select"].include?(show_as)
    return 'column' if ["check_box", "multiple_select"].include?(show_as)
    return 'text' if show_as == 'text'
  end

  def query_results
    @query_results
  end

  def report()
    data = get_data

    format_data(data)
  end

  private
  def get_data
    # TODO: Use left_joins after Rails 5 upgrade
    data = @form.fields
          .joins(:alternatives)
          .joins('LEFT JOIN custom_forms_plugin_form_answers '\
                 'ON custom_forms_plugin_alternatives.id = custom_forms_plugin_form_answers.alternative_id')
          .group('custom_forms_plugin_fields.id, custom_forms_plugin_alternatives.id')
          .order('custom_forms_plugin_alternatives.id')
          .select('custom_forms_plugin_fields.name AS field_name,'\
                  'custom_forms_plugin_fields.show_as AS show_as,'\
                  'custom_forms_plugin_alternatives.id AS alternative,'\
                  'custom_forms_plugin_alternatives.label AS label,'\
                  'COUNT(custom_forms_plugin_form_answers.alternative_id) AS answer_count')
    
    data
  end

  def format_data(data)
    computed_fields = []
    computed_data = []

    data.map do |r|
      if computed_fields.include?(r.field_name)
        computed_data.each do |c|
          if c["field"] == r.field_name
            c["data"][r.label] = r.answer_count
            break
          end
        end
      else
        computed_fields << r.field_name
        data = { "data" => { r.label => r.answer_count},
                 "field" => r.field_name,
                 "show_as" => chart_to_show_data(r.show_as),
                 "summary" => {}}
        computed_data << data
      end
    end

    computed_data
  end 
end
