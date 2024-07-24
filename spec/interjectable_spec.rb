# frozen_string_literal: true

require 'spec_helper'

describe Interjectable do
  shared_examples_for "an interjectable class" do
    let(:instance) { klass.new }

    describe "#inject" do
      before do
        klass.inject(:some_dependency) { :service }
      end

      it "doesn't have #inject as an instance method" do
        expect { instance.inject(:some_dependency) { :service } }.to raise_error(NameError)
      end

      it "adds an instance method getter and setter" do
        instance.some_dependency = 'aaa'
        expect(instance.some_dependency).to eq('aaa')
      end

      it "lazy-loads the default block" do
        expect(instance.instance_variable_get("@some_dependency")).to be_nil
        expect(instance.some_dependency).to eq(:service)
        expect(instance.instance_variable_get("@some_dependency")).not_to be_nil
      end

      it "allows transitive dependencies (via instance_eval)" do
        klass.inject(:first_dependency) { second_dependency }
        klass.inject(:second_dependency) { :value }

        expect(instance.first_dependency).to eq(:value)
      end

      it "calls dependency block once, even with a falsy value" do
        count = 0;
        klass.inject(:some_falsy_dependency) { count += 1; nil }

        2.times { expect(instance.some_falsy_dependency).to be_nil }
        expect(count).to eq(1)
      end

      it "errors when injecting the same dependency multiple times" do
        expect { klass.inject(:some_dependency) { :some_other_value } }
          .to raise_error(Interjectable::MethodAlreadyDefined)
      end

      it "errors when there is an instance method with the same name already defined" do
        klass.class_eval do
          define_method(:duplicate_dependency) { :the_method }
        end
        expect(instance.duplicate_dependency).to eq(:the_method)
        expect { klass.inject(:duplicate_dependency) { :some_other_value } }
          .to raise_error(Interjectable::MethodAlreadyDefined)
      end

      it "allows you to inject a non static default" do
        klass.module_eval { attr_accessor :foo }
        klass.inject(:good_dependency) { foo }
        instance.foo = 2
        expect(instance.good_dependency).to eq(2)
      end

      context "with a dependency on another class" do
        before do
          expect(defined?(SomeOtherClass)).to be_falsey

          klass.inject(:some_other_class) { SomeOtherClass.new }
        end

        it "does not need to load that class (can be stubbed away)" do
          instance.some_other_class = :fake_other_class

          expect(instance.some_other_class).to eq(:fake_other_class)
        end
      end

      context "with a subclass" do
        let(:subclass) { Class.new(klass) }
        let(:subclass_instance) { subclass.new }

        it "does not error if the method exists on the superclass" do
          subclass.inject(:some_dependency) { :some_other_value }
          expect(subclass_instance.some_dependency).to eq(:some_other_value)
        end

        it "allows injection on the subclass without injecting on the superclass" do
          subclass.inject(:subclass_dependency) { :brand_new_value }
          expect(subclass_instance.subclass_dependency).to eq(:brand_new_value)
          expect { instance.subclass_dependency }.to raise_error(NoMethodError)
        end

        context "with a chain of subclasses" do
          let(:lower_subclass) { Class.new(subclass) }
          let(:lower_subclass_instance) { lower_subclass.new }

          it "retrieves injected methods from all ancestors when requested" do
            subclass.inject(:subclass_dependency) { :subclass_value }
            lower_subclass.inject(:lower_subclass_dependency) { :lower_subclass_value }
          end
        end
      end
    end

    describe "#inject_static" do
      let(:other_instance) { klass.new }

      before do
        klass.inject_static(:static_dependency) { :some_value }
      end

      it "doesn't have #inject_static as an instance method" do
        expect { instance.inject_static(:static_dependency) { :some_value } }.to raise_error(NameError)
      end

      it "adds an instance method and setter" do
        instance.static_dependency = 'aaa'
        expect(instance.static_dependency).to eq('aaa')
      end

      it "adds a class method and setter" do
        klass.static_dependency = 'aaa'
        expect(klass.static_dependency).to eq('aaa')
      end

      it "shares a value across all instances of a class" do
        instance.static_dependency = 'bbb'
        expect(other_instance.static_dependency).to eq('bbb')
        expect(klass.static_dependency).to eq('bbb')
      end

      it "calls its dependency block once across all instances" do
        count = 0;
        klass.inject_static(:falsy_static_dependency) { count += 1; nil }

        expect(instance.falsy_static_dependency).to be_nil
        expect(other_instance.falsy_static_dependency).to be_nil
        expect(klass.falsy_static_dependency).to be_nil

        expect(count).to eq(1)
      end

      it "errors when inject_static-ing a dependency multiple times" do
        expect { klass.inject_static(:static_dependency) { :some_other_value } }
          .to raise_error(Interjectable::MethodAlreadyDefined)
      end

      it "errors when there is an instance method with the same name already defined" do
        klass.class_eval do
          define_method(:duplicate_static_dependency) { :the_method }
        end
        expect(instance.duplicate_static_dependency).to eq(:the_method)
        expect { klass.inject_static(:duplicate_static_dependency) { :some_other_value } }
          .to raise_error(Interjectable::MethodAlreadyDefined)
      end

      it "errors when there is a class method with the same name already defined" do
        klass.class_eval do
          define_singleton_method(:duplicate_static_dependency) { :the_method }
        end
        expect(klass.duplicate_static_dependency).to eq(:the_method)
        expect { klass.inject_static(:duplicate_static_dependency) { :some_other_value } }
          .to raise_error(Interjectable::MethodAlreadyDefined)
      end

      it "errors if you inject a non static default" do
        klass.module_eval { attr_accessor :foo }
        klass.inject_static(:bad_dependency) { foo }
        expect { instance.bad_dependency }.to raise_error(NameError)
        expect { klass.bad_dependency }.to raise_error(NameError)
      end

      context "with a subclass" do
        let(:subclass) { Class.new(klass) }
        let(:subclass_instance) { subclass.new }

        it "shares its values with its superclass" do
          instance.static_dependency = 'ccc'
          expect(subclass_instance.static_dependency).to eq('ccc')
          expect(subclass.static_dependency).to eq('ccc')
        end

        it "does not error if the method exists on the super klass" do
          subclass.inject_static(:static_dependency) { :some_other_value }
          expect(subclass_instance.static_dependency).to eq(:some_other_value)
          expect(subclass.static_dependency).to eq(:some_other_value)
        end

        it "does not error when lazily setting the dep from a subclass first" do
          expect(subclass.static_dependency).to eq(:some_value)
          expect(klass.static_dependency).to eq(:some_value)
          expect(subclass.static_dependency).to eq(:some_value)
        end

        it "only defines the class variable on the injecting class" do
          expect(subclass.static_dependency).to eq(:some_value)
          expect(klass.class_variable_get(:@@static_dependency)).to eq(:some_value)
        end

        it "allows injection on the subclass without injecting on the superclass" do
          subclass.inject_static(:static_subclass_dependency) { :brand_new_value }
          expect(subclass_instance.static_subclass_dependency).to eq(:brand_new_value)
          expect { klass.static_subclass_dependency }.to raise_error(NoMethodError)
          expect { instance.static_subclass_dependency }.to raise_error(NoMethodError)
        end

        context "with a chain of subclasses" do
          let(:lower_subclass) { Class.new(subclass) }
          let(:lower_subclass_instance) { lower_subclass.new }

          it "retrieves injected methods from all ancestors when requested" do
            subclass.inject_static(:static_subclass_dependency) { :subclass_value }
            lower_subclass.inject_static(:static_lower_subclass_dependency) { :lower_subclass_value }
          end
        end
      end
    end

    describe "#injected_methods" do
      before do
        klass.inject(:a) { :a }
        klass.inject_static(:b) { :b }
      end

      it "lists injected methods on the instance and static ones too" do
        injected_methods = instance.injected_methods

        expect(injected_methods).to match_array(
          [
            :injected_methods, :a, :a=, :b, :b=,
          ],
        )
      end

      context "with a subclass" do
        let(:subclass) do
          Class.new(klass) do
            inject(:c) { :c }
          end
        end
        let(:include_super) { true }
        let(:subclass_instance) { subclass.new }

        it "includes super methods by default" do
          injected_methods = subclass_instance.injected_methods(include_super)

          expect(injected_methods).to match_array(
            [
              :injected_methods,
              :a,
              :a=,
              :b,
              :b=,
              :c,
              :c=,
            ],
          )
        end

        context "with include_super = false" do
          let(:include_super) { false }

          it "does not include super methods" do
            injected_methods = subclass_instance.injected_methods(include_super)

            expect(injected_methods).to_not include(:a)
            expect(injected_methods).to_not include(:a=)
            expect(injected_methods).to_not include(:b)
            expect(injected_methods).to_not include(:b=)

            expect(injected_methods).to match_array(
              [
                :injected_methods,
                :c,
                :c=,
              ],
            )
          end
        end
      end
    end

    describe ".injected_methods" do
      before do
        klass.inject(:a) { :a }
        klass.inject_static(:b) { :b }
      end

      it "lists static injected methods class" do
        injected_methods = klass.injected_methods

        expect(injected_methods).to match_array(
          [
            :injected_methods, :b, :b=,
          ],
        )
        expect(injected_methods).to_not include(:a)
        expect(injected_methods).to_not include(:a=)
      end

      context "with a subclass" do
        let(:subclass) do
          Class.new(klass) do
            inject(:c) { :c }
            inject_static(:d) { :d }
          end
        end
        let(:include_super) { true }

        it "includes super methods by default" do
          injected_methods = subclass.injected_methods(include_super)

          expect(injected_methods).to match_array(
            [
              :injected_methods,
              :b,
              :b=,
              :d,
              :d=
            ],
          )
          expect(injected_methods).to_not include(:a), 'skips instance methods'
          expect(injected_methods).to_not include(:a=), 'skips instance methods'
          expect(injected_methods).to_not include(:c), 'skips instance methods'
          expect(injected_methods).to_not include(:c=), 'skips instance methods'
        end

        context "with include_super = false" do
          let(:include_super) { false }

          it "does not include super methods" do
            injected_methods = subclass.injected_methods(include_super)

            expect(injected_methods).to_not include(:a), 'skips instance methods'
            expect(injected_methods).to_not include(:a=), 'skips instance methods'
            expect(injected_methods).to_not include(:b), 'skips super methods'
            expect(injected_methods).to_not include(:b=), 'skips super methods'
            expect(injected_methods).to_not include(:c), 'skips instance methods'
            expect(injected_methods).to_not include(:c=), 'skips instance methods'

            expect(injected_methods).to match_array(
              [
                :injected_methods,
                :d,
                :d=,
              ],
            )
          end
        end
      end
    end
  end

  context "when extended" do
    let(:klass) { Class.new { extend Interjectable } }

    it_should_behave_like "an interjectable class"
  end

  context "when included" do
    let(:klass) { Class.new { include Interjectable } }

    it_should_behave_like "an interjectable class"
  end
end
