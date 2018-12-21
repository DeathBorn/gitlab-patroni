class ConsulCookbook::Resource::ConsulDefinition
  attribute(:parameters, option_collector: false, default: {})

  def to_json
    final_parameters = parameters

    # Because 'services' type can be an Array
    if final_parameters.is_a?(Hash) && final_parameters[:name].nil?
      final_parameters = final_parameters.merge(name: name)
    end

    JSON.pretty_generate(type => final_parameters)
  end
end
