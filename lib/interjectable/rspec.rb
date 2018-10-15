# frozen_string_literal: true

module Interjectable
  module ClassMethods
    class SuperclassInjectStatic < Struct.new(:klass, :dependency)
      def override(setter)
        cvar = "@@#{dependency}"
        klass.remove_class_variable(cvar) if klass.class_variable_defined?(cvar)
        klass.define_singleton_method(dependency) do
          if class_variable_defined?(cvar)
            class_variable_get(cvar)
          else
            class_variable_set(cvar, instance_eval(&setter))
          end
        end
      end

      def restore
        cvar = "@@#{dependency}"
        klass.remove_class_variable(cvar) if klass.class_variable_defined?(cvar)
        klass.singleton_class.remove_method(dependency)
      end
    end

    class InjectStatic < SuperclassInjectStatic
      def override(*)
        @meth = klass.singleton_method(dependency)
        super
      end

      def restore
        cvar = "@@#{dependency}"
        klass.remove_class_variable(cvar) if klass.class_variable_defined?(cvar)
        klass.define_singleton_method(dependency, @meth)
      end
    end

    class SuperclassInject < Struct.new(:klass, :dependency)
      def override(setter)
        ivar = "@#{dependency}"
        klass.define_method(dependency) do
          if instance_variable_defined?(ivar)
            instance_variable_get(ivar)
          else
            instance_variable_set(ivar, instance_eval(&setter))
          end
        end
      end

      def restore
        klass.remove_method(dependency)
      end
    end

    class Inject < SuperclassInject
      def override(*)
        @meth = klass.instance_method(dependency)
        super
      end

      def restore
        klass.define_method(dependency, @meth)
      end
    end

    RESTORE_HOOKS = Hash.new { |h, k| h[k] = [] }
    private_constant :Inject, :SuperclassInject, :InjectStatic, :SuperclassInjectStatic, :RESTORE_HOOKS

    def test_inject(dependency, &setter)
      unless setter
        raise ArgumentError, "missing setter #{dependency.inspect}, correct usage: #test_inject(#{dependency.inspect}) { FakeDependency.new }"
      end
      rspec_example_group = setter.binding.receiver.class

      unless rspec_example_group < RSpec::Core::ExampleGroup
        raise "#test_inject can only be called from an RSpec ExampleGroup (e.g.: it, before, after)"
      end

      injector = if singleton_methods(false).include?(dependency) # inject_static(dependency) on this class
        InjectStatic.new(self, dependency)
      elsif singleton_methods.include?(dependency) # inject_static(dependency) on a superclass of this class
        SuperclassInjectStatic.new(self, dependency)
      elsif instance_methods(false).include?(dependency) # inject(dependency) on this class
        Inject.new(self, dependency)
      elsif instance_methods.include?(dependency) # inject(dependency) on a superclass of this class
        SuperclassInject.new(self, dependency)
      else
        raise ArgumentError, "tried to override a non-existent dependency: #{dependency.inspect}"
      end

      injector.override(setter)

      scope = rspec_example_group.currently_executing_a_context_hook? ? :context : :each

      key = [self, dependency, scope]
      # if dependency == :dependency && scope == :each
      #   puts "override: #{key.inspect} #{rspec_example_group}"
      # end

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
      # if dependency == :dependency && scope == :each
      #   puts "adding new after=#{key.inspect} hooks=#{RESTORE_HOOKS[key]} group=#{rspec_example_group}"
      # end
      RESTORE_HOOKS[key] << rspec_example_group

      # if dependency == :dependency && scope == :each
      #   puts RESTORE_HOOKS.select { |(_, d, s)| d == :dependency && s == :each }
      # end

      rspec_example_group.after(scope) do
        # if dependency == :dependency && scope == :each
        #   puts "restore:  #{key.inspect} #{rspec_example_group}"
        # end
        injector.restore
      end
    end
  end
end
