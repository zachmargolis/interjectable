# frozen_string_literal: true

require "interjectable/version"

module Interjectable
  MethodAlreadyDefined = Class.new(StandardError)

  def self.included(mod)
    mod.send(:extend, ClassMethods)
    mod.send(:include, InstanceMethods)
  end

  def self.extended(mod)
    mod.send(:extend, ClassMethods)
    mod.send(:include, InstanceMethods)
  end

  module InstanceMethods
    def injected_methods(include_super = true)
      injected = self.class.instance_variable_get(:@injected_methods).to_a

      if include_super
        super_injected = self.class.ancestors.flat_map do |klass|
          klass.instance_variable_get(:@injected_methods).to_a
        end

        [
          :injected_methods,
          *super_injected,
          *injected,
        ].uniq
      else
        [:injected_methods, *injected]
      end
    end
  end

  module ClassMethods
    # Defines a helper methods on instances that memoize values per-instance.
    #
    # Calling a second time is an error. Use `#test_inject` for overriding in
    # RSpec tests. You need to `require "interjectable/rspec"` to use
    # `#test_inject`. See the README.md.
    #
    # Similar to writing
    #
    #   attr_writer :dependency
    #
    #   def dependency
    #     @dependency ||= instance_eval(&default_block)
    #   end
    def inject(dependency, &default_block)
      if instance_methods(false).include?(dependency)
        raise MethodAlreadyDefined, "#{dependency} is already defined"
      end

      attr_writer dependency

      define_method(dependency) do
        ivar_name = :"@#{dependency}"
        if instance_variable_defined?(ivar_name)
          instance_variable_get(ivar_name)
        else
          instance_variable_set(ivar_name, instance_eval(&default_block))
        end
      end

      @injected_methods ||= []
      @injected_methods += [dependency, :"#{dependency}="]
    end

    # Defines helper methods on instances that memoize values per-class.
    # (shared across all instances of a class, including instances of
    # subclasses).
    #
    # Calling a second time is an error. Use `#test_inject` for overriding in
    # RSpec tests. You need to `require "interjectable/rspec"` to use
    # `#test_inject`. See the README.md.
    #
    # Similar to writing
    #
    #   cattr_writer :dependency
    #
    #   def dependency
    #     @@dependency ||= instance_eval(&default_block)
    #   end
    def inject_static(dependency, &default_block)
      if instance_methods(false).include?(dependency) || methods(false).include?(dependency)
        raise MethodAlreadyDefined, "#{dependency} is already defined"
      end

      injecting_class = self

      cvar_name = :"@@#{dependency}"
      setter = :"#{dependency}="

      define_method(setter) do |value|
        injecting_class.send(setter, value)
      end

      define_singleton_method(setter) do |value|
        injecting_class.class_variable_set(cvar_name, value)
      end

      define_method(dependency) do
        injecting_class.send(dependency)
      end

      define_singleton_method(dependency) do
        if class_variable_defined?(cvar_name)
          injecting_class.class_variable_get(cvar_name)
        else
          injecting_class.class_variable_set(cvar_name, instance_eval(&default_block))
        end
      end

      @static_injected_methods ||= []
      @static_injected_methods += [dependency, :"#{dependency}="]
    end

    # @return [Array<Symbol>]
    def injected_methods(include_super = true)
      injected = @injected_methods.to_a + @static_injected_methods.to_a

      if include_super
        super_injected = ancestors.flat_map do |klass|
          klass.instance_variable_get(:@injected_methods).to_a +
            klass.instance_variable_get(:@static_injected_methods).to_a
        end

        [
          :injected_methods,
          *super_injected,
          *injected,
        ].uniq
      else
        [:injected_methods, *injected]
      end
    end
  end
end
