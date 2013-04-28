require "interjectable/version"

module Interjectable
  def self.extended(mod)
    super
  end

  def inject(dependency, &default_block)
    attr_writer dependency

    define_method(dependency) do
      # @dependency ||= instance_eval(&default_block)
      ivar_name = "@#{dependency}"
      instance_variable_get(ivar_name) || begin
        instance_variable_set(ivar_name, instance_eval(&default_block))
      end
    end
  end
end
