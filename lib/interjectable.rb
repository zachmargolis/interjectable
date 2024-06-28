# frozen_string_literal: true

require "interjectable/version"

module Interjectable
  MethodAlreadyDefined = Class.new(StandardError)

  INJECTED_METHODS = :injected_methods
  INJECTED_METHODS_IVAR = :"@#{INJECTED_METHODS}"

  def self.included(mod)
    mod.send(:extend, ClassMethods)
    set_inherited_injected_methods(mod)
  end

  def self.extended(mod)
    mod.send(:extend, ClassMethods)
    set_inherited_injected_methods(mod)
  end

  private

  # Defines both an instance and singleton helper method `injected_methods` to track injected dependencies.
  #
  # The `injected_methods` helper method:
  # - does not differentiate between dependencies injected on instances vs. classes
  # - passes injected methods from a superclass to its subclasses, but not vice versa
  # - includes itself as one of the injected methods (i.e. :injected_methods will be present)
  def self.set_inherited_injected_methods(mod)
    mod.class_eval do
      def self.inherited(subclass)
        super
        subclass.instance_variable_set(INJECTED_METHODS_IVAR,
                                       instance_variable_get(INJECTED_METHODS_IVAR) || [INJECTED_METHODS])
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

      setter = :"#{dependency}="
      if instance_variable_defined?(INJECTED_METHODS_IVAR)
        instance_variable_set(INJECTED_METHODS_IVAR,
                              (instance_variable_get(INJECTED_METHODS_IVAR) + [dependency, setter]).uniq)
      else
        instance_variable_set(INJECTED_METHODS_IVAR, [INJECTED_METHODS, dependency, setter])
      end

      injecting_class = self

      define_method(INJECTED_METHODS) do
        injecting_class.instance_variable_get(INJECTED_METHODS_IVAR)
      end

      define_singleton_method(INJECTED_METHODS) do
        injecting_class.instance_variable_get(INJECTED_METHODS_IVAR)
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

      if injecting_class.instance_variable_defined?(INJECTED_METHODS_IVAR)
        injecting_class.instance_variable_set(INJECTED_METHODS_IVAR,
          (injecting_class.instance_variable_get(INJECTED_METHODS_IVAR) + [dependency, setter]).uniq)
      else
        injecting_class.instance_variable_set(INJECTED_METHODS_IVAR, [INJECTED_METHODS, dependency, setter])
      end

      define_method(INJECTED_METHODS) do
        injecting_class.instance_variable_get(INJECTED_METHODS_IVAR)
      end

      define_singleton_method(INJECTED_METHODS) do
        injecting_class.instance_variable_get(INJECTED_METHODS_IVAR)
      end
    end
  end
end
