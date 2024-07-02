# frozen_string_literal: true

require "interjectable/version"

module Interjectable
  MethodAlreadyDefined = Class.new(StandardError)

  def self.included(mod)
    mod.send(:extend, ClassMethods)
  end

  def self.extended(mod)
    mod.send(:extend, ClassMethods)
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
    #
    # Also defines both an instance and singleton helper method `injected_methods(include_super = true)`,
    # which tracks injected dependencies regardless of whether the dependency was injected on the instance or class.
    # It includes itself as one of the injected methods (i.e. `injected_methods` will be present).
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

      injected_methods = :injected_methods
      injected_methods_ivar = :"@#{injected_methods}"
      setter = :"#{dependency}="

      unless instance_variable_defined?(injected_methods_ivar)
        instance_variable_set(injected_methods_ivar, [injected_methods])
      end
      instance_variable_get(injected_methods_ivar).append(dependency, setter)

      injecting_class = self

      define_method(injected_methods) do |include_super = true|
        injecting_class.send(injected_methods, include_super)
      end

      define_singleton_method(injected_methods) do |include_super = true|
        unless injecting_class.instance_variable_defined?(injected_methods_ivar)
          injecting_class.instance_variable_set(injected_methods_ivar, [injected_methods])
        end

        if include_super && injecting_class.superclass.respond_to?(injected_methods)
          return [*injecting_class.instance_variable_get(injected_methods_ivar),
                  *injecting_class.superclass.send(injected_methods, include_super)].uniq
        end

        injecting_class.instance_variable_get(injected_methods_ivar)
      end
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
    #
    # Also defines both an instance and singleton helper method `injected_methods(include_super = true)`,
    # which tracks injected dependencies regardless of whether the dependency was injected on the instance or class.
    # It includes itself as one of the injected methods (i.e. `injected_methods` will be present).
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

      injected_methods = :injected_methods
      injected_methods_ivar = :"@#{injected_methods}"

      unless injecting_class.instance_variable_defined?(injected_methods_ivar)
        injecting_class.instance_variable_set(injected_methods_ivar, [injected_methods])
      end
      injecting_class.instance_variable_get(injected_methods_ivar).append(dependency, setter)

      define_method(injected_methods) do |include_super = true|
        injecting_class.send(injected_methods, include_super)
      end

      define_singleton_method(injected_methods) do |include_super = true|
        unless injecting_class.instance_variable_defined?(injected_methods_ivar)
          injecting_class.instance_variable_set(injected_methods_ivar, [injected_methods])
        end

        if include_super && injecting_class.superclass.respond_to?(injected_methods)
          return [*injecting_class.instance_variable_get(injected_methods_ivar),
                  *injecting_class.superclass.send(injected_methods, include_super)].uniq
        end

        injecting_class.instance_variable_get(injected_methods_ivar)
      end
    end
  end
end
