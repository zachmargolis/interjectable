# frozen_string_literal: true

module Interjectable
  module ClassMethods
    BLANK = Object.new

    SuperclassInjectStatic = Struct.new(:klass, :dependency) do
      def override(value, &setter)
        var = ::Interjectable::ClassMethods::BLANK
        klass.define_singleton_method(dependency) do
          return var if var != ::Interjectable::ClassMethods::BLANK

          var = value != ::Interjectable::ClassMethods::BLANK ? value : instance_eval(&setter)
        end

        klass.define_singleton_method("#{dependency}=") do |new_value|
          var = new_value
        end
      end

      def restore
        klass.singleton_class.remove_method(dependency)
        klass.singleton_class.remove_method("#{dependency}=")
      end
    end

    class InjectStatic < SuperclassInjectStatic
      def override(*)
        @getter = klass.singleton_method(dependency)
        @setter = klass.singleton_method("#{dependency}=")
        super
      end

      def restore
        klass.define_singleton_method(dependency, @getter)
        klass.define_singleton_method("#{dependency}=", @setter)
      end
    end

    SuperclassInject = Struct.new(:klass, :dependency) do
      def override(value, &setter)
        ivar = "@#{dependency}"
        klass.send(:define_method, dependency) do
          if instance_variable_defined?(ivar)
            instance_variable_get(ivar)
          else
            instance_variable_set(ivar, value != ::Interjectable::ClassMethods::BLANK ? value : instance_eval(&setter))
          end
        end
      end

      def restore
        klass.remove_method(dependency)
      end
    end

    class Inject < SuperclassInject
      def override(*)
        @getter = klass.instance_method(dependency)
        super
      end

      def restore
        klass.send(:define_method, dependency, @getter)
      end
    end

    RESTORE_HOOKS = Hash.new { |h, k| h[k] = [] }
    private_constant :Inject, :SuperclassInject, :InjectStatic, :SuperclassInjectStatic, :RESTORE_HOOKS

    def test_inject(dependency, &setter)
      unless setter
        raise ArgumentError, "missing setter #{dependency.inspect}, correct usage: #test_inject(#{dependency.inspect}) { FakeDependency.new }"
      end
      rspec_example_group = setter.binding.receiver.class

      ClassMethods.test_inject(rspec_example_group, self, dependency, BLANK, &setter)
    end

    def self.test_inject(rspec_example_group, target, dependency, value, &setter)
      unless value || setter
        raise ArgumentError, "missing value or setter for #{target}'s #{dependency.inspect}"
      end

      unless rspec_example_group < RSpec::Core::ExampleGroup
        raise "#test_inject can only be called from an RSpec ExampleGroup (e.g.: it, before, after)"
      end

      injector =
        if target.singleton_methods(false).include?(dependency) # inject_static(dependency) on this class
          InjectStatic.new(target, dependency)
        elsif target.singleton_methods.include?(dependency) # inject_static(dependency) on a superclass of this class
          SuperclassInjectStatic.new(target, dependency)
        elsif target.instance_methods(false).include?(dependency) # inject(dependency) on this class
          Inject.new(target, dependency)
        elsif target.instance_methods.include?(dependency) # inject(dependency) on a superclass of this class
          SuperclassInject.new(target, dependency)
        else
          raise ArgumentError, "tried to override a non-existent dependency: #{dependency.inspect}"
        end

      injector.override(value, &setter)

      scope = rspec_example_group.currently_executing_a_context_hook? ? :context : :each

      key = [target, dependency, scope]
      # If we already have a restore after(:each) hook for this class +
      # dependency + scope, don't add another. To check if we already have an
      # after(:each) hook, we look at all previous after(:each) hooks we've
      # registered and see if we are currently in a subclass (i.e. we are
      # nested within) of any of them.
      #
      # We don't need to guard against multiple after(:context / :all) hooks
      # for the same #test_inject call since those before hooks only run once,
      # and therefore only setup a single after hook.
      return if scope == :each && RESTORE_HOOKS[key].any? { |group| rspec_example_group <= group }

      RESTORE_HOOKS[key] << rspec_example_group

      rspec_example_group.after(scope) do
        injector.restore
      end
    end
  end

  module RSpecHelper
    def test_inject(target, dependency, value)
      unless value
        raise ArgumentError, "missing value for #{dependency.inspect}, correct usage: test_inject(my_thing, #{dependency.inspect}, FakeDependency.new)"
      end

      ClassMethods.test_inject(self.class, target, dependency, value)
    end
  end
end

if defined?(RSpec)
  RSpec.configure do |c|
    c.include(Interjectable::RSpecHelper)
  end
else
  raise "RSpec helper was required but RSpec has not been defined"
end
